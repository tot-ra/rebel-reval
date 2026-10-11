extends RefCounted

## Owl species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## owl plumage, spawn weights, or song metadata.

const GROUP_OWL := &"owl"
const POSE_PERCHED := &"perched"

const PROFILES: Dictionary = {
	&"tawny_owl":
	{
		"name": "Tawny owl",
		"group": GROUP_OWL,
		"scale_m": 0.39,
		"pose": POSE_PERCHED,
		"colors": [Color("7a6248"), Color("4e4034"), Color("c8a879")],
		"song":
		{
			"cue": &"bird.tawny_owl.call",
			"kind": &"hooting_phrase",
			"time": &"night",
			"cadence_s": Vector2(12.0, 30.0)
		},
		"abundance": 0.42
	},
}
