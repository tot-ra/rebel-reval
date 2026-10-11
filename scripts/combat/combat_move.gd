class_name CombatMove
extends RefCounted

## One authored player action as both gameplay timing and clip presentation.
##
## WHY one record: the logic clock (impact, duration, cancel) and the clip clock
## (the frame where the weapon visibly lands) must never drift apart. Keeping
## them side by side lets the rig warp any source clip so its contact frame
## lands exactly on the single gameplay impact signal.

## Canonical animation id resolved by SharedCharacterRig (e.g. `sword_attack_2`).
var id: StringName = &""
## Logic seconds from action start to the impact signal.
var impact_sec: float = 0.0
## Logic seconds of the whole committed action before recovery.
var duration_sec: float = 0.0
## Logic seconds after which a buffered follow-up (combo or evade) may start.
## Values >= duration_sec mean the move cannot be cancelled early.
var cancel_sec: float = 0.0
## Presentation-only freeze on the contact pose after impact (weight).
var hit_stop_sec: float = 0.0
## Seconds into the source clip where the strike visibly connects. Zero means
## the move has no contact frame and the clip is scaled linearly instead.
var source_contact_sec: float = 0.0
## Multipliers applied to the equipped item's base attack profile.
var damage_mult: float = 1.0
var reach_mult: float = 1.0
var stamina_mult: float = 1.0
## Absolute facing cone override; NAN keeps the item's own value.
var facing_dot: float = NAN
## Forward step (logic px) taken between start and impact, for weight.
var lunge_px: float = 0.0
var pierces_guard: bool = false


static func make(data: Dictionary) -> CombatMove:
	var move := CombatMove.new()
	move.id = StringName(String(data.get("id", "")))
	move.impact_sec = float(data.get("impact_sec", 0.0))
	move.duration_sec = maxf(move.impact_sec, float(data.get("duration_sec", 0.0)))
	move.cancel_sec = float(data.get("cancel_sec", move.duration_sec))
	move.hit_stop_sec = float(data.get("hit_stop_sec", 0.0))
	move.source_contact_sec = float(data.get("source_contact_sec", 0.0))
	move.damage_mult = float(data.get("damage_mult", 1.0))
	move.reach_mult = float(data.get("reach_mult", 1.0))
	move.stamina_mult = float(data.get("stamina_mult", 1.0))
	move.facing_dot = float(data.get("facing_dot", NAN))
	move.lunge_px = float(data.get("lunge_px", 0.0))
	move.pierces_guard = bool(data.get("pierces_guard", false))
	return move


## Copy with the logic clock scaled for a body build (hit stop and lunge scale with it). The source
## clip contact second never changes, so the contact frame still lands on the (scaled) impact.
func scaled_for_build(timing_mult: float, lunge_mult: float) -> CombatMove:
	var copy := CombatMove.new()
	copy.id = id
	copy.impact_sec = impact_sec * timing_mult
	copy.duration_sec = duration_sec * timing_mult
	copy.cancel_sec = cancel_sec * timing_mult
	copy.hit_stop_sec = hit_stop_sec * timing_mult
	copy.source_contact_sec = source_contact_sec
	copy.damage_mult = damage_mult
	copy.reach_mult = reach_mult
	copy.stamina_mult = stamina_mult
	copy.facing_dot = facing_dot
	copy.lunge_px = lunge_px * lunge_mult
	copy.pierces_guard = pierces_guard
	return copy


## Maps the logic action clock onto the source clip clock.
##
## Contact moves: a quadratic ease spends most of the anticipation on the
## wind-up and compresses the downswing into an accelerating finish, the
## contact pose holds for the hit-stop, then the follow-through plays out.
## Moves without contact (rolls, dodges, hits, casts without a release frame)
## stretch the clip linearly across the action.
func source_time(elapsed_sec: float, source_length_sec: float) -> float:
	var duration := maxf(duration_sec, 0.001)
	var elapsed := clampf(elapsed_sec, 0.0, duration)
	if source_contact_sec <= 0.0 or impact_sec <= 0.0:
		return source_length_sec * elapsed / duration
	var contact := minf(source_contact_sec, source_length_sec)
	if elapsed <= impact_sec:
		var ratio := elapsed / impact_sec
		return contact * ratio * ratio
	if elapsed <= impact_sec + hit_stop_sec:
		return contact
	var follow := (elapsed - impact_sec - hit_stop_sec) / maxf(
		duration - impact_sec - hit_stop_sec, 0.001
	)
	return lerpf(contact, source_length_sec, clampf(follow, 0.0, 1.0))
