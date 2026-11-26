# Integrationsanteckningar

## Västtrafik
Officiell API-dokumentation: https://github.com/vasttrafik/api-pr-docs/blob/main/docs/REST.md. Version 4. Bearer-token krävs. Bas-URL/token-URL ges efter registrering på https://developer.vasttrafik.se/ .

- locations/by-text används för att hitta rätt StopArea-GID.
- stop-areas/{stopAreaGid}/departures hämtar avgångar. stop-points/{stopPointGid}/departures kan användas för verifierad plattform.
- Strukturerad riktning kan verifieras med directionGid och/eller details med servicejourneycalls. Ett textmatchat destination-hint räcker inte alltid.
- För återgivning: estimatedOtherwisePlannedTime, plannedTime, cancellation-fält, realtimeStopPoint. Slutliga fältnamn/schema kontrolleras mot riktiga svar.

## Garmin
HTTPS-mekanism: https://developer.garmin.com/connect-iq/articles/core-topics/HTTPS.html .
Manifest/behörigheter: https://developer.garmin.com/connect-iq/articles/core-topics/Manifest_and_Permissions.html .
Connect IQ SDK: https://developer.garmin.com/connect-iq/sdk/ .

## Öppna frågor inför driftsättning
1. Faktiska API-credentials och giltiga anropsgränser.
2. Verifierad StopAreaGid/StopPointGid och destination på samtliga tre hållplatser.
3. Bekräfta exakt riktning och färdväg för 173 från Kretsloppsparken.
4. Backendadress med HTTPS, cache/rate limit, eventuell accesskontroll.
5. Garmins korrekta produktidentiteter i manifest och slutlig simulatorlayout.
