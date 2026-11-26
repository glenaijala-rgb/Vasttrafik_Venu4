# Profilkonfiguration

**profiles.json är den enda källan för hållplatser, linjer och riktning.** Filen är versionerad och avsedd för produktion, men har initialt **null** för ej verifierade GID:n och pending för riktning. Detta är avsiktligt: den skarpa appen ska fail-closed med CONFIG_INCOMPLETE tills riktiga live-värden fyllts i.

- profiles[]: godtyckligt antal profiler
- stations[]: godtyckligt antal stationer per profil
- criteria[]: godtyckligt antal linje-/riktningskrav per station
- defaults: startprofil, cache, sökfönster, max antal avgångar, tidszon

VIKTIGT: Alla lineNames och headsignHints här är användarkrav/kandidater, INTE slutlig API-verifiering. Se docs/adding-stations.md.

Kör: node scripts/validate-config.mjs
