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
	&"oleviste_church": "St. Olaf's Church",
	&"holy_spirit_church": "Holy Spirit Church",
	&"town_hall": "Town Hall",
	&"viru_gate_foreland": "Pirita",
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
	&"city_kalev_smithy": "Kalev's Smithy",
	&"city_forum": "Town Hall Square",
	&"city_viru_gate": "Viru Gate",
	&"city_viru_outside": "Beyond Viru Gate",
	&"city_karja_outside": "Beyond Karja Gate",
	&"city_harju_outside": "Beyond Harju Gate",
	&"city_coastal_gate": "Coastal Gate",
	&"city_fish_landing": "Fish Landing",
	&"city_pikk_granary": "Pikk Granary",
	&"city_st_olaf": "St. Olaf's Church",
	&"city_st_nicholas": "St. Nicholas' Church",
	&"city_toompea_road": "Toompea Road",
	&"city_castle_barracks": "Castle Barracks",
	&"city_bishop_garden": "Archbishop's Garden",
	&"city_kalarand": "Kalamaja",
	&"reval_east": "Workers' District",
	&"reval_center": "Central District",
	&"reval_north": "Merchant District",
	&"reval_monastery": "Monastery District",
	&"reval_south": "Knights District",
	&"reval_toompea": "Toompea",
	&"reval_archbishops_garden": "Archbishop's Garden",
	&"st_olafs_guild_hall": "St. Olaf's Guild Hall",
	&"oleviste_church": "St. Olaf's Church",
	&"holy_spirit_church": "Holy Spirit Church",
	&"town_hall": "Town Hall",
	&"viru_gate_foreland": "Pirita",
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
	&"world_rakvere": "Rakvere Castle",
	&"world_haapsalu": "Haapsalu Castle",
	&"world_lihula": "Lihula Castle",
	&"world_tartu": "Dorpat Castle",
	&"world_viljandi": "Viljandi Castle",
	&"world_poltsamaa": "Põltsamaa Castle",
	&"world_narva": "Narva Castle",
	&"world_karksi": "Karksi-Nuia",
	&"world_helme": "Helme Castle",
	&"world_maasilinna": "Maasilinna Castle",
	&"world_karja": "Karja Fortress",
	&"world_klint": "Baltic Klint Coast",
	&"world_soomaa": "Soomaa Flood Refuge",
	&"world_frontier_ugandi": "Otepää - Vastseliina Frontier",
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
