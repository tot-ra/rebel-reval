class_name MapAuditRegistry
extends RefCounted

## One executable inventory for every declarative map package. The registry owns no
## geometry; it only calls the existing factories so the final audit cannot silently
## omit a converted or inactive verification map.

const SmithyCourtyard := preload("res://scripts/map/smithy_courtyard_definition.gd")
const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MarketCivicQuarter := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd")
const StOlafsGuildHall := preload("res://scripts/map/definitions/prototypes/st_olafs_guild_hall_definition.gd")
const NorthQuarter := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const MonasteryQuarter := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")
const ArchbishopsGarden := preload("res://scripts/map/definitions/prototypes/archbishops_garden_definition.gd")
const ToompeaQuarter := preload("res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd")
const SouthQuarter := preload("res://scripts/map/definitions/prototypes/south_quarter_definition.gd")
const HarborWarehouse := preload("res://scripts/map/definitions/prototypes/harbor_warehouse_definition.gd")
const RevalHarborNorth := preload("res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd")
const RevalHarborEast := preload("res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd")
const Coast := preload("res://scripts/map/definitions/outdoor/coast_harbor_definitions.gd")
const Villages := preload("res://scripts/map/definitions/outdoor/village_monastery_definitions.gd")
const Castles := preload("res://scripts/map/definitions/outdoor/castle_definitions.gd")
const Wilderness := preload("res://scripts/map/definitions/outdoor/wilderness_event_definitions.gd")


static func all() -> Array[MapDefinition]:
	var definitions: Array[MapDefinition] = [
		SmithyCourtyard.create(),
		KalevSmithy.create(),
		LowerTownSlice.create(),
		MarketCivicQuarter.create(),
		StOlafsGuildHall.create(),
		NorthQuarter.create(),
		MonasteryQuarter.create(),
		ArchbishopsGarden.create(),
		ToompeaQuarter.create(),
		SouthQuarter.create(),
		HarborWarehouse.create(),
		RevalHarborNorth.create(),
		RevalHarborEast.create(),
	]
	definitions.append_array(Coast.all())
	definitions.append_array(Villages.all())
	definitions.append_array(Castles.all())
	definitions.append_array(Wilderness.all())
	return definitions


static func by_id() -> Dictionary:
	var result: Dictionary = {}
	for definition in all():
		result[String(definition.map_id)] = definition
	return result
