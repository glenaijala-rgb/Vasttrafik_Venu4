import { AppError } from './errors.mjs';

export function secureUrl(value) {
  let url;
  try { url = new URL(value); } catch { throw new AppError('CONFIG_INCOMPLETE', 503); }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
    throw new AppError('CONFIG_INCOMPLETE', 503);
  }
  return url;
}

export class TokenProvider {
  constructor(env, fetcher = fetch, clock = Date.now) {
    this.env = env; this.fetch = fetcher; this.clock = clock;
    this.token = null; this.expires = 0; this.pending = null;
  }
  invalidate(token) { if (token === this.token) this.expires = 0; }
  async get() {
    if (this.token && this.expires > this.clock()) return this.token;
    if (this.pending) return this.pending;
    this.pending = this.obtain();
    try { return await this.pending; } finally { this.pending = null; }
  }
  async obtain() {
    const e = this.env;
    if (!e.VASTTRAFIK_CLIENT_ID || !e.VASTTRAFIK_CLIENT_SECRET) throw new AppError('CONFIG_INCOMPLETE', 503);
    const url = secureUrl(e.VASTTRAFIK_TOKEN_URL);
    try {
      const r = await this.fetch(url, {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(8000),
        headers: { 'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: 'Basic ' + Buffer.from(e.VASTTRAFIK_CLIENT_ID + ':' + e.VASTTRAFIK_CLIENT_SECRET).toString('base64') },
        body: 'grant_type=client_credentials'
      });
      if (!r.ok) throw new AppError('UPSTREAM_UNAVAILABLE');
      const data = await r.json();
      if (typeof data.access_token !== 'string' || !data.access_token || !Number.isFinite(Number(data.expires_in)) || Number(data.expires_in) <= 0) throw new AppError('UPSTREAM_UNAVAILABLE');
      this.token = data.access_token;
      this.expires = this.clock() + Math.max(1, Number(data.expires_in) - 60) * 1000;
      return this.token;
    } catch (error) { throw error instanceof AppError ? error : new AppError('UPSTREAM_UNAVAILABLE'); }
  }
}
