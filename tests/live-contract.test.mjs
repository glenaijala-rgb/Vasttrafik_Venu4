import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { loadConfig } from '../scripts/validate-config.mjs';
import { matches, normalize, onwardStops } from '../backend/src/normalize.mjs';
import { DepartureService } from '../backend/src/service.mjs';

const samples = JSON.parse(fs.readFileSync(new URL('./fixtures/live-2026-11-28.json', import.meta.url)));
const config = loadConfig();
const accepted = {
  '753-heden': ['Heden'],
  '25-hisingen': ['Länsmansgården', 'Länsmanstorget'],
  '78-gamlestaden': ['Gamlestads Torg'],
  '173-mot-centrum': ['Heden']
};
for (const profile of config.profiles) for (const station of profile.stations) for (const rule of station.criteria) {
  test(`live contract ${station.key}/${rule.id}: verified directions and opposite stop`, () => {
    let count = 0;
    for (const sample of samples.filter(s => s.stationKey === station.key)) {
      const raw = sample.departure;
      const expected = rule.lineNames.includes(raw.serviceJourney.line.shortName) && accepted[rule.id].includes(raw.serviceJourney.directionDetails.shortDirection);
      assert.equal(matches(raw, rule, null), expected);
      if (!expected) continue;
      count++;
      const normalized = normalize(raw, station);
      assert.equal(normalized.line, raw.serviceJourney.line.shortName);
      assert.equal(normalized.destination, raw.serviceJourney.directionDetails.shortDirection);
      const reversed = structuredClone(raw);
      reversed.realtimeStopPoint = { ...raw.stopPoint, gid: raw.stopPoint.gid.endsWith('1') ? raw.stopPoint.gid.slice(0, -1) + '2' : raw.stopPoint.gid.slice(0, -1) + '1' };
      assert.equal(matches(reversed, rule, null), false);
      const onward = onwardStops(sample.details, raw);
      const endpoint = { '753': '9021014003127000', '25': '9021014003180000', '78': '9021014002670000', '173': '9021014003127000' }[normalized.line];
      assert.ok(onward.includes(endpoint));
      if (normalized.line === '173') {
        assert.ok(onward.includes('9021014002675000')); // Nylösegatan in Gamlestaden
        assert.ok(!onward.includes('9021014002670000')); // Not Gamlestads Torg
      }
    }
    assert.ok(count > 0);
  });
}
for (const profile of config.profiles) {
  test(`live contract ${profile.id}: merged profile uses real v4 fields`, async () => {
    const now = Date.parse('2026-11-30T15:00:00+01:00');
    const service = new DepartureService(config, {
      async departures(station) { return { results: samples.filter(s => s.stationKey === station.key).map(s => s.departure), truncated: false }; }
    }, () => now);
    const result = await service.get(profile.id);
    assert.ok(result.departures.length >= 2);
    assert.deepEqual([...new Set(result.departures.map(d => d.line))].sort(), profile.id === 'home' ? ['25', '753'] : ['173', '78']);
    assert.ok(result.departures.every((d, i, all) => !i || d.departureEpoch >= all[i - 1].departureEpoch));
  });
}
