extends RefCounted

## Tern species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## tern plumage, spawn weights, or song metadata.

const GROUP_TERN := &"tern"
const POSE_GLIDING := &"gliding"

const PROFILES: Dictionary = {
	&"common_tern":
	{
		"name": "Common tern",
		"group": GROUP_TERN,
		"scale_m": 0.35,
		"pose": POSE_GLIDING,
		"colors": [Color("d8d9d4"), Color("2d3336"), Color("c74a39")],
		"song":
		{
			"cue": &"bird.common_tern.call",
			"kind": &"sharp_kik",
			"time": &"day",
			"cadence_s": Vector2(2.5, 8.0)
		},
		"abundance": 0.68
	},
}
