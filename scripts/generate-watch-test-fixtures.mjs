import fs from 'node:fs';
import { loadConfig } from './validate-config.mjs';
import { matches, normalize, onwardStops } from '../backend/src/normalize.mjs';
const root = new URL('../', import.meta.url);
const samples = JSON.parse(fs.readFileSync(new URL('tests/fixtures/live-2026-11-28.json', root)));
const cfg = loadConfig();
const mc = x => x === null ? 'null' : typeof x === 'object' ? Array.isArray(x) ? `[${x.map(mc).join(',')}]` : `{${Object.entries(x).filter(([,v])=>v!==undefined).map(([k,v])=>`${JSON.stringify(k)}=>${mc(v)}`).join(',')}}` : JSON.stringify(x);
const stationMap = new Map(cfg.profiles.flatMap(p=>p.stations).map(s=>[s.key,s]));
const stop = s => s && ({gid:s.gid,platform:s.platform,stopArea:s.stopArea && {gid:s.stopArea.gid}});
const fixtures=samples.map(s=>{
  const station=stationMap.get(s.stationKey), d=s.departure;
  const raw={...d,stopPoint:stop(d.stopPoint),serviceJourney:{gid:d.serviceJourney.gid,direction:d.serviceJourney.direction,directionDetails:d.serviceJourney.directionDetails,line:{name:d.serviceJourney.line.name,shortName:d.serviceJourney.line.shortName}}};
  const expected=normalize(raw,station);
  return {raw,stationKey:s.stationKey,expected:{line:expected.line,destination:expected.destination,departureEpoch:expected.departureEpoch,delayMinutes:expected.delayMinutes},matches:station.criteria.map(r=>matches(raw,r,null)),onward:onwardStops(s.details,d),details:{serviceJourneys:s.details.serviceJourneys.map(j=>({gid:j.gid,callsOnServiceJourney:j.callsOnServiceJourney.map(c=>({...c,stopPoint:stop(c.stopPoint)}))}))}};
});
fs.writeFileSync(new URL('garmin/tests/LiveFixtures.mc',root),`// Generated real traffic snapshots for TEST TARGET ONLY.\n(:test)\nmodule LiveFixtures { const DATA=${mc(fixtures)}; }\n`);
