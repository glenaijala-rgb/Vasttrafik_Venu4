# Garmin-app i Monkey C

**Codex ska skapa ett giltigt Connect IQ-projekt här** med manifest.xml, resources/ och source/. Stöd både Venu 4 41 mm och 45 mm. Garmin SDK och simulator används för riktig kompilering/test.

- Watch-app eller widget enligt Connect IQ:s faktisk stödda app-typ för användningsflödet, dokumentera valet.
- Gemensam kronologisk listvy för varje profileId, oavsett antalet ingående hållplatser.
- HEM öppnas alltid. Med exakt två profiler växlar knappen **Hållplats** direkt.
- Stora linje- och minuttal, kort stationLabel och destination, scroll, lastUpdated och fel.
- Hämtning via Communications.makeWebRequest med Communications permission, telefonen som internetproxy.
- Backendens HTTPS-URL kan konfigureras utan inbakade hemligheter.
- Ingen GPS och ingen separat mobilapp.
- Ingen produktionsmock; fixture-data bara i enhetstest/simulatorgranskning.
