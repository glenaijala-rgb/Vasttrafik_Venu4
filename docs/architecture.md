# Arkitektur: direktanslutning

Beslut 2026-11-28: klockan ansluter direkt till Västtrafik med egna privata API-inställningar. Ingen egen server eller hostingtjänst krävs. Se [beslut, moduler och begränsningar](direct-mode.md).

Venu 4 (Monkey C) → Garmin Connect på telefonen → HTTPS/OAuth2 → Planera Resa API v4.

Fullvyn hämtar data, filtrerar generiskt enligt den genererade konfigurationen och sparar full cache samt kompakt Glance-cache. Glance visar de två närmaste ej inställda avgångarna och hämtar inte data själv. Ny öppning börjar på Hem.

Config/profiles.json är enda källa för profiler, stationer och kriterier. generate-watch-config.mjs validerar och genererar DirectConfig.mc samt StartupConfig.mc. Pending-konfiguration stoppar nätflödet. Inga hållplatsspecifika UI-villkor finns.

DirectClient sköter OAuth och paginering; DirectRules sköter normalisering, riktningar, delinställda turer och tidsordning; Model/Cache sköter generationsskydd vid profilbyte, status och cache. API-hemligheter lagras separat i Application.Properties. Se direct-mode.md för den accepterade säkerhetsavvägningen.

Backendens separata token/client/config/rules/service/server-moduler behålls som lokala verifieringsverktyg och referens för regeltester. Backendens HTTP-kontrakt ändras inte och ingen extern backend har satts upp.
