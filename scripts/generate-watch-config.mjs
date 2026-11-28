import { writeFileSync } from 'node:fs';
import { loadConfig, validateConfig } from './validate-config.mjs';
const config = loadConfig();
if (validateConfig(config).length) throw new Error('Invalid configuration');
const quote = s => JSON.stringify(s);
const profiles = config.profiles.map(p => `{"id" => ${quote(p.id)}, "label" => ${quote(p.label)}}`).join(', ');
writeFileSync(new URL('../garmin/source/StartupConfig.mc', import.meta.url),
  `// Generated from config/profiles.json; do not edit.\n(:glance)\nmodule StartupConfig {\n    const PROFILE = ${quote(config.defaults.startupProfile)};\n    const PROFILES = [${profiles}];\n}\n`);
