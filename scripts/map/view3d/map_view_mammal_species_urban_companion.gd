extends RefCounted

## Urban companion profiles for MapViewMammalSpecies (P0-185 shard).
## Stable IDs and accessor APIs remain on the facade; edit this file when tuning
## Lower Town street actors (cat, dog, horse, rat) plumage, spawn weights, or scale overrides.

const GROUP_CANID := &"canid"
const GROUP_FELID := &"felid"
const GROUP_RODENT := &"rodent"
const GROUP_UNGULATE := &"ungulate"
const POSE_STANDING := &"standing"
const POSE_RESTING := &"resting"
const CONTEXT_HARBOR := &"harbor"
const CONTEXT_LOWER_TOWN := &"lower_town"
const CONTEXT_MARKET := &"market_civic"
const CONTEXT_FORELAND := &"foreland"

const PROFILES: Dictionary = {
	&"cat":
	{
		# Cat and rat are the close-range Lower Town actors, so their proportions are
		"name": "Domestic cat",
		"group": GROUP_FELID,
		"scale_m": 0.42,
		"pose": POSE_RESTING,
		"colors": [Color("8a7a62"), Color("4a4038"), Color("e8ddd0")],
		"geometry":
		{
			# measured from the real animal rather than inherited from the felid/rodent
			"body": Vector3(0.48, 0.20, 0.17),
			"head": 0.09,
			"neck": 0.05,
			"legs": 0.20,
			"ears": 0.07,
			"tail": 0.32
		},
		"abundance": 0.72,
		"spawn": {CONTEXT_LOWER_TOWN: 0.92, CONTEXT_MARKET: 0.68}
	},
	&"dog":
	{
		# reference blocks: small head, low-slung body, long tail.
		"name": "Domestic dog",
		"group": GROUP_CANID,
		"scale_m": 0.52,
		"pose": POSE_STANDING,
		"colors": [Color("8a6a42"), Color("4a4038"), Color("2a2824")],
		"geometry": {"body": Vector3(0.62, 0.28, 0.24), "tail": 0.24},
		"abundance": 0.68,
		"spawn": {CONTEXT_LOWER_TOWN: 0.88, CONTEXT_MARKET: 0.62}
	},
	&"horse":
	{
		"name": "Horse",
		"group": GROUP_UNGULATE,
		"scale_m": 1.42,
		"pose": POSE_STANDING,
		"colors": [Color("7a5a38"), Color("4a3424"), Color("2a241c")],
		"geometry": {"body": Vector3(1.02, 0.50, 0.34), "neck": 0.34, "legs": 0.58, "tail": 0.42},
		"abundance": 0.54,
		"spawn": {CONTEXT_LOWER_TOWN: 0.48, CONTEXT_MARKET: 0.42, CONTEXT_FORELAND: 0.38}
	},
	&"rat":
	{
		"name": "Brown rat",
		"group": GROUP_RODENT,
		"scale_m": 0.24,
		"pose": POSE_STANDING,
		"colors": [Color("6a5a48"), Color("4a4038"), Color("2a2824")],
		"geometry":
		{
			"body": Vector3(0.28, 0.11, 0.10),
			"head": 0.055,
			"neck": 0.02,
			"legs": 0.05,
			"ears": 0.05,
			"tail": 0.30
		},
		"abundance": 0.82,
		"spawn": {CONTEXT_LOWER_TOWN: 0.86, CONTEXT_HARBOR: 0.72}
	},
}
