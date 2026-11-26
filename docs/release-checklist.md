# Kontrollista innan skarp drift

## Extern data
- [ ] Västtrafik utvecklarkonto och behörighet till API Planera Resa v4.
- [ ] Klienthemligheter registrerade i säker driftmiljö, inte i Git.
- [ ] Riktiga stopAreaGid/stopPointGid verifierade för Wennerbergsgatan, Toltorpsskolan och Kretsloppsparken.
- [ ] Verifierad riktning och linje för 753/Heden, 25/Hisingen, 78/Gamlestads Torg och 173/Heden i önskad färdriktning.
- [ ] Alla aktiva konfigurationsregler har verificationStatus 'verified' och strukturerade selektorer.
- [ ] Kör 'node scripts/validate-config.mjs --production' utan fel.
- [ ] Ingen buss i motriktning visas i skarpa exempel.

## Backend
- [ ] OAuth2/tokenförnyelse, åtkomst till live-API, timeout och 429/5xx hanteras.
- [ ] Cache/rate limit och icke-allmän proxy säkerställda.
- [ ] Schema, felkoder, loggning utan tokens och konfigurationsändringar dokumenterade.
- [ ] Test för nya hållplatser och regler passerar utan Monkey C-ändring.
- [ ] Inga syntetiska svar används i produktion.

## Klocka
- [ ] Riktigt manifest och kompilering för Venu 4 41/45 mm.
- [ ] Stora siffror, blandade Hem-avgångar, Jobb, rullning, Hållplats-knapp.
- [ ] **Glance A** visar två närmaste ej inställda avgångar sida vid sida, även om samma linje, i båda Venu 4-storlekarna.
- [ ] Glance-kort öppnar fullvy, och Hållplats-knappen finns bara i fullvyn.
- [ ] Testad Glance för 0/1/2+ avgångar, stale/offline, cache, inställd tur och profilväxling i riktig simulator.
- [ ] Alla status- och felmeddelanden samt tidszoner fungerar.
- [ ] USB-installation/sideload och test på fysisk Venu 4.
- [ ] Test med verkliga avgångar jämförd mot officiell avgångsinformation.

**Definition:** Git-repo förberett ≠ backend driftsatt ≠ widget färdig. Markera inte lösningen färdig förrän ovan klar.
