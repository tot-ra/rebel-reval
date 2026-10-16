# ADR 0061: Cold and wetness exposure for the hero

**Reference:** maintainer requests R-1830 (wetness, body temperature, freezing to death) and
2026-10-17 (session: "the hero can freeze outdoors, even to death; warm up by a fire or indoors;
show it with an icon or a message first, an animation and spoken lines later"). Epic **R-1830**
(tasks R-2183..R-2187).
Feature page: [`HERO_EXPOSURE.md`](../SYSTEMS/HERO_EXPOSURE.md).

## Status

**Accepted** 2026-10-17. The maintainer asked to take R-1830 into work; the five decisions below
were proposed by the agent and are open to revision by the maintainer before or after v1 lands.

## Context

- The weather already simulates what the hero would feel: `SkyWeather3D.air_temperature_c()`
  (date climate + daily anomaly + time of day, R-2075), rain and snow, wind; everything is in the
  saved weather state.
- Shelter is already known: `CityWorld3D.enclosed_interior` and `CityPlan.is_under_roof()` (used
  by the lightning hazard, ADR 0057). Water depth is known from `PlayerSwimState`.
- Fires exist with a schedule: house hearths follow `HouseholdDay.hearth_state()`, the smithy
  forge follows the city clock.
- The motion style network (ADR 0051) already has `wet` and `core_cold` body channels that make a
  body hunch, hug itself and shiver. Today it runs its own presentation-only physiology.
- [Scope](../../agents/skills/scope-and-repo/SKILL.md) puts "survival sims" out of scope. This ADR
  adds one narrow weather hazard, not a needs simulation.

## Decision

1. **Two meters, both saved.** *Wetness* 0..1: rain outdoors and not under a roof soaks slowly
   (snow slower), puddles barely, wading by depth, swimming soaks fully at once. *Body heat* 1..0
   (1 = comfortable). Both live in `PlayerState` and save with the game.
2. **Chill.** The heat loss rate follows the air temperature (no loss above about +10 C when dry),
   wind adds to it and wetness multiplies it (soaked clothes feel about 8 C colder and lose heat
   about twice as fast). Order of effects: the body shivers, which burns stamina and holds back
   half the loss while stamina lasts; then body heat falls at the full rate; below about 0.35 the
   hero walks slower; at 0 health drains with damage type `cold` and the hero can die. No
   frostbite, no hunger, thirst or sleep needs.
3. **Warming.** An interior has its own temperature (about +12 C, a home with a lit hearth
   warmer). Within about 3 m of a lit hearth, the forge or another fire the hero warms and dries
   fast. A roof outside (porch, gate passage) stops rain but not cold. Fire never heals health by
   itself.
4. **Feedback, v1.** Status icons beside the vitals bars (wet, chilled, freezing), drawn in code;
   a short message once on each worsening threshold ("Soaked to the skin", "Freezing - find a
   fire"); a frost vignette at the screen edges while freezing; the hero's motion style is fed his
   real `wet` and `core_cold`, so he hunches and shivers. Later: spoken lines and a dedicated
   animation once the neural rig (ADR 0056) lands.
5. **Death.** A cold death opens the death screen with the `cold` damage type. Until a dedicated
   illustration exists (its own art task with an `assets/SOURCES.csv` row), it falls back to the
   neutral one.

## Alternatives

- **Collapse instead of death** (wake up in a warm house, lose time/coins): kinder, but the
  maintainer explicitly asked that freezing can kill.
- **Cold only, no wetness:** simpler, but rain and the moat would mean nothing, and wetness is the
  core of R-1830.
- **Reuse the motion physiology as gameplay state:** it is presentation-only and tuned for the
  style network; gameplay needs a small, saved, tunable model. The style network now reads the
  gameplay values for the hero instead of simulating its own.

## Consequences

- New saved fields `PlayerState.wetness` and `PlayerState.body_heat` (old saves load as dry and
  warm).
- A new damage type `cold` for the death screen.
- Every interior and fire becomes gameplay-relevant; a broken shelter query shows up as an
  unfair death, so the model is covered by unit tests.
- Clothing warmth (citizen wardrobe, R-1662) can later scale the heat loss.
