# V2.2 – implementation

Källkod finns nu. Se [V2.2-dokumentation](../docs/v2.2-ak-hem.md) för gällande funktion, drift och verifiering. Äldre text nedan är historisk specifikation.

---

# Garmin-app i Monkey C

**Codex ska skapa ett giltigt Connect IQ-projekt här** med manifest.xml, resources/ och source/. Stöd både Venu 4 41 mm och 45 mm. Garmin SDK och simulator används för riktig kompilering/test.

- **Glance A är obligatoriskt**: `AppBase.getGlanceView()` + `WatchUi.GlanceView`, tillsammans med fullskärmsvy via `getInitialView()`. Välj korrekt app-typ i manifest efter kontroll i Garmin SDK.
- Glance visar två närmaste ej inställda avgångar bredvid varandra från samma profil, stor text och ingen knapp. Använd cache-first och tydlig stale-/offline-status. Se docs/glance-spec.md.
- Gemensam kronologisk listvy för varje profileId, oavsett antalet ingående hållplatser.
- HEM öppnas alltid. Med exakt två profiler växlar knappen **Hållplats** direkt.
- Stora linje- och minuttal, kort stationLabel och destination, scroll, lastUpdated och fel.
- Hämtning via Communications.makeWebRequest med Communications permission, telefonen som internetproxy.
- Backendens HTTPS-URL kan konfigureras utan inbakade hemligheter.
- Ingen GPS och ingen separat mobilapp.
- Ingen produktionsmock; fixture-data bara i enhetstest/simulatorgranskning.
