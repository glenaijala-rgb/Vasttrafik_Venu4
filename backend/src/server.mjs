import { createServer } from 'node:http';
import { timingSafeEqual, createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { loadConfig, validateConfig } from '../../scripts/validate-config.mjs';
import { TokenProvider } from './token.mjs';
import { VasttrafikClient } from './client.mjs';
import { DepartureService } from './service.mjs';
import { AppError } from './errors.mjs';

const digest = value => createHash('sha256').update(value).digest();
export function createApp({ service, accessKey, clock = Date.now, maxRequests = 60 }) {
  // One private installation: global limiter cannot be bypassed by spoofing IP headers.
  let windowStart = clock(), count = 0;
  return async (req, res) => {
    const send = (status, body, extra = {}) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff', ...extra });
      res.end(JSON.stringify(body));
    };
    try {
      const url = new URL(req.url, 'http://localhost');
      if (req.method !== 'GET') return send(405, { error: 'METHOD_NOT_ALLOWED' }, { Allow: 'GET' });
      if (url.pathname === '/health') return send(200, { status: 'ok', service: 'vasttrafik-venu4' });
      if (!['/api/v1/departures', '/api/v1/profiles'].includes(url.pathname)) return send(404, { error: 'NOT_FOUND' });
      if (!accessKey || accessKey.length < 32) throw new AppError('CONFIG_INCOMPLETE', 503);
      const supplied = req.headers.authorization ?? '';
      if (!timingSafeEqual(digest(supplied), digest('Bearer ' + accessKey))) return send(401, { error: 'UNAUTHORIZED' });
      if (clock() - windowStart >= 60000) { windowStart = clock(); count = 0; }
      if (++count > maxRequests) throw new AppError('RATE_LIMITED', 429, Math.max(1, Math.ceil((windowStart + 60000 - clock()) / 1000)));
      if (url.pathname === '/api/v1/profiles') return send(200, { schemaVersion: 1, startupProfile: service.config.defaults.startupProfile,
        profiles: service.config.profiles.map(p => ({ id: p.id, label: p.label })) });
      if ([...url.searchParams.keys()].some(k => k !== 'profile') || url.searchParams.getAll('profile').length !== 1) throw new AppError('INVALID_PROFILE', 400);
      return send(200, await service.get(url.searchParams.get('profile')));
    } catch (error) {
      const safe = error instanceof AppError ? error : new AppError('INTERNAL_ERROR', 500);
      send(safe.status, { error: safe.code }, safe.status === 429 || safe.status === 502 ? { 'Retry-After': String(safe.retryAfter) } : {});
    }
  };
}

export function start(env = process.env) {
  const config = loadConfig();
  const errors = validateConfig(config);
  if (errors.length) throw new Error('Invalid profile configuration: ' + errors.join('; '));
  const service = new DepartureService(config, new VasttrafikClient(env, new TokenProvider(env)));
  const server = createServer({ requestTimeout: 30000, headersTimeout: 10000 }, createApp({ service, accessKey: env.WATCH_ACCESS_KEY }));
  server.listen(Number(env.PORT || 8787), env.HOST || '127.0.0.1', () => console.log('Västtrafik backend listening on port ' + (env.PORT || 8787)));
  return server;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) start();
