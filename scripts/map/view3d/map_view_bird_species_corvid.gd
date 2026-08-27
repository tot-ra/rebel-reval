extends RefCounted

## Corvid species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## corvid plumage, spawn weights, or song metadata.

const GROUP_CORVID := &"corvid"
const POSE_PERCHED := &"perched"
const CONTEXT_LOWER_TOWN := &"lower_town"
const CONTEXT_MARKET := &"market_civic"
const CONTEXT_TOOMPEA := &"toompea"
const CONTEXT_FORELAND := &"foreland"
const CONTEXT_GARDEN := &"garden"

const PROFILES: Dictionary = {
	&"hooded_crow":
	{
		"name": "Hooded crow",
		"group": GROUP_CORVID,
		"scale_m": 0.49,
		"pose": POSE_PERCHED,
		"colors": [Color("777b78"), Color("242728"), Color("303333")],
		"song":
		{
			"cue": &"bird.hooded_crow.call",
			"kind": &"rough_caw",
			"time": &"day",
			"cadence_s": Vector2(4.0, 12.0)
		},
		"abundance": 0.82
	},
	&"rook":
	{
		"name": "Rook",
		"group": GROUP_CORVID,
		"scale_m": 0.46,
		"pose": POSE_PERCHED,
		"colors": [Color("25292a"), Color("15191a"), Color("8f8b7d")],
		"geometry": {"beak": 0.26},
		"song":
		{
			"cue": &"bird.rook.call",
			"kind": &"nasal_kaah",
			"time": &"day",
			"cadence_s": Vector2(3.0, 9.0)
		},
		"abundance": 0.68,
		"spawn": {CONTEXT_MARKET: 0.92, CONTEXT_FORELAND: 0.76}
	},
	&"western_jackdaw":
	{
		"name": "Western jackdaw",
		"group": GROUP_CORVID,
		"scale_m": 0.34,
		"pose": POSE_PERCHED,
		"colors": [Color("353a3b"), Color("24292a"), Color("8e9691")],
		"geometry": {"body": Vector3(0.43, 0.24, 0.23), "tail": 0.28},
		"song":
		{
			"cue": &"bird.western_jackdaw.call",
			"kind": &"metallic_chyak",
			"time": &"day",
			"cadence_s": Vector2(2.0, 7.0)
		},
		"abundance": 0.88,
		"spawn": {CONTEXT_TOOMPEA: 0.88, CONTEXT_LOWER_TOWN: 0.92}
	},
	&"eurasian_magpie":
	{
		"name": "Eurasian magpie",
		"group": GROUP_CORVID,
		"scale_m": 0.46,
		"pose": POSE_PERCHED,
		"colors": [Color("e0ded4"), Color("202626"), Color("477069")],
		"geometry": {"tail": 0.62, "body": Vector3(0.42, 0.23, 0.22)},
		"song":
		{
			"cue": &"bird.eurasian_magpie.call",
			"kind": &"rattling_chatter",
			"time": &"day",
			"cadence_s": Vector2(5.0, 14.0)
		},
		"abundance": 0.56,
		"spawn": {CONTEXT_GARDEN: 0.82, CONTEXT_FORELAND: 0.75}
	},
}
