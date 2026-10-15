# ADR 0050: Social life of the census citizens: venues, weekly rhythm, gatherings and travel

**Reference:** maintainer request 2026-10-15 (session, RU): "implement social life in terms of
buildings and processes for citizens: when they woke up, did they go somewhere, did they have a
tavern, something like our nightlife or daylife? Where did they go, did they travel across cities,
how did they meet other people? Design the process change, what needs to change in the city, maybe
new buildings modelled on historical ones." Epic **R-1966** (SOC-0); research **R-1967**
([dossier](../../history/dossiers/dailylife/social-life-and-daily-rhythm-1343.md)); design **R-1985**;
first slice **R-1984**.

Builds on [ADR 0008](0008-three-act-campaign-and-faction-scope.md) (scope),
[ADR 0028](0028-seamless-building-interiors.md) (interiors),
[ADR 0032](0032-bespoke-landmark-sites-in-the-city.md) (landmark sites),
[ADR 0046](0046-church-services-and-collective-channeling.md) (church services) and the
LIFE-0 epic (R-1337) whose tavern and church anchors (R-1354) the first slice delivers for the
seamless city.

## Status

**Proposed.** The first slice (R-1984) stays inside the existing census scheduler and LIFE-0
scope and ships without waiting; everything under "Gated by this ADR" waits for approval.

## Context

- 3,902 census residents walk a timetable by trade ([`CITIZENS.md`](../SYSTEMS/CITIZENS.md)), but
  their day ended with a walk to a well or gate; 26 innkeepers, 29 alewives and 39 brewers had no
  customers, there were no guild rooms, one bath, no week (every day was a working day) and no
  night bell.
- The evidence ([R-1967 dossier](../../history/dossiers/dailylife/social-life-and-daily-rhythm-1343.md)):
  the day ran on church bells; night rest began at the nine o'clock bell and closed beer-shops and
  wine rooms; Tallinn had a krug by 1280; the council kept a wine cellar under the town hall
  (1322); St Canute's guild held its house from 1326 and St Olaf's from 1341 (both on Pikk); public
  baths stood by the Nuns' Gate (1310), by St Olaf (1329) and on Sauna street; journeymen drank in
  suburb krugs and had to be back before the gates shut; ship crews slept aboard; spring thaw was
  the worst season for land travel, the Novgorod summer convoy was forming in April.
- `GameCalendar.weekday_index` used the Gregorian form of Zeller's congruence on Julian dates, so
  every weekday was one day early (Easter 1343 came out a Saturday).

## Decision

1. **Social life is part of the census timetable, not a simulation.** A resident's place stays a
   pure function of (weekday, hour). Weekday variants of a pattern (`craft@sat`, `craft@sun`) and
   conditional keys (`evening`, `sunday`, `bath`) resolved from per-resident flags carry it. No
   saved state.
2. **Venues are houses that already exist in 1343.** A beer-shop is the door and diele of a
   brewer's, alewife's or innkeeper's census house (the suburb houses on the Viru and Karja roads
   are the krugs outside the gates); the council wine cellar is the town hall; guild evenings are
   at the guild houses on Pikk; baths are the attested bath sites. No free-standing "tavern" with
   a sign board, no Great Guild hall (1407-10), no Blackheads (1399/1400).
3. **The week:** Monday-Friday working days; Saturday afternoon bath for those who bathe (German,
   Danish and Swedish burghers mostly); Sunday no work or trade, church, an afternoon walk and the
   week's longest evening out. The generic church slot stays until ADR 0046 replaces it.
4. **The day's end:** work stops at the evening bell (about 18:00-19:00), the social hour follows,
   and everyone is home by the nine o'clock night bell; hosts close about nine. Most drinkers sit
   inside (not drawn), a share stands at the door.
5. **Who goes where** is decided by status and trade: councillors and merchants to the wine cellar,
   masters of a guild's trades to its house, everyone else to one of the two nearest beer-shops;
   men far more often than women.
6. **The campaign calendar is Julian.** `weekday_index` uses the Julian congruence.

### Gated by this ADR (needs approval)

- **New plan buildings:** St Canute's guild house on the Pikk 20 plot (empty in the plan today), a
  harbour beer booth by the fish landing, the bath houses by St Olaf and on Sauna street as POIs.
- **Venue presentation:** a dressing kit (bush on a pole, benches, barrels, tankards) and two
  interiors (beer-shop diele, guild hall with trestle tables) - each an art task with
  `assets/SOURCES.csv` rows (asset freeze P0-040).
- **Gatherings:** dated, deterministic events that move people for an evening: guild drinking
  feasts (later night bell at eleven), weddings and funerals of census households, the council
  proclamation at the church door. Built on the existing event overlay model, not a new event bus.
- **Travel:** residents away from Reval on a given date (merchants on the Lübeck, Visby, Riga and
  Novgorod legs, skippers waiting for open water) are absent from the streets; guest merchants
  lodge with burgher hosts; Harju peasants come in at dawn and leave before the gates close. After
  23 April the land roads close to normal traffic (uprising).

## Alternatives

- **Free-standing taverns as new landmark buildings.** Rejected: the 1343 evidence is for beer
  sold from houses, and it would invent buildings where census families live.
- **A per-resident needs simulation (thirst, sociability).** Rejected: non-deterministic, needs
  saved state, and the census timetable already answers "where is this person now".
- **Feast days through the phase system.** Rejected: phases are story time; social rhythm follows
  the calendar like seasons and market days do.

## Consequences

- Evenings and Sundays look different from weekday mornings; the beer-shop becomes a natural
  rumour hub for quests (*Bitter Brew*) and the night bell a stealth timer.
- Weekday-dependent systems (market-day fallback, population profiles) shift to the correct day;
  tests that hard-coded the old weekday were updated.
- More residents are outdoors in the evening; the presentation caps (12 outdoor, 6 indoor bodies)
  are unchanged, so cost is bounded.
- Follow-up tasks: SOC-4 (R-1986) evening capture and presence tuning, SOC-5 (R-1987) St
  Canute's house and venue POIs, SOC-6 (R-1988) venue dressing and interiors, SOC-7 (R-1989)
  gatherings, SOC-8 (R-1990) travel and absence, SOC-9 (R-1991) venue dialogue and barks.
