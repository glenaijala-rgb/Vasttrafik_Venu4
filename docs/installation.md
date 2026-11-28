# Kom igång – steg för steg

Appen hämtar nu riktiga avgångar direkt från Västtrafik. Ingen egen server behövs. Kontot, nycklarna, hållplatsverifieringen och SDK-byggena är klara på denna dator.

## 1. Västtrafik-kontot

1. Öppna https://developer.vasttrafik.se/ .
2. Klicka på länken **Skapa ett konto**. Välj din e-postadress och ditt lösenord själv. Följ eventuell e-postbekräftelse.
3. Logga in och skapa en **applikation** med namnet **Vasttrafik Venu4** och beskrivningen **Privata bussavgångar på min Garmin-klocka**.
4. Välj **Prenumerera på nytt API** och **Planera Resa v4**. Guidens illustration kan visa äldre v2; vår app behöver v4.
5. Applikationen har en **klientidentifierare** och en **hemlighet**. Behåll dem i portalen tills nästa steg. Klistra inte in dem i chatten.

Kontrollerat mot [kontoguiden](https://developer.vasttrafik.se/guides/get-started) och [API-sidan](https://developer.vasttrafik.se/apis/13/v4) den 28 november 2026. Kontot, villkorsgodkännandet och lösenordet hanterar du själv.

## 2. Spara nycklarna lokalt

Öppna PowerShell och klistra in hela blocket:

```powershell
cd 'D:\kod\Vastrafik Venu4'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-secrets.ps1
```

Scriptet frågar efter klientidentifieraren och hemligheten. Inmatningen är dold. Högerklicka för att klistra in; Ctrl+V kan bli ett kontrolltecken i Windows PowerShell. Vid byte av nycklar: lägg till -UpdateCredentials i kommandot. Övriga inställningar behålls. Det skapar backend/.env med filåtkomst endast för ditt Windows-konto och en separat slumpnyckel för klockappen. Filen ignoreras av Git. En befintlig fil skrivs inte över.

Säg till Codex: **Kontot och nycklarna är klara.** Skicka inte själva nycklarna.

## 3. Nästa arbete för Codex

- Kör npm run discover:stops. Kontrollera kommun och hållplatsområde för samtliga tre hållplatser.
- Verifiera 753, 25, 78 och 173 i rätt riktning mot riktiga avgångar och vid behov hållplatsföljden.
- Uppdatera GID:n och verifieringsbevis i config/profiles.json. Hints räcker inte som produktionsregel.
- Kör node scripts/validate-config.mjs --production och npm run verify:live.
- Spara bevis lokalt under backend/evidence/. Scriptsen lagrar inga tokens där. Sätt aldrig verified bara för att syntetiska tester passerar.

## 4. Garmin-verktygen

SDK 9.3.0 finns i D:\dev-cache\garmin\sdk. Java finns i Android Studios installation. Enhetsfiler för båda Venu 4-storlekarna är installerade; nio native tester per storlek passerar.

1. Öppna D:\dev-cache\garmin\manager\sdkmanager.exe i Utforskaren. Om inget fönster öppnas, kontrollera om en kvarvarande dold sdkmanager-process blockerar starten. Den tidigare låsningen löstes genom att avsluta just den processen och starta programmet på nytt.
2. Logga in med ditt Garmin-konto om programmet begär det.
3. Under **Devices**, installera **Venu 4 41mm** och **Venu 4 45mm**. SDK Manager kan också behöva välja aktiv SDK.
4. Meddela Codex när enheterna är installerade. Då kan båda byggena, native testerna och verkliga Glance-format kontrolleras.

## 5. Klockinstallation utan server

1. Anslut din Venu 4 med USB-kabeln. Ange om det är 41 eller 45 mm.
2. Använd rätt produktionsfil: garmin/bin/venu441mm.prg respektive garmin/bin/venu445mm.prg. Kopiera den till klockans GARMIN/APPS med namnet VASTTRAFIK.PRG.
3. Kopiera den privata filen garmin/local/VASTTRAFIK.SET till klockans GARMIN/APPS/SETTINGS/VASTTRAFIK.SET. Filen innehåller API-inställningarna och får inte delas.
4. Koppla från klockan säkert. Kontrollera att den är ansluten till Garmin Connect på telefonen och att telefonen har internet.
5. Öppna Västtrafik. Hem ska visa 753 och 25. Knappen Hållplats växlar till Jobb. Jämför avgångarna med Västtrafik och prova rullning samt snabbvyn.

På denna dator är inställningsfilen förberedd med simulatorns lokala Properties-API. Se [direktanslutning](direct-mode.md). För nyinstallation på annan dator måste en ny privat inställningsfil förberedas; kopiera aldrig nycklar till källkod eller chatten.

Installera aldrig syntax-check.prg, testbyggen eller provisioning.prg på klockan. Fysisk installation, anslutningsbortfall och livejämförelse på klockan återstår innan appen kan kallas driftklar.
