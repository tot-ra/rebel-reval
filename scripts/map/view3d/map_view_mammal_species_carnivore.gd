extends RefCounted

## Carnivore profiles for MapViewMammalSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## bear, wolf, fox, or lynx plumage, spawn weights, or scale overrides.

const GROUP_BEAR := &"bear"
const GROUP_CANID := &"canid"
const GROUP_FELID := &"felid"
const POSE_STANDING := &"standing"
const CONTEXT_FORELAND := &"foreland"
const CONTEXT_WOODLAND := &"woodland"

const PROFILES: Dictionary = {
	&"brown_bear":
	{
		"name": "Brown bear",
		"group": GROUP_BEAR,
		"scale_m": 1.35,
		"pose": POSE_STANDING,
		"colors": [Color("6a4a32"), Color("4a3424"), Color("2a2018")],
		"abundance": 0.12
	},
	&"wolf":
	{
		"name": "Wolf",
		"group": GROUP_CANID,
		"scale_m": 0.95,
		"pose": POSE_STANDING,
		"colors": [Color("7a7468"), Color("4f4a42"), Color("2a2824")],
		"abundance": 0.18,
		"spawn": {CONTEXT_WOODLAND: 0.82, CONTEXT_FORELAND: 0.68}
	},
	&"red_fox":
	{
		"name": "Red fox",
		"group": GROUP_CANID,
		"scale_m": 0.62,
		"pose": POSE_STANDING,
		"colors": [Color("b56a3a"), Color("e8ddd0"), Color("2a2824")],
		"geometry": {"tail": 0.42},
		"abundance": 0.46,
		"spawn": {CONTEXT_FORELAND: 0.78, CONTEXT_WOODLAND: 0.62}
	},
	&"lynx":
	{
		"name": "Eurasian lynx",
		"group": GROUP_FELID,
		"scale_m": 0.82,
		"pose": POSE_STANDING,
		"colors": [Color("b39a72"), Color("6f5a42"), Color("2a2824")],
		"geometry": {"ears": 0.16, "tail": 0.12},
		"abundance": 0.14,
		"spawn": {CONTEXT_WOODLAND: 0.76}
	},
}
