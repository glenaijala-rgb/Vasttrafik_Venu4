# Backend

Node.js 24 med HTTP/fetch och Ajv för JSON-schema. Valet gör att samma kod kan testas på Windows utan molnkonto och köras i en container bakom HTTPS. Ingen molntjänst eller betald resurs har skapats.

- token.mjs: OAuth2, token-cache och samtidiga tokenanrop.
- client.mjs: v4-anrop, HTTPS, tidsgränser, explicit paginering, 401-förnyelse och 429-paus.
- normalize.mjs: verifierade AND-villkor, flyttade hållplatslägen, tider, inställda anrop, passage efter aktuell hållplats, sortering och dubbletter.
- service.mjs: generiska profiler, 45 sekunders cache, coalescing, 15 sekunders felbackoff och gemensam tidsbudget. Fel på en station avbryter hela profilen.
- server.mjs: privat Bearer-skydd, profiler, 60 autentiserade anrop/minut/process och neutrala felsvar.

Skapa backend/.env med scripts/setup-secrets.ps1 och kör npm start från reporoten. /health är en liveness-kontroll, inte ett bevis på fungerande live-data.

Container: docker build -f backend/Dockerfile -t vasttrafik-venu4 .
Kör en instans bakom HTTPS med giltigt certifikat. Containerbygget är förberett men inte verifierat på denna dator. Driftplattform och eventuell kostnad måste väljas före extern driftsättning. Produktionshemligheter tillhandahålls av driftplattformen; .env kopieras inte till containern.

WATCH_ACCESS_KEY skyddar bara denna installations avgränsade API. Västtrafiks klienthemlighet lämnar aldrig servern. Appnyckeln ersätter inte rate limiting. Flera serverinstanser kräver gemensamt rate-limit/cache-lager.

Alla regelarrayer kombineras med OCH; värden inom en array är alternativ. allowedDirectionGids skickas som directionGid till Västtrafik; directionDetails innehåller inget destinations-GID. headsignHints är metadata. Aktiva regler måste vara verifierade. Oväntad hållplatsflytt släpps inte igenom ett stopPoint-filter.

Officiell OpenAPI-definition granskad på https://developer.vasttrafik.se/apis/13/v4 den 2026-11-28. Live-svar ska fortfarande verifieras.
