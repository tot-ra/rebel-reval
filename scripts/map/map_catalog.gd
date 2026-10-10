class_name MapCatalog
extends RefCounted

const MAPS: Dictionary = {
	"forge":
	{"path": "res://scenes/reval_east/forge/forge.tscn", "scope": "production", "active": true},
	"world_harju":
	{"path": "res://scenes/world_travel/world_harju.tscn", "scope": "prototype", "active": false},
	"world_padise":
	{"path": "res://scenes/world_travel/world_padise.tscn", "scope": "prototype", "active": false},
	"world_saaremaa":
	{
		"path": "res://scenes/world_travel/world_saaremaa.tscn",
		"scope": "prototype",
		"active": false
	},
	"world_rebel_kings":
	{
		"path": "res://scenes/world_travel/world_rebel_kings.tscn",
		"scope": "prototype",
		"active": false
	},
	"world_kanavere":
	{
		"path": "res://scenes/world_travel/world_kanavere.tscn",
		"scope": "prototype",
		"active": false
	},
	"world_sojamae":
	{"path": "res://scenes/world_travel/world_sojamae.tscn", "scope": "prototype", "active": false},
	"world_paide":
	{"path": "res://scenes/world_travel/world_paide.tscn", "scope": "prototype", "active": false},
	"world_parnu":
	{"path": "res://scenes/world_travel/world_parnu.tscn", "scope": "prototype", "active": false},
	"world_poide":
	{"path": "res://scenes/world_travel/world_poide.tscn", "scope": "prototype", "active": false}
}


static func get_map(id: String) -> Dictionary:
	return MAPS.get(id, {})


static func is_active(id: String) -> bool:
	var m = get_map(id)
	return m.get("active", false)


static func get_scope(id: String) -> String:
	var m = get_map(id)
	return m.get("scope", "")
