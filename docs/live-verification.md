# Live-verifiering 2026-11-28

OAuth och Planera Resa v4 verifierade med användarens lokala nycklar. Sökningar gjordes för aktuell lördag och måndag 2026-11-30 kl. 15–18 svensk tid. Råa trafikbevis ligger lokalt under den Git-ignorerade katalogen backend/evidence; reducerade verkliga trafikexempel finns i tests/fixtures/live-2026-11-28.json. Inga autentiseringsuppgifter ingår.

| Hållplats | stopAreaGid | Tillåtet stopPointGid | Regel |
|---|---|---|---|
| Wennerbergsgatan, Mölndal | 9021014012222000 | 9022014012222002 (B) | 753 mot Heden |
| Toltorpsskolan, Mölndal | 9021014012221000 | 9022014012221002 (B) | 25 mot Hisingen |
| Kretsloppsparken, Göteborg | 9021014005095000 | 9022014005095001 (A) | 78 mot Gamlestads Torg; 173 mot Heden |

Verifieringen använder locations/by-text, avgångar i båda riktningar och servicejourneycalls i detaljsvaren. Produktionsregeln är linjebeteckning OCH verifierat stopPoint-GID. Destinationshint används inte som filter. directionGid behövs inte när hållplatsläget särskiljer riktningen; inga sådana GID:n har gissats. Ett nytt realtidsläge som inte verifierats utesluts tills konfigurationen uppdateras.

- 753 från läge B passerar Toltorpsskolan, Sahlgrenska, Chalmers och fortsätter till Heden. Läge A går mot Mölndal.
- 25 från läge B har både Länsmansgården och Länsmanstorget som skyltning. Båda verifierade turerna passerar Hjalmar Brantingsplatsen på Hisingen. Läge A mot Balltorp/Mölndal utesluts.
- 78 från läge A passerar Alelyckan, Skräppekärr Östra, Alekärrsgatan och Nylösegatan till Gamlestads Torg. Läge B går mot Eriksbo.
- 173 från läge A passerar samma korridor till Nylösegatan, därefter Kristinedal, Svingeln, Polhemsplatsen och Heden. **Den stannar inte vid Gamlestads Torg.** Den verifierades i vardagens tidtabell; lördagens tre timmars sökfönster innehöll ingen 173. Detta är inte ett påstående om hela helgens trafik.

API:ets line.name är exempelvis ”Buss 753”; line.shortName är ”753”. Backend använder shortName med designation/name som reserv. directionDetails.shortDirection ger läsbar destination utan tillägget ”Påstigning fram”. Detaljsvar kan innehålla flera sammanhängande serviceJourneys; rätt tur väljs med exakt serviceJourney.gid och rätt hållplatsanrop med GID och avgångstid.

Verifieringen gäller aktuell tidtabell. Gör om den vid linjeomläggning. Klockbygge, simulator, HTTPS-drift och fysisk klocka måste fortfarande verifieras innan systemet är driftklart.
