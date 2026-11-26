# Bindande UI-spec v2.0 – Garmin Venu 4

## Principer
Rund, mörk, högkontrastskärm. **Stora siffror** är viktigare än antalet samtidiga rader. En generisk vy som visar profilens avgångar från 1..N hållplatser i en **gemensam lista**, utan grupper.

## Layout
- Överst: aktiv profil, t.ex. **HEM** eller **JOBB**, centrerad.
- Varje avgång max två rader. Första: **linjenummer** till vänster och **N min** till höger, helst 26–30 faktiska px eller större där det går. Andra: kort hållplatsnamn + destination, läsbara 14–18 px.
- Exempel Hem: rad 1 '753       3 min', rad 2 'Wennerbergsg. · Heden'; nästa rad '25       6 min' och 'Toltorpssk. · Hisingen'. Detta är en **blandad tidsordnad lista**, inte två block.
- Jobb: t.ex. '78 4 min' följt av 'Kretsloppsp. · Gamlestads Torg', sedan '173 9 min' följt av 'Kretsloppsp. · Heden'. Exempeltider är inte live-data.
- Mitt: rullbar lista; visa så många som ryms, normalt ca 3–4 på 41 mm och 4–5 på 45 mm men **ingen förminskning** för att få in fler. 16 eller fler resultat nås genom scroll.
- Nedre fast område: synlig knapp **Hållplats** (minst ca 44×44 px beröringsyta om tillgängligt), status 'Uppd HH:mm' där text inte kapas på rund skärm.
- Tydlig separering mellan scrollgest och byte av profil. Ingen oavsiktlig knapptryckning vid rullning. Profilbyte återställer scrollpositionen.
- Skärmstorlek: Venu 4 41 mm 390×390 och 45 mm 454×454. Använd cirkelsäker layout och mät text i Garmins Graphics API. HTML-mockup ersätter **inte** SDK-simulator.

## Beteende
- Ny öppning = Hem, alltid; inga GPS-anrop.
- Ett tryck på **Hållplats** växlar Hem -> Jobb eller Jobb -> Hem. När fler än två profiler konfigureras får man välja i meny, men två-profilsflödet ska inte försvåras.
- Hämta data vid öppning/byte och efter uttrycklig uppdatering. Gammal cache får visas enbart med tydlig 'Gammal data'-status.
- Status: Hämtar, Uppdaterad HH:mm, Ingen anslutning, Inga avgångar, Inställd, +N min försening och eventuellt nytt hållplatsläge.
- Inställd: visa 'Inställd' istället för ordinarie nedräkning. Sortera på avgångens tidsposition även om inställd, men markera tydligt.

## Acceptance UI
- Linjenummer och minuter är dominerande i 41 mm simulatorn.
- 753/25 från olika hållplatser blandas och kan skiljas via kortnamn.
- Button Hållplats alltid på plats under scroll.
- Scroll når alla hämtade avgångar och visar inte delvis klippt slutrad.
- Robust mot långa linjenummer/namn och framtida tredje hållplats.
- Syntetiska skärmtider förekommer endast i docs/ui-preview.html eller tester.
