import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import Ajv2020 from 'ajv/dist/2020.js';

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const schema = JSON.parse(readFileSync(resolve(root, 'config/profiles.schema.json'), 'utf8'));
const schemaCheck = new Ajv2020({ allErrors: true, strict: false }).compile(schema);
export const loadConfig = (path = resolve(root, "config/profiles.json")) =>
  JSON.parse(readFileSync(path, "utf8"));

export function validateConfig(config, { production = false } = {}) {
  if (!schemaCheck(config)) return schemaCheck.errors.map(e => `${e.instancePath}: ${e.message}`);
  const errors = [];
  const fail = (p, message) => errors.push(p + ": " + message);
  const unique = (xs, path) => {
    const seen = new Set();
    for (const x of xs) {
      if (!x || typeof x !== "string") fail(path, "ID must be a nonempty string");
      else if (seen.has(x)) fail(path, "duplicate ID: " + x);
      seen.add(x);
    }
  };
  if (config?.schemaVersion !== 2) fail("schemaVersion", "expected 2");
  const profiles = config?.profiles;
  if (!Array.isArray(profiles) || profiles.length < 1) {
    fail("profiles", "at least one profile is required");
    return errors;
  }
  unique(profiles.map(p => p.id), "profiles");
  if (!profiles.some(p => p.id === config?.defaults?.startupProfile)) {
    fail("defaults.startupProfile", "must refer to an existing profile");
  }
  if (!Number.isInteger(config?.defaults?.maxUpcomingDepartures) || config.defaults.maxUpcomingDepartures < 1) {
    fail("defaults.maxUpcomingDepartures", "must be a positive integer");
  }
  for (const key of ['searchHorizonMinutes', 'cacheTtlSeconds', 'staleAfterSeconds']) {
    if (!Number.isInteger(config.defaults[key]) || config.defaults[key] < 1) fail('defaults.' + key, 'positive integer required');
  }
  if (config.defaults.cacheTtlSeconds > config.defaults.staleAfterSeconds) fail('defaults', 'cache TTL exceeds stale threshold');
  if (config.defaults.searchHorizonMinutes > 1440) fail('defaults', 'search horizon exceeds 24 hours');
  for (const profile of profiles) {
    const pp = "profiles." + profile.id;
    if (!profile.label || typeof profile.label !== "string") fail(pp + ".label", "required");
    if (!Array.isArray(profile.stations) || !profile.stations.length) {
      fail(pp + ".stations", "at least one station required");
      continue;
    }
    unique(profile.stations.map(st => st.key), pp + ".stations");
    for (const st of profile.stations) {
      const sp = pp + ".stations." + st.key;
      if (!st.name || !st.shortLabel) fail(sp, "name and shortLabel required");
      if (production && !/^9021\d{12}$/.test(st.stopAreaGid ?? '')) fail(sp + ".stopAreaGid", "verified StopArea GID required in production");
      if (!Array.isArray(st.criteria) || !st.criteria.length) {
        fail(sp + ".criteria", "at least one criterion required");
        continue;
      }
      unique(st.criteria.map(c => c.id), sp + ".criteria");
      for (const c of st.criteria) {
        const cp = sp + ".criteria." + c.id;
        if (!Array.isArray(c.lineNames) || !c.lineNames.length) fail(cp + ".lineNames", "line list required");
        if (!c.direction || !Array.isArray(c.direction.headsignHints)) {
          fail(cp + ".direction", "object and headsignHints required");
          continue;
        }
        if (production && c.enabled !== false) {
          if (c.direction.verificationStatus !== "verified") fail(cp + ".direction", "pending verification");
          const d = c.direction;
          const structured = ["allowedDirectionGids", "allowedStopPointGids", "allowedPlatforms", "mustPassStopAreaGids"];
          if (!structured.some(k => Array.isArray(d[k]) && d[k].length)) {
            fail(cp + ".direction", "production rule needs a verified structured direction selector");
          }
          if (!d.verifiedAt || Number.isNaN(Date.parse(d.verifiedAt))) fail(cp + ".direction.verifiedAt", "valid ISO timestamp required");
          if (!d.verificationNote?.trim()) fail(cp + '.direction.verificationNote', 'verification evidence required');
          for (const key of ['allowedDirectionGids', 'allowedStopPointGids', 'mustPassStopAreaGids']) {
            const pattern = key === 'allowedStopPointGids' ? /^9022\d{12}$/ : /^9021\d{12}$/;
            if (d[key].some(id => !pattern.test(id))) fail(cp + '.' + key, 'invalid GID');
          }
        }
      }
    }
  }
  return errors;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const production = process.argv.includes("--production");
  const errors = validateConfig(loadConfig(), { production });
  if (errors.length) {
    process.stderr.write("Configuration invalid:\n" + errors.map(x => " - " + x).join("\n") + "\n");
    process.exitCode = 1;
  } else {
    process.stdout.write("OK: profile configuration structure" + (production ? " and production readiness" : "") + "\n");
  }
}
