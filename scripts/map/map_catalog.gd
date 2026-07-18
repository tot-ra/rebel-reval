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
	"reval_toompea": {
		"path": "res://scenes/reval_toompea/reval_toompea.tscn",
		"scope": "archive",
		"active": false
	},
	"market_civic_quarter": {
		"path": "res://scenes/reval_center/market_civic_quarter/market.tscn",
		"scope": "prototype",
		"active": false
	},
	"st_olafs_guild_hall": {
		"path": "res://scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn",
		"scope": "prototype",
		"active": false
	},
	"reval_harbor": {
		"path": "res://scenes/harbor/harbor.tscn",
		"scope": "prototype",
		"active": false
	},
	"harbor_warehouse": {
		"path": "res://scenes/harbor/warehouse.tscn",
		"scope": "archive",
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
