# Klockappen

Monkey C watch-app med getGlanceView(), WatchUi.GlanceView, fullvy, två närmaste ej inställda avgångar och lokal cache. Produkt-ID:n venu441mm och venu445mm är bekräftade i SDK 9.3.0:s exempel. Enhetsbygge är blockerat av saknade device packages.

Kör scripts/build-watch.ps1 från reporoten. -SdkPath och -JavaHome kan anges. -SyntaxOnly gör generell kompilering; dess .prg är INTE en installationsfil för Venu 4. Scriptet kräver BUILD SUCCESSFUL eftersom vissa kompilatorfel ändå ger exitkod 0.

- App.mc: startläge, fullvy och Glance.
- Model.mc: HTTPS via telefon, validering, profilbyte, skydd mot sena svar och timeout.
- Cache.mc: ålder, urval och minutberäkning.
- Glance.mc: vit linje och blå minuter sida vid sida, kompakt cache per profil.
- View.mc: blandad lista, stora siffror, rullning, Hållplats-knapp, profilmeny.
- StartupConfig.mc: genereras från config/profiles.json av byggscriptet.

Svep upp/ned, tryck Hållplats för profilbyte och rubriken för uppdatering. Hem väljs vid ny fullvy; när sessionen stängs återgår Glance till Hem. Detta måste verifieras mot verklig Venu 4-livscykel.

BackendUrl och WatchAccessKey fylls i via simulatorns App Settings Editor. Sideloadade appar är inte garanterade att få inställningssida i mobilappen; vid USB-installation behövs simulatorns .set-fil. Västtrafiks API-nycklar får aldrig skrivas i klockans inställningar.

Fyra native unit tests finns i tests/DepartureTests.mc. Kompilera med tests.jungle och -t, kör därefter monkeydo <test.prg> <device> -t när enheterna finns. Testerna har kompilerats men INTE körts.

Privat signeringsnyckel: local/developer.der. Den ignoreras av Git och ska säkerhetskopieras privat. Ingen Store-publicering har skett.
