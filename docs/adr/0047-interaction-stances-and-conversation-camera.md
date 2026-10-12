# ADR 0047: Talk, fight or duel with anyone: stances and a universal conversation camera

**Reference:** maintainer request 2026-10-12 (session, RU): "walk up to a person (cats too, any
character) and click: talk, or attack. Peaceful by default; draw the weapon like in the Witcher
and the click becomes a blow. From spirit sight the action is a spirit duel fought as dialogue.
The conversation needs a cinematic camera that changes angle per speaker and rises to the
gameplay camera when a duel starts." Epic **R-1884** (TALK-0), tasks **R-1885..R-1889**.

Builds on [ADR 0003](0003-authored-offline-dialogue-and-prohibit-runtime-llm.md) (authored
dialogue), [ADR 0033](0033-teen-protagonist-and-spirit-dialogue-combat.md) and
[ADR 0038](0038-realtime-3d-spirit-arena-and-topic-spells.md) (spirit duels), [ADR 0041](0041-spirit-sight-auras-and-soul-lights.md)
(spirit sight), [ADR 0044](0044-named-npc-presentation-tier.md) (named NPCs) and
[ADR 0034](0034-cutscene-mode-and-cinematic-prologue.md) (no per-scene camera rigs).

## Status

**Accepted (maintainer request, 2026-10-12).**

## Context

- Census residents and named NPCs could be clicked, but only to open a read-only card. Talking
  needed a hand-placed `Interactable` with an authored record, so almost nobody could be talked to.
- In third person every left click swung the weapon, even at a peaceful crowd; brawls with
  residents (R-1756) made that a guilt-carrying act on a misclick.
- The R-1877 conversation shot placed its camera by geometry alone. In the smithy it could look
  through a ceiling beam and lose the speakers' heads; it had one fixed angle for the whole talk.
- The city has no 3D physics colliders (bodies live on the 2D logic plane), so a camera cannot
  ray-cast against walls through the physics server.

## Decision

1. **Stances.** The hero is peaceful by default (weapon sheathed and hidden). `player_draw_weapon`
   (`G`; pad Share) draws or sheathes. Sheathed, the primary click talks to the person under the
   cursor or uses things, and never swings; clicking a real hostile draws and strikes (as in the
   Witcher). The attack button on a sheathed hero draws first. Starting a conversation sheathes.
   Stance is transient (not saved).
2. **Spirit sight is the third stance.** In sight, a click or `interact` on a person opens a
   spirit duel against that person in place; outside sight the conversation's inner-eye reply
   does the same.
3. **Anyone can talk.** One authored generic record, `dialogue.city.small_talk`, is spoken by any
   resident or named NPC through the placeholder `char.interlocutor`; the runtime supplies the
   name, portrait and `{interlocutor_*}` tokens. A generic duel `dialogue.city.spirit_duel` does
   the same for duels. Authored per-person dialogue can replace them later without new plumbing.
4. **Universal conversation camera.** `ConversationShot` opens on a two-shot, cuts to an
   over-the-shoulder close shot of each speaker (staying on one side of the line between them),
   and hands back to play by cutting or by craning up to the live gameplay camera (the duel
   entry). Shots are chosen by line of sight against the drawn meshes (`ShotOcclusion`): scenery
   rejects an angle; a passer-by in the way is hidden for that shot instead.
5. **Cats and other creatures** use the same contract (a logic body with
   `hold_for_talk` / `release_talk` and a rig); no city cats exist yet, so they are a follow-up.

## Alternatives

- **Context menu on click (Talk / Attack / Duel).** Rejected: slower than the stance model, and
  the maintainer asked for Witcher-like drawing.
- **Hold-to-attack, tap-to-talk.** Rejected: the heavy strike already uses the hold.
- **Physics colliders for the camera.** Rejected: thousands of building and prop meshes would need
  3D bodies only for the camera; triangle tests on the few meshes near a conversation are cheaper.
- **Per-person dialogue for every resident.** Out of reach (thousands of residents); generic
  records with tokens first, authored records for named NPCs later.

## Consequences

- No new pillar and no scope removal: dialogue, brawls and spirit duels already exist; this
  decides how the player reaches them and how conversations are framed.
- Misclicks no longer cause brawls or guilt; attacking a resident needs the weapon drawn.
- Tests that expect a click to swing must draw the weapon first.
- Generic talk carries no state; duels with strangers set no flags and cost no guilt yet.
- Docs: [`DIALOGUE.md`](../SYSTEMS/DIALOGUE.md#talk-to-anyone-r-1887),
  [`CUTSCENES.md`](../SYSTEMS/CUTSCENES.md), [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md),
  [`COMBAT.md`](../SYSTEMS/COMBAT.md), [`CONTROLS.md`](../CONTROLS.md).
