extends RefCounted

## Gull species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## gull plumage, spawn weights, or song metadata.

const GROUP_GULL := &"gull"
const POSE_GLIDING := &"gliding"

const PROFILES: Dictionary = {
	&"herring_gull":
	{
		"name": "Herring gull",
		"group": GROUP_GULL,
		"scale_m": 0.60,
		"pose": POSE_GLIDING,
		"colors": [Color("d9d8cf"), Color("666d73"), Color("f0e8ce")],
		"song":
		{
			"cue": &"bird.herring_gull.call",
			"kind": &"harsh_laugh",
			"time": &"day",
			"cadence_s": Vector2(4.0, 12.0)
		},
		"abundance": 0.90
	},
	&"common_gull":
	{
		"name": "Common gull",
		"group": GROUP_GULL,
		"scale_m": 0.43,
		"pose": POSE_GLIDING,
		"colors": [Color("deddd4"), Color("81888d"), Color("f2e4bd")],
		"song":
		{
			"cue": &"bird.common_gull.call",
			"kind": &"clear_laugh",
			"time": &"day",
			"cadence_s": Vector2(5.0, 14.0)
		},
		"abundance": 0.72
	},
}
