class_name MapCatalog
extends RefCounted

const MAPS: Dictionary = {
	"forge":
	{"path": "res://scenes/reval_east/forge/forge.tscn", "scope": "production", "active": true},
	"world_kanavere":
	{
		"path": "res://scenes/world_travel/world_kanavere.tscn",
		"scope": "prototype",
		"active": false
	},
	"world_sojamae":
	{"path": "res://scenes/world_travel/world_sojamae.tscn", "scope": "prototype", "active": false},
	"world_parnu":
	{"path": "res://scenes/world_travel/world_parnu.tscn", "scope": "prototype", "active": false},
	"world_poide":
	{"path": "res://scenes/world_travel/world_poide.tscn", "scope": "prototype", "active": false},
	"world_rakvere":
	{"path": "res://scenes/world_travel/world_rakvere.tscn", "scope": "prototype", "active": false},
	"world_haapsalu":
	{"path": "res://scenes/world_travel/world_haapsalu.tscn", "scope": "prototype", "active": false},
	"world_lihula":
	{"path": "res://scenes/world_travel/world_lihula.tscn", "scope": "prototype", "active": false},
	"world_tartu":
	{"path": "res://scenes/world_travel/world_tartu.tscn", "scope": "prototype", "active": false},
	"world_viljandi":
	{"path": "res://scenes/world_travel/world_viljandi.tscn", "scope": "prototype", "active": false},
	"world_poltsamaa":
	{
		"path": "res://scenes/world_travel/world_poltsamaa.tscn",
		"scope": "prototype",
		"active": false
	},
	"world_narva":
	{"path": "res://scenes/world_travel/world_narva.tscn", "scope": "prototype", "active": false},
	"world_karksi":
	{"path": "res://scenes/world_travel/world_karksi.tscn", "scope": "prototype", "active": false},
	"world_helme":
	{"path": "res://scenes/world_travel/world_helme.tscn", "scope": "prototype", "active": false},
	"world_maasilinna":
	{
		"path": "res://scenes/world_travel/world_maasilinna.tscn",
		"scope": "prototype",
		"active": false
	},
	"world_karja":
	{"path": "res://scenes/world_travel/world_karja.tscn", "scope": "prototype", "active": false},
	"world_klint":
	{"path": "res://scenes/world_travel/world_klint.tscn", "scope": "prototype", "active": false},
	"world_soomaa":
	{"path": "res://scenes/world_travel/world_soomaa.tscn", "scope": "prototype", "active": false},
	"world_frontier_ugandi":
	{
		"path": "res://scenes/world_travel/world_frontier_ugandi.tscn",
		"scope": "prototype",
		"active": false
	}
}


static func get_map(id: String) -> Dictionary:
	return MAPS.get(id, {})


static func is_active(id: String) -> bool:
	var m = get_map(id)
	return m.get("active", false)


static func get_scope(id: String) -> String:
	var m = get_map(id)
	return m.get("scope", "")
