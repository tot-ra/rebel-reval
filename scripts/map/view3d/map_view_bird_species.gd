class_name MapViewBirdSpecies
extends RefCounted

## Data-only catalog for north-Baltic ambient birds. P0-117 owns stable IDs,
## visual/acoustic profile stubs, and district suitability. Runtime spawning,
## flight, voice playback, and gameplay interaction remain P0-105 concerns.

const GROUP_GULL := &"gull"
const GROUP_TERN := &"tern"
const GROUP_WATERFOWL := &"waterfowl"
const GROUP_WADER := &"wader"
const GROUP_RAPTOR := &"raptor"
const GROUP_OWL := &"owl"
const GROUP_CORVID := &"corvid"
const GROUP_SWALLOW := &"swallow"
const GROUP_SONGBIRD := &"songbird"
const GROUP_WOODPECKER := &"woodpecker"

const ALL_GROUPS: Array[StringName] = [
	GROUP_GULL,
	GROUP_TERN,
	GROUP_WATERFOWL,
	GROUP_WADER,
	GROUP_RAPTOR,
	GROUP_OWL,
	GROUP_CORVID,
	GROUP_SWALLOW,
	GROUP_SONGBIRD,
	GROUP_WOODPECKER,
]

const POSE_STANDING := &"standing"
const POSE_PERCHED := &"perched"
const POSE_GLIDING := &"gliding"
const ALL_POSES: Array[StringName] = [POSE_STANDING, POSE_PERCHED, POSE_GLIDING]

const CONTEXT_HARBOR := &"harbor"
const CONTEXT_LOWER_TOWN := &"lower_town"
const CONTEXT_MARKET := &"market_civic"
const CONTEXT_MONASTERY := &"monastery"
const CONTEXT_TOOMPEA := &"toompea"
const CONTEXT_FORELAND := &"foreland"
const CONTEXT_WETLAND := &"wetland"
const CONTEXT_WOODLAND := &"woodland"
const CONTEXT_GARDEN := &"garden"

const ALL_CONTEXTS: Array[StringName] = [
	CONTEXT_HARBOR,
	CONTEXT_LOWER_TOWN,
	CONTEXT_MARKET,
	CONTEXT_MONASTERY,
	CONTEXT_TOOMPEA,
	CONTEXT_FORELAND,
	CONTEXT_WETLAND,
	CONTEXT_WOODLAND,
	CONTEXT_GARDEN,
]

const SPECIES_HERRING_GULL := &"herring_gull"
const SPECIES_COMMON_GULL := &"common_gull"
const SPECIES_COMMON_TERN := &"common_tern"
const SPECIES_MUTE_SWAN := &"mute_swan"
const SPECIES_MALLARD := &"mallard"
const SPECIES_GREYLAG_GOOSE := &"greylag_goose"
const SPECIES_GREAT_CORMORANT := &"great_cormorant"
const SPECIES_GREY_HERON := &"grey_heron"
const SPECIES_NORTHERN_LAPWING := &"northern_lapwing"
const SPECIES_COMMON_SNIPE := &"common_snipe"
const SPECIES_WHITE_TAILED_EAGLE := &"white_tailed_eagle"
const SPECIES_OSPREY := &"osprey"
const SPECIES_COMMON_BUZZARD := &"common_buzzard"
const SPECIES_COMMON_KESTREL := &"common_kestrel"
const SPECIES_TAWNY_OWL := &"tawny_owl"
const SPECIES_HOUSE_SPARROW := &"house_sparrow"
const SPECIES_HOODED_CROW := &"hooded_crow"
const SPECIES_ROOK := &"rook"
const SPECIES_WESTERN_JACKDAW := &"western_jackdaw"
const SPECIES_EURASIAN_MAGPIE := &"eurasian_magpie"
const SPECIES_BARN_SWALLOW := &"barn_swallow"
const SPECIES_SKYLARK := &"skylark"
const SPECIES_YELLOWHAMMER := &"yellowhammer"
const SPECIES_COMMON_CHAFFINCH := &"common_chaffinch"
const SPECIES_GREAT_TIT := &"great_tit"
const SPECIES_EUROPEAN_ROBIN := &"european_robin"
const SPECIES_COMMON_BLACKBIRD := &"common_blackbird"
const SPECIES_SONG_THRUSH := &"song_thrush"
const SPECIES_COMMON_NIGHTINGALE := &"common_nightingale"
const SPECIES_GREAT_SPOTTED_WOODPECKER := &"great_spotted_woodpecker"

const ALL_SPECIES: Array[StringName] = [
	SPECIES_HERRING_GULL,
	SPECIES_COMMON_GULL,
	SPECIES_COMMON_TERN,
	SPECIES_MUTE_SWAN,
	SPECIES_MALLARD,
	SPECIES_GREYLAG_GOOSE,
	SPECIES_GREAT_CORMORANT,
	SPECIES_GREY_HERON,
	SPECIES_NORTHERN_LAPWING,
	SPECIES_COMMON_SNIPE,
	SPECIES_WHITE_TAILED_EAGLE,
	SPECIES_OSPREY,
	SPECIES_COMMON_BUZZARD,
	SPECIES_COMMON_KESTREL,
	SPECIES_TAWNY_OWL,
	SPECIES_HOUSE_SPARROW,
	SPECIES_HOODED_CROW,
	SPECIES_ROOK,
	SPECIES_WESTERN_JACKDAW,
	SPECIES_EURASIAN_MAGPIE,
	SPECIES_BARN_SWALLOW,
	SPECIES_SKYLARK,
	SPECIES_YELLOWHAMMER,
	SPECIES_COMMON_CHAFFINCH,
	SPECIES_GREAT_TIT,
	SPECIES_EUROPEAN_ROBIN,
	SPECIES_COMMON_BLACKBIRD,
	SPECIES_SONG_THRUSH,
	SPECIES_COMMON_NIGHTINGALE,
	SPECIES_GREAT_SPOTTED_WOODPECKER,
]

## Geometry families remain deliberately bounded. Species overrides below change
## proportions and plumage while these ten families preserve cheap model reuse.
const GROUP_GEOMETRY: Dictionary = {
	GROUP_GULL: {"body": Vector3(0.52, 0.24, 0.25), "head": 0.15, "wing_span": 1.20, "wing_chord": 0.36, "tail": 0.24, "beak": 0.19, "neck": 0.08, "legs": 0.19},
	GROUP_TERN: {"body": Vector3(0.44, 0.18, 0.18), "head": 0.12, "wing_span": 1.32, "wing_chord": 0.27, "tail": 0.42, "beak": 0.25, "neck": 0.06, "legs": 0.12},
	GROUP_WATERFOWL: {"body": Vector3(0.62, 0.30, 0.34), "head": 0.16, "wing_span": 1.10, "wing_chord": 0.42, "tail": 0.18, "beak": 0.22, "neck": 0.22, "legs": 0.17},
	GROUP_WADER: {"body": Vector3(0.42, 0.20, 0.20), "head": 0.12, "wing_span": 1.02, "wing_chord": 0.31, "tail": 0.18, "beak": 0.36, "neck": 0.30, "legs": 0.48},
	GROUP_RAPTOR: {"body": Vector3(0.52, 0.29, 0.30), "head": 0.17, "wing_span": 1.42, "wing_chord": 0.50, "tail": 0.34, "beak": 0.13, "neck": 0.05, "legs": 0.22},
	GROUP_OWL: {"body": Vector3(0.42, 0.38, 0.34), "head": 0.23, "wing_span": 1.14, "wing_chord": 0.49, "tail": 0.24, "beak": 0.08, "neck": 0.0, "legs": 0.20},
	GROUP_CORVID: {"body": Vector3(0.47, 0.25, 0.24), "head": 0.15, "wing_span": 1.03, "wing_chord": 0.38, "tail": 0.35, "beak": 0.22, "neck": 0.06, "legs": 0.23},
	GROUP_SWALLOW: {"body": Vector3(0.34, 0.13, 0.14), "head": 0.10, "wing_span": 0.94, "wing_chord": 0.22, "tail": 0.48, "beak": 0.08, "neck": 0.02, "legs": 0.08},
	GROUP_SONGBIRD: {"body": Vector3(0.31, 0.19, 0.18), "head": 0.13, "wing_span": 0.68, "wing_chord": 0.25, "tail": 0.25, "beak": 0.11, "neck": 0.02, "legs": 0.18},
	GROUP_WOODPECKER: {"body": Vector3(0.39, 0.22, 0.20), "head": 0.14, "wing_span": 0.76, "wing_chord": 0.29, "tail": 0.32, "beak": 0.19, "neck": 0.03, "legs": 0.20},
}

## Suitability values are relative authoring weights, not probabilities. P0-105
## may normalize a selected context after applying phase and population budgets.
const GROUP_SPAWN_WEIGHTS: Dictionary = {
	GROUP_GULL: {CONTEXT_HARBOR: 1.0, CONTEXT_LOWER_TOWN: 0.22, CONTEXT_MARKET: 0.46, CONTEXT_MONASTERY: 0.08, CONTEXT_TOOMPEA: 0.10, CONTEXT_FORELAND: 0.30, CONTEXT_WETLAND: 0.38, CONTEXT_WOODLAND: 0.0, CONTEXT_GARDEN: 0.05},
	GROUP_TERN: {CONTEXT_HARBOR: 1.0, CONTEXT_LOWER_TOWN: 0.04, CONTEXT_MARKET: 0.08, CONTEXT_MONASTERY: 0.0, CONTEXT_TOOMPEA: 0.02, CONTEXT_FORELAND: 0.40, CONTEXT_WETLAND: 0.72, CONTEXT_WOODLAND: 0.0, CONTEXT_GARDEN: 0.0},
	GROUP_WATERFOWL: {CONTEXT_HARBOR: 0.62, CONTEXT_LOWER_TOWN: 0.02, CONTEXT_MARKET: 0.03, CONTEXT_MONASTERY: 0.06, CONTEXT_TOOMPEA: 0.0, CONTEXT_FORELAND: 0.38, CONTEXT_WETLAND: 1.0, CONTEXT_WOODLAND: 0.04, CONTEXT_GARDEN: 0.18},
	GROUP_WADER: {CONTEXT_HARBOR: 0.48, CONTEXT_LOWER_TOWN: 0.0, CONTEXT_MARKET: 0.0, CONTEXT_MONASTERY: 0.0, CONTEXT_TOOMPEA: 0.0, CONTEXT_FORELAND: 0.58, CONTEXT_WETLAND: 1.0, CONTEXT_WOODLAND: 0.05, CONTEXT_GARDEN: 0.08},
	GROUP_RAPTOR: {CONTEXT_HARBOR: 0.32, CONTEXT_LOWER_TOWN: 0.10, CONTEXT_MARKET: 0.06, CONTEXT_MONASTERY: 0.12, CONTEXT_TOOMPEA: 0.52, CONTEXT_FORELAND: 0.82, CONTEXT_WETLAND: 0.54, CONTEXT_WOODLAND: 0.68, CONTEXT_GARDEN: 0.10},
	GROUP_OWL: {CONTEXT_HARBOR: 0.02, CONTEXT_LOWER_TOWN: 0.14, CONTEXT_MARKET: 0.05, CONTEXT_MONASTERY: 0.36, CONTEXT_TOOMPEA: 0.34, CONTEXT_FORELAND: 0.46, CONTEXT_WETLAND: 0.18, CONTEXT_WOODLAND: 1.0, CONTEXT_GARDEN: 0.30},
	GROUP_CORVID: {CONTEXT_HARBOR: 0.52, CONTEXT_LOWER_TOWN: 0.86, CONTEXT_MARKET: 1.0, CONTEXT_MONASTERY: 0.70, CONTEXT_TOOMPEA: 0.68, CONTEXT_FORELAND: 0.64, CONTEXT_WETLAND: 0.38, CONTEXT_WOODLAND: 0.60, CONTEXT_GARDEN: 0.62},
	GROUP_SWALLOW: {CONTEXT_HARBOR: 0.58, CONTEXT_LOWER_TOWN: 0.82, CONTEXT_MARKET: 0.72, CONTEXT_MONASTERY: 0.66, CONTEXT_TOOMPEA: 0.45, CONTEXT_FORELAND: 0.88, CONTEXT_WETLAND: 0.66, CONTEXT_WOODLAND: 0.20, CONTEXT_GARDEN: 0.72},
	GROUP_SONGBIRD: {CONTEXT_HARBOR: 0.16, CONTEXT_LOWER_TOWN: 0.54, CONTEXT_MARKET: 0.42, CONTEXT_MONASTERY: 0.72, CONTEXT_TOOMPEA: 0.46, CONTEXT_FORELAND: 0.78, CONTEXT_WETLAND: 0.44, CONTEXT_WOODLAND: 0.80, CONTEXT_GARDEN: 1.0},
	GROUP_WOODPECKER: {CONTEXT_HARBOR: 0.0, CONTEXT_LOWER_TOWN: 0.04, CONTEXT_MARKET: 0.0, CONTEXT_MONASTERY: 0.20, CONTEXT_TOOMPEA: 0.12, CONTEXT_FORELAND: 0.42, CONTEXT_WETLAND: 0.18, CONTEXT_WOODLAND: 1.0, CONTEXT_GARDEN: 0.48},
}

## `scale_m` is approximate body length used to preserve relative runtime scale.
## `song` is metadata only: no audio stream or playback behavior is loaded here.
const PROFILES: Dictionary = {
	SPECIES_HERRING_GULL: {"name": "Herring gull", "group": GROUP_GULL, "scale_m": 0.60, "pose": POSE_GLIDING, "colors": [Color("d9d8cf"), Color("666d73"), Color("f0e8ce")], "song": {"cue": &"bird.herring_gull.call", "kind": &"harsh_laugh", "time": &"day", "cadence_s": Vector2(4.0, 12.0)}, "abundance": 0.90},
	SPECIES_COMMON_GULL: {"name": "Common gull", "group": GROUP_GULL, "scale_m": 0.43, "pose": POSE_GLIDING, "colors": [Color("deddd4"), Color("81888d"), Color("f2e4bd")], "song": {"cue": &"bird.common_gull.call", "kind": &"clear_laugh", "time": &"day", "cadence_s": Vector2(5.0, 14.0)}, "abundance": 0.72},
	SPECIES_COMMON_TERN: {"name": "Common tern", "group": GROUP_TERN, "scale_m": 0.35, "pose": POSE_GLIDING, "colors": [Color("d8d9d4"), Color("2d3336"), Color("c74a39")], "song": {"cue": &"bird.common_tern.call", "kind": &"sharp_kik", "time": &"day", "cadence_s": Vector2(2.5, 8.0)}, "abundance": 0.68},
	SPECIES_MUTE_SWAN: {"name": "Mute swan", "group": GROUP_WATERFOWL, "scale_m": 1.45, "pose": POSE_STANDING, "colors": [Color("e8e5dc"), Color("d8d5cc"), Color("d77a36")], "geometry": {"neck": 0.72, "body": Vector3(0.72, 0.32, 0.38), "head": 0.13, "beak": 0.25}, "song": {"cue": &"bird.mute_swan.call", "kind": &"hiss_and_wing", "time": &"day", "cadence_s": Vector2(12.0, 28.0)}, "abundance": 0.32},
	SPECIES_MALLARD: {"name": "Mallard", "group": GROUP_WATERFOWL, "scale_m": 0.56, "pose": POSE_STANDING, "colors": [Color("766a4d"), Color("335b4d"), Color("d3a442")], "geometry": {"neck": 0.13, "beak": 0.26}, "song": {"cue": &"bird.mallard.call", "kind": &"quack", "time": &"day", "cadence_s": Vector2(4.0, 13.0)}, "abundance": 0.82},
	SPECIES_GREYLAG_GOOSE: {"name": "Greylag goose", "group": GROUP_WATERFOWL, "scale_m": 0.82, "pose": POSE_STANDING, "colors": [Color("938d7c"), Color("6f7168"), Color("d68c4c")], "geometry": {"neck": 0.46, "body": Vector3(0.68, 0.31, 0.36)}, "song": {"cue": &"bird.greylag_goose.call", "kind": &"nasal_honk", "time": &"day", "cadence_s": Vector2(5.0, 16.0)}, "abundance": 0.54},
	SPECIES_GREAT_CORMORANT: {"name": "Great cormorant", "group": GROUP_WATERFOWL, "scale_m": 0.88, "pose": POSE_STANDING, "colors": [Color("252b2b"), Color("15191a"), Color("c9a85b")], "geometry": {"neck": 0.52, "body": Vector3(0.58, 0.25, 0.28), "beak": 0.29, "tail": 0.30}, "song": {"cue": &"bird.great_cormorant.call", "kind": &"guttural_croak", "time": &"day", "cadence_s": Vector2(8.0, 22.0)}, "abundance": 0.38, "spawn": {CONTEXT_HARBOR: 0.92, CONTEXT_WETLAND: 0.70}},
	SPECIES_GREY_HERON: {"name": "Grey heron", "group": GROUP_WADER, "scale_m": 0.94, "pose": POSE_STANDING, "colors": [Color("858d91"), Color("444b4e"), Color("d6b050")], "geometry": {"neck": 0.66, "legs": 0.72, "beak": 0.48, "body": Vector3(0.48, 0.19, 0.20)}, "song": {"cue": &"bird.grey_heron.call", "kind": &"harsh_fraank", "time": &"day", "cadence_s": Vector2(14.0, 35.0)}, "abundance": 0.34},
	SPECIES_NORTHERN_LAPWING: {"name": "Northern lapwing", "group": GROUP_WADER, "scale_m": 0.30, "pose": POSE_STANDING, "colors": [Color("303d39"), Color("dedbd0"), Color("6f8a69")], "geometry": {"neck": 0.08, "legs": 0.27, "beak": 0.16, "body": Vector3(0.45, 0.22, 0.23)}, "song": {"cue": &"bird.northern_lapwing.call", "kind": &"peewit", "time": &"day", "cadence_s": Vector2(3.0, 10.0)}, "abundance": 0.70, "spawn": {CONTEXT_FORELAND: 0.90}},
	SPECIES_COMMON_SNIPE: {"name": "Common snipe", "group": GROUP_WADER, "scale_m": 0.27, "pose": POSE_STANDING, "colors": [Color("76664c"), Color("4f4738"), Color("d0b577")], "geometry": {"neck": 0.05, "legs": 0.25, "beak": 0.56, "body": Vector3(0.42, 0.19, 0.19)}, "song": {"cue": &"bird.common_snipe.call", "kind": &"ticking_and_drumming", "time": &"dawn_dusk", "cadence_s": Vector2(4.0, 12.0)}, "abundance": 0.58},
	SPECIES_WHITE_TAILED_EAGLE: {"name": "White-tailed eagle", "group": GROUP_RAPTOR, "scale_m": 0.86, "pose": POSE_GLIDING, "colors": [Color("574b3b"), Color("332e28"), Color("ded8c5")], "geometry": {"wing_span": 1.72, "wing_chord": 0.58, "body": Vector3(0.58, 0.31, 0.34)}, "song": {"cue": &"bird.white_tailed_eagle.call", "kind": &"far_carrying_yelp", "time": &"day", "cadence_s": Vector2(18.0, 42.0)}, "abundance": 0.16, "spawn": {CONTEXT_HARBOR: 0.45, CONTEXT_FORELAND: 0.72, CONTEXT_WETLAND: 0.62}},
	SPECIES_OSPREY: {"name": "Osprey", "group": GROUP_RAPTOR, "scale_m": 0.58, "pose": POSE_GLIDING, "colors": [Color("d9d2bd"), Color("4c4438"), Color("d2b365")], "geometry": {"wing_span": 1.58, "wing_chord": 0.43}, "song": {"cue": &"bird.osprey.call", "kind": &"thin_whistle", "time": &"day", "cadence_s": Vector2(12.0, 32.0)}, "abundance": 0.20, "spawn": {CONTEXT_HARBOR: 0.48, CONTEXT_WETLAND: 0.76}},
	SPECIES_COMMON_BUZZARD: {"name": "Common buzzard", "group": GROUP_RAPTOR, "scale_m": 0.54, "pose": POSE_GLIDING, "colors": [Color("755e45"), Color("4b3d30"), Color("c5aa82")], "song": {"cue": &"bird.common_buzzard.call", "kind": &"mewing_peeoo", "time": &"day", "cadence_s": Vector2(10.0, 27.0)}, "abundance": 0.46},
	SPECIES_COMMON_KESTREL: {"name": "Common kestrel", "group": GROUP_RAPTOR, "scale_m": 0.34, "pose": POSE_GLIDING, "colors": [Color("a56a43"), Color("4d4b4b"), Color("d6b36d")], "geometry": {"wing_span": 1.20, "wing_chord": 0.35, "tail": 0.42, "body": Vector3(0.47, 0.25, 0.26)}, "song": {"cue": &"bird.common_kestrel.call", "kind": &"rapid_kikiki", "time": &"day", "cadence_s": Vector2(6.0, 18.0)}, "abundance": 0.42, "spawn": {CONTEXT_TOOMPEA: 0.74, CONTEXT_LOWER_TOWN: 0.26}},
	SPECIES_TAWNY_OWL: {"name": "Tawny owl", "group": GROUP_OWL, "scale_m": 0.39, "pose": POSE_PERCHED, "colors": [Color("7a6248"), Color("4e4034"), Color("c8a879")], "song": {"cue": &"bird.tawny_owl.call", "kind": &"hooting_phrase", "time": &"night", "cadence_s": Vector2(12.0, 30.0)}, "abundance": 0.42},
	SPECIES_HOUSE_SPARROW: {"name": "House sparrow", "group": GROUP_SONGBIRD, "scale_m": 0.15, "pose": POSE_PERCHED, "colors": [Color("8a7255"), Color("4b453d"), Color("c5ad7e")], "geometry": {"body": Vector3(0.32, 0.21, 0.20), "beak": 0.09}, "song": {"cue": &"bird.house_sparrow.call", "kind": &"cheep_chatter", "time": &"day", "cadence_s": Vector2(1.5, 5.0)}, "abundance": 1.0, "spawn": {CONTEXT_LOWER_TOWN: 1.0, CONTEXT_MARKET: 0.95}},
	SPECIES_HOODED_CROW: {"name": "Hooded crow", "group": GROUP_CORVID, "scale_m": 0.49, "pose": POSE_PERCHED, "colors": [Color("777b78"), Color("242728"), Color("303333")], "song": {"cue": &"bird.hooded_crow.call", "kind": &"rough_caw", "time": &"day", "cadence_s": Vector2(4.0, 12.0)}, "abundance": 0.82},
	SPECIES_ROOK: {"name": "Rook", "group": GROUP_CORVID, "scale_m": 0.46, "pose": POSE_PERCHED, "colors": [Color("25292a"), Color("15191a"), Color("8f8b7d")], "geometry": {"beak": 0.26}, "song": {"cue": &"bird.rook.call", "kind": &"nasal_kaah", "time": &"day", "cadence_s": Vector2(3.0, 9.0)}, "abundance": 0.68, "spawn": {CONTEXT_MARKET: 0.92, CONTEXT_FORELAND: 0.76}},
	SPECIES_WESTERN_JACKDAW: {"name": "Western jackdaw", "group": GROUP_CORVID, "scale_m": 0.34, "pose": POSE_PERCHED, "colors": [Color("353a3b"), Color("24292a"), Color("8e9691")], "geometry": {"body": Vector3(0.43, 0.24, 0.23), "tail": 0.28}, "song": {"cue": &"bird.western_jackdaw.call", "kind": &"metallic_chyak", "time": &"day", "cadence_s": Vector2(2.0, 7.0)}, "abundance": 0.88, "spawn": {CONTEXT_TOOMPEA: 0.88, CONTEXT_LOWER_TOWN: 0.92}},
	SPECIES_EURASIAN_MAGPIE: {"name": "Eurasian magpie", "group": GROUP_CORVID, "scale_m": 0.46, "pose": POSE_PERCHED, "colors": [Color("e0ded4"), Color("202626"), Color("477069")], "geometry": {"tail": 0.62, "body": Vector3(0.42, 0.23, 0.22)}, "song": {"cue": &"bird.eurasian_magpie.call", "kind": &"rattling_chatter", "time": &"day", "cadence_s": Vector2(5.0, 14.0)}, "abundance": 0.56, "spawn": {CONTEXT_GARDEN: 0.82, CONTEXT_FORELAND: 0.75}},
	SPECIES_BARN_SWALLOW: {"name": "Barn swallow", "group": GROUP_SWALLOW, "scale_m": 0.19, "pose": POSE_GLIDING, "colors": [Color("e7ddd0"), Color("283d49"), Color("9c4b3e")], "song": {"cue": &"bird.barn_swallow.song", "kind": &"liquid_twitter", "time": &"day", "cadence_s": Vector2(2.0, 6.0)}, "abundance": 0.86},
	SPECIES_SKYLARK: {"name": "Skylark", "group": GROUP_SONGBIRD, "scale_m": 0.18, "pose": POSE_GLIDING, "colors": [Color("8d785a"), Color("625642"), Color("d0b987")], "geometry": {"wing_span": 0.82, "tail": 0.30}, "song": {"cue": &"bird.skylark.song", "kind": &"sustained_aerial_warble", "time": &"dawn_day", "cadence_s": Vector2(7.0, 20.0)}, "abundance": 0.78, "spawn": {CONTEXT_FORELAND: 1.0, CONTEXT_LOWER_TOWN: 0.08}},
	SPECIES_YELLOWHAMMER: {"name": "Yellowhammer", "group": GROUP_SONGBIRD, "scale_m": 0.17, "pose": POSE_PERCHED, "colors": [Color("c3b44d"), Color("76694a"), Color("e0cf59")], "song": {"cue": &"bird.yellowhammer.song", "kind": &"descending_phrase", "time": &"day", "cadence_s": Vector2(3.0, 9.0)}, "abundance": 0.66, "spawn": {CONTEXT_FORELAND: 0.94, CONTEXT_GARDEN: 0.62}},
	SPECIES_COMMON_CHAFFINCH: {"name": "Common chaffinch", "group": GROUP_SONGBIRD, "scale_m": 0.15, "pose": POSE_PERCHED, "colors": [Color("b77f66"), Color("526678"), Color("e1d6bc")], "song": {"cue": &"bird.common_chaffinch.song", "kind": &"descending_trill", "time": &"dawn_day", "cadence_s": Vector2(2.5, 8.0)}, "abundance": 0.90},
	SPECIES_GREAT_TIT: {"name": "Great tit", "group": GROUP_SONGBIRD, "scale_m": 0.14, "pose": POSE_PERCHED, "colors": [Color("b9b44b"), Color("2d3536"), Color("e1d9c3")], "geometry": {"body": Vector3(0.30, 0.22, 0.20), "tail": 0.21}, "song": {"cue": &"bird.great_tit.song", "kind": &"two_note_repeat", "time": &"dawn_day", "cadence_s": Vector2(2.0, 7.0)}, "abundance": 0.92},
	SPECIES_EUROPEAN_ROBIN: {"name": "European robin", "group": GROUP_SONGBIRD, "scale_m": 0.14, "pose": POSE_PERCHED, "colors": [Color("786b55"), Color("9f5134"), Color("c8b58c")], "geometry": {"body": Vector3(0.29, 0.23, 0.21), "tail": 0.18}, "song": {"cue": &"bird.european_robin.song", "kind": &"thin_fluting_warble", "time": &"dawn_dusk", "cadence_s": Vector2(4.0, 11.0)}, "abundance": 0.78},
	SPECIES_COMMON_BLACKBIRD: {"name": "Common blackbird", "group": GROUP_SONGBIRD, "scale_m": 0.25, "pose": POSE_PERCHED, "colors": [Color("282a28"), Color("1d201f"), Color("d39a3c")], "geometry": {"body": Vector3(0.38, 0.22, 0.21), "tail": 0.36, "beak": 0.14}, "song": {"cue": &"bird.common_blackbird.song", "kind": &"rich_fluting_phrase", "time": &"dawn_dusk", "cadence_s": Vector2(5.0, 14.0)}, "abundance": 0.72},
	SPECIES_SONG_THRUSH: {"name": "Song thrush", "group": GROUP_SONGBIRD, "scale_m": 0.23, "pose": POSE_PERCHED, "colors": [Color("8b7455"), Color("5f513f"), Color("d7c6a1")], "geometry": {"body": Vector3(0.37, 0.22, 0.21), "tail": 0.31}, "song": {"cue": &"bird.song_thrush.song", "kind": &"repeated_fluting_motifs", "time": &"dawn_dusk", "cadence_s": Vector2(4.0, 12.0)}, "abundance": 0.68},
	SPECIES_COMMON_NIGHTINGALE: {"name": "Common nightingale", "group": GROUP_SONGBIRD, "scale_m": 0.16, "pose": POSE_PERCHED, "colors": [Color("826b50"), Color("6e5943"), Color("b79a70")], "geometry": {"tail": 0.32}, "song": {"cue": &"bird.common_nightingale.song", "kind": &"powerful_varied_phrase", "time": &"night_dawn", "cadence_s": Vector2(4.0, 11.0)}, "abundance": 0.42, "spawn": {CONTEXT_GARDEN: 0.86, CONTEXT_WOODLAND: 0.78, CONTEXT_MARKET: 0.08}},
	SPECIES_GREAT_SPOTTED_WOODPECKER: {"name": "Great spotted woodpecker", "group": GROUP_WOODPECKER, "scale_m": 0.23, "pose": POSE_PERCHED, "colors": [Color("d8d2c3"), Color("292b2b"), Color("a74335")], "song": {"cue": &"bird.great_spotted_woodpecker.call", "kind": &"sharp_kik_and_drumming", "time": &"day", "cadence_s": Vector2(7.0, 18.0)}, "abundance": 0.60},
}


static func is_known_species(species: StringName) -> bool:
	return species in ALL_SPECIES


static func is_known_group(group: StringName) -> bool:
	return group in ALL_GROUPS


static func is_known_pose(pose: StringName) -> bool:
	return pose in ALL_POSES


static func id_for(species: StringName) -> StringName:
	if not is_known_species(species):
		return &""
	return StringName("bird.%s" % species)


static func is_known_id(bird_id: StringName) -> bool:
	return not parse_variant(bird_id).is_empty()


## Accepted authoring forms are bird.<species> and bird.<species>.<pose>.
static func parse_variant(variant: StringName) -> Dictionary:
	var parts := String(variant).split(".")
	if parts.size() < 2 or parts.size() > 3 or parts[0] != "bird":
		return {}
	var species := StringName(parts[1])
	if not is_known_species(species):
		return {}
	var pose := default_pose(species)
	if parts.size() == 3:
		pose = StringName(parts[2])
		if not is_known_pose(pose):
			return {}
	return {"species": species, "pose": pose}


static func profile_for(species: StringName) -> Dictionary:
	if not is_known_species(species):
		return {}
	return (PROFILES[species] as Dictionary).duplicate(true)


static func common_name(species: StringName) -> String:
	return String(PROFILES.get(species, {}).get("name", String(species)))


static func group_for(species: StringName) -> StringName:
	return StringName(PROFILES.get(species, {}).get("group", &""))


static func default_pose(species: StringName) -> StringName:
	return StringName(PROFILES.get(species, {}).get("pose", POSE_PERCHED))


static func scale_m(species: StringName) -> float:
	return float(PROFILES.get(species, {}).get("scale_m", 0.2))


static func geometry_for(species: StringName) -> Dictionary:
	var group := group_for(species)
	if not GROUP_GEOMETRY.has(group):
		return {}
	var geometry := (GROUP_GEOMETRY[group] as Dictionary).duplicate()
	var overrides: Dictionary = PROFILES[species].get("geometry", {})
	geometry.merge(overrides, true)
	geometry["scale_m"] = scale_m(species)
	return geometry


static func colors_for(species: StringName) -> Array[Color]:
	var source: Array = PROFILES.get(species, {}).get("colors", [Color.GRAY, Color.DARK_GRAY, Color.BEIGE])
	var colors: Array[Color] = []
	for color: Variant in source:
		colors.append(color as Color)
	return colors


static func song_profile_for(species: StringName) -> Dictionary:
	if not is_known_species(species):
		return {}
	return (PROFILES[species].get("song", {}) as Dictionary).duplicate(true)


static func spawn_weights_for(species: StringName) -> Dictionary:
	var group := group_for(species)
	if not GROUP_SPAWN_WEIGHTS.has(group):
		return {}
	var abundance := float(PROFILES[species].get("abundance", 1.0))
	var weights: Dictionary = {}
	for context in ALL_CONTEXTS:
		weights[context] = clampf(float(GROUP_SPAWN_WEIGHTS[group].get(context, 0.0)) * abundance, 0.0, 1.0)
	var overrides: Dictionary = PROFILES[species].get("spawn", {})
	for context: Variant in overrides:
		if context in ALL_CONTEXTS:
			weights[context] = clampf(float(overrides[context]), 0.0, 1.0)
	return weights


static func spawn_weight(species: StringName, context: StringName) -> float:
	return float(spawn_weights_for(species).get(context, 0.0))
