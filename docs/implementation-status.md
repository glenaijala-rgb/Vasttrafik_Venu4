# Implementationsstatus 2026-11-28

## Genomfört

- GitHub-repot glenaijala-rgb/Vasttrafik_Venu4 hämtat till den ursprungligen tomma mappen.
- Backend, generiskt regelverk, schema, OAuth, HTTPS-klient, paginering, 429-paus, felbackoff, privat åtkomst och cache implementerade.
- Monkey C med Glance A, fullvy, profilbyte, cache, rullning och status implementerad.
- Garmin SDK 9.3.0 hämtat. Produkt-ID:n bekräftade i SDK:s ConfigurableWatchFace/manifest.xml.
- npm run check: **35/35 tester godkända**. Syntetiska data finns endast i tester/förhandsvisning.
- Enhetsbyggen venu441mm och venu445mm: **BUILD SUCCESSFUL**. Nio native tester: **9/9 PASS på vardera enheten** i Garmin-simulatorn.
- Simulatorgranskning: Glance A och fullvy på båda storlekarna med nyligen hämtade verkliga API-svar i cache. Hem/Jobb-byte på 41 mm, rullning på 45 mm och gammal-cache-varning på 45 mm kontrollerade. Se [simulatorkontroll](simulator-verification.md).
- Lokal HTTP-test: 200 health, 401 utan nyckel, 400 fel profil, 503 ofärdig konfiguration och 429 rate limit.
- Ingen extern driftsättning eller Store-publicering. Filer för privat sideload har överförts till fysisk Venu 4 45 mm; första start på klockan återstår.

## Kvar innan drift

1. Västtrafik-konto, API-prenumeration och OAuth är nu verifierade.
2. Samtliga regler har verifierade hållplatslägen och status verified. Se [live-verifiering](live-verification.md). Lokal HTTP-kontroll gav 200 för båda profilerna: Hem 16 avgångar (15 med realtid), Jobb 6 (alla med realtid). 173 verifierades i vardagens tidtabell.
3. Enhetsfilerna är installerade. Båda enhetsbyggena och native testerna är godkända.
4. Direkt OAuth/HTTPS från Garmin-simulatorn till Västtrafik har verifierats på 41 och 45 mm. Hem visar riktiga 25/753-avgångar och Jobb visar 78 i rätt riktning. Återstående acceptans: fysisk klocka, verkligt anslutningsbortfall och full visuell edge-case-matris (0/1/inställt/långa texter). Logiska cachefallen täcks av native tester.
5. Egen HTTPS-host behövs inte efter användarens beslut om direktanslutning. Privata inställningar är förberedda lokalt.
6. Installationsfilerna är kopierade till klockan och återlästa med matchande SHA-256. Koppla från USB, öppna appen och jämför verkliga avgångar.

**Implementerad och delvis verifierad, inte driftklar.** Simulatorprov ersätter inte fysisk klocktest.

## API-dokumentationskontroll

[Officiell OpenAPI-definition](https://developer.vasttrafik.se/apis/13/v4), fliken API-definition, läst 2026-11-28. Live-trafik verifierad samma dag, se live-verification.md.

- Server: https://ext-api.vasttrafik.se/pr/v4 ; token: https://ext-api.vasttrafik.se/token .
- Avgångssökning: **startDateTime**, timeSpanInMinutes, maxDeparturesPerLineAndDirection, limit, offset och valfri directionGid.
- results får vara null och hanteras som tom lista.
- Normalisering använder serviceJourney.gid, serviceJourney.line.shortName (reserv designation/name), serviceJourney.directionDetails.shortDirection (reserv direction), stopPoint och realtimeStopPoint.
- plannedTime, estimatedTime och estimatedOtherwisePlannedTime styr tider och realtidsmarkering.
- Detaljer: serviceJourneys[].callsOnServiceJourney[]. isArrivalCancelled och isDepartureCancelled finns på detaljanropets hållplatsanrop. Delvis inställda turer kräver därför detaljkontroll.
- directionDetails är textkomponenter, inte ett destinations-GID. GID-filtret tillämpas i avgångsfrågan.

API-kvot och verkliga svar ska följas upp med användarens konto före drift.

## Direktläge utan hosting

Se [arkitekturbeslut](direct-mode.md). Ingen extern tjänst har satts upp. Produktionsfilerna för båda storlekarna har kontrollerats mot de verkliga nyckelvärdena och innehåller inga sådana värden. Den separata privata SET-filen innehåller båda nycklarna och ignoreras av Git. Installationsmapparna är hashkontrollerade och skyddade med Windows-filbehörigheter för den aktuella användaren. Vid den första kontrollen var ingen fysisk Garmin-enhet ansluten. Efter användarens drivrutinsuppdatering identifierades Venu 4 - 45mm som WPD med status OK.

## Överföring till fysisk klocka 2026-11-28

VASTTRAFIK.PRG (132 028 byte) kopierades till Internal Storage/GARMIN/Apps och den privata VASTTRAFIK.SET (149 byte) till Apps/SETTINGS över MTP. Båda filerna kopierades tillbaka till en privat lokal kontrollmapp; SHA-256 matchade respektive original. Inga befintliga appar eller inställningar skrevs över. Första start efter frånkoppling, nätanslutning via telefon, realtidsjämförelse och Glance på fysisk klocka återstår. Överföringen ensam innebär inte att appen är driftklar.
