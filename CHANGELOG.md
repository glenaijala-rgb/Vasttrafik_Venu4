# Ändringslogg

## 2.1.0 – implementation under verifiering – 2026-11-28

- Implementerad privat Node-backend för Planera Resa v4 med schema, generiska filter, OAuth, cache, tidsgränser och rate limit.
- Implementerad Monkey C-app för Venu 4 med Glance A, fullvy, cache och profilbyte.
- 29 Node-tester passerar; generell app- och native testkompilering passerar.
- Ny kontoguide, lokal inmatning av hemligheter, byggscript och separata live-kontroller.
- Inte en driftklar release: credentials, verifierade GID:n/riktningar, device packages, simulator, HTTPS-drift och klocktest återstår.
