import { mkdirSync, writeFileSync } from 'node:fs';
import { loadConfig } from './validate-config.mjs';
import { TokenProvider } from '../backend/src/token.mjs';
import { VasttrafikClient } from '../backend/src/client.mjs';
const client = new VasttrafikClient(process.env, new TokenProvider(process.env));
const config = loadConfig();
const names = [...new Set(config.profiles.flatMap(p => p.stations.map(s => s.name)))];
const directory = new URL('../backend/evidence/', import.meta.url);
mkdirSync(directory, { recursive: true });
try {
  for (const name of names) {
    const result = await client.locations(name);
    const safeName = name.replace(/[^a-zåäö0-9]/gi, '-');
    writeFileSync(new URL(`locations-${safeName}.json`, directory), JSON.stringify({ capturedAt: new Date().toISOString(), query: name, result }, null, 2));
    console.log(`Sökresultat sparat för ${name}. Kontrollera kommun, namn och GID innan konfigurationen ändras.`);
  }
} catch (e) { console.error(e.code ?? 'UPSTREAM_UNAVAILABLE'); process.exitCode = 1; }
