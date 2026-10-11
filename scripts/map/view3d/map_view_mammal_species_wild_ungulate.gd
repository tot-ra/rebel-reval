extends RefCounted

## Wild ungulate profiles for MapViewMammalSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## elk, deer, or wild boar plumage, spawn weights, or scale overrides.

const GROUP_UNGULATE := &"ungulate"
const POSE_GRAZING := &"grazing"
const CONTEXT_FORELAND := &"foreland"
const CONTEXT_GARDEN := &"garden"
const CONTEXT_WOODLAND := &"woodland"

const PROFILES: Dictionary = {
	&"elk":
	{
		"name": "Elk",
		"group": GROUP_UNGULATE,
		"scale_m": 1.55,
		"pose": POSE_GRAZING,
		"colors": [Color("6a5844"), Color("4a3c30"), Color("2a241c")],
		"geometry": {"body": Vector3(1.18, 0.58, 0.42), "horns": 0.42},
		"abundance": 0.16,
		"spawn": {CONTEXT_WOODLAND: 0.72, CONTEXT_FORELAND: 0.58}
	},
	&"red_deer":
	{
		"name": "Red deer",
		"group": GROUP_UNGULATE,
		"scale_m": 1.18,
		"pose": POSE_GRAZING,
		"colors": [Color("8a6848"), Color("5a4632"), Color("2a241c")],
		"geometry": {"horns": 0.36},
		"abundance": 0.22,
		"spawn": {CONTEXT_WOODLAND: 0.68}
	},
	&"roe_deer":
	{
		"name": "Roe deer",
		"group": GROUP_UNGULATE,
		"scale_m": 0.78,
		"pose": POSE_GRAZING,
		"colors": [Color("9a7a52"), Color("6a5438"), Color("2a241c")],
		"geometry": {"body": Vector3(0.72, 0.36, 0.30), "horns": 0.14},
		"abundance": 0.34,
		"spawn": {CONTEXT_FORELAND: 0.74, CONTEXT_GARDEN: 0.28}
	},
	&"wild_boar":
	{
		"name": "Wild boar",
		"group": GROUP_UNGULATE,
		"scale_m": 0.92,
		"pose": POSE_GRAZING,
		"colors": [Color("4a3428"), Color("2a2018"), Color("1a1814")],
		"geometry": {"head": 0.18, "tail": 0.08},
		"abundance": 0.28,
		"spawn": {CONTEXT_WOODLAND: 0.62, CONTEXT_FORELAND: 0.48}
	},
}
