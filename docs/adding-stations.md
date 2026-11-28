> **Beslut 2026-11-28:** Användaren har valt direktanslutning till Västtrafik utan egen server och godkänt API-nycklar i klockans privata inställningar. Detta ersätter äldre krav på backenddrift och backend-only secrets nedan. Nycklar får fortfarande aldrig finnas i Git, källkod eller distribuerad appfil. Se [direktanslutning](direct-mode.md).

# Så lägger vi till nya hållplatser, linjer och regler

**Mål:** Inga kodändringar i Garmin-appen när en ny hållplats läggs till i en befintlig profil.

## Var konfigureras det?
config/profiles.json är sanningskälla. Strukturen är:
- profiles[]: id, label, sortOrder, stations[]
- stations[]: key, name, shortLabel, stopAreaGid, criteria[]
- criteria[]: id, enabled, lineNames[], direction
- direction: description, headsignHints[], allowedDirectionGids[], allowedStopPointGids[], allowedPlatforms[], mustPassStopAreaGids[], verificationStatus, verifiedAt, verificationNote.

## Ny hållplats i Hem
1. Lägg till ett stationsobjekt med unikt key i profilen 'home'. Kortnamn ska vara tydligt på klockans andra rad.
2. Sök upp korrekt stopAreaGid via live-API locations/by-text. Kontrollera hållplatsnamn, kommun och att rätt StopArea valts.
3. Lägg till en eller flera criterion för önskade linjer och **exakta färdriktningar**. Börja med verificationStatus 'pending'.
4. Verifiera med verkliga avgångssvar och vid behov detaljer för servicejourneycalls vilka destinationGid, plattform/stopPoint och eventuella via-stopp som faktiskt gäller.
5. Sätt endast status 'verified' och datum efter dokumenterad kontroll. Fyll i minst ett strukturerat riktningskriterium. Spara inte lösningen genom att filtrera bara på rå headsign-sträng.
6. Lägg till regressionstest för tillåten/otillåten linje, rätt/fel riktning och förväntat kortnamn.
7. Kör validering och CI. Generera klockkonfiguration och bygg/installera appen på nytt. **Ingen handskriven Monkey C-ändring behövs.**

## Ny linje/riktning på befintlig hållplats
Lägg till ett nytt criterion med unikt id i samma stationsobjekt. Flera destinationer för en linje kan ligga i samma regel om de är ekvivalenta; skilda korridorer bör vara separata regler.

## Ny profil
Lägg till ett nytt profiles-objekt. Backend hanterar profil-ID direkt. Med två profiler ger Hållplats-knappen direkt byte; vid tre eller fler ska Garmin-appen kunna visa en profilväljare och tydligt visa aktiv profil. UI-typen ska inte vara beroende av antal hållplatser i en profil.

## 'Alla bussar åt ett visst håll'
Undvik global wildcard på linjer eller godtycklig textmatchning. Lista verifierade linjer/riktningar i criteria, alternativt bygg verifierad passagekorridor med stopPoint och servicejourneycalls. Vid ny linje får den läggas till efter verifiering, utan Garmin-ändring.

## Kontrollpunkter
- Kontrollera GID och riktning efter linjeomläggning/tidtabellsskifte.
- Kontrollera att stopPoint/platform-flytt hanteras med realtimeStopPoint.
- Kontrollera 200-tom-lista separat från 503-konfigurationsfel.
- Riktning för 173 från Kretsloppsparken ska särskilt valideras mot den begärda geografiska färdriktningen.
- Testdata får aldrig visas som live.
