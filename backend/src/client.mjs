import { AppError } from './errors.mjs';
import { secureUrl } from './token.mjs';

export class VasttrafikClient {
  constructor(env, tokens, fetcher = fetch, clock = Date.now) {
    this.env = env; this.tokens = tokens; this.fetch = fetcher; this.clock = clock; this.blockedUntil = 0;
  }
  async get(path, params = {}, deadline = this.clock() + 16000) {
    if (this.clock() >= deadline) throw new AppError('UPSTREAM_UNAVAILABLE');
    if (this.clock() < this.blockedUntil) throw new AppError('UPSTREAM_UNAVAILABLE');
    const base = secureUrl(this.env.VASTTRAFIK_API_BASE_URL).href.replace(/\/$/, '') + '/';
    const url = new URL(path, base);
    if (!url.href.startsWith(base)) throw new AppError('CONFIG_INCOMPLETE', 503);
    for (const [key, value] of Object.entries(params)) if (value != null) url.searchParams.set(key, String(value));
    for (let attempt = 0; attempt < 2; attempt++) {
      if (this.clock() >= deadline) throw new AppError('UPSTREAM_UNAVAILABLE');
      const token = await this.tokens.get();
      try {
        const r = await this.fetch(url, { redirect: 'error', signal: AbortSignal.timeout(Math.max(1, Math.min(8000, deadline - this.clock()))),
          headers: { Authorization: 'Bearer ' + token, Accept: 'application/json', 'Accept-Language': 'sv' } });
        if (r.status === 401 && attempt === 0) { this.tokens.invalidate(token); continue; }
        if (r.status === 429) {
          const raw = r.headers.get('retry-after');
          const seconds = /^\d+$/.test(raw ?? '') ? Number(raw) : (Date.parse(raw) - this.clock()) / 1000;
          this.blockedUntil = this.clock() + Math.min(3600, Math.max(30, Number.isFinite(seconds) ? seconds : 60)) * 1000;
        }
        if (!r.ok) throw new AppError('UPSTREAM_UNAVAILABLE');
        return await r.json();
      } catch (error) { throw error instanceof AppError ? error : new AppError('UPSTREAM_UNAVAILABLE'); }
    }
    throw new AppError('UPSTREAM_UNAVAILABLE');
  }
  async departures(station, directionGid, now, horizon, deadline = this.clock() + 20000) {
    const path = `stop-areas/${encodeURIComponent(station.stopAreaGid)}/departures`;
    const results = [];
    // Explicit offset pagination: never follow upstream-provided URLs with our bearer token.
    for (let page = 0; page < 10; page++) {
      const data = await this.get(path, { startDateTime: new Date(now).toISOString(), timeSpanInMinutes: horizon,
        maxDeparturesPerLineAndDirection: 100, limit: 100, offset: page * 100, directionGid }, deadline);
      // The official v4 schema explicitly allows a null results array.
      if (data.results === null) return { results, truncated: false };
      if (!Array.isArray(data.results)) throw new AppError('UPSTREAM_UNAVAILABLE');
      results.push(...data.results);
      if (data.results.length < 100) return { results, truncated: false };
    }
    return { results, truncated: true };
  }
  details(station, reference, deadline) {
    return this.get(`stop-areas/${encodeURIComponent(station.stopAreaGid)}/departures/${encodeURIComponent(reference)}/details`, { includes: 'servicejourneycalls' }, deadline);
  }
  locations(name) { return this.get('locations/by-text', { q: name, types: 'stoparea', limit: 10 }); }
}
