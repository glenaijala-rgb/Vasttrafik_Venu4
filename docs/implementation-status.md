# Implementationsstatus 2026-11-28

## Genomfört

- GitHub-repot glenaijala-rgb/Vasttrafik_Venu4 hämtat till den ursprungligen tomma mappen.
- Backend, generiskt regelverk, schema, OAuth, HTTPS-klient, paginering, 429-paus, felbackoff, privat åtkomst och cache implementerade.
- Monkey C med Glance A, fullvy, profilbyte, cache, rullning och status implementerad.
- Garmin SDK 9.3.0 hämtat. Produkt-ID:n bekräftade i SDK:s ConfigurableWatchFace/manifest.xml.
- npm run check: **35/35 tester godkända**. Syntetiska data finns endast i tester/förhandsvisning.
- Generell Monkey C-kompilering: **BUILD SUCCESSFUL**. Native testtarget: **BUILD SUCCESSFUL**, men fyra native tester **inte körda**.
- Lokal HTTP-test: 200 health, 401 utan nyckel, 400 fel profil, 503 ofärdig konfiguration och 429 rate limit.
- Ingen extern driftsättning, Store-publicering eller klockinstallation.

## Kvar innan drift

1. Västtrafik-konto, API-prenumeration och OAuth är nu verifierade.
2. Samtliga regler har verifierade hållplatslägen och status verified. Se [live-verifiering](live-verification.md). Lokal HTTP-kontroll gav 200 för båda profilerna: Hem 16 avgångar (15 med realtid), Jobb 6 (alla med realtid). 173 verifierades i vardagens tidtabell.
3. Installera Venu 4-enhetsfiler. Byggförsöket gav **Invalid device id specified: 'venu441mm'**. Produktnamnet finns i SDK-exemplen men installerat device package saknas.
4. Kör native tester och granska verklig Glance/fullvy på båda storlekarna: marginaler, långa texter, 0/1/2+ avgångar, stale/offline och profil-livscykel. Ingen simulatorlayout är godkänd ännu.
5. Välj HTTPS-host och verifiera container, TLS, appnyckel och sideload-inställningar.
6. Installera på klockan och jämför verkliga avgångar.

**Implementerad och delvis verifierad, inte driftklar.** Generell kompilering ersätter inte enhetsbygge eller klocktest.

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
