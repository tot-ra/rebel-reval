class_name MapViewPlantSpecies
extends RefCounted

## Concrete north-Baltic herbs, wetland plants, and food/fibre crops. Generic
## grass.* variants remain terrain-cover styles; entries here are botanical
## species with their own cached procedural mesh profile.

const ARCHETYPE_HERB := &"herb"
const ARCHETYPE_ROSETTE := &"rosette"
const ARCHETYPE_FLOWER := &"flower"
const ARCHETYPE_BROAD := &"broad"
const ARCHETYPE_FROND := &"frond"
const ARCHETYPE_MOSS := &"moss"
const ARCHETYPE_REED := &"reed"
const ARCHETYPE_CATTAIL := &"cattail"
const ARCHETYPE_AQUATIC := &"aquatic"
const ARCHETYPE_CEREAL := &"cereal"
const ARCHETYPE_STALK := &"stalk"
const ARCHETYPE_VINE := &"vine"

const SPECIES_NETTLE := &"nettle"
const SPECIES_MUGWORT := &"mugwort"
const SPECIES_YARROW := &"yarrow"
const SPECIES_PLANTAIN := &"plantain"
const SPECIES_DANDELION := &"dandelion"
const SPECIES_BURDOCK := &"burdock"
const SPECIES_THISTLE := &"thistle"
const SPECIES_CLOVER := &"clover"
const SPECIES_FERN := &"fern"
const SPECIES_MOSS := &"moss"
const SPECIES_REED := &"reed"
const SPECIES_CATTAIL := &"cattail"
const SPECIES_WATER_LILY := &"water_lily"
const SPECIES_CABBAGE := &"cabbage"
const SPECIES_TURNIP := &"turnip"
const SPECIES_ONION := &"onion"
const SPECIES_GARLIC := &"garlic"
const SPECIES_PEA := &"pea"
const SPECIES_BROAD_BEAN := &"broad_bean"
const SPECIES_RYE := &"rye"
const SPECIES_WHEAT := &"wheat"
const SPECIES_BARLEY := &"barley"
const SPECIES_OAT := &"oat"
const SPECIES_FLAX := &"flax"
const SPECIES_HEMP := &"hemp"
const SPECIES_HOPS := &"hops"
const SPECIES_MINT := &"mint"
const SPECIES_CARAWAY := &"caraway"
const SPECIES_CHAMOMILE := &"chamomile"
const SPECIES_ST_JOHNS_WORT := &"st_johns_wort"

const ALL_SPECIES: Array[StringName] = [
	SPECIES_NETTLE, SPECIES_MUGWORT, SPECIES_YARROW, SPECIES_PLANTAIN,
	SPECIES_DANDELION, SPECIES_BURDOCK, SPECIES_THISTLE, SPECIES_CLOVER,
	SPECIES_FERN, SPECIES_MOSS, SPECIES_REED, SPECIES_CATTAIL,
	SPECIES_WATER_LILY, SPECIES_CABBAGE, SPECIES_TURNIP, SPECIES_ONION,
	SPECIES_GARLIC, SPECIES_PEA, SPECIES_BROAD_BEAN, SPECIES_RYE,
	SPECIES_WHEAT, SPECIES_BARLEY, SPECIES_OAT, SPECIES_FLAX,
	SPECIES_HEMP, SPECIES_HOPS, SPECIES_MINT, SPECIES_CARAWAY,
	SPECIES_CHAMOMILE, SPECIES_ST_JOHNS_WORT,
]

const ALL_VARIANTS: Array[StringName] = [
	&"plant.nettle", &"plant.mugwort", &"plant.yarrow", &"plant.plantain",
	&"plant.dandelion", &"plant.burdock", &"plant.thistle", &"plant.clover",
	&"plant.fern", &"plant.moss", &"plant.reed", &"plant.cattail",
	&"plant.water_lily", &"crop.cabbage", &"crop.turnip", &"crop.onion",
	&"crop.garlic", &"crop.pea", &"crop.broad_bean", &"crop.rye",
	&"crop.wheat", &"crop.barley", &"crop.oat", &"crop.flax",
	&"crop.hemp", &"crop.hops", &"plant.mint", &"plant.caraway",
	&"plant.chamomile", &"plant.st_johns_wort",
]

## Profiles alter actual geometry, not only tint. Height/spread/stem differences
## keep related species recognizable while sharing a small set of mesh builders.
const PROFILES: Dictionary = {
	SPECIES_NETTLE: {"archetype": ARCHETYPE_HERB, "height": 0.72, "spread": 0.24, "stems": 5, "density": 0.34, "color": Color(0.30, 0.66, 0.24), "accent": Color(0.62, 0.82, 0.44)},
	SPECIES_MUGWORT: {"archetype": ARCHETYPE_HERB, "height": 0.64, "spread": 0.30, "stems": 6, "density": 0.30, "color": Color(0.48, 0.66, 0.42), "accent": Color(0.70, 0.76, 0.58)},
	SPECIES_YARROW: {"archetype": ARCHETYPE_FLOWER, "height": 0.62, "spread": 0.26, "stems": 5, "density": 0.30, "color": Color(0.38, 0.68, 0.30), "accent": Color(0.94, 0.91, 0.72)},
	SPECIES_PLANTAIN: {"archetype": ARCHETYPE_ROSETTE, "height": 0.28, "spread": 0.34, "stems": 7, "density": 0.35, "color": Color(0.36, 0.62, 0.28), "accent": Color(0.38, 0.30, 0.18)},
	SPECIES_DANDELION: {"archetype": ARCHETYPE_FLOWER, "height": 0.34, "spread": 0.30, "stems": 4, "density": 0.34, "color": Color(0.40, 0.70, 0.28), "accent": Color(1.00, 0.78, 0.08)},
	SPECIES_BURDOCK: {"archetype": ARCHETYPE_BROAD, "height": 0.72, "spread": 0.54, "stems": 6, "density": 0.25, "color": Color(0.30, 0.58, 0.26), "accent": Color(0.58, 0.30, 0.55)},
	SPECIES_THISTLE: {"archetype": ARCHETYPE_FLOWER, "height": 0.86, "spread": 0.30, "stems": 4, "density": 0.24, "color": Color(0.36, 0.58, 0.30), "accent": Color(0.68, 0.36, 0.72)},
	SPECIES_CLOVER: {"archetype": ARCHETYPE_ROSETTE, "height": 0.20, "spread": 0.32, "stems": 9, "density": 0.48, "color": Color(0.42, 0.76, 0.32), "accent": Color(0.90, 0.82, 0.88)},
	SPECIES_FERN: {"archetype": ARCHETYPE_FROND, "height": 0.48, "spread": 0.52, "stems": 7, "density": 0.38, "color": Color(0.24, 0.58, 0.24), "accent": Color(0.44, 0.70, 0.34)},
	SPECIES_MOSS: {"archetype": ARCHETYPE_MOSS, "height": 0.10, "spread": 0.42, "stems": 9, "density": 0.54, "color": Color(0.32, 0.56, 0.28), "accent": Color(0.50, 0.64, 0.32)},
	SPECIES_REED: {"archetype": ARCHETYPE_REED, "height": 1.12, "spread": 0.24, "stems": 7, "density": 0.42, "color": Color(0.56, 0.72, 0.34), "accent": Color(0.74, 0.66, 0.34)},
	SPECIES_CATTAIL: {"archetype": ARCHETYPE_CATTAIL, "height": 1.02, "spread": 0.30, "stems": 5, "density": 0.38, "color": Color(0.42, 0.68, 0.32), "accent": Color(0.30, 0.16, 0.08)},
	SPECIES_WATER_LILY: {"archetype": ARCHETYPE_AQUATIC, "height": 0.12, "spread": 0.56, "stems": 5, "density": 0.32, "color": Color(0.28, 0.58, 0.30), "accent": Color(0.96, 0.90, 0.82)},
	SPECIES_CABBAGE: {"archetype": ARCHETYPE_BROAD, "height": 0.46, "spread": 0.58, "stems": 10, "density": 0.40, "color": Color(0.48, 0.68, 0.38), "accent": Color(0.68, 0.78, 0.54)},
	SPECIES_TURNIP: {"archetype": ARCHETYPE_ROSETTE, "height": 0.42, "spread": 0.42, "stems": 8, "density": 0.40, "color": Color(0.42, 0.70, 0.32), "accent": Color(0.76, 0.64, 0.78)},
	SPECIES_ONION: {"archetype": ARCHETYPE_STALK, "height": 0.54, "spread": 0.18, "stems": 7, "density": 0.46, "color": Color(0.38, 0.66, 0.34), "accent": Color(0.84, 0.82, 0.72)},
	SPECIES_GARLIC: {"archetype": ARCHETYPE_STALK, "height": 0.48, "spread": 0.20, "stems": 6, "density": 0.44, "color": Color(0.46, 0.70, 0.38), "accent": Color(0.84, 0.76, 0.86)},
	SPECIES_PEA: {"archetype": ARCHETYPE_VINE, "height": 0.78, "spread": 0.34, "stems": 6, "density": 0.38, "color": Color(0.38, 0.70, 0.30), "accent": Color(0.82, 0.82, 0.92)},
	SPECIES_BROAD_BEAN: {"archetype": ARCHETYPE_HERB, "height": 0.82, "spread": 0.32, "stems": 5, "density": 0.36, "color": Color(0.34, 0.66, 0.30), "accent": Color(0.82, 0.76, 0.88)},
	SPECIES_RYE: {"archetype": ARCHETYPE_CEREAL, "height": 1.12, "spread": 0.24, "stems": 8, "density": 0.50, "color": Color(0.64, 0.70, 0.34), "accent": Color(0.72, 0.62, 0.28)},
	SPECIES_WHEAT: {"archetype": ARCHETYPE_CEREAL, "height": 0.94, "spread": 0.26, "stems": 9, "density": 0.52, "color": Color(0.76, 0.70, 0.34), "accent": Color(0.86, 0.68, 0.26)},
	SPECIES_BARLEY: {"archetype": ARCHETYPE_CEREAL, "height": 0.88, "spread": 0.30, "stems": 8, "density": 0.50, "color": Color(0.70, 0.72, 0.36), "accent": Color(0.82, 0.72, 0.30)},
	SPECIES_OAT: {"archetype": ARCHETYPE_CEREAL, "height": 1.00, "spread": 0.34, "stems": 7, "density": 0.46, "color": Color(0.58, 0.70, 0.36), "accent": Color(0.78, 0.72, 0.44)},
	SPECIES_FLAX: {"archetype": ARCHETYPE_FLOWER, "height": 0.72, "spread": 0.24, "stems": 7, "density": 0.46, "color": Color(0.34, 0.64, 0.32), "accent": Color(0.42, 0.60, 0.92)},
	SPECIES_HEMP: {"archetype": ARCHETYPE_STALK, "height": 1.18, "spread": 0.34, "stems": 6, "density": 0.38, "color": Color(0.28, 0.60, 0.28), "accent": Color(0.48, 0.68, 0.36)},
	SPECIES_HOPS: {"archetype": ARCHETYPE_VINE, "height": 1.20, "spread": 0.38, "stems": 7, "density": 0.34, "color": Color(0.32, 0.64, 0.28), "accent": Color(0.66, 0.72, 0.34)},
	SPECIES_MINT: {"archetype": ARCHETYPE_HERB, "height": 0.46, "spread": 0.34, "stems": 7, "density": 0.42, "color": Color(0.34, 0.72, 0.42), "accent": Color(0.68, 0.52, 0.78)},
	SPECIES_CARAWAY: {"archetype": ARCHETYPE_FLOWER, "height": 0.66, "spread": 0.28, "stems": 6, "density": 0.34, "color": Color(0.38, 0.66, 0.34), "accent": Color(0.92, 0.88, 0.74)},
	SPECIES_CHAMOMILE: {"archetype": ARCHETYPE_FLOWER, "height": 0.34, "spread": 0.34, "stems": 7, "density": 0.44, "color": Color(0.42, 0.68, 0.32), "accent": Color(0.96, 0.94, 0.82)},
	SPECIES_ST_JOHNS_WORT: {"archetype": ARCHETYPE_FLOWER, "height": 0.58, "spread": 0.30, "stems": 6, "density": 0.34, "color": Color(0.38, 0.66, 0.30), "accent": Color(0.96, 0.76, 0.16)},
}


static func is_known_species(species: StringName) -> bool:
	return species in ALL_SPECIES


static func is_known_variant(variant: StringName) -> bool:
	return variant in ALL_VARIANTS


static func parse_variant(variant: StringName) -> Dictionary:
	if not is_known_variant(variant):
		return {}
	var parts := String(variant).split(".")
	return {
		"category": StringName(parts[0]),
		"species": StringName(parts[1]),
	}


static func profile_for(species: StringName) -> Dictionary:
	return (PROFILES.get(species, PROFILES[SPECIES_NETTLE]) as Dictionary).duplicate()


static func scale_range(species: StringName) -> Vector2:
	var profile := profile_for(species)
	var height := float(profile.get("height", 0.5))
	# Meshes are authored at their profile height. Small scale variation prevents
	# cloned rows without erasing the meaningful inter-species proportions.
	return Vector2(0.88, 1.12) if height < 1.0 else Vector2(0.84, 1.08)


static func scatter_density(species: StringName) -> float:
	return float(profile_for(species).get("density", 0.32))


static func instance_tint(_species: StringName, roll: float) -> Color:
	var shade := lerpf(0.88, 1.10, roll)
	return Color(shade, shade, shade)
