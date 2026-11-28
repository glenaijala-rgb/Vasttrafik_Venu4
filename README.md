# Västtrafik för Garmin Venu 4 — version 2.2 (utveckling)

Tre vyer: **Hem**, **Jobb**, **Åk hem**. Hem/Jobb använder konfigurationsstyrda avgångsregler. Åk hem använder position eller manuellt vald hållplats och APR v4 för resor till en privat konfigurerad slutadress, inklusive slutpromenad. Glance A visar två närmaste Hem-avgångar från cache. Fullvyn uppdaterar cirka varje minut när aktiv.

## Kom igång
- [Version 2.2 – funktion, drift och verifiering](docs/v2.2-ak-hem.md) (gäller före äldre specs vid konflikt)
- [Backendkod](backend/src/server.mjs) (Node 22, OAuth2, autentiserad proxy)
- [Garminprojekt](garmin/manifest.xml) och [Monkey C-kod](garmin/source/TransitApp.mc)
- [Hållplatsregler](config/profiles.json) (pending tills verifierade)
- [Backendtest](backend/test/model.test.mjs) och CI
- Äldre [Glance A-spec](docs/glance-spec.md), [arkitektur](docs/architecture.md), [API-kontrakt](docs/api-contract.md) och [UI-spec](docs/ui-spec.md) är basunderlag; v2.2-dokumentet gäller för tillkommande funktioner.

## Status
Källkod till backend och Garmin finns. Ingen produktionsdrift, ingen verifierad Västtrafik-anslutning, ingen färdig PRG. SDK-kompilering och praktisk test återstår. Privata koordinater och nycklar anges endast i driftkonfiguration, aldrig i detta offentliga repo.
