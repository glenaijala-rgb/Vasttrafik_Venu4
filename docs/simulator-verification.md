# Garmin-simulator 2026-11-28

SDK 9.3.0, enheter venu441mm och venu445mm (simulatorns firmwaremodell 6.0.3). Produktionsfilerna är garmin/bin/venu441mm.prg respektive venu445mm.prg; båda gav BUILD SUCCESSFUL. Dessa filer innehåller inga Västtrafik-hemligheter.

Fem tester i garmin/tests/DepartureTests.mc kompilerades med -t och kördes via monkeydo /t för vardera enheten: 5 PASS, 0 fel. De täcker inställda/passerade avgångar, två från samma linje, 0/1 avgång, gammal cache, framtida klocka, minutberäkning, försenat svar efter profilbyte samt strängjämförelser/cache/profilväxling.

Den visuella kontrollen avslöjade att Monkey C-strängar jämfördes med ==, vilket gav HOME i stället för HEM och kunde avvisa svar/cache med ett separat strängobjekt. Alla profiljämförelser använder nu equals. Regressionstestet använder separata strängobjekt och lagringens returvärden.

Glance-rubriken klipptes i 41 mm-modellens verkliga kortyta. Rubriken fick mindre, uppmätt font och vertikal marginal. Båda avgångarna använder samma fontstorlek, vald efter båda texternas bredd. Slutlayout granskad i båda simulatorerna, exempel 753 8m bredvid 25 10m från verklig cache.

En lokal, Git-ignorerad testtarget under garmin/local laddade nyligen hämtade backend/evidence/live-home.json och live-work.json via DepartureModel.receive. Därefter visades samma produktionsvyer från cachen. Ingen syntetisk produktionskälla eller separat demo-app skapades. Installera aldrig preview- eller tests-filerna på klockan.

Visuellt kontrollerat:

- Glance A: två avgångar sida vid sida på 41 mm (274×128 innehållsyta) och 45 mm (318×150).
- Korttryck öppnar fullvyn med Hem och en gemensam lista på båda modellerna.
- Hållplats växlar till Jobb på 41 mm. Native test verifierar även växling tillbaka.
- Svep rullar listan på 45 mm med Hållplats kvar längst ned.
- Äldre cache visar Gammal data utan minutantal i 45 mm-snabbvyn.
- Saknad serverinställning visas tydligt i fullvyn.

Begränsningar: ingen sammanhängande HTTPS-anslutning från simulatorn, fysisk klockinstallation eller verkligt BLE/offline-prov ännu. Alla visuella edge cases och hela Glance/fullvy-livscykeln är inte färdigprovade på båda modellerna. Backendens verkliga HTTP-flöde verifierades separat. Appen är därför inte driftklar.
