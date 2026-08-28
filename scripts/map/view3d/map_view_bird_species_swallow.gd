extends RefCounted

## Swallow species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## swallow plumage, spawn weights, or song metadata.

const GROUP_SWALLOW := &"swallow"
const POSE_GLIDING := &"gliding"

const PROFILES: Dictionary = {
	&"barn_swallow":
	{
		"name": "Barn swallow",
		"group": GROUP_SWALLOW,
		"scale_m": 0.19,
		"pose": POSE_GLIDING,
		"colors": [Color("e7ddd0"), Color("283d49"), Color("9c4b3e")],
		"song":
		{
			"cue": &"bird.barn_swallow.song",
			"kind": &"liquid_twitter",
			"time": &"day",
			"cadence_s": Vector2(2.0, 6.0)
		},
		"abundance": 0.86
	},
}
