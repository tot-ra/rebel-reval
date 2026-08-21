class_name MapViewMeshBuilderBuildingRegistry
extends RefCounted

## Renderer boundary for authored buildings that are landmarks or institutions.
## The registry is deliberately metadata-only: collision, navigation, and stable
## definition records remain owned by the map/compiler layers.

const EXCEPTIONAL_IDS := {
	&"town_hall_mass": &"civic",
	&"church_silhouette": &"church",
	&"holy_spirit_hospital": &"institutional",
	&"guild_frontage": &"guild",
	&"st_catherines_church": &"church",
	&"st_olaf_silhouette": &"church",
	&"cathedral_silhouette": &"church",
	&"viru_gate_north_tower": &"gatehouse",
	&"viru_gate_south_tower": &"gatehouse",
}

const EXCEPTIONAL_STYLES := {
	&"house.town_hall": &"civic",
	&"house.church": &"church",
	&"house.cathedral": &"church",
	&"house.guild": &"guild",
	&"house.gatehouse": &"gatehouse",
	&"house.hospital": &"institutional",
	&"house.convent.precinct": &"monastic_precinct",
}

const EXCEPTIONAL_PRIMITIVES := {
	&"town_hall_1343": &"civic",
	&"holy_spirit_chapel_1343": &"church",
	&"stone_church": &"church",
	&"stone_hall": &"hall",
	&"monastic_range": &"hall",
	&"st_michaels_precinct_1343": &"monastic_precinct",
	&"st_michaels_chapel_1343": &"monastic_precinct",
	&"st_michaels_service_wing_1343": &"monastic_precinct",
	&"gatehouse": &"gatehouse",
}


static func exceptional_category(building: Dictionary) -> StringName:
	# Only house records cross this boundary. Wall records may have similar
	# historical names, but they must retain the fortification renderer.
	if (
		StringName(String(building.get("kind", MapTypes.BUILDING_KIND_HOUSE)))
		!= MapTypes.BUILDING_KIND_HOUSE
	):
		return &""
	var building_id := StringName(String(building.get("id", "")))
	if EXCEPTIONAL_IDS.has(building_id):
		return EXCEPTIONAL_IDS[building_id]
	var style := StringName(String(building.get("style", "")))
	if EXCEPTIONAL_STYLES.has(style):
		return EXCEPTIONAL_STYLES[style]
	var primitive := StringName(String(building.get("primitive", "")))
	if EXCEPTIONAL_PRIMITIVES.has(primitive):
		return EXCEPTIONAL_PRIMITIVES[primitive]
	return &""


static func is_exceptional(building: Dictionary) -> bool:
	return not exceptional_category(building).is_empty()
