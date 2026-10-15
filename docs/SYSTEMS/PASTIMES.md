# Pastimes: games and leisure of common people

Status: planned (epic **R-1956**, tasks **R-1957**..**R-1965**). Nothing on this page is built yet.

Scope: how ordinary people of Reval, its suburbs and the Harju villages spent free time in 1343 (dice, board games, children's games, strength contests, feast-day customs), shown as ambient life and, for a few games, playable with citizens. Two goals: teach real 14th-century culture, and add short, varied play between quests.

Out of scope: a gambling economy or casino loop; a universal good/evil score; procedural content or runtime LLM; anything dated after 1343 (period rule: dated later -> exclude; unknown 1343 state -> simplified later form, labelled). Playable games need ADR 0049 (task **R-1958**) accepted first. Naval and castle-building mini-games stay excluded ([`MINI_GAMES.md`](../MINI_GAMES.md)).

## Today

- No pastimes exist. Citizens work, eat, sleep, go to church and fetch water; nobody plays.
- Related playable loops planned elsewhere: market haggling, smuggling run, tavern brawl ([`MINI_GAMES.md`](../MINI_GAMES.md)); brawls with residents (R-1756).
- The entry point for playing with a citizen already exists: talk to anyone via ADR 0047 ([`DIALOGUE.md`](./DIALOGUE.md), `dialogue.city.small_talk`).

## Evidence

Dossier: [`pastimes-1343`](../../history/dossiers/dailylife/pastimes-1343.md) (task **R-1957**, status partial, awaiting canon review). Key findings:

- **Dice** are the best-attested adult pastime: 14 bone and antler dice from the Town Hall Square, faces numbered 1:2, 3:4, 5:6, one die with enlarged high faces for cheating. Council and guild statutes fined gamblers (Tallinn records from 1394).
- **Football:** no evidence for Livonia. Children's leather ball (Tartu find) and the village ball-and-stick folk game (`ämmamuna`, recorded only in the 19th-20th centuries) are what we can show.
- **Children:** buzz bones (`vurriluu`, the commonest toy in Estonian digs), knucklebones, four-sided tops, toy weapons.
- **Excluded:** popinjay and marksmen's companies, Blackheads, merchant-guild May Count feasts, playing cards, clay whistles, hopscotch.
- **Siege rule** (from [`festivals-games-and-public-life`](../../history/dossiers/culture/festivals-games-and-public-life.md)): after 23 April alarms, ration queues and musters displace leisure; keep watchmen's dice and children's play, drop feast-day and village games.
- **Unconfirmed:** a morris/tables/chess find from medieval Estonia; any dating for wrestling or stick-pulling.

## Design (draft, pending R-1957 and R-1958)

### Ambient pastimes (watch)

Ranked by the dossier; labels A (Reval/Livonia), B (Baltic/Hanseatic or Estonian archaeology), C (plausible or simplified later form).

| Candidate | Who, where, when | Label | Task |
|---|---|---|---|
| Dice circle | journeymen, sailors, carters; Town Hall Square edge, alehouse, harbour; evening, not on Sunday morning | A/B | R-1959 |
| Buzz bones, knucklebones, tops | children; lanes, yards, doorsteps; by day | B | R-1959 |
| Toy swords and bows, leather ball | boys; lanes, waste ground; by day | B | R-1959 |
| Morris over a bench board | artisans, older men; benches, doorways; evening, Sunday afternoon | B | R-1959 |
| Easter-week swing, ball-and-stick | Harju village youth; village green; Easter week (Easter 13 Apr 1343) | C | R-1959 |

### Playable games (play, max 3 for Act 1)

| Candidate | Feel | Label | Task |
|---|---|---|---|
| Dice "Pasch or more": three dice, triples beat any total, best of three, opponent may carry a weighted die the player can spot | quick luck game, under 2 minutes | C rules on A material | R-1962 |
| Nine men's morris | calm thinking game, opponent skill by who they are | B | R-1963 |
| Buzz-bone duel (timing pulls keep the bone humming) or, if dated, a strength contest | skill toy for the teen protagonist / village feast contest | B / U | R-1964 (idea) |

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
