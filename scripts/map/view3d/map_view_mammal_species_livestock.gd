extends RefCounted

## Domestic livestock profiles for MapViewMammalSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## penned-yard species plumage, spawn weights, or scale overrides.

const GROUP_FOWL := &"fowl"
const GROUP_SWINE := &"swine"
const GROUP_UNGULATE := &"ungulate"
const POSE_STANDING := &"standing"
const POSE_GRAZING := &"grazing"
const CONTEXT_LOWER_TOWN := &"lower_town"
const CONTEXT_MARKET := &"market_civic"
const CONTEXT_FORELAND := &"foreland"
const CONTEXT_WETLAND := &"wetland"

const PROFILES: Dictionary = {
	&"chicken":
	{
		"name": "Chicken",
		"group": GROUP_FOWL,
		"scale_m": 0.34,
		"pose": POSE_STANDING,
		"colors": [Color("c8a86a"), Color("8a4a28"), Color("d8c8a8")],
		"abundance": 0.76,
		"spawn": {CONTEXT_LOWER_TOWN: 0.62, CONTEXT_FORELAND: 0.58}
	},
	&"duck":
	{
		"name": "Domestic duck",
		"group": GROUP_FOWL,
		"scale_m": 0.38,
		"pose": POSE_STANDING,
		"colors": [Color("6a5a42"), Color("4a6a52"), Color("d8a848")],
		"abundance": 0.58,
		"spawn": {CONTEXT_FORELAND: 0.52, CONTEXT_WETLAND: 0.34}
	},
	&"goose":
	{
		"name": "Domestic goose",
		"group": GROUP_FOWL,
		"scale_m": 0.62,
		"pose": POSE_STANDING,
		"colors": [Color("e8e4dc"), Color("6a6a62"), Color("d8a848")],
		"geometry": {"neck": 0.18},
		"abundance": 0.46,
		"spawn": {CONTEXT_FORELAND: 0.62}
	},
	&"pig":
	{
		"name": "Domestic pig",
		"group": GROUP_SWINE,
		"scale_m": 0.82,
		"pose": POSE_STANDING,
		"colors": [Color("d8a8a0"), Color("c88880"), Color("4a3424")],
		"abundance": 0.48,
		"spawn": {CONTEXT_FORELAND: 0.52, CONTEXT_LOWER_TOWN: 0.22}
	},
	&"cow":
	{
		"name": "Cattle",
		"group": GROUP_UNGULATE,
		"scale_m": 1.72,
		"pose": POSE_GRAZING,
		"colors": [Color("8a6a48"), Color("e8e4dc"), Color("4a3424")],
		"geometry": {"body": Vector3(1.30, 0.62, 0.48), "horns": 0.12},
		"abundance": 0.32,
		"spawn": {CONTEXT_FORELAND: 0.68}
	},
	&"sheep":
	{
		"name": "Sheep",
		"group": GROUP_UNGULATE,
		"scale_m": 0.92,
		"pose": POSE_GRAZING,
		"colors": [Color("e8e4dc"), Color("b8b0a4"), Color("4a3424")],
		"geometry": {"body": Vector3(0.78, 0.40, 0.32)},
		"abundance": 0.38,
		"spawn": {CONTEXT_FORELAND: 0.72}
	},
}
