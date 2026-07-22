class_name LocationHud
extends CanvasLayer

## Location display names for map HUD. The visible label now lives under MinimapHud;
## this class keeps the curated naming table and humanized fallbacks.
const DISPLAY_NAMES_BY_MAP: Dictionary = {
	&"lower_town_slice": "Workers' District",
	&"kalev_smithy": "Kalev's Smithy",
	&"market_civic_quarter": "Central District",
	&"north_quarter": "Merchant District",
	&"monastery_quarter": "Monastery District",
	&"south_quarter": "Knights District",
	&"toompea_quarter": "Toompea",
	&"archbishops_garden": "Archbishop's Garden",
	&"st_olafs_guild_hall": "St. Olaf's Guild Hall",
	&"viru_gate_foreland": "Viru Gate Foreland",
	&"reval_harbor_north": "Coastal Gate Landing",
	&"reval_harbor_east": "Kalamaja Fishing Shore",
	&"reval_harbor": "Reval Harbour",
	&"harbor_warehouse": "Harbour Warehouse",
	&"world.sacred_grove": "Sacred Grove",
	&"world.harju": "Harju Village",
	&"world.padise": "Padise Monastery",
	&"world.saaremaa": "Saaremaa",
	&"world.rebel_kings": "Rebel Kings' Camp",
	&"world.kanavere": "Kanavere Bog",
	&"world.sojamae": "Sõjamäe",
	&"world.paide": "Paide Castle",
	&"world.parnu": "Pärnu",
	&"world.poide": "Pöide Castle",
}

## Transition-manifest scene IDs (DoorNavigator) mapped to the same curated labels.
const DISPLAY_NAMES_BY_SCENE: Dictionary = {
	&"forge": "Kalev's Smithy",
	&"reval_east": "Workers' District",
	&"reval_center": "Central District",
	&"reval_north": "Merchant District",
	&"reval_monastery": "Monastery District",
	&"reval_south": "Knights District",
	&"reval_toompea": "Toompea",
	&"reval_archbishops_garden": "Archbishop's Garden",
	&"st_olafs_guild_hall": "St. Olaf's Guild Hall",
	&"viru_gate_foreland": "Viru Gate Foreland",
	&"reval_harbor_north": "Coastal Gate Landing",
	&"reval_harbor_east": "Kalamaja Fishing Shore",
	&"reval_harbor": "Reval Harbour",
	&"harbor_warehouse": "Harbour Warehouse",
	&"world_sacred_grove": "Sacred Grove",
	&"world_harju": "Harju Village",
	&"world_padise": "Padise Monastery",
	&"world_saaremaa": "Saaremaa",
	&"world_rebel_kings": "Rebel Kings' Camp",
	&"world_kanavere": "Kanavere Bog",
	&"world_sojamae": "Sõjamäe",
	&"world_paide": "Paide Castle",
	&"world_parnu": "Pärnu",
	&"world_poide": "Pöide Castle",
}


func configure(definition: MapDefinition) -> void:
	var location_label := get_node("LocationLabel") as Label
	location_label.text = display_name_for(definition)
	location_label.visible = not location_label.text.is_empty()


static func display_name_for(definition: MapDefinition) -> String:
	if definition == null:
		return ""

	var authored_name := String(DISPLAY_NAMES_BY_MAP.get(definition.map_id, ""))
	if not authored_name.is_empty():
		return authored_name

	# Prototype and future maps still get a useful label until a curated HUD name
	# is added above. Map IDs are preferred because they describe the current scene.
	return _humanize_id(definition.map_id)


static func display_name_for_scene(scene_id: StringName) -> String:
	var authored_name := String(DISPLAY_NAMES_BY_SCENE.get(scene_id, ""))
	if not authored_name.is_empty():
		return authored_name
	return _humanize_id(scene_id)


static func _humanize_id(value: StringName) -> String:
	var words := String(value).trim_prefix("prototype.").replace("_", " ").split(" ", false)
	for index in words.size():
		words[index] = words[index].capitalize()
	return " ".join(words)
