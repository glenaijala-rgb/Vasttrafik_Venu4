# Västtrafik för Garmin Venu 4

**Mål: skarp privat Connect IQ-app med realtidsavgångar, inte en demonstration.** Backend och Monkey C-app är implementerade. Live-anslutning, Venu 4-enhetsbyggen och installation återstår. Börja med [installationsguiden](docs/installation.md).

## Funktion
- **Hem är alltid startläge.** En gemensam tidsordnad och rullbar avgångslista från Wennerbergsgatan, buss 753 mot Heden, samt Toltorpsskolan, buss 25 mot Hisingen.
- **Jobb:** Kretsloppsparken med linje 78 mot Gamlestads Torg och 173 mot Heden i avsedd färdriktning. Lägg till andra avgångar först när färdriktningen är verifierad.
- **Snabbvy: alternativ A**, med två närmaste avgångar sida vid sida, stora linjenummer/minuter och Hem som standard. Ett tryck på kortet öppnar fullvyn.
- **Fullskärmsvy:** hög kontrast, stora linje-/minutsiffror. Knappen **Hållplats** växlar Hem/Jobb med ett tryck.
- Hämtar riktiga avgångstider via säker backend och Garmin Connect, ingen GPS behövs.

## Skalbar konfiguration
Alla profiler, hållplatser, linjer och riktningsregler ligger i **config/profiles.json**. Varje profil innehåller valfritt antal stationsobjekt; varje station innehåller valfritt antal criteria. Ett tillägg ska normalt endast kräva konfigurationsändring, validering och test, **inte nya Monkey C-vyer**.

## Dokument
- [Codex-arbetsuppdrag](CODEX_START.md) och [AGENTS.md](AGENTS.md)
- [Funktionskrav](docs/functional-spec.md)
- [UI-krav](docs/ui-spec.md), [Glance A – fastställd spec](docs/glance-spec.md) och [interaktiv UI-skiss](docs/ui-preview.html)
- [Arkitektur och datamodell](docs/architecture.md)
- [Backend-API-kontrakt](docs/api-contract.md)
- [Lägg till fler hållplatser och krav](docs/adding-stations.md)
- [Driftsättning och kontroll](docs/release-checklist.md)

## Struktur
- **config/** profil- och regeldefinition; verifierade ID:n återförs hit före driftsättning
- **backend/** säker HTTPS-/OAuth2-proxy, filtrering, sortering, validering och cache
- **garmin/** Connect IQ-app i Monkey C för Venu 4 41/45 mm
- **tests/** enhets-, integrations- och regeltester
- **docs/** normerande specifikationer, API och UI
- **scripts/** automatisk konfigurationsvalidering
- **.github/workflows/** automatiska kontroller

## Verklig status
**2026-11-28: implementerad, inte driftklar.** 29 automatiska Node-tester passerar. Appen och fyra native tester har kompilerats generellt med Garmin SDK 9.3.0. Klocktesterna har ännu inte körts. Venu 4-enhetsfiler saknas, så enhetsbygge, simulatorgranskning och klockinstallation återstår. API-nycklar, verifierade hållplatsriktningar och HTTPS-drift återstår också. Se [aktuell status](docs/implementation-status.md).

Kör `npm ci` och `npm run check` från reporoten för lokal verifiering.

Officiella API-dokument: https://github.com/vasttrafik/api-pr-docs/blob/main/docs/REST.md
Garmin: https://developer.garmin.com/connect-iq/
