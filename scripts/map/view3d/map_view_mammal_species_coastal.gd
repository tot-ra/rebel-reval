extends RefCounted

## Coastal and nocturnal profiles for MapViewMammalSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## seal or bat plumage, spawn weights, or scale overrides.

const GROUP_SEAL := &"seal"
const GROUP_BAT := &"bat"
const POSE_STANDING := &"standing"
const POSE_RESTING := &"resting"
const CONTEXT_HARBOR := &"harbor"
const CONTEXT_WETLAND := &"wetland"

const PROFILES: Dictionary = {
	&"grey_seal":
	{
		"name": "Grey seal",
		"group": GROUP_SEAL,
		"scale_m": 1.42,
		"pose": POSE_RESTING,
		"colors": [Color("8a8a82"), Color("6a6a62"), Color("4a4a44")],
		"abundance": 0.18,
		"spawn": {CONTEXT_HARBOR: 0.86}
	},
	&"ringed_seal":
	{
		"name": "Ringed seal",
		"group": GROUP_SEAL,
		"scale_m": 1.05,
		"pose": POSE_RESTING,
		"colors": [Color("9a9488"), Color("6a6458"), Color("4a443c")],
		"geometry": {"body": Vector3(0.82, 0.28, 0.24)},
		"abundance": 0.12,
		"spawn": {CONTEXT_HARBOR: 0.62, CONTEXT_WETLAND: 0.42}
	},
	&"common_bat":
	{
		"name": "Common bat",
		"group": GROUP_BAT,
		"scale_m": 0.10,
		"pose": POSE_STANDING,
		"colors": [Color("4a4038"), Color("2a2824"), Color("6a5a48")],
		"abundance": 0.36
	},
}
