import test from "node:test";
import assert from "node:assert/strict";
import { loadConfig } from "../scripts/validate-config.mjs";
test("Glance A has two departure slots",()=>assert.equal(loadConfig().defaults.glanceMaxDepartures,2));
test("Home merged chronology is enabled",()=>assert.equal(loadConfig().profiles.find(p=>p.id==="home").mergeByDepartureTime,true));
