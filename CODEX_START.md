# Codex: startuppdrag för skarp version 2.1

Implementera den skarpa Västtrafik-widgeten enligt docs/functional-spec.md, docs/ui-spec.md och **docs/glance-spec.md** (fastställt alternativ A). Återanvänd och håll config/profiles.json som den enda källan för profilernas hållplatser, linjer och riktningsvillkor.

## Beställning
1. Skapa riktigt Connect IQ-projekt och korrekt manifest för Venu 4 41/45 mm. Använd Communications.makeWebRequest via Garmin Connect för HTTPS till vår backend.
2. Skapa en minimal säker backend, gärna TypeScript i Cloudflare Workers, med Västtrafiks OAuth2 och live-APR v4. Alternativt välmotiverad Python/FastAPI. Anslutningar måste vara konfigurerbara, inga hårdkodade hemligheter eller påhittade URL:er.
3. Implementera generisk konfigurationsmodell: ett obegränsat antal profiler -> stationer -> kriterier; varje kriterium har linjer, giltiga riktningar och verifierade stopPoint/StopArea-regler. Default Hem.
4. Lös **verkliga** stopp-ID:n samt riktningar genom tillgängliga live-API-frågor och dokumentera verifieringen i config. Särskilt 173 från Kretsloppsparken och vad som menas med 'mot Gamlestaden'. Om creds saknas, ange blockerande uppgift, hitta inte på.
5. Hämta tillgängliga kommande avgångar, filtrera på alla kriterier och slå ihop kronologiskt utan grupper; sikta på 16 eller fler inom sökfönstret när de finns.
6. Implementera **Glance A**, två närmaste ej inställda avgångar sida vid sida med linjenummer och minuter, även om samma linje två gånger. Kortet öppnar fullvyn, där stora siffror, kort hållplatsnamn per rad, försenings- och inställt-status, rullning och fast knapp **Hållplats** finns. Båda vyerna delar datakälla/cache.
7. Testa: blandning av stationer, rätt/omvänd riktning, inställt/delinställt, realtime/fallback, identiska linjer, midnatt/DST, tomt/gammalt svar, fler profiler, 41/45 mm. För Glance A särskilt: två från samma linje, en/ingen avgång, utesluten inställd avgång, gammal cache, aktuell profil och Glance-kortets verkliga storlek.
8. Dokumentera konfiguration, deploy, credentials, test och sideload. Säkerställ att det går att lägga till en tredje hållplats utan ändringar i Monkey C-koden.

## Leveranskrav
- Riktig backend- och Garmin-kod, inga mockar som produktionsbeteende.
- Automatiska enhetstester/CI, separat integrationskontroll som kräver riktiga API-credentials.
- Driftklart **först efter** verifierade API-credentials, stop-GID/riktningar, Garmin-SDK-build och test på enheten.
- Kör inte extern publicering/deploy som använder användarens konto utan uttrycklig instruktion.
