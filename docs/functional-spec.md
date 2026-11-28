> **Beslut 2026-11-28:** Användaren har valt direktanslutning till Västtrafik utan egen server och godkänt API-nycklar i klockans privata inställningar. Detta ersätter äldre krav på backenddrift och backend-only secrets nedan. Nycklar får fortfarande aldrig finnas i Git, källkod eller distribuerad appfil. Se [direktanslutning](direct-mode.md).

# Funktions- och teknisk specifikation v2.1

## 1. Syfte
Privat, **skarpt driftsatt** Garmin Connect IQ-widget för Venu 4 med Västtrafiks verkliga planerade och beräknade avgångar. Bygg inte en temporär mock-implementation som huvudspår. Tester får innehålla syntetiska fixtures. Klockan ska inte behöva egen GPS eller en mobilwebbsida.

## 2. Profiler och aktuell omfattning
**Hem, alltid förvald vid ny öppning:** en och samma tidsordnade rullbara lista som blandar:
- Wennerbergsgatan: linje **753** i riktning **Heden**.
- Toltorpsskolan: linje **25** i riktning **Hisingen/Länsmansgården**.

**Jobb:** Kretsloppsparken: linje **78** mot Gamlestads Torg samt **173** mot Heden i avsedd färdriktning. Ytterligare busslinjer i korrekt riktning ska kunna kompletteras i konfiguration, men **ingen buss i motriktning** får passera filtret.

För alla ovanstående är slutliga Västtrafik-GID:n och detaljerade riktningstester **öppna verifieringspunkter**. Ansvarsfull implementation får inte hävda att dessa är verifierade utan live-svar. Kontrollera särskilt om 173:s färdväg faktiskt överensstämmer med 'mot Gamlestaden'. Det är ett verksamhetskrav om riktning, inte likhet mellan bussens slutdestination och textsträngen Gamlestaden.

## 3. Generiska tillägg
En profil kan ha 1..N hållplatser. En hållplats kan ha 1..N filterregler. Varje regel definierar:
- linje eller flera linjer (eventuellt regel för alla **verifierade** linjer i en riktning)
- tillåtna destinationer och/eller riktnings-GID:n samt önskat hållplatsläge/stopPoint
- möjliga krav på att turen passerar ett visst läge (verifieras mot details/servicejourneycalls när nödvändigt)
- kortnamn som syns per avgång på klockan
- verifieringsstatus, med insamlade bevis vid övergång till aktiv drift.

**Utökning av config/profiles.json ska inte kräva ändring av klockans kod.** Backend och Garmin använder profil-ID i ett stabilt normaliserat API. Varje regel testas individuellt, sedan profilens samlade resultat.

## 4. Snabbvy och fullvy
- **Glance A:** två närmaste ej inställda avgångar från profilens gemensamma kronologiska lista, **sida vid sida** med stora linjenummer/minuter; även samma linje två gånger är tillåtet. Ingen uppdelning per hållplats.
- Snabbvyn är startpunkt till interaktiv fullskärmsvy. Knappen **Hållplats** finns i fullvyn, inte i Glance. Hem är förvalt vid ny öppning.
- Snabbvyn använder samma backend/data som fullvyn, med kompakt cache och tydligt meddelande vid gammal data. Se **docs/glance-spec.md** för bindande krav och edge cases.

## 5. UI
Se normerande docs/ui-spec.md. Stora primära siffror, hög kontrast, två raders objekt, sortering efter faktisk/beräknad avgångstid, fler resultat via scroll, status, fast knapp **Hållplats**. En synlig rad med kort ursprungshållplats identifierar alltid vilken station avgången gäller. Ingen gruppering under Hem.

## 5. Tid och filtrering
- Backend hämtar v4 stop-areas/{stopAreaGid}/departures, alternativt stop-points/{stopPointGid}/departures där det behövs och har verifierats.
- Använd estimatedOtherwisePlannedTime eller exakt verifierat motsvarande fält, jämför med plannedTime. Hantera tidszon Europe/Stockholm och ISO/RFC3339 inklusive sommartid och midnatt.
- Filtrera per kriterium innan sammanslagning. Använd inte enbart strängmatchning av destination när det finns risk för fel riktning. Säkra med GID och hållplatslägen eller bekräftad rutt; fail closed för oklara regler.
- Sammanfoga och sortera på avgångstid. Normalgräns 16 inom konfigurerad sökhorisont. Om färre finns får de inte ersättas med felaktiga turer.
- Slå inte samman olika faktiska avgångar av misstag. Rensa dubbletter enbart när samma källavgång hämtats flera gånger.
- Avgångar som passerat ska tas bort vid nästa hämtning. Inställda avgångar tydligt markerade, utan vanlig nedräkning. Delinställda turer ska tolkas med relevanta fält på aktuell hållplats.

## 6. Kommunikation och fel
- Klockan anropar GET /api/v1/departures?profile=home|work över HTTPS via Garmin Connect och ska tåla förlorad BLE/Internet.
- Backend håller OAuth-hemligheter, gör kort cache (ca 45 sek, styrbart), rate limiting och begränsar till på förhand definierade profiler. Inte generell öppet åtkomlig trafikproxy.
- Klockan begär uppdatering vid öppning, vid profilbyte och manuellt. Ingen aggressiv polling i bakgrunden.
- Felmeddelanden för konfiguration saknas, uppströms-API nere, ingen anslutning, inga avgångar, samt gammal data. Klockan får visa gammalt svar med tydlig varning, aldrig som om det vore live.
- Kontrollera API-anropsgränser och villkor i Västtrafiks utvecklarportal.

## 7. Tillgänglighet, acceptans
- Hem startar utan GPS; 753 och 25 i en gemensam korrekt sorterad lista.
- Jobb inkluderar korrekt 78/173 men ingen motriktning, med explicit live-verifiering.
- Samma UI för 1 eller många hållplatser och för nya profiler.
- Flera kommande avgångar nås med scroll; minsta huvudfont föredras större framför fler synliga rader.
- Hållplats växlar profiler med ett tryck. Flera framtida profiler kan få en valmeny men befintlig etttrycksväxling ska bestå med två profiler.
- Både Venu 4 41 och 45 mm fungerar i SDK-simulator och helst på fysisk klocka.
- Avbryt liveläget med CONFIG_INCOMPLETE när obligatoriska ID:n/riktningar fortfarande är obekräftade.
- Dokumenterad installation, driftsättning, test och felsökning.

## 8. Ej med
Automatisk positionsbestämning, GPS, mobilinställningswebbplats, biljetter, karta, pushnotiser, Connect IQ Store-publicering. Kan byggas senare utan ny kärnarkitektur.

## 9. Dokumenthierarki
Detta dokument och docs/ui-spec.md är normerande. config/profiles.json definierar konkreta regler, docs/api-contract.md definierar gränssnittet och docs/adding-stations.md reglerar tillägg.
