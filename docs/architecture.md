# Teknisk arkitektur och ansvar

Garmin Venu 4 (Connect IQ/Monkey C)
-> Bluetooth + Garmin Connect på telefon
-> HTTPS GET /api/v1/departures?profile=...
-> säker liten backend (rekommenderad TypeScript/Cloudflare Worker)
-> Västtrafik Planera Resa API v4 + OAuth2

## Backendens moduler (rekommenderad)
- **Config loader/schema validation:** en profil har N stationer, station N criteria; fail-closed om obligatoriska regler är pending.
- **OAuth provider:** använder miljöhemligheter, tokenförnyelse och återförsök; aldrig token i Git.
- **Västtrafik client:** requests till stop-area-departures, stop-point-departures och details vid verifieringsbehov; timeouts och hantering av 429/5xx.
- **Rule engine:** tillåtna linjer OCH verifierad riktning/hållplatsläge/passage. Hints och preliminära platformkandidater är metadata för upptäckt och får inte styra liveläget.
- **Normalizer/merger:** samma utgående Departure-format oavsett källa; deduplicera verkliga dubletter; sortera med beräknad eller planerad tid.
- **Cache/server:** cache 30–60 sek, rate limiting, allowlist för profilsökningar, hälsokontroll utan känslig data.
- **Tests:** konfigurationsvalidering, filtrering, sammanflätning, felsteg, schemakontrakt och skarpa API-samples (med redigerade hemligheter).

## Kritiska designbeslut
1. Klockan känner **inte** till hållplats-ID:n. Endast profil-ID:t och normaliserade avgångsobjekt skickas till Garmin.
2. Backend har **inga specialfall för Hem eller Jobb**. Profilernas beteende definieras enbart i konfigurationen.
3. JSON-konfiguration kan expanderas utan att ändra API-kontrakt eller layout.
4. OAuth-auth, GID-verifiering, rate limiting och tokenrotationsprocess dokumenteras före live-drift.
5. Välj ett hanterbart driftalternativ med HTTPS och säker sekretesslagring. Backend är inte en allmänt fri Västtrafik-proxy.
6. Dokumentera om klockans nätverksanrop, minnesgränser eller app-behörigheter kräver SDK-specifika anpassningar.

Källor: https://github.com/vasttrafik/api-pr-docs/blob/main/docs/REST.md och https://developer.garmin.com/connect-iq/articles/core-topics/HTTPS.html
