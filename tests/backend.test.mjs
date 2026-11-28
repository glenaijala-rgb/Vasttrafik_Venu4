import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { loadConfig, validateConfig } from '../scripts/validate-config.mjs';
import { TokenProvider } from '../backend/src/token.mjs';
import { VasttrafikClient } from '../backend/src/client.mjs';
import { DepartureService } from '../backend/src/service.mjs';
import { cancelled, matches, normalize, merge, onwardStops } from '../backend/src/normalize.mjs';
import { createApp } from '../backend/src/server.mjs';

const NOW = Date.parse('2026-10-25T00:55:00Z');
const env = { VASTTRAFIK_API_BASE_URL: 'https://example.test/pr/v4', VASTTRAFIK_TOKEN_URL: 'https://example.test/token',
  VASTTRAFIK_CLIENT_ID: 'test-id', VASTTRAFIK_CLIENT_SECRET: 'test-secret' };
const config = () => {
  const c = loadConfig();
  for (const p of c.profiles) for (const [i, s] of p.stations.entries()) {
    s.stopAreaGid = '902100000000000' + i;
    for (const r of s.criteria) Object.assign(r.direction, {
      verificationStatus: 'verified', verifiedAt: '2026-01-01T00:00:00Z', verificationNote: 'SYNTHETIC TEST ONLY',
      allowedStopPointGids: ['9022000000000001']
    });
  }
  return c;
};
function raw(line = '753', minute = 1, extra = {}) {
  return { serviceJourney: { gid: 'journey-' + line + '-' + minute, line: { name: line }, direction: 'TEST destination' },
    stopPoint: { gid: '9022000000000001', platform: 'A' },
    plannedTime: new Date(NOW + minute * 60000).toISOString(), isCancelled: false, ...extra };
}

test('pending configuration fails closed before a single upstream call', async () => {
  const pending = loadConfig();
  pending.profiles[0].stations[0].criteria[0].direction.verificationStatus = 'pending';
  const service = new DepartureService(pending, { departures() { assert.fail('no network allowed'); } });
  await assert.rejects(service.get('home'), { code: 'CONFIG_INCOMPLETE', status: 503 });
  await assert.rejects(service.get('unknown'), { code: 'INVALID_PROFILE' });
});
test('schema rejects malformed selector arrays and production rejects invalid GIDs', () => {
  const c = config();
  assert.deepEqual(validateConfig(c, { production: true }), []);
  c.profiles[0].stations[0].criteria[0].direction.allowedStopPointGids = null;
  assert.ok(validateConfig(c).length);
  const other = config(); other.profiles[0].stations[0].stopAreaGid = 'not-a-gid';
  assert.ok(validateConfig(other, { production: true }).length);
});
for (const profile of config().profiles) for (const station of profile.stations) for (const rule of station.criteria) {
  test(`${profile.id}/${station.key}/${rule.id}: rejects opposite direction and wrong line`, () => {
    const d = raw(rule.lineNames[0]);
    assert.equal(matches(d, rule, null), true);
    assert.equal(matches(raw('WRONG'), rule, null), false);
    assert.equal(matches({ ...d, stopPoint: { gid: '9022000000000002', platform: 'B' } }, rule, null), false);
    assert.equal(matches({ ...d, realtimeStopPoint: { gid: '9022000000000002', platform: 'B' } }, rule, null), false);
    assert.equal(matches(d, { ...rule, enabled: false }, null), false);
  });
}
test('every configured selector is required; headsign hints cannot authorize an unverified direction', () => {
  const r = config().profiles[0].stations[0].criteria[0];
  r.direction.allowedDirectionGids = ['9021000000000099'];
  r.direction.allowedPlatforms = ['A'];
  r.direction.mustPassStopAreaGids = ['9021000000000088'];
  assert.equal(matches(raw(), r, '9021000000000099', ['9021000000000088']), true);
  assert.equal(matches(raw(), r, null, ['9021000000000088']), false);
  assert.equal(matches(raw(), r, '9021000000000099'), false);
  r.direction.verificationStatus = 'pending';
  assert.equal(matches(raw(), r, '9021000000000099', ['9021000000000088']), false);
});
test('cancellations are local to the departure, not arrival-only or another part of a journey', () => {
  assert.equal(cancelled({ isCancelled: true }), true);
  assert.equal(cancelled({ isCancelled: true, isArrivalCancelled: true }), false);
  assert.equal(cancelled({ isCancelled: false, isDepartureCancelled: true }), true);
  assert.equal(cancelled({ isPartCancelled: true, isCancelled: false }), false);
});
test('normalization uses real-time timestamp, moved platform and stable call identity', () => {
  const station = config().profiles[0].stations[0];
  const d = normalize(raw(), station);
  assert.equal(d.isRealtime, false);
  const rt = normalize(raw('753', 1, { estimatedTime: new Date(NOW+180000).toISOString(), realtimeStopPoint: { gid: 'moved', platform: 'C' } }), station);
  assert.equal(rt.delayMinutes, 2); assert.equal(rt.isRealtime, true); assert.equal(rt.platform, 'C');
  assert.equal(rt.id, d.id); assert.equal(rt.platformChanged, true);
  assert.throws(() => normalize(raw('753', 1, { plannedTime: '2026-01-01T10:00:00' }), station));
});
test('merge interleaves stations, retains two same-line calls and deduplicates actual calls', () => {
  const stations = config().profiles[0].stations;
  const a = normalize(raw('753', 3), stations[0]);
  const b = normalize(raw('25', 2), stations[1]);
  const c = normalize(raw('753', 4), stations[0]);
  assert.deepEqual(merge([a, b, c, a], NOW, 180, 16).map(d => d.line), ['25', '753', '753']);
  assert.equal(merge([a,b,c], NOW+181000, 180, 16).length, 1);
});
test('DST repeated local hour and midnight sort by absolute time', () => {
  const station = config().profiles[0].stations[0];
  const a = normalize(raw('753', 1, { plannedTime: '2026-10-25T02:59:00+02:00' }), station);
  const b = normalize(raw('25', 1, { plannedTime: '2026-10-25T02:01:00+01:00' }), station);
  assert.deepEqual(merge([b,a], NOW, 180, 16).map(d => d.line), ['753', '25']);
  const midnight = normalize(raw('25', 1, { plannedTime: '2026-11-29T00:01:00+01:00' }), station);
  assert.equal(merge([midnight], Date.parse('2026-11-28T23:59:00+01:00'), 5, 16).length, 1);
});
test('passage must occur after the actual departure, not earlier in the route', () => {
  const d = raw();
  const call = (gid, time) => ({ stopPoint: { gid: d.stopPoint.gid, stopArea: { gid } }, plannedDepartureTime: time });
  const details = { serviceJourneys: [{ gid: d.serviceJourney.gid, callsOnServiceJourney: [
    call('before', '2026-01-01T00:00:00Z'), call('current', d.plannedTime), call('after', '2026-01-01T01:00:00Z')
  ] }] };
  assert.deepEqual(onwardStops(details, d), ['after']);
  assert.throws(() => onwardStops({}, d));
});
test('service fetches all stations, caches, coalesces concurrent refresh and removes elapsed times', async () => {
  let calls = 0, now = NOW;
  const service = new DepartureService(config(), { async departures(station) {
    calls++; await new Promise(resolve => setTimeout(resolve, 5));
    return { results: [raw(station.key === 'wennerbergsgatan' ? '753' : '25', 0.5)], truncated: false };
  } }, () => now);
  const [a,b] = await Promise.all([service.get('home'), service.get('home')]);
  assert.deepEqual(a,b); assert.equal(calls, 2); assert.equal(a.departures.length, 2);
  now += 31000;
  assert.equal((await service.get('home')).departures.length, 0); assert.equal(calls, 2);
  now += 15000;
  await service.get('home'); assert.equal(calls, 4);
});
test('third station and third profile work with the same service; no UI-specific filter', async () => {
  const c = config(); const p = structuredClone(c.profiles[0]); p.id = 'third'; p.label = 'Tredje';
  p.stations.push({ ...structuredClone(p.stations[0]), key: 'extra', shortLabel: 'Extra' }); c.profiles.push(p);
  const s = new DepartureService(c, { async departures(station) {
    const d = raw(station.criteria[0].lineNames[0]); d.serviceJourney.gid += station.key;
    return { results: [d], truncated: false };
  } }, () => NOW);
  const result = await s.get('third');
  assert.equal(result.departures.length, 3); assert.equal(result.profiles.length, 3);
});
test('one failed station never silently becomes a complete successful profile', async () => {
  const s = new DepartureService(config(), { async departures() { throw new Error('secret upstream detail'); } }, () => NOW);
  await assert.rejects(s.get('home'));
  await assert.rejects(s.get('home'), { code: 'UPSTREAM_UNAVAILABLE' });
});
test('OAuth token calls coalesce and expire; HTTP and missing credentials fail closed', async () => {
  let calls = 0, now = NOW;
  const t = new TokenProvider(env, async (url, options) => {
    calls++; assert.equal(options.redirect, 'error');
    assert.equal(options.body, 'grant_type=client_credentials');
    return Response.json({ access_token: 'TEST-TOKEN', expires_in: 120 });
  }, () => now);
  assert.deepEqual(await Promise.all([t.get(), t.get()]), ['TEST-TOKEN', 'TEST-TOKEN']); assert.equal(calls, 1);
  now += 61000; await t.get(); assert.equal(calls, 2);
  await assert.rejects(new TokenProvider({}).get(), { code: 'CONFIG_INCOMPLETE' });
  await assert.rejects(new TokenProvider({ ...env, VASTTRAFIK_TOKEN_URL: 'http://example.test/token' }).get(), { code: 'CONFIG_INCOMPLETE' });
});
test('401 renews once, 429 respects cooldown, malformed responses fail', async () => {
  let calls = 0, invalidations = 0;
  const tokens = { async get() { return 'TOKEN'; }, invalidate() { invalidations++; } };
  const c = new VasttrafikClient(env, tokens, async () => ++calls === 1 ? new Response('', { status: 401 }) : Response.json({ results: [] }), () => NOW);
  assert.deepEqual(await c.get('test'), { results: [] }); assert.equal(invalidations, 1);
  const rate = new VasttrafikClient(env, tokens, async () => { calls++; return new Response('', { status: 429, headers: { 'Retry-After': '120' } }); }, () => NOW);
  await assert.rejects(rate.get('test')); const after = calls;
  await assert.rejects(rate.get('test')); assert.equal(calls, after);
  const bad = new VasttrafikClient(env, tokens, async () => Response.json({ unexpected: [] }));
  await assert.rejects(bad.departures(config().profiles[0].stations[0], null, NOW, 180));
});
test('pagination queries the configured endpoint, never an upstream next URL', async () => {
  const seen = [];
  const c = new VasttrafikClient(env, { async get() { return 'TOKEN'; } }, async url => {
    seen.push(new URL(url));
    return Response.json({ results: seen.length === 1 ? Array.from({length:100}, () => raw()) : [raw('25')], links: { next: 'https://evil.test/' } });
  });
  const result = await c.departures(config().profiles[0].stations[0], '9021000000000099', NOW, 180);
  assert.equal(result.results.length, 101);
  assert.equal(seen[1].searchParams.get('offset'), '100'); assert.equal(seen[1].origin, 'https://example.test');
  assert.equal(seen[0].searchParams.get('directionGid'), '9021000000000099');
  assert.equal(seen[0].searchParams.get('startDateTime'), new Date(NOW).toISOString());
  assert.equal(seen[0].searchParams.has('dateTime'), false);
});
test('part-cancelled journey resolves cancellation at the exact call using details', async () => {
  const c = config(); c.profiles = [c.profiles[0]]; c.profiles[0].stations = [c.profiles[0].stations[0]];
  const d = raw('753', 1, { isPartCancelled: true, detailsReference: 'test-ref' });
  const service = new DepartureService(c, {
    async departures() { return { results: [d] }; },
    async details() { return { serviceJourneys: [{ gid: d.serviceJourney.gid, callsOnServiceJourney: [{
      stopPoint: d.stopPoint, plannedDepartureTime: d.plannedTime, isDepartureCancelled: true, isCancelled: false
    }] }] }; }
  }, () => NOW);
  assert.equal((await service.get('home')).departures[0].isCancelled, true);
});
test('documented null results is an empty departure list', async () => {
  const c = new VasttrafikClient(env, { async get() { return 'TOKEN'; } }, async () => Response.json({ results: null }));
  assert.deepEqual(await c.departures(config().profiles[0].stations[0], null, NOW, 180), { results: [], truncated: false });
});
test('HTTP endpoint enforces authentication, profile allowlist, safe errors and rate limit', async t => {
  const accessKey = 'a'.repeat(40);
  const pending = loadConfig();
  pending.profiles[0].stations[0].criteria[0].direction.verificationStatus = 'pending';
  const service = new DepartureService(pending, {});
  const server = createServer(createApp({ service, accessKey, maxRequests: 3 }));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => { server.closeAllConnections(); server.close(); });
  const base = 'http://127.0.0.1:' + server.address().port;
  const auth = { headers: { Authorization: 'Bearer ' + accessKey } };
  assert.equal((await fetch(base+'/health')).status, 200);
  assert.equal((await fetch(base+'/api/v1/departures?profile=home')).status, 401);
  assert.equal((await fetch(base+'/api/v1/departures?profile=unknown', auth)).status, 400);
  const response = await fetch(base+'/api/v1/departures?profile=home', auth);
  assert.equal(response.status, 503); assert.deepEqual(await response.json(), { error: 'CONFIG_INCOMPLETE' });
  assert.equal((await fetch(base+'/api/v1/profiles', auth)).status, 200);
  assert.equal((await fetch(base+'/api/v1/profiles', auth)).status, 429);
});
