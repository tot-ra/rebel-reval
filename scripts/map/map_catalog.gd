class_name MapCatalog
extends RefCounted

const MAPS: Dictionary = {
	"forge": {
		"path": "res://scenes/reval_east/forge/forge.tscn",
		"scope": "production",
		"active": true
	},
	"reval_east": {
		"path": "res://scenes/reval_east/reval_east.tscn",
		"scope": "production",
		"active": true
	},
	"reval_center": {
		"path": "res://scenes/reval_center/reval_center.tscn",
		"scope": "prototype",
		"active": false
	},
	"reval_north": {
		"path": "res://scenes/reval_north/reval_north.tscn",
		"scope": "prototype",
		"active": false
	},
	"reval_monastery": {
		"path": "res://scenes/reval_monastery/reval_monastery.tscn",
		"scope": "prototype",
		"active": false
	},
	"reval_archbishops_garden": {
		"path": "res://scenes/reval_archbishops_garden/reval_archbishops_garden.tscn",
		"scope": "prototype",
		"active": false
	},
	"reval_toompea": {
		"path": "res://scenes/reval_toompea/reval_toompea.tscn",
		"scope": "prototype",
		"active": false
	},
	"reval_south": {
		"path": "res://scenes/reval_south/reval_south.tscn",
		"scope": "prototype",
		"active": false
	},
	"st_olafs_guild_hall": {
		"path": "res://scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn",
		"scope": "prototype",
		"active": false
	},
	"viru_gate_foreland": {
		"path": "res://scenes/reval_east/viru_gate_foreland/viru_gate_foreland.tscn",
		"scope": "prototype",
		"active": false
	},
	"reval_harbor_north": {
		"path": "res://scenes/harbor/harbor_north.tscn",
		"scope": "prototype",
		"active": false
	},
	"reval_harbor_east": {
		"path": "res://scenes/harbor/harbor_east.tscn",
		"scope": "prototype",
		"active": false
	},
	"reval_harbor": {
		"path": "res://scenes/harbor/harbor.tscn",
		"scope": "archive",
		"active": false
	},
	"harbor_warehouse": {
		"path": "res://scenes/harbor/warehouse.tscn",
		"scope": "archive",
		"active": false
	},
	"world_sacred_grove": {
		"path": "res://scenes/world_travel/world_sacred_grove.tscn",
		"scope": "prototype",
		"active": false
	},
	"world_harju": {
		"path": "res://scenes/world_travel/world_harju.tscn",
		"scope": "prototype",
		"active": false
	},
	"world_padise": {
		"path": "res://scenes/world_travel/world_padise.tscn",
		"scope": "prototype",
		"active": false
	},
	"world_saaremaa": {
		"path": "res://scenes/world_travel/world_saaremaa.tscn",
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
