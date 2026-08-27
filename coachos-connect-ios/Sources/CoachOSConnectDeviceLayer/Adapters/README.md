# Adapters

Deze map is bewust leeg in Sprint 1.

Hier komen in latere sprints de concrete implementaties van
`DeviceAdapterProtocol`, te beginnen met de PM5/Concept2 Adapter (Sprint 5
in de oorspronkelijke roadmap), gevolgd door Wahoo, Tacx, Garmin, Polar,
Stryd en overige apparaten.

Sprint 1 levert alleen de architectuur (`DeviceAdapterProtocol`,
`DeviceLayer`, `DeviceAdapterRegistry`, capability-systeem). Er wordt hier
expliciet nog geen Bluetooth-code, geen fabrikant-SDK en geen
apparaat-specifieke logica toegevoegd — eerst de lege stekkerdoos, daarna
de apparaten erin.

Elke toekomstige adapter:
1. Implementeert `DeviceAdapterProtocol` volledig.
2. Rapporteert zijn eigen `capabilities()` naar waarheid — nooit een
   capability claimen die het apparaat niet daadwerkelijk ondersteunt.
3. Wordt geregistreerd via een `DeviceAdapterFactory` bij de `DeviceLayer`
   in `AppAssembly`, niet ergens anders in de app.
4. Bevat geen sportlogica en geen coach-beslissingen — die blijven in
   CoachOS.
