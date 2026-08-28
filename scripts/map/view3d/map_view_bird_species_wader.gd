extends RefCounted

## Wader species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## wader plumage, spawn weights, or song metadata.

const GROUP_WADER := &"wader"
const POSE_STANDING := &"standing"
const CONTEXT_FORELAND := &"foreland"

const PROFILES: Dictionary = {
	&"grey_heron":
	{
		"name": "Grey heron",
		"group": GROUP_WADER,
		"scale_m": 0.94,
		"pose": POSE_STANDING,
		"colors": [Color("858d91"), Color("444b4e"), Color("d6b050")],
		"geometry": {"neck": 0.66, "legs": 0.72, "beak": 0.48, "body": Vector3(0.48, 0.19, 0.20)},
		"song":
		{
			"cue": &"bird.grey_heron.call",
			"kind": &"harsh_fraank",
			"time": &"day",
			"cadence_s": Vector2(14.0, 35.0)
		},
		"abundance": 0.34
	},
	&"northern_lapwing":
	{
		"name": "Northern lapwing",
		"group": GROUP_WADER,
		"scale_m": 0.30,
		"pose": POSE_STANDING,
		"colors": [Color("303d39"), Color("dedbd0"), Color("6f8a69")],
		"crest": true,
		"geometry": {"neck": 0.08, "legs": 0.27, "beak": 0.16, "body": Vector3(0.45, 0.22, 0.23)},
		"song":
		{
			"cue": &"bird.northern_lapwing.call",
			"kind": &"peewit",
			"time": &"day",
			"cadence_s": Vector2(3.0, 10.0)
		},
		"abundance": 0.70,
		"spawn": {CONTEXT_FORELAND: 0.90}
	},
	&"common_snipe":
	{
		"name": "Common snipe",
		"group": GROUP_WADER,
		"scale_m": 0.27,
		"pose": POSE_STANDING,
		"colors": [Color("76664c"), Color("4f4738"), Color("d0b577")],
		"geometry": {"neck": 0.05, "legs": 0.25, "beak": 0.56, "body": Vector3(0.42, 0.19, 0.19)},
		"song":
		{
			"cue": &"bird.common_snipe.call",
			"kind": &"ticking_and_drumming",
			"time": &"dawn_dusk",
			"cadence_s": Vector2(4.0, 12.0)
		},
		"abundance": 0.58
	},
}
