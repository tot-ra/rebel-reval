class_name CityHouseWealth
extends RefCounted

## Visual wealth tier of a plan building and the timber wall finish it gets
## (R-1659, docs/SYSTEMS/COTTAGE_WINDOWS.md). The tier comes from the census
## household living in the building; buildings without one fall back to a
## deterministic guess from size and fabric. Appearance only: nothing here is
## saved or read by gameplay.

const POOR := 0
const MIDDLING := 1
const RICH := 2
## Census household class -> tier (the same split as HouseholdLayout.TIER).
const CLASS_TIER := {"poor": POOR, "master": MIDDLING, "merchant": RICH, "great": RICH}
## Timber wall plates per family and tier, as weighted pools: a poor cottage is
## mostly silver-grey unprotected logs, a middling one fresh pine, a rich one
## tar-coated or kept-fresh timber. Stems live in the AR-03 surface library.
const WALL_STEMS := {
	&"log":
	[
		["logwall_weathered", "logwall_weathered", "logwall_weathered", "logwall_pine"],
		["logwall_pine", "logwall_pine", "logwall_weathered", "logwall_tar"],
		["logwall_tar", "logwall_tar", "logwall_pine"],
	],
	&"plank":
	[
		["plank_vertical", "plank_vertical", "plank_horizontal"],
		["plank_horizontal", "plank_horizontal", "plank_vertical", "plank_tarred"],
		["plank_tarred", "plank_tarred", "plank_horizontal"],
	],
}
## Weathering strength (rising damp, rain streaks) of each plate; tar keeps
## water out, grey logs have stood bare for decades.
const STEM_AGE := {
	"logwall_weathered": 1.35,
	"logwall_pine": 1.0,
	"logwall_tar": 0.7,
	"plank_vertical": 1.3,
	"plank_horizontal": 1.0,
	"plank_tarred": 0.7,
}
## Wall tint per plate, replacing the family's single brown: the plates carry
## their own colour, so silver-grey logs must not be browned back to pine.
const STEM_TINT := {
	"logwall_weathered": Color(0.8, 0.77, 0.72),
	"logwall_pine": Color(0.74, 0.6, 0.45),
	"logwall_tar": Color(0.55, 0.42, 0.32),
	"plank_vertical": Color(0.78, 0.74, 0.68),
	"plank_horizontal": Color(0.72, 0.6, 0.47),
	"plank_tarred": Color(0.55, 0.43, 0.33),
}
## Per-building tint hues: warm resinous, neutral, grey-silvered, smoke-browned.
const TIMBER_HUES: Array[Color] = [
	Color(1.04, 0.98, 0.9),
	Color(1.0, 1.0, 1.0),
	Color(0.94, 0.96, 0.98),
	Color(0.97, 0.93, 0.88),
]

static var _tiers: Dictionary = {}


## Census tiers of the plan's households, by plan building id.
static func bind(plan: CityPlan) -> void:
	var tiers := {}
	var roster := CitizenRoster.load_for(plan)
	for hh: String in roster.households:
		var household: Dictionary = roster.households[hh]
		tiers[String(household["building"])] = int(
			CLASS_TIER.get(String(household.get("class", "poor")), POOR)
		)
	bind_tiers(tiers)


static func bind_tiers(tiers: Dictionary) -> void:
	_tiers = tiers


static func clear() -> void:
	_tiers = {}


static func tier_of(b: Dictionary, ring: PackedVector2Array) -> int:
	var id := String(b["id"])
	if _tiers.has(id):
		return int(_tiers[id])
	if String(b.get("kind", "house")) == "outbuilding":
		return POOR
	if StringName(b.get("material", "")) == &"limestone":
		return RICH
	var area := absf(CityBuildingBuilder.signed_area(ring))
	if area >= 120.0:
		return RICH
	if area >= 65.0:
		return MIDDLING
	return absi(hash(id + ":wealth")) % 2


## Library stem of a timber wall, or "" for families that keep one plate.
static func wall_stem(b: Dictionary, family: StringName, tier: int) -> String:
	if not WALL_STEMS.has(family):
		return ""
	var pool: Array = WALL_STEMS[family][clampi(tier, POOR, RICH)]
	return pool[absi(hash(String(b["id"]) + ":wall")) % pool.size()]


## Vertex tint of a building's walls: the old brightness roll times a hue,
## seeded separately so the shared building RNG keeps its draw schedule.
static func wall_tint(b: Dictionary, brightness: Color) -> Color:
	var hue := TIMBER_HUES[absi(hash(String(b["id"]) + ":hue")) % TIMBER_HUES.size()]
	var tint := Color(brightness.r * hue.r, brightness.g * hue.g, brightness.b * hue.b)
	tint.a = 1.0
	return tint
