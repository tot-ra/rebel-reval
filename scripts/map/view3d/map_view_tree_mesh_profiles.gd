class_name MapViewTreeMeshProfiles
extends RefCounted

## Botanical growth profiles for MapViewTreeMeshes (P0-185 shard).
## Edit species tuning here; procedural wood/canopy/fruit emitters stay on the facade.

const MAX_LEAF_SPRAYS := 110
const MAX_FRUIT_COUNT := 18

static func profile_for(species: StringName) -> Dictionary:
	match species:
		&"spruce":
			return _profile(
				3.0,
				0.125,
				0.48,
				2.55,
				14,
				2,
				1.18,
				-0.10,
				0.48,
				0.48,
				0.52,
				0.08,
				72,
				10,
				0.13,
				0.20
			)
		&"pine":
			return _profile(
				2.85,
				0.120,
				1.42,
				2.58,
				11,
				2,
				1.08,
				0.12,
				0.58,
				0.56,
				0.54,
				0.02,
				68,
				10,
				0.15,
				0.18
			)
		# Birch: tall slender bole + dense small-leaf sprays; tip-only sprays looked bald.
		&"birch":
			return _profile(
				3.15,
				0.062,
				0.70,
				2.95,
				16,
				2,
				0.82,
				0.34,
				0.52,
				0.56,
				0.44,
				0.24,
				104,
				14,
				0.145,
				0.48
			)
		&"oak":
			return _profile(
				2.28,
				0.155,
				0.76,
				1.88,
				9,
				2,
				0.98,
				0.20,
				0.62,
				0.59,
				0.58,
				0.08,
				72,
				10,
				0.19,
				0.38
			)
		&"alder":
			return _profile(
				2.42,
				0.115,
				0.62,
				2.04,
				10,
				2,
				0.78,
				0.31,
				0.56,
				0.57,
				0.53,
				0.13,
				70,
				10,
				0.16,
				0.34
			)
		&"aspen":
			return _profile(
				2.92,
				0.088,
				1.05,
				2.63,
				12,
				2,
				0.58,
				0.48,
				0.48,
				0.53,
				0.49,
				0.05,
				72,
				10,
				0.14,
				0.36
			)
		&"maple":
			return _profile(
				2.38,
				0.132,
				0.72,
				2.02,
				10,
				2,
				0.88,
				0.27,
				0.60,
				0.58,
				0.56,
				0.06,
				72,
				10,
				0.17,
				0.40
			)
		&"linden":
			return _profile(
				2.55,
				0.118,
				0.68,
				2.20,
				11,
				2,
				0.78,
				0.38,
				0.54,
				0.55,
				0.52,
				0.08,
				70,
				10,
				0.17,
				0.36
			)
		&"apple":
			return _profile(
				1.82,
				0.138,
				0.50,
				1.47,
				9,
				2,
				0.78,
				0.18,
				0.67,
				0.61,
				0.60,
				0.12,
				68,
				9,
				0.17,
				0.42,
				14
			)
		&"cherry":
			return _profile(
				2.02,
				0.108,
				0.58,
				1.72,
				10,
				2,
				0.72,
				0.36,
				0.62,
				0.59,
				0.57,
				0.08,
				68,
				9,
				0.15,
				0.40,
				18
			)
		&"ash":
			return _profile(
				2.95,
				0.108,
				1.05,
				2.64,
				12,
				2,
				0.76,
				0.46,
				0.50,
				0.54,
				0.48,
				0.04,
				72,
				10,
				0.16,
				0.34
			)
		&"elm":
			return _profile(
				2.58,
				0.140,
				0.82,
				2.28,
				11,
				2,
				0.92,
				0.32,
				0.58,
				0.56,
				0.54,
				0.08,
				72,
				10,
				0.17,
				0.36
			)
		&"willow":
			return _profile(
				2.36,
				0.122,
				0.66,
				2.16,
				13,
				2,
				0.88,
				0.18,
				0.54,
				0.58,
				0.48,
				0.42,
				84,
				11,
				0.16,
				0.38
			)
		&"rowan":
			return _profile(
				2.34,
				0.086,
				0.88,
				2.12,
				12,
				2,
				0.62,
				0.44,
				0.50,
				0.54,
				0.48,
				0.05,
				72,
				10,
				0.14,
				0.32
			)
		&"hazel":
			return _profile(
				1.58,
				0.095,
				0.34,
				1.38,
				12,
				2,
				0.68,
				0.34,
				0.62,
				0.58,
				0.52,
				0.10,
				70,
				9,
				0.16,
				0.34
			)
		&"juniper":
			return _profile(
				1.84,
				0.078,
				0.18,
				1.78,
				13,
				2,
				0.46,
				0.22,
				0.44,
				0.50,
				0.46,
				0.05,
				70,
				9,
				0.10,
				0.18
			)
		&"plum":
			return _profile(
				1.92,
				0.122,
				0.48,
				1.62,
				10,
				2,
				0.76,
				0.24,
				0.62,
				0.58,
				0.56,
				0.10,
				68,
				9,
				0.16,
				0.38,
				12
			)
		&"pear":
			return _profile(
				2.30,
				0.115,
				0.72,
				2.08,
				11,
				2,
				0.62,
				0.50,
				0.48,
				0.54,
				0.50,
				0.04,
				68,
				9,
				0.16,
				0.34,
				10
			)
		&"hawthorn":
			return _profile(
				1.72,
				0.108,
				0.42,
				1.48,
				11,
				2,
				0.72,
				0.30,
				0.66,
				0.58,
				0.54,
				0.08,
				70,
				9,
				0.14,
				0.32,
				12
			)
		&"blackthorn":
			return _profile(
				1.58,
				0.100,
				0.34,
				1.36,
				12,
				2,
				0.70,
				0.24,
				0.68,
				0.58,
				0.54,
				0.10,
				68,
				9,
				0.13,
				0.30,
				12
			)
		_:
			return _profile(
				2.38,
				0.125,
				0.72,
				2.02,
				10,
				2,
				0.84,
				0.28,
				0.58,
				0.58,
				0.55,
				0.08,
				68,
				9,
				0.17,
				0.38
			)


static func _profile(
	trunk_height: float,
	trunk_radius: float,
	crown_start: float,
	crown_end: float,
	primary_count: int,
	depth: int,
	primary_length: float,
	branch_rise: float,
	split_angle: float,
	length_decay: float,
	radius_decay: float,
	droop: float,
	leaf_sprays: int,
	leaves_per_spray: int,
	leaf_length: float,
	leaf_spread: float,
	fruit_count: int = 0
) -> Dictionary:
	return {
		"trunk_height": trunk_height,
		"trunk_radius": trunk_radius,
		"crown_start": crown_start,
		"crown_end": crown_end,
		"primary_count": primary_count,
		"depth": depth,
		"primary_length": primary_length,
		"branch_rise": branch_rise,
		"split_angle": split_angle,
		"length_decay": length_decay,
		"radius_decay": radius_decay,
		"droop": droop,
		"leaf_sprays": mini(leaf_sprays, MAX_LEAF_SPRAYS),
		"leaves_per_spray": leaves_per_spray,
		"leaf_length": leaf_length,
		"leaf_spread": leaf_spread,
		"fruit_count": mini(fruit_count, MAX_FRUIT_COUNT),
	}
