extends RefCounted

## Woodpecker species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## woodpecker plumage, spawn weights, or song metadata.

const GROUP_WOODPECKER := &"woodpecker"
const POSE_PERCHED := &"perched"

const PROFILES: Dictionary = {
	&"great_spotted_woodpecker":
	{
		"name": "Great spotted woodpecker",
		"group": GROUP_WOODPECKER,
		"scale_m": 0.23,
		"pose": POSE_PERCHED,
		"colors": [Color("d8d2c3"), Color("292b2b"), Color("a74335")],
		"song":
		{
			"cue": &"bird.great_spotted_woodpecker.call",
			"kind": &"sharp_kik_and_drumming",
			"time": &"day",
			"cadence_s": Vector2(7.0, 18.0)
		},
		"abundance": 0.60
	},
}
