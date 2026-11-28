import { mkdirSync, writeFileSync } from 'node:fs';
import { loadConfig, validateConfig } from './validate-config.mjs';
import { TokenProvider } from '../backend/src/token.mjs';
import { VasttrafikClient } from '../backend/src/client.mjs';
import { DepartureService } from '../backend/src/service.mjs';
const config = loadConfig();
const errors = validateConfig(config, { production: true });
if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
else {
  const client = new VasttrafikClient(process.env, new TokenProvider(process.env));
  const service = new DepartureService(config, client);
  const directory = new URL('../backend/evidence/', import.meta.url);
  mkdirSync(directory, { recursive: true });
  try {
    for (const profile of config.profiles) {
      const response = await service.get(profile.id);
      writeFileSync(new URL(`live-${profile.id}.json`, directory), JSON.stringify(response, null, 2));
      console.log(`${profile.label}: ${response.departures.length} verkliga avgångar hämtade. Jämför riktning/tider med Västtrafik.`);
    }
  } catch (e) { console.error(e.code ?? 'UPSTREAM_UNAVAILABLE'); process.exitCode = 1; }
}
