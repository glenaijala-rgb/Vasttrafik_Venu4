# Västtrafik för Garmin Venu 4

**Mål: skarp privat Connect IQ-app med realtidsavgångar, inte en demonstration.** Detta repo innehåller en produktionsinriktad krav- och projektstruktur för Codex. Klockapp och backend ska implementeras mot Västtrafiks riktiga Planera Resa API v4.

## Funktion
- **Hem är alltid startläge.** En gemensam tidsordnad och rullbar avgångslista från Wennerbergsgatan, buss 753 mot Heden, samt Toltorpsskolan, buss 25 mot Hisingen.
- **Jobb:** Kretsloppsparken med linje 78 mot Gamlestads Torg och 173 mot Heden i avsedd färdriktning. Lägg till andra avgångar först när färdriktningen är verifierad.
- Hög kontrast och stora linje-/minutsiffror. Knappen **Hållplats** växlar Hem/Jobb med ett tryck.
- Hämtar riktiga avgångstider via säker backend och Garmin Connect, ingen GPS behövs.

## Skalbar konfiguration
Alla profiler, hållplatser, linjer och riktningsregler ligger i **config/profiles.json**. Varje profil innehåller valfritt antal stationsobjekt; varje station innehåller valfritt antal criteria. Ett tillägg ska normalt endast kräva konfigurationsändring, validering och test, **inte nya Monkey C-vyer**.

## Dokument
- [Codex-arbetsuppdrag](CODEX_START.md) och [AGENTS.md](AGENTS.md)
- [Funktionskrav](docs/functional-spec.md)
- [UI-krav](docs/ui-spec.md) och [interaktiv UI-skiss](docs/ui-preview.html)
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
**Projektstrukturen och specifikationen finns här. Klockapp och backend är ännu inte implementerade.** Ingen skarp anslutning är genomförd, eftersom Västtrafik-credentials och verifierade hållplats-GID:n saknas. Dessa får inte hittas på. Testdata/mockup får aldrig presenteras som livetraffik.

Officiella API-dokument: https://github.com/vasttrafik/api-pr-docs/blob/main/docs/REST.md
Garmin: https://developer.garmin.com/connect-iq/
