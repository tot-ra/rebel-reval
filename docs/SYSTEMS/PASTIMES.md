# Pastimes: games and leisure of common people

Status: planned (epic **R-1956**, tasks **R-1957**..**R-1965**). Nothing on this page is built yet.

Scope: how ordinary people of Reval, its suburbs and the Harju villages spent free time in 1343 (dice, board games, children's games, strength contests, feast-day customs), shown as ambient life and, for a few games, playable with citizens. Two goals: teach real 14th-century culture, and add short, varied play between quests.

Out of scope: a gambling economy or casino loop; a universal good/evil score; procedural content or runtime LLM; anything dated after 1343 (period rule: dated later -> exclude; unknown 1343 state -> simplified later form, labelled). Playable games need ADR 0049 (task **R-1958**) accepted first. Naval and castle-building mini-games stay excluded ([`MINI_GAMES.md`](../MINI_GAMES.md)).

## Today

- No pastimes exist. Citizens work, eat, sleep, go to church and fetch water; nobody plays.
- Related playable loops planned elsewhere: market haggling, smuggling run, tavern brawl ([`MINI_GAMES.md`](../MINI_GAMES.md)); brawls with residents (R-1756).
- The entry point for playing with a citizen already exists: talk to anyone via ADR 0047 ([`DIALOGUE.md`](./DIALOGUE.md), `dialogue.city.small_talk`).

## Evidence

Dossier: `history/dossiers/dailylife/pastimes-1343.md` (task **R-1957**, not written yet). Until it lands, every item below is a **candidate** to be confirmed, labelled or excluded.

Questions the dossier must answer: was there anything like football or a bat-and-ball game in Livonia (expected answer: no reliable evidence, which is itself a fact to teach); which dice games and board games are attested in Hanseatic towns; what the Tallinn excavations show (bone dice, gaming pieces, tops, bone skates); which Estonian folk contests (stick-pulling, wrestling, swings) can be shown as a simplified later form; how the council and church treated gambling.

## Design (draft, pending R-1957 and R-1958)

### Ambient pastimes (watch)

| Candidate | Who, where, when | Task |
|---|---|---|
| Dice circle | journeymen, carters, sailors; bench or table by a tavern or harbour, evening | R-1959 |
| Board game (morris or tables) | artisans, clerks, older men; bench by a door, evening, Sundays | R-1959 |
| Tops and knucklebones | boys and girls; lanes and yards, by day | R-1959 |
| Feast-day swing, wrestling, races | Estonian village youth; village green, Easter (13 Apr 1343) and St George (23 Apr) | R-1959 |
| Tavern songs and a travelling musician | mixed; tavern interiors, evening | later, after R-1957 |

### Playable games (play, max 3 for Act 1)

| Candidate | Feel | Task |
|---|---|---|
| Dice for a small stake | quick luck game, under 2 minutes | R-1962 |
| Nine men's morris (or tables, per R-1957) | calm thinking game, opponent skill by who they are | R-1963 |
| Strength contest (stick-pulling or wrestling) | physical timing contest at a village feast | R-1964 (idea) |

All games start from a conversation ("Play a game?") with a citizen whose place, hour, age and rank fit; the citizen may refuse. Throws and AI are seeded from `GameState`, so results replay after save/load. Stakes are small (a coin or a drink, a trust nudge, a rumour). The first time the player watches or plays a pastime a short sourced note joins the journal (R-1965).

### Planned stable IDs

`minigame.pastime.<game>`, `flag.pastime.<game>.played`, `pastime.<game>.wins`, `journal.custom.<pastime>`, `obj.pastime.dice`, `obj.pastime.dice_cup`, `obj.pastime.morris_board`, `obj.pastime.top`, `obj.pastime.knucklebones`.

## Tasks

| ID | Task | Depends on |
|---|---|---|
| **R-1957** PT-1 | Research dossier: games, sport and leisure c. 1343 (incl. football question) | - |
| **R-1958** PT-2 | ADR 0049 folk pastime mini-games + `MINI_GAMES.md` shortlist | PT-1 |
| **R-1959** PT-3 | Ambient pastime routines in the citizen scheduler | PT-1 (PT-4 props, can stub) |
| **R-1960** PT-4 | Pastime props kit (dice, cup, board, tops, knucklebones) | PT-1 |
| **R-1961** PT-5 | Pastime runtime: "Play a game?", seeded session, stakes into `GameState` | PT-2 |
| **R-1962** PT-6 | Playable dice game | PT-5, PT-4 |
| **R-1963** PT-7 | Playable nine men's morris | PT-5, PT-4 |
| **R-1964** PT-8 | Playable strength contest at a village feast (idea) | PT-5, PT-3 |
| **R-1965** PT-9 | "Customs of Reval" journal notes | PT-1, PT-5 |

## Verification (when built)

Each task names its tests and GPU captures. The page moves to `Status: implemented` with runtime entry points, test files and screenshots once PT-3 and PT-5 with one game land.

## Limits

- Much folk-game evidence for Estonia is recorded centuries after 1343; such items can only appear as labelled simplified later forms.
- Stakes and opponent skill are invented gameplay values.
