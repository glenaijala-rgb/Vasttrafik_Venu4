import { validateConfig } from '../../scripts/validate-config.mjs';
import { AppError } from './errors.mjs';
import { matches, normalize, merge, onwardStops, withCallCancellation } from './normalize.mjs';

export class DepartureService {
  constructor(config, client, clock = Date.now) {
    this.config = config; this.client = client; this.clock = clock;
    this.cache = new Map(); this.pending = new Map(); this.failures = new Map();
  }
  async get(profileId) {
    const profile = this.config.profiles.find(p => p.id === profileId);
    if (!profile) throw new AppError('INVALID_PROFILE', 400);
    const scoped = { ...this.config, defaults: { ...this.config.defaults, startupProfile: profileId }, profiles: [profile] };
    if (validateConfig(scoped, { production: true }).length) throw new AppError('CONFIG_INCOMPLETE', 503);
    const now = this.clock();
    const cached = this.cache.get(profileId);
    if (cached && now - cached.generatedEpoch * 1000 < this.config.defaults.cacheTtlSeconds * 1000) {
      return { ...cached, departures: cached.departures.filter(d => d.departureEpoch * 1000 >= now) };
    }
    if (this.failures.get(profileId) > now) throw new AppError('UPSTREAM_UNAVAILABLE');
    if (this.pending.has(profileId)) return this.pending.get(profileId);
    const promise = this.load(profile, now).then(result => { this.cache.set(profileId, result); return result; })
      .catch(error => { this.failures.set(profileId, this.clock() + 15000); throw error; })
      .finally(() => this.pending.delete(profileId));
    this.pending.set(profileId, promise);
    return promise;
  }
  async load(profile, now) {
    const all = []; let isPartial = false;
    const defaults = this.config.defaults;
    const deadline = this.clock() + 20000;
    // Sequential station/direction queries put a fixed upper bound on upstream concurrency.
    for (const station of profile.stations) {
      const rules = station.criteria.filter(c => c.enabled);
      const directions = [...new Set(rules.flatMap(c => c.direction.allowedDirectionGids.length ? c.direction.allowedDirectionGids : [null]))];
      const detailsCache = new Map();
      for (const direction of directions) {
        const page = await this.client.departures(station, direction, now, defaults.searchHorizonMinutes, deadline);
        isPartial ||= page.truncated;
        for (const raw of page.results) {
          for (const rule of rules) {
            // Pre-filter before spending requests on journey details.
            if (!matches(raw, { ...rule, direction: { ...rule.direction, mustPassStopAreaGids: [] } }, direction)) continue;
            let onward = [];
            let resolved = raw;
            if (rule.direction.mustPassStopAreaGids.length || raw.isPartCancelled === true) {
              if (!raw.detailsReference) throw new AppError('UPSTREAM_UNAVAILABLE');
              if (!detailsCache.has(raw.detailsReference)) detailsCache.set(raw.detailsReference, await this.client.details(station, raw.detailsReference, deadline));
              const details = detailsCache.get(raw.detailsReference);
              if (rule.direction.mustPassStopAreaGids.length) onward = onwardStops(details, raw);
              if (raw.isPartCancelled === true) resolved = withCallCancellation(details, raw);
            }
            if (matches(raw, rule, direction, onward)) { all.push(normalize(resolved, station)); break; }
          }
        }
      }
    }
    return { schemaVersion: 1, profileId: profile.id, profileLabel: profile.label,
      generatedAt: new Date(now).toISOString(), generatedEpoch: Math.floor(now / 1000),
      timezone: defaults.timezone, staleAfterSeconds: defaults.staleAfterSeconds, isPartial,
      profiles: this.config.profiles.map(p => ({ id: p.id, label: p.label })),
      departures: merge(all, now, defaults.searchHorizonMinutes, defaults.maxUpcomingDepartures) };
  }
}
