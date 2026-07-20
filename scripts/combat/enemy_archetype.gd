class_name EnemyArchetype
extends RefCounted

## Tunable combat AI profile. Watchman and sergeant share one state machine;
## only these numbers differ (P1-025).

const ID_WATCHMAN := &"enemy.watchman"
const ID_SERGEANT := &"enemy.sergeant"

var id: StringName = ID_WATCHMAN
var display_label := "Watchman"

## Perception / leash (world units; tests use the same abstract distance).
var detect_radius: float = 120.0
var engage_radius: float = 72.0
var lose_sight_radius: float = 220.0

## Phase durations (seconds).
var detect_duration_sec: float = 0.45
var telegraph_duration_sec: float = 0.55
var attack_duration_sec: float = 0.55
var attack_impact_sec: float = 0.22
var react_duration_sec: float = 0.35
var disengage_duration_sec: float = 0.6

## Attack contract used when the shared machine emits attack_impact.
var attack_damage: float = 8.0
var attack_reach_px: float = 48.0
var attack_stamina_cost: float = 6.0
var attack_damage_type: StringName = &"blunt"
var attack_animation: StringName = &"hammer_attack"


static func watchman() -> EnemyArchetype:
	## Street watch: slower read, longer telegraph, lighter strike.
	var profile := EnemyArchetype.new()
	profile.id = ID_WATCHMAN
	profile.display_label = "Watchman"
	profile.detect_radius = 110.0
	profile.engage_radius = 64.0
	profile.lose_sight_radius = 200.0
	profile.detect_duration_sec = 0.5
	profile.telegraph_duration_sec = 0.65
	profile.attack_duration_sec = 0.6
	profile.attack_impact_sec = 0.24
	profile.react_duration_sec = 0.4
	profile.disengage_duration_sec = 0.7
	profile.attack_damage = 7.0
	profile.attack_reach_px = 44.0
	profile.attack_stamina_cost = 5.0
	profile.attack_damage_type = &"blunt"
	profile.attack_animation = &"hammer_attack"
	return profile


static func sergeant() -> EnemyArchetype:
	## Livonian sergeant: sharper detect, shorter telegraph, heavier strike.
	var profile := EnemyArchetype.new()
	profile.id = ID_SERGEANT
	profile.display_label = "Sergeant"
	profile.detect_radius = 150.0
	profile.engage_radius = 80.0
	profile.lose_sight_radius = 260.0
	profile.detect_duration_sec = 0.3
	profile.telegraph_duration_sec = 0.4
	profile.attack_duration_sec = 0.5
	profile.attack_impact_sec = 0.18
	profile.react_duration_sec = 0.28
	profile.disengage_duration_sec = 0.5
	profile.attack_damage = 12.0
	profile.attack_reach_px = 56.0
	profile.attack_stamina_cost = 8.0
	profile.attack_damage_type = &"slash"
	profile.attack_animation = &"sword_attack"
	return profile


func make_attack_profile() -> AttackProfile:
	var profile := AttackProfile.new()
	profile.animation = attack_animation
	profile.damage = attack_damage
	profile.reach_px = attack_reach_px
	profile.impact_timing_sec = attack_impact_sec
	profile.attack_duration_sec = attack_duration_sec
	profile.stamina_cost = attack_stamina_cost
	profile.damage_type = attack_damage_type
	return profile
