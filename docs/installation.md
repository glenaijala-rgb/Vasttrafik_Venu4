# Kom igång – steg för steg

Appen har kod men visar ännu inte riktiga avgångar. Gör först steg 1, så kan Codex sedan fortsätta.

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
.\scripts\setup-secrets.ps1
```

Scriptet frågar efter klientidentifieraren och hemligheten. Inmatningen är dold. Det skapar backend/.env med filåtkomst endast för ditt Windows-konto och en separat slumpnyckel för klockappen. Filen ignoreras av Git. En befintlig fil skrivs inte över.

Säg till Codex: **Kontot och nycklarna är klara.** Skicka inte själva nycklarna.

## 3. Nästa arbete för Codex

- Kör npm run discover:stops. Kontrollera kommun och hållplatsområde för samtliga tre hållplatser.
- Verifiera 753, 25, 78 och 173 i rätt riktning mot riktiga avgångar och vid behov hållplatsföljden.
- Uppdatera GID:n och verifieringsbevis i config/profiles.json. Hints räcker inte som produktionsregel.
- Kör node scripts/validate-config.mjs --production och npm run verify:live.
- Spara bevis lokalt under backend/evidence/. Scriptsen lagrar inga tokens där. Sätt aldrig verified bara för att syntetiska tester passerar.

## 4. Garmin-verktygen

SDK 9.3.0 finns i D:\dev-cache\garmin\sdk. Java finns i Android Studios installation. Enhetsfiler saknas fortfarande.

1. Öppna D:\dev-cache\garmin\manager\sdkmanager.exe i Utforskaren. Ett bakgrundsstartförsök gav inget användbart fönster; starta programmet synligt själv vid behov.
2. Logga in med ditt Garmin-konto om programmet begär det.
3. Under **Devices**, installera **Venu 4 41mm** och **Venu 4 45mm**. SDK Manager kan också behöva välja aktiv SDK.
4. Meddela Codex när enheterna är installerade. Då kan båda byggena, native testerna och verkliga Glance-format kontrolleras.

## 5. Server och klockinstallation

Servern behöver en beständig HTTPS-adress med giltigt certifikat så att Garmin Connect når den. Driftplattform, konto och eventuell kostnad är ännu inte valda. Ingen extern drift har skapats.

Efter godkända simulatorbyggen och driftsatt server:

1. Ställ in BackendUrl till serveradressen och WatchAccessKey till den separata privata appnyckeln, inte Västtrafiks hemlighet.
2. Vid sideload: spara .set-filen från simulatorns App Settings Editor. Verifiera den faktiska inställningsfilen och filnamnet före kopiering. Mobilappen kan sakna inställningar för sideloadade appar.
3. Anslut klockan med USB. Kopiera rätt enhetsbyggda .prg till GARMIN/APPS och den verifierade .set-filen till GARMIN/APPS/SETTINGS enligt Garmins sideload-flöde.
4. Koppla från säkert. Jämför verkliga avgångar med Västtrafik. Kontrollera Hem/Jobb, svepning, flygläge och gammal data.

Installera **aldrig syntax-check.prg eller syntax-tests.prg**. De är generella kompileringskontroller, inte Venu 4-byggen.
