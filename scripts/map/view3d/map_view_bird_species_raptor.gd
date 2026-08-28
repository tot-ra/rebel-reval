extends RefCounted

## Raptor species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## raptor plumage, spawn weights, or song metadata.

const GROUP_RAPTOR := &"raptor"
const POSE_GLIDING := &"gliding"
const CONTEXT_HARBOR := &"harbor"
const CONTEXT_LOWER_TOWN := &"lower_town"
const CONTEXT_TOOMPEA := &"toompea"
const CONTEXT_FORELAND := &"foreland"
const CONTEXT_WETLAND := &"wetland"

const PROFILES: Dictionary = {
	&"white_tailed_eagle":
	{
		"name": "White-tailed eagle",
		"group": GROUP_RAPTOR,
		"scale_m": 0.86,
		"pose": POSE_GLIDING,
		"colors": [Color("574b3b"), Color("332e28"), Color("ded8c5")],
		"geometry": {"wing_span": 1.72, "wing_chord": 0.58, "body": Vector3(0.58, 0.31, 0.34)},
		"song":
		{
			"cue": &"bird.white_tailed_eagle.call",
			"kind": &"far_carrying_yelp",
			"time": &"day",
			"cadence_s": Vector2(18.0, 42.0)
		},
		"abundance": 0.16,
		"spawn": {CONTEXT_HARBOR: 0.45, CONTEXT_FORELAND: 0.72, CONTEXT_WETLAND: 0.62}
	},
	&"osprey":
	{
		"name": "Osprey",
		"group": GROUP_RAPTOR,
		"scale_m": 0.58,
		"pose": POSE_GLIDING,
		"colors": [Color("d9d2bd"), Color("4c4438"), Color("d2b365")],
		"geometry": {"wing_span": 1.58, "wing_chord": 0.43},
		"song":
		{
			"cue": &"bird.osprey.call",
			"kind": &"thin_whistle",
			"time": &"day",
			"cadence_s": Vector2(12.0, 32.0)
		},
		"abundance": 0.20,
		"spawn": {CONTEXT_HARBOR: 0.48, CONTEXT_WETLAND: 0.76}
	},
	&"common_buzzard":
	{
		"name": "Common buzzard",
		"group": GROUP_RAPTOR,
		"scale_m": 0.54,
		"pose": POSE_GLIDING,
		"colors": [Color("755e45"), Color("4b3d30"), Color("c5aa82")],
		"song":
		{
			"cue": &"bird.common_buzzard.call",
			"kind": &"mewing_peeoo",
			"time": &"day",
			"cadence_s": Vector2(10.0, 27.0)
		},
		"abundance": 0.46
	},
	&"common_kestrel":
	{
		"name": "Common kestrel",
		"group": GROUP_RAPTOR,
		"scale_m": 0.34,
		"pose": POSE_GLIDING,
		"colors": [Color("a56a43"), Color("4d4b4b"), Color("d6b36d")],
		"geometry":
		{"wing_span": 1.20, "wing_chord": 0.35, "tail": 0.42, "body": Vector3(0.47, 0.25, 0.26)},
		"song":
		{
			"cue": &"bird.common_kestrel.call",
			"kind": &"rapid_kikiki",
			"time": &"day",
			"cadence_s": Vector2(6.0, 18.0)
		},
		"abundance": 0.42,
		"spawn": {CONTEXT_TOOMPEA: 0.74, CONTEXT_LOWER_TOWN: 0.26}
	},
}
