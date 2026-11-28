export const epoch = s => typeof s === 'string' && Number.isFinite(Date.parse(s)) ? Math.floor(Date.parse(s)/1000) : null;
export const departureTime = x => epoch(x.estimatedOtherwisePlannedDepartureTime ?? x.estimatedDepartureTime ?? x.plannedDepartureTime ?? x.estimatedOtherwisePlannedTime ?? x.plannedTime);
export const arrivalTime = x => epoch(x.estimatedOtherwisePlannedArrivalTime ?? x.estimatedArrivalTime ?? x.plannedArrivalTime ?? x.estimatedOtherwisePlannedTime ?? x.plannedTime);
export const cancelled = x => x.isDepartureCancelled === true || x.isCancelled === true || x.isPartCancelled === true;
const lineOf = x => x.serviceJourney?.line?.designation ?? x.serviceJourney?.line?.name;
const stopName = x => x?.realtimeStopPoint?.name ?? x?.stopPoint?.name ?? x?.name ?? '';
export function verified(c) {
 const d=c.direction; return d.verificationStatus==='verified' && Boolean(d.allowedDirectionGids.length || d.allowedStopPointGids.length || d.allowedPlatforms.length || d.mustPassStopAreaGids.length);
}
export function ruleMatches(x,c,calls=[]) {
 const d=c.direction, s=x.stopPoint ?? {};
 if(!c.enabled || !verified(c) || !c.lineNames.includes(lineOf(x))) return false;
 return (!d.allowedDirectionGids.length || d.allowedDirectionGids.includes(x.serviceJourney?.directionGid ?? x.directionGid ?? calls.at(-1)?.stopPoint?.stopArea?.gid)) &&
 (!d.allowedStopPointGids.length || d.allowedStopPointGids.includes(s.gid)) &&
 (!d.allowedPlatforms.length || d.allowedPlatforms.includes(s.platform)) &&
 d.mustPassStopAreaGids.every(g=>calls.some(k=>k.stopPoint?.stopArea?.gid===g || k.stopAreaGid===g));
}
export function normalizeDeparture(x,s) {
 const t=departureTime(x), p=epoch(x.plannedDepartureTime ?? x.plannedTime);
 if(t===null || p===null || !lineOf(x) || !x.serviceJourney?.gid || !x.stopPoint?.gid) return null;
 return {id:[x.serviceJourney.gid,x.stopPoint.gid,p].join(':'),stationKey:s.key,stationLabel:s.shortLabel,line:lineOf(x),destination:x.serviceJourney.direction ?? '',departureEpoch:t,departureTime:new Date(t*1000).toISOString(),plannedTime:new Date(p*1000).toISOString(),isRealtime:Boolean(x.estimatedDepartureTime ?? x.estimatedTime),isCancelled:cancelled(x),delayMinutes:Math.round((t-p)/60),platform:x.realtimeStopPoint?.platform ?? x.stopPoint.platform ?? ''};
}
const linkStep=(x, fallback)=>({kind:'walk',line:'Gå',from:stopName(x.origin),to:stopName(x.destination),departureEpoch:departureTime(x) ?? departureTime(x.origin??{}),arrivalEpoch:arrivalTime(x) ?? arrivalTime(x.destination??{}),meters:Number.isFinite(x.distanceInMeters)?x.distanceInMeters:null,index:x.journeyLegIndex??fallback});
export function normalizeJourney(j) {
 if(cancelled(j) || !Array.isArray(j.tripLegs)) return null;
 const legs=j.tripLegs;
 if(legs.some(x=>cancelled(x)||x.origin?.isDepartureCancelled||x.destination?.isArrivalCancelled)) return null;
 const steps=legs.map((x,i)=>({kind:'ride',line:lineOf(x)??'',from:stopName(x.origin),to:stopName(x.destination),direction:x.serviceJourney?.direction??'',platform:x.origin?.realtimeStopPoint?.platform??x.origin?.stopPoint?.platform??'',departureEpoch:departureTime(x.origin??{})??departureTime(x),arrivalEpoch:arrivalTime(x.destination??{})??arrivalTime(x),index:x.journeyLegIndex??i}));
 if(steps.some(x=>!x.line || x.departureEpoch===null || x.arrivalEpoch===null)) return null;
 for(const x of j.connectionLinks??[]) steps.push(linkStep(x,0));
 if(j.departureAccessLink) steps.push(linkStep(j.departureAccessLink,-1));
 if(j.arrivalAccessLink) steps.push(linkStep(j.arrivalAccessLink,999));
 if(j.destinationLink) steps.push(linkStep(j.destinationLink,0));
 steps.sort((a,b)=>a.index-b.index);
 const start=departureTime(j)??steps[0]?.departureEpoch, end=arrivalTime(j)??steps.at(-1)?.arrivalEpoch;
 if(!steps.length || start==null || end==null || end<start) return null;
 const ride=steps.find(s=>s.kind==='ride');
 return {departureEpoch:start,arrivalEpoch:end,boardEpoch:ride?.departureEpoch??start,line:ride?.line??'Gå',boardStop:ride?.from??'',alightStop:steps.filter(s=>s.kind==='ride').at(-1)?.to??'',changes:Math.max(0,legs.length-1),walkMeters:steps.some(s=>s.kind==='walk'&&s.meters===null)?null:steps.reduce((n,s)=>n+(s.meters??0),0),steps};
}
export function rank(rows,now,limit=3) {
 const seen=new Set(); return rows.filter(x=>x && x.departureEpoch>=now-30).sort((a,b)=>a.arrivalEpoch-b.arrivalEpoch||a.changes-b.changes||a.departureEpoch-b.departureEpoch).filter(x=>{const k=JSON.stringify(x.steps);if(seen.has(k))return false;seen.add(k);return true;}).slice(0,limit);
}
export function coordinate(lat,lon) {
 if(lat==null||lon==null||String(lat).trim()===''||String(lon).trim()==='') throw Error('INVALID_POSITION');
 const a=Number(lat), b=Number(lon);
 if(!Number.isFinite(a)||!Number.isFinite(b)||Math.abs(a)>90||Math.abs(b)>180) throw Error('INVALID_POSITION');
 return {lat:a,lon:b};
}
