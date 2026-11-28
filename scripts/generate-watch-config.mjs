import { writeFileSync } from 'node:fs';
import { loadConfig, validateConfig } from './validate-config.mjs';
const config = loadConfig();
if (validateConfig(config).length) throw new Error('Invalid configuration');
const quote = s => JSON.stringify(s);
const profiles = config.profiles.map(p => `{"id" => ${quote(p.id)}, "label" => ${quote(p.label)}}`).join(', ');
writeFileSync(new URL('../garmin/source/StartupConfig.mc', import.meta.url),
  `// Generated from config/profiles.json; do not edit.\n(:glance)\nmodule StartupConfig {\n    const PROFILE = ${quote(config.defaults.startupProfile)};\n    const PROFILES = [${profiles}];\n}\n`);
const monkey = value => value === null ? 'null' : Array.isArray(value) ? `[${value.map(monkey).join(', ')}]` : typeof value === 'object' ? `{${Object.entries(value).map(([k,v]) => `${quote(k)} => ${monkey(v)}`).join(', ')}}` : JSON.stringify(value);
const direct = config.profiles.map(p => ({ id:p.id, label:p.label, stations:p.stations.map(s => ({key:s.key, shortLabel:s.shortLabel, stopAreaGid:s.stopAreaGid, criteria:s.criteria.map(r => ({enabled:r.enabled,lineNames:r.lineNames,direction:{verificationStatus:r.direction.verificationStatus,allowedDirectionGids:r.direction.allowedDirectionGids,allowedStopPointGids:r.direction.allowedStopPointGids,allowedPlatforms:r.direction.allowedPlatforms,mustPassStopAreaGids:r.direction.mustPassStopAreaGids}}))})) }));
writeFileSync(new URL('../garmin/source/DirectConfig.mc', import.meta.url), `// Generated public configuration, never credentials.\nmodule DirectConfig {\n const VALID = ${validateConfig(config,{production:true}).length === 0};\n const PROFILES = ${monkey(direct)};\n const HORIZON = ${config.defaults.searchHorizonMinutes};\n const LIMIT = ${config.defaults.maxUpcomingDepartures};\n const TTL = ${config.defaults.cacheTtlSeconds};\n const STALE = ${config.defaults.staleAfterSeconds};\n}\n`);
