class_name AttackProfile
extends RefCounted

const DEFAULT_ANIMATION := &"unarmed_attack"
const DEFAULT_DAMAGE := 8.0
const DEFAULT_REACH_PX := 48.0
const DEFAULT_FACING_DOT := 0.35
const DEFAULT_IMPACT_TIMING_SEC := 0.22
const DEFAULT_ATTACK_DURATION_SEC := 0.55
const DEFAULT_STAMINA_COST := 0.0
const DEFAULT_DAMAGE_TYPE := &"blunt"

var animation: StringName = DEFAULT_ANIMATION
var damage: float = DEFAULT_DAMAGE
var reach_px: float = DEFAULT_REACH_PX
var facing_dot: float = DEFAULT_FACING_DOT
var impact_timing_sec: float = DEFAULT_IMPACT_TIMING_SEC
var attack_duration_sec: float = DEFAULT_ATTACK_DURATION_SEC
var stamina_cost: float = DEFAULT_STAMINA_COST
var damage_type: StringName = DEFAULT_DAMAGE_TYPE


static func unarmed() -> AttackProfile:
	return AttackProfile.new()


static func from_content(data: Dictionary) -> AttackProfile:
	var profile := AttackProfile.new()
	profile.animation = StringName(String(data.get("animation", DEFAULT_ANIMATION)))
	profile.damage = maxf(0.0, float(data.get("damage", DEFAULT_DAMAGE)))
	profile.reach_px = maxf(1.0, float(data.get("reach_px", DEFAULT_REACH_PX)))
	profile.facing_dot = clampf(float(data.get("facing_dot", DEFAULT_FACING_DOT)), -1.0, 1.0)
	profile.impact_timing_sec = maxf(0.01, float(data.get("impact_timing_sec", DEFAULT_IMPACT_TIMING_SEC)))
	profile.attack_duration_sec = maxf(
		profile.impact_timing_sec,
		float(data.get("attack_duration_sec", DEFAULT_ATTACK_DURATION_SEC))
	)
	profile.stamina_cost = maxf(0.0, float(data.get("stamina_cost", DEFAULT_STAMINA_COST)))
	profile.damage_type = StringName(String(data.get("damage_type", DEFAULT_DAMAGE_TYPE)))
	return profile
