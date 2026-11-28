# Backend API-kontrakt v1 (eget kontrakt)

Endast definierade profiler ska accepteras.
- Alla `/api/v1/*` kräver `Authorization: Bearer <WATCH_ACCESS_KEY>`, separat från Västtrafiks nycklar. Fel nyckel ger 401 UNAUTHORIZED.
- GET /api/v1/profiles returnerar schemaVersion, startupProfile och profiles med id/label.
- GET /api/v1/departures?profile=home
- GET /api/v1/departures?profile=work
- GET /health (utan känsliga uppgifter)

Svar 200, **exempeldata nedan är inte riktiga avgångar**:

    {
      "schemaVersion": 1,
      "profileId": "home",
      "generatedAt": "2026-11-26T16:24:00+01:00",
      "timezone": "Europe/Stockholm",
      "isPartial": false,
      "departures": [
        {
          "id": "illustrative-not-live",
          "stationKey": "wennerbergsgatan",
          "stationLabel": "Wennerbergsg.",
          "line": "753",
          "destination": "Heden",
          "departureTime": "2026-11-26T16:27:00+01:00",
          "plannedTime": "2026-11-26T16:26:00+01:00",
          "isRealtime": true,
          "isCancelled": false,
          "delayMinutes": 1,
          "platform": "B"
        }
      ]
    }

- departures: platt lista stigande efter departureTime, över ALLA valda stationer inom profilen. Inga grupper.
- departureTime = estimatedOtherwisePlannedTime eller motsvarande verifierat fält (RFC3339), plannedTime = planerad tid.
- id: härled säkert från faktisk tur-/hållplats-/avgångsreferens (inte index).
- stationKey/stationLabel: från config, viktigt när flera hållplatser visas tillsammans.
- isRealtime, isCancelled, delayMinutes, platform: baseras på verifierade Västtrafiks fält, inte på gissningar.
- generatedAt är när backend sammanställde svaret; klienten visar dataålder och hanterar stale.
- max 16 i standardconfig när så många matchningar finns. Tom lista är giltigt 200-svar.
- Fel: 400 INVALID_PROFILE, 503 CONFIG_INCOMPLETE, 502 UPSTREAM_UNAVAILABLE, 429 RATE_LIMITED, utan hemligheter i body.
- Klienten måste hantera okända tillkommande fält. Backend får lägga till fält men får inte ändra befintlig semantik utan versionshöjning.
- När profil-ID läggs till krävs ingen ändring av avgångs-JSON-kontraktet.

Verifiera verkliga Västtrafik-fältnamn/svar med real API innan färdig kod låses.

Bakåtkompatibla tillägg: `generatedEpoch` och `departureEpoch` är Unix-sekunder för klockan. `profileLabel`, `profiles` och `staleAfterSeconds` ingår i svaret; `platformChanged` tillkommer per avgång. `generatedAt` ändras inte när cache återanvänds. Passerade avgångar tas bort även ur cachade svar. Uppströmsfel ger felsvar, aldrig gammal data med ny tidsstämpel. `isPartial=true` markerar nådd pagineringsgräns.
