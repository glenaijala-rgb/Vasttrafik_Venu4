# Backend: skarp Västtrafik-proxy (implementation till Codex)

**Här ska riktig backend-kod implementeras**, ingen mockserver i produktion. Rekommendation: TypeScript/Cloudflare Workers, om inget viktigare talar för Python/FastAPI.

## Förväntade moduler
- src/config: läs och validera config/profiles.json, kontrollera production-ready-regler
- src/auth: OAuth2-bearer-token mot Västtrafik, hantera utgångna tokens
- src/client: hämtning av stop-area/stop-point departures, ev. detail för riktning
- src/rules: filtrering per linje och **verifierad riktning**, fail closed
- src/normalize: beräknad/planerad tid, inställt, stopLabel, sortering, deduplicering
- src/http: GET /api/v1/departures?profile=... samt begränsad health
- src/cache: kort TTL, fel-/rate-limit-hantering
- tests: regressionsfall för 753, 25, 78, 173 och framtida tillägg

## Skarpa villkor
- Miljön tillhandahåller VASTTRAFIK_CLIENT_ID, VASTTRAFIK_CLIENT_SECRET samt **API- och token-URL från utvecklarportalen**, aldrig i Git.
- Inga påhittade stopAreaGid; kontrollera live via locations/by-text och faktiska departures/details.
- Fail closed: oklara riktningsregler ska inte tyst släppa igenom turer. Ange CONFIG_INCOMPLETE.
- En begränsad och gärna åtkomstskyddad endpoint, med rimlig rate-limit. En statisk klientnyckel i klockan är inte en perfekt säkerhetsgräns.
- Endast tillgänglig Västtrafik-data visas. Syntetiska exempel finns i docs/ui-preview.html och tester, aldrig i skarp respons.
- Implementationsförslag och release-gate finns i docs/release-checklist.md.
