import test from "node:test";
import assert from "node:assert/strict";
import { loadConfig, validateConfig } from "../scripts/validate-config.mjs";

test("the versioned profile structure is valid", () => {
  assert.deepEqual(validateConfig(loadConfig()), []);
});
test("home contains two different stations; job contains two bus criteria", () => {
  const cfg = loadConfig();
  const home = cfg.profiles.find(p => p.id === "home");
  const job = cfg.profiles.find(p => p.id === "work");
  assert.deepEqual(home.stations.map(s => s.key), ["wennerbergsgatan", "toltorpsskolan"]);
  assert.deepEqual(job.stations[0].criteria.map(c => c.lineNames[0]), ["78", "173"]);
});
test("production must not start with unverified stop IDs or direction selectors", () => {
  const cfg = loadConfig();
  assert.deepEqual(validateConfig(cfg, { production: true }), []);
  cfg.profiles[0].stations[0].criteria[0].direction.verificationStatus = 'pending';
  assert.ok(validateConfig(cfg, { production: true }).length > 0);
});
test("adding another station needs only configuration data", () => {
  const cfg = structuredClone(loadConfig());
  const third = structuredClone(cfg.profiles[0].stations[0]);
  third.key = "new-station";
  third.name = "Nytt hållplatsnamn";
  third.shortLabel = "Ny hållpl.";
  third.criteria[0].id = "new-rule";
  cfg.profiles[0].stations.push(third);
  assert.deepEqual(validateConfig(cfg), []);
});
test("duplicate station keys are rejected", () => {
  const cfg = structuredClone(loadConfig());
  cfg.profiles[0].stations[1].key = cfg.profiles[0].stations[0].key;
  assert.ok(validateConfig(cfg).some(x => x.includes("duplicate ID")));
});
test("unrecognized startup profile is rejected", () => {
  const cfg = structuredClone(loadConfig());
  cfg.defaults.startupProfile = "unknown";
  assert.ok(validateConfig(cfg).some(x => x.includes("startupProfile")));
});
