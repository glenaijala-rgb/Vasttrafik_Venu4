# Direktanslutning utan egen server

Beslut 2026-11-28: användaren avstår från hostingtjänster och accepterar privata API-nycklar på sin klocka. Detta ersätter tidigare backendkrav. Ingen molntjänst, provperiod, betalplan eller extern drift har skapats. Västtrafiks framtida API-villkor kan vi inte garantera.

## Flöde

Venu 4 → Garmin Connect på telefonen → HTTPS till Västtrafik. Appen hämtar OAuth-token och Planera Resa v4-data direkt. Telefonens internetanslutning behövs; datorn behöver inte vara igång. Snabbvyn läser kompakt cache från senaste öppning av fullvyn och gör inga egna nätanrop.

- `DirectClient.mc`: OAuth, tokenförnyelse vid 401, sekventiella frågor, 60 sekunders paus efter 429 och total tidsgräns.
- `DirectRules.mc`: generiska riktningar, hållplatslägen, passage efter rätt hållplatsanrop, inställda turer, tidszoner, normalisering och sortering.
- `DirectConfig.mc`: genereras från `config/profiles.json`, utan hemligheter. Ofullständig konfiguration stänger hämtningen.
- `Model.mc`/`Cache.mc`: samma data till fullvy och Glance, 45 sekunders cache, 15 sekunders minsta uppdateringsintervall, åldersvarning efter 180 sekunder.

Avgångar hämtas fem åt gången eftersom större svar överskred Garmins svarsbuffert i verkligt prov. Högst 400 råavgångar per station/riktningsfråga; nådd gräns markeras som ofullständig lista. Hämtningen avbryts efter 40 sekunder vid nästa callback; UI släpper en fastnad hämtning efter 45 sekunder. Detaljsvar som överskrider Garmins buffert ger tydligt fel, aldrig gissad riktning eller inställningsstatus. Detta är en begränsning att kontrollera när nya långa rutter införs.

Backendkoden finns kvar som lokalt verktyg för GID-verifiering, regeljämförelser och tester. Den körs inte för klockans dagliga användning. Det äldre HTTP-kontraktet är oförändrat; direktklienten producerar dess normaliserade klockfält i minnet.

## Privata inställningar

`VasttrafikClientId` och `VasttrafikClientSecret` lagras i Garmin Application.Properties, separat från `.prg`. De är inte ett krypterat nyckelvalv: den som får tillgång till klockans eller datorns privata filer kan få tillgång till API-nycklarna. Vid förlust kan de återkallas hos Västtrafik. Detta är den av användaren accepterade avvägningen.

Nycklar ligger inte i källkod, Git, loggutskrifter eller produktionsresurser. `.SET`, `.env` och `garmin/local/` ignoreras av Git. Dela inte den privata `.SET`-filen. Produktionsappen har ingen funktion som tar emot nycklar genom godtyckliga telefonmeddelanden.

På utvecklingsdatorn har en separat lokal simulatorhjälpare sparat nycklar via Garmins egna Properties-API. Den hjälparen finns endast under `garmin/local/` och ska inte installeras på klockan. Simulatorns sparade inställningar har kopierats till `garmin/local/VASTTRAFIK.SET`. Endast den vanliga enhetsbyggda appen och inställningsfilen används vid sideload. Ingen extern inställningswebbsida har använts för nycklarna.

## Konfiguration och tester

När stationer ändras: verifiera live, ändra JSON, kör `npm run check`, `node scripts/generate-watch-test-fixtures.mjs` och bygg om båda enheterna med `scripts/build-watch.ps1`. Appens handskrivna vyer och regler behöver inga stationsspecifika ändringar, men den genererade konfigurationen kräver ett nytt bygge och installation.

Native tester finns i `garmin/tests.jungle`. De jämför direktklientens regler med sparade verkliga v4-svar och backendens förväntade normalisering samt provar tokenförnyelse, 429, paginering, inställt, cache och profilbyte. Testbyggen får aldrig installeras som produktionsapp.
