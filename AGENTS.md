# V2.2 – gällande instruktion

Implementation finns i backend/src och garmin/source. Läs docs/v2.2-ak-hem.md först. Den ersätter tidigare instruktioner om att koden inte finns, att positionering inte ingår samt förslag om val av teknik. Behåll Node 22 och Monkey C, verifiera befintlig kod mot skarpa APR-svar och Garmin SDK. Skriv inte om i onödan. Ingen deploy eller publicering utan uppdrag.

---

# Instruktioner till Codex

Bygg **den avsedda skarpa lösningen**, inte en prototyp som behöver skrivas om. Läs CODEX_START.md och docs/functional-spec.md, docs/ui-spec.md, **docs/glance-spec.md**, docs/architecture.md, docs/api-contract.md och docs/adding-stations.md före implementation.

1. Välj Västtrafiks riktiga **Planera Resa API v4**, med bearer-token via OAuth2 och hemligheter i backend-miljön. Inga inbyggda API-nycklar eller tokens i Git/Garmin-kod.
2. Bygg Garmin Connect IQ-app med **Glance A** i Monkey C för Venu 4 41 mm och 45 mm. Implementera `AppBase.getGlanceView()` och `WatchUi.GlanceView` samt interaktiv fullvy via `getInitialView()`. Verifiera manifest och app-typ i SDK. Ingen stationsspecifik UI-kod.
3. Bygg backend för **alla profiler/stationer/criteria i config/profiles.json**. Implementationen får inte innehålla specialfall för just Hem/Jobb/753/25/78/173. Backend väljer, sammanfogar, filtrerar, sorterar och presenterar generiska avgångar.
4. Verifiera stopAreaGid, relevanta stopPoint/directionGid, destinationsskyltning och verklig linjesträckning mot Västtrafiks live-data. En hint är **aldrig tillräcklig som ensam produktionsregel**. Status pending ska medföra tydligt CONFIG_INCOMPLETE/fail-closed.
5. Gör realtidsflödet från API till Venu 4 direkt. Syntetiska fixtures får användas **endast i tester** eller uttrycklig UI-förhandsvisning; bygg inte en separat demo-app.
6. Bygg med tydliga moduler: secrets/token, Västtrafik client, konfiguration, normalisering, filter, sammanslagning, server-API, watch UI/network/cache. Skydda mot felaktig riktning och överbelastning.
7. Filtrering ska vara testad per regel och profil, med regressionstest när nya stationer läggs till. Håll api-kontraktet stabilt när ytterligare profiler/stationer tillkommer.
8. En knapp **Hållplats** växlar direkt mellan Hem och Jobb; konfigurationsdrivet kan fler profiler få en enkel väljare. Startläge alltid Hem. Positionering ingår inte.
9. Hög kontrast och stora fonter. **Glance A** visar två närmaste avgångarna sida vid sida ur samma gemensamma lista; cache-first och inga egna knappar. Fullvyn är rullbar och har Hållplats-knappen. Testa båda verkliga Glance-formaten i Garmin-simulatorn, inte bara HTML-preview.
10. Rapportera bygg- och testresultat sakligt. Om credentials eller SDK saknas: implementera allt möjligt, dokumentera exakt blockerande steg, märk **inte** systemet driftklart.
11. Låt ingen hemlighet komma in i Git eller loggar. Produktion ska ha tidsgränser, 429-hantering, felsvar, kort cache och rimlig takt på polling.
12. Ändra repo genom vanliga commits/PR enligt användarens instruktion; publicera inte app i Connect IQ Store eller sätt upp extern drift utan särskilt uppdrag.

**Definition of done:** verklig API-hämtning, verifierade GID:n/riktningar, testad generisk konfiguration, kompilering för Venu 4, praktisk installation och verifiering av realtidsdata i klockan. Ej klart om något av detta saknas.
