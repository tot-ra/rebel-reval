extends RefCounted

## Mustelid profiles for MapViewMammalSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## otter, badger, stoat, pine marten, or polecat plumage, spawn weights, or scale overrides.

const GROUP_MUSTELID := &"mustelid"
const POSE_STANDING := &"standing"
const CONTEXT_HARBOR := &"harbor"
const CONTEXT_WETLAND := &"wetland"
const CONTEXT_WOODLAND := &"woodland"

const PROFILES: Dictionary = {
	&"otter":
	{
		"name": "Eurasian otter",
		"group": GROUP_MUSTELID,
		"scale_m": 0.62,
		"pose": POSE_STANDING,
		"colors": [Color("5a4a3a"), Color("e8ddd0"), Color("2a2824")],
		"geometry": {"body": Vector3(0.58, 0.16, 0.14), "tail": 0.32},
		"abundance": 0.26,
		"spawn": {CONTEXT_HARBOR: 0.48, CONTEXT_WETLAND: 0.76}
	},
	&"badger":
	{
		"name": "European badger",
		"group": GROUP_MUSTELID,
		"scale_m": 0.68,
		"pose": POSE_STANDING,
		"colors": [Color("7a6a52"), Color("2a2824"), Color("e8ddd0")],
		"geometry": {"body": Vector3(0.56, 0.22, 0.18)},
		"abundance": 0.30
	},
	&"stoat":
	{
		"name": "Stoat",
		"group": GROUP_MUSTELID,
		"scale_m": 0.28,
		"pose": POSE_STANDING,
		"colors": [Color("8a7a62"), Color("e8e4dc"), Color("2a2824")],
		"geometry": {"body": Vector3(0.38, 0.12, 0.10), "tail": 0.16},
		"abundance": 0.32
	},
	&"pine_marten":
	{
		"name": "Pine marten",
		"group": GROUP_MUSTELID,
		"scale_m": 0.48,
		"pose": POSE_STANDING,
		"colors": [Color("6a4a2a"), Color("d8c8a8"), Color("2a2824")],
		"geometry": {"tail": 0.30},
		"abundance": 0.28,
		"spawn": {CONTEXT_WOODLAND: 0.72}
	},
	&"polecat":
	{
		"name": "European polecat",
		"group": GROUP_MUSTELID,
		"scale_m": 0.42,
		"pose": POSE_STANDING,
		"colors": [Color("4a3a2a"), Color("d8c8a8"), Color("2a2824")],
		"abundance": 0.22
	},
}
