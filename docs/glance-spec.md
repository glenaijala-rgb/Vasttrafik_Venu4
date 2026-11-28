> **Beslut 2026-11-28:** Användaren har valt direktanslutning till Västtrafik utan egen server och godkänt API-nycklar i klockans privata inställningar. Detta ersätter äldre krav på backenddrift och backend-only secrets nedan. Nycklar får fortfarande aldrig finnas i Git, källkod eller distribuerad appfil. Se [direktanslutning](direct-mode.md).

# Garmin Venu 4 – Snabbvy (Glance), alternativ A v2.1

**Beslut:** Två närmaste relevanta avgångar **bredvid varandra**, med stora linjenummer och minuter. Exempel: `753 3m | 25 8m`. Detta är en komplettering till den fullständiga listvyn, inte en separat datatjänst.

## Utseende
- Litet Glance-kort, mörk högkontrastbakgrund.
- Rubrik `VÄSTTRAFIK · HEM`, alternativt `VÄSTTRAFIK · JOBB` när Jobb visas.
- Två horisontella poster. Varje post visar linjenummer (vit) och minuter till avgång (ljusblått), tillräckligt stora för att kunna läsas snabbt. Enkel avdelare kan användas.
- En liten bussikon till vänster är valfri om siffrorna fortfarande ryms. Inga hållplatsnamn, destinationsrader eller separata grupper i snabbvyn.
- Inga egna knappar i Glance. Välj hela kortet för att öppna fullskärmsvyn; endast där finns knappen **Hållplats**.
- Fullvyn behåller blandad kronologisk lista, rullning och stor text enligt docs/ui-spec.md.
- HTML-förhandsvisningen är inte en exakt Garmin-layout. Kontrollera **Glance-kortets verkliga dimensioner**, fontmått och säker marginal i Venu 4-simulatorerna för både 41 och 45 mm.

## Urval och data
1. Använd samma profil och normaliserade `departures[]` från backend som fullvyn.
2. Filtrera enligt alla regler och hållplatser i profilen, sortera efter beräknad avgångstid (annars planerad).
3. Visa de **två närmast kommande, ej inställda** avgångarna, även om de är från samma hållplats eller samma linje. Välj inte automatiskt en av varje linje.
4. Återstående minuter beräknas från tidsstämpel och klockans aktuella tid, inte från en statisk text som blir föråldrad.
5. Finns bara en avgång visas den plus ett streck; saknas avgångar visas `Inga avgångar`. Inställda turer markeras i fullvyn men ska inte uppta en av Glance-platserna.
6. Senast hämtade data visas endast om de är tillräckligt färska. Annars visa tydligt `Gammal data`, `Ingen anslutning` eller `Öppna för att hämta` i stället för missvisande minutantal.
7. Hem är standard vid ny öppning enligt tidigare krav. Glance och fullvy får inte visa data från olika profiler under samma aktiva session. Codex ska testa detta mot faktisk Venu 4-livscykel.

## Teknisk anvisning till Codex
- Implementera `Application.AppBase.getGlanceView()` och `WatchUi.GlanceView` samt fullvyn via `getInitialView()`. Verifiera korrekt manifest-app-typ i SDK.
- Glance har begränsat minne och funktioner. Använd **cache-first** från den ordinarie HTTPS-backenden och lagra kompakt data (profil-ID, tidsstämplar och relevanta avgångar) som båda vyerna kan läsa.
- Förutsätt **inte** att live-webbanrop kan göras direkt från Glance utan test i Garmin SDK; fullvyn hämtar normalt uppgifter och sparar cache.
- Använd resurser med `scope="glance"` där relevant. Inga hemligheter i klockappen.
- Ingen separat Garmin-app eller särskilt Glance-API behöver byggas.

## Acceptanskriterier
- Två avgångar från olika stationer samt två från samma linje visas korrekt.
- Nästa ej inställda avgång väljs om den närmaste är inställd.
- 1/0 avgångar, cache utan internet och åldrad data hanteras tydligt.
- Ett tryck på kortet öppnar fullvyn; Hållplats finns där och växlar Hem/Jobb.
- Glance A fungerar i **båda** Venu 4-simulatorerna; layout klipper inte text och visar rätt profil.
- Produktionsflödet innehåller inga syntetiska avgångar.

Garmin-källor: https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html och https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/GlanceView.html .
