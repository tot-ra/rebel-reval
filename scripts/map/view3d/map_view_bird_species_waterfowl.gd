extends RefCounted

## Waterfowl species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## waterfowl plumage, spawn weights, or song metadata.

const GROUP_WATERFOWL := &"waterfowl"
const POSE_STANDING := &"standing"
const CONTEXT_HARBOR := &"harbor"
const CONTEXT_WETLAND := &"wetland"

const PROFILES: Dictionary = {
	&"mute_swan":
	{
		"name": "Mute swan",
		"group": GROUP_WATERFOWL,
		"scale_m": 1.45,
		"pose": POSE_STANDING,
		"colors": [Color("e8e5dc"), Color("d8d5cc"), Color("d77a36")],
		"geometry": {"neck": 0.72, "body": Vector3(0.72, 0.32, 0.38), "head": 0.13, "beak": 0.25},
		"song":
		{
			"cue": &"bird.mute_swan.call",
			"kind": &"hiss_and_wing",
			"time": &"day",
			"cadence_s": Vector2(12.0, 28.0)
		},
		"abundance": 0.32
	},
	&"mallard":
	{
		"name": "Mallard",
		"group": GROUP_WATERFOWL,
		"scale_m": 0.56,
		"pose": POSE_STANDING,
		"colors": [Color("766a4d"), Color("335b4d"), Color("d3a442")],
		"breast": Color("77503a"),
		"geometry": {"neck": 0.13, "beak": 0.26},
		"song":
		{
			"cue": &"bird.mallard.call",
			"kind": &"quack",
			"time": &"day",
			"cadence_s": Vector2(4.0, 13.0)
		},
		"abundance": 0.82
	},
	&"greylag_goose":
	{
		"name": "Greylag goose",
		"group": GROUP_WATERFOWL,
		"scale_m": 0.82,
		"pose": POSE_STANDING,
		"colors": [Color("938d7c"), Color("6f7168"), Color("d68c4c")],
		"geometry": {"neck": 0.46, "body": Vector3(0.68, 0.31, 0.36)},
		"song":
		{
			"cue": &"bird.greylag_goose.call",
			"kind": &"nasal_honk",
			"time": &"day",
			"cadence_s": Vector2(5.0, 16.0)
		},
		"abundance": 0.54
	},
	&"great_cormorant":
	{
		"name": "Great cormorant",
		"group": GROUP_WATERFOWL,
		"scale_m": 0.88,
		"pose": POSE_STANDING,
		"colors": [Color("252b2b"), Color("15191a"), Color("c9a85b")],
		"geometry": {"neck": 0.52, "body": Vector3(0.58, 0.25, 0.28), "beak": 0.29, "tail": 0.30},
		"song":
		{
			"cue": &"bird.great_cormorant.call",
			"kind": &"guttural_croak",
			"time": &"day",
			"cadence_s": Vector2(8.0, 22.0)
		},
		"abundance": 0.38,
		"spawn": {CONTEXT_HARBOR: 0.92, CONTEXT_WETLAND: 0.70}
	},
}
