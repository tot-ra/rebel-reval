extends RefCounted

## Songbird species profiles for MapViewBirdSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## songbird plumage, spawn weights, or song metadata.

const GROUP_SONGBIRD := &"songbird"
const POSE_PERCHED := &"perched"
const POSE_GLIDING := &"gliding"
const CONTEXT_LOWER_TOWN := &"lower_town"
const CONTEXT_MARKET := &"market_civic"
const CONTEXT_FORELAND := &"foreland"
const CONTEXT_GARDEN := &"garden"
const CONTEXT_WOODLAND := &"woodland"

const PROFILES: Dictionary = {
	&"house_sparrow":
	{
		"name": "House sparrow",
		"group": GROUP_SONGBIRD,
		"scale_m": 0.15,
		"pose": POSE_PERCHED,
		"colors": [Color("8a7255"), Color("4b453d"), Color("c5ad7e")],
		"breast": Color("c9bda6"),
		"geometry": {"body": Vector3(0.32, 0.21, 0.20), "beak": 0.09},
		"song":
		{
			"cue": &"bird.house_sparrow.call",
			"kind": &"cheep_chatter",
			"time": &"day",
			"cadence_s": Vector2(1.5, 5.0)
		},
		"abundance": 1.0,
		"spawn": {CONTEXT_LOWER_TOWN: 1.0, CONTEXT_MARKET: 0.95}
	},
	&"skylark":
	{
		"name": "Skylark",
		"group": GROUP_SONGBIRD,
		"scale_m": 0.18,
		"pose": POSE_GLIDING,
		"colors": [Color("8d785a"), Color("625642"), Color("d0b987")],
		"geometry": {"wing_span": 0.82, "tail": 0.30},
		"song":
		{
			"cue": &"bird.skylark.song",
			"kind": &"sustained_aerial_warble",
			"time": &"dawn_day",
			"cadence_s": Vector2(7.0, 20.0)
		},
		"abundance": 0.78,
		"spawn": {CONTEXT_FORELAND: 1.0, CONTEXT_LOWER_TOWN: 0.08}
	},
	&"yellowhammer":
	{
		"name": "Yellowhammer",
		"group": GROUP_SONGBIRD,
		"scale_m": 0.17,
		"pose": POSE_PERCHED,
		"colors": [Color("c3b44d"), Color("76694a"), Color("e0cf59")],
		"breast": Color("d9c34a"),
		"song":
		{
			"cue": &"bird.yellowhammer.song",
			"kind": &"descending_phrase",
			"time": &"day",
			"cadence_s": Vector2(3.0, 9.0)
		},
		"abundance": 0.66,
		"spawn": {CONTEXT_FORELAND: 0.94, CONTEXT_GARDEN: 0.62}
	},
	&"common_chaffinch":
	{
		"name": "Common chaffinch",
		"group": GROUP_SONGBIRD,
		"scale_m": 0.15,
		"pose": POSE_PERCHED,
		"colors": [Color("b77f66"), Color("526678"), Color("e1d6bc")],
		"breast": Color("c08a70"),
		"song":
		{
			"cue": &"bird.common_chaffinch.song",
			"kind": &"descending_trill",
			"time": &"dawn_day",
			"cadence_s": Vector2(2.5, 8.0)
		},
		"abundance": 0.90
	},
	&"great_tit":
	{
		"name": "Great tit",
		"group": GROUP_SONGBIRD,
		"scale_m": 0.14,
		"pose": POSE_PERCHED,
		"colors": [Color("b9b44b"), Color("2d3536"), Color("e1d9c3")],
		"breast": Color("cfc45a"),
		"geometry": {"body": Vector3(0.30, 0.22, 0.20), "tail": 0.21},
		"song":
		{
			"cue": &"bird.great_tit.song",
			"kind": &"two_note_repeat",
			"time": &"dawn_day",
			"cadence_s": Vector2(2.0, 7.0)
		},
		"abundance": 0.92
	},
	&"european_robin":
	{
		"name": "European robin",
		"group": GROUP_SONGBIRD,
		"scale_m": 0.14,
		"pose": POSE_PERCHED,
		"colors": [Color("786b55"), Color("9f5134"), Color("c8b58c")],
		"breast": Color("b3603c"),
		"geometry": {"body": Vector3(0.29, 0.23, 0.21), "tail": 0.18},
		"song":
		{
			"cue": &"bird.european_robin.song",
			"kind": &"thin_fluting_warble",
			"time": &"dawn_dusk",
			"cadence_s": Vector2(4.0, 11.0)
		},
		"abundance": 0.78
	},
	&"common_blackbird":
	{
		"name": "Common blackbird",
		"group": GROUP_SONGBIRD,
		"scale_m": 0.25,
		"pose": POSE_PERCHED,
		"colors": [Color("282a28"), Color("1d201f"), Color("d39a3c")],
		"geometry": {"body": Vector3(0.38, 0.22, 0.21), "tail": 0.36, "beak": 0.14},
		"song":
		{
			"cue": &"bird.common_blackbird.song",
			"kind": &"rich_fluting_phrase",
			"time": &"dawn_dusk",
			"cadence_s": Vector2(5.0, 14.0)
		},
		"abundance": 0.72
	},
	&"song_thrush":
	{
		"name": "Song thrush",
		"group": GROUP_SONGBIRD,
		"scale_m": 0.23,
		"pose": POSE_PERCHED,
		"colors": [Color("8b7455"), Color("5f513f"), Color("d7c6a1")],
		"geometry": {"body": Vector3(0.37, 0.22, 0.21), "tail": 0.31},
		"song":
		{
			"cue": &"bird.song_thrush.song",
			"kind": &"repeated_fluting_motifs",
			"time": &"dawn_dusk",
			"cadence_s": Vector2(4.0, 12.0)
		},
		"abundance": 0.68
	},
	&"common_nightingale":
	{
		"name": "Common nightingale",
		"group": GROUP_SONGBIRD,
		"scale_m": 0.16,
		"pose": POSE_PERCHED,
		"colors": [Color("826b50"), Color("6e5943"), Color("b79a70")],
		"geometry": {"tail": 0.32},
		"song":
		{
			"cue": &"bird.common_nightingale.song",
			"kind": &"powerful_varied_phrase",
			"time": &"night_dawn",
			"cadence_s": Vector2(4.0, 11.0)
		},
		"abundance": 0.42,
		"spawn": {CONTEXT_GARDEN: 0.86, CONTEXT_WOODLAND: 0.78, CONTEXT_MARKET: 0.08}
	},
}
