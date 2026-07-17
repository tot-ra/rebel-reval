class_name ItemCarryProfile
extends RefCounted

const DEFAULTS_BY_CATEGORY := {
	"weapon": {"grid_width": 2, "grid_height": 2, "weight_g": 4000},
	"evidence": {"grid_width": 1, "grid_height": 1, "weight_g": 250},
	"commission_object": {"grid_width": 1, "grid_height": 2, "weight_g": 1200},
	"material": {"grid_width": 1, "grid_height": 1, "weight_g": 1800},
	"supply": {"grid_width": 1, "grid_height": 1, "weight_g": 400},
	"quest_tool": {"grid_width": 1, "grid_height": 2, "weight_g": 1500},
}

const MAX_STACK_SIZE := 20

var grid_width: int = 1
var grid_height: int = 1
var weight_kg: float = 0.5
var stackable: bool = false


static func from_content_record(record: Dictionary) -> ItemCarryProfile:
	var profile := ItemCarryProfile.new()
	var category := String(record.get("category", "supply"))
	var defaults: Dictionary = DEFAULTS_BY_CATEGORY.get(category, DEFAULTS_BY_CATEGORY["supply"])
	var gameplay: Dictionary = record.get("gameplay", {})
	var carry: Dictionary = gameplay.get("carry", {})

	profile.grid_width = maxi(1, int(carry.get("grid_width", defaults["grid_width"])))
	profile.grid_height = maxi(1, int(carry.get("grid_height", defaults["grid_height"])))
	var weight_g := int(carry.get("weight_g", defaults["weight_g"]))
	profile.weight_kg = maxf(0.05, float(weight_g) / 1000.0)
	profile.stackable = bool(gameplay.get("stackable", false))
	return profile


static func fallback(item_id: StringName) -> ItemCarryProfile:
	var profile := ItemCarryProfile.new()
	profile.grid_width = 1
	profile.grid_height = 1
	profile.weight_kg = 0.5
	profile.stackable = false
	if String(item_id).contains("hammer"):
		profile.grid_width = 2
		profile.grid_height = 2
		profile.weight_kg = 4.5
	return profile


func cell_count() -> int:
	return grid_width * grid_height


func total_weight(quantity: int) -> float:
	return weight_kg * maxi(1, quantity)
