extends RefCounted

## Small mammal profiles for MapViewMammalSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## beaver, squirrel, hare, or hedgehog plumage, spawn weights, or scale overrides.

const GROUP_RODENT := &"rodent"
const GROUP_LAGOMORPH := &"lagomorph"
const GROUP_INSECTIVORE := &"insectivore"
const POSE_STANDING := &"standing"
const CONTEXT_FORELAND := &"foreland"
const CONTEXT_GARDEN := &"garden"
const CONTEXT_WETLAND := &"wetland"
const CONTEXT_WOODLAND := &"woodland"

const PROFILES: Dictionary = {
	&"beaver":
	{
		"name": "Beaver",
		"group": GROUP_RODENT,
		"scale_m": 0.58,
		"pose": POSE_STANDING,
		"colors": [Color("5a4638"), Color("3a2e24"), Color("2a241c")],
		"geometry": {"tail": 0.28, "body": Vector3(0.42, 0.20, 0.18)},
		"abundance": 0.24,
		"spawn": {CONTEXT_WETLAND: 0.82}
	},
	&"squirrel":
	{
		"name": "Red squirrel",
		"group": GROUP_RODENT,
		"scale_m": 0.22,
		"pose": POSE_STANDING,
		"colors": [Color("9a4a28"), Color("d8c8a8"), Color("4a3424")],
		"geometry": {"tail": 0.28, "ears": 0.10},
		"abundance": 0.58,
		"spawn": {CONTEXT_GARDEN: 0.72, CONTEXT_WOODLAND: 0.68}
	},
	&"hare":
	{
		"name": "European hare",
		"group": GROUP_LAGOMORPH,
		"scale_m": 0.52,
		"pose": POSE_STANDING,
		"colors": [Color("9a8468"), Color("d8c8a8"), Color("6a5a48")],
		"abundance": 0.52,
		"spawn": {CONTEXT_FORELAND: 0.88}
	},
	&"hedgehog":
	{
		"name": "European hedgehog",
		"group": GROUP_INSECTIVORE,
		"scale_m": 0.20,
		"pose": POSE_STANDING,
		"colors": [Color("6a5a48"), Color("4a4038"), Color("2a241c")],
		"abundance": 0.42
	},
}
