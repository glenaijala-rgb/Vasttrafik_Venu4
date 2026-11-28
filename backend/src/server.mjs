import http from 'node:http';
import {readFileSync} from 'node:fs';
import {timingSafeEqual} from 'node:crypto';
import {epoch,verified,ruleMatches,normalizeDeparture,normalizeJourney,rank,coordinate} from './model.mjs';
const env=process.env, cfg=JSON.parse(readFileSync(env.PROFILES_FILE||new URL('../../config/profiles.json',import.meta.url),'utf8'));
const required=['VASTTRAFIK_CLIENT_ID','VASTTRAFIK_CLIENT_SECRET','VASTTRAFIK_API_URL','VASTTRAFIK_TOKEN_URL','WATCH_ACCESS_TOKEN'];
for(const k of required) if(!env[k]) throw Error('Missing '+k);
for(const k of ['VASTTRAFIK_API_URL','VASTTRAFIK_TOKEN_URL']) if(new URL(env[k]).protocol!=='https:') throw Error('HTTPS required');
if(env.WATCH_ACCESS_TOKEN.length<32) throw Error('WATCH_ACCESS_TOKEN must be >=32 characters');
let token=null,tokenUntil=0,tokenPending=null, blockedUntil=0;
const now=()=>Math.floor(Date.now()/1000);
const fail=(code,status=502)=>Object.assign(Error(code),{status});
async function request(url,options={}) {
 if(Date.now()<blockedUntil) throw fail('RATE_LIMITED',429);
 const res=await fetch(url,{...options,redirect:'error',signal:AbortSignal.timeout(10000)});
 if(res.status===429){const v=Number(res.headers.get('retry-after'));blockedUntil=Date.now()+1000*(Number.isFinite(v)&&v>0?Math.min(300,v):60);throw fail('RATE_LIMITED',429);}
 return res;
}
async function auth(){
 if(token&&Date.now()<tokenUntil)return token;
 if(!tokenPending) tokenPending=(async()=>{
 const res=await request(env.VASTTRAFIK_TOKEN_URL,{method:'POST',headers:{Authorization:'Basic '+Buffer.from(env.VASTTRAFIK_CLIENT_ID+':'+env.VASTTRAFIK_CLIENT_SECRET).toString('base64'),'Content-Type':'application/x-www-form-urlencoded'},body:'grant_type=client_credentials'});
 if(!res.ok)throw fail('UPSTREAM_AUTH');
 const data=await res.json();if(!data.access_token)throw fail('UPSTREAM_AUTH');
 token=data.access_token;tokenUntil=Date.now()+Math.max(0,(Number(data.expires_in??300)-30)*1000);return token;
 })().finally(()=>{tokenPending=null;});
 return tokenPending;
}
async function api(path,params={}){
 const url=new URL(env.VASTTRAFIK_API_URL.replace(/\/$/,'')+'/'+path);
 for(const [k,v] of Object.entries(params))if(v!=null)url.searchParams.set(k,String(v));
 for(let i=0;i<2;i++){
 const res=await request(url,{headers:{Authorization:'Bearer '+await auth(),Accept:'application/json'}});
 if(res.status===401&&i===0){token=null;continue;}
 if(!res.ok)throw fail('UPSTREAM_UNAVAILABLE');
 return res.json();
 }throw fail('UPSTREAM_AUTH');
}
const rows=x=>{if(!Array.isArray(x.results))throw fail('UPSTREAM_SCHEMA');return x.results;};
const cache=new Map(),inflight=new Map();
async function cached(key,fn){
 const old=cache.get(key);if(old&&Date.now()-old.at<45000)return old.data;
 if(inflight.has(key))return inflight.get(key);
 const task=fn().then(data=>{if(cache.size>=128)cache.delete(cache.keys().next().value);cache.set(key,{at:Date.now(),data});return data;}).finally(()=>inflight.delete(key));
 inflight.set(key,task);return task;
}
async function departures(id){
 const p=cfg.profiles.find(x=>x.id===id);if(!p)throw fail('INVALID_PROFILE',400);
 for(const s of p.stations)if(!/^\d{16}$/.test(s.stopAreaGid??'')||s.criteria.some(c=>c.enabled&&!verified(c)))throw fail('CONFIG_INCOMPLETE',503);
 return cached('dep:'+id,async()=>{
 const all=await Promise.all(p.stations.map(async s=>{
 const result=await api('stop-areas/'+s.stopAreaGid+'/departures',{limit:100,timeSpanInMinutes:cfg.defaults.searchHorizonMinutes});
 const out=[];
 for(const x of rows(result)){
 const candidates=s.criteria.filter(c=>c.enabled&&c.lineNames.includes(x.serviceJourney?.line?.designation??x.serviceJourney?.line?.name));
 if(!candidates.length)continue;
 let calls=[];
 if(candidates.some(c=>c.direction.mustPassStopAreaGids.length || c.direction.allowedDirectionGids.length)){
 if(!x.detailsReference)continue;
 const d=await api('stop-areas/'+s.stopAreaGid+'/departures/'+encodeURIComponent(x.detailsReference)+'/details',{includes:'servicejourneycalls'});
 calls=d.serviceJourneyCalls??d.serviceJourney?.calls??[];
 // Only downstream calls may satisfy via-rules.
 const at=calls.findIndex(c=>c.stopPoint?.gid===x.stopPoint?.gid);
 if(at<0)continue;calls=calls.slice(at);
 }
 if(candidates.some(c=>ruleMatches(x,c,calls))){const d=normalizeDeparture(x,s);if(d&&d.departureEpoch>=now()-30)out.push(d);}
 }
 return out;
 }));
 const unique=[...new Map(all.flat().map(d=>[d.id,d])).values()].sort((a,b)=>a.departureEpoch-b.departureEpoch).slice(0,cfg.defaults.maxUpcomingDepartures);
 return {schemaVersion:1,profileId:id,generatedAt:new Date().toISOString(),generatedEpoch:now(),timezone:'Europe/Stockholm',isPartial:false,departures:unique};
 });
}
function getHome(){
 try{return coordinate(env.HOME_LAT,env.HOME_LON);}catch{throw fail('HOME_CONFIG_INCOMPLETE',503);}
}
async function journeys(q){
 const home=getHome();let origin;
 if(q.has('originKey')){
 const station=cfg.profiles.flatMap(p=>p.stations).find(s=>s.key===q.get('originKey'));
 if(!station||!/^\d{16}$/.test(station.stopAreaGid??''))throw fail('ORIGIN_CONFIG_INCOMPLETE',503);
 origin={originGid:station.stopAreaGid};
 }else{
 let c;try{c=coordinate(q.get('lat'),q.get('lon'));}catch{throw fail('INVALID_POSITION',400);}
 origin={originLatitude:c.lat,originLongitude:c.lon};
 }
 // Location-based results deliberately not persisted or globally cached.
 const data=await api('journeys',{...origin,destinationLatitude:home.lat,destinationLongitude:home.lon,originWalk:'1,,',destWalk:'1,,',limit:8});
 const options=rank(rows(data).map(normalizeJourney),now(),3);
 if(rows(data).length&&!options.length && rows(data).some(j=>!j.isCancelled&&!j.isDeparted))throw fail('NO_VALID_JOURNEYS',502);
 return {schemaVersion:1,generatedEpoch:now(),destinationLabel:'Hem',journeys:options};
}
const rate={start:0,count:0};let busy=0;
const equal=(a,b)=>{const x=Buffer.from(a),y=Buffer.from(b);return x.length===y.length&&timingSafeEqual(x,y);};
const send=(res,status,data)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
http.createServer(async(req,res)=>{
 let slot=false;
 try{
 const u=new URL(req.url,'http://localhost');
 if(req.method!=='GET')throw fail('METHOD_NOT_ALLOWED',405);
 if(u.pathname==='/health')return send(res,200,{ok:true});
 if(!equal(req.headers.authorization??'','Bearer '+env.WATCH_ACCESS_TOKEN))throw fail('UNAUTHORIZED',401);
 if(Date.now()-rate.start>60000){rate.start=Date.now();rate.count=0;}
 if(++rate.count>20||busy>=3)throw fail('RATE_LIMITED',429);
 busy++;slot=true;
 if(u.pathname==='/api/v1/departures')return send(res,200,await departures(u.searchParams.get('profile')));
 if(u.pathname==='/api/v1/journeys/home')return send(res,200,await journeys(u.searchParams));
 if(u.pathname==='/api/v1/origins')return send(res,200,{origins:cfg.profiles.flatMap(p=>p.stations).filter(s=>/^\d{16}$/.test(s.stopAreaGid??'')).map(s=>({key:s.key,label:s.name}))});
 throw fail('NOT_FOUND',404);
 }catch(e){send(res,e.status??502,{error:e.status?e.message:'UPSTREAM_UNAVAILABLE'});}
 finally{if(slot)busy--;}
}).listen(Number(env.PORT??8080),env.HOST??'127.0.0.1');
