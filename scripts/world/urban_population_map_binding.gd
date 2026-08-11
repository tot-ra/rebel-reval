class_name UrbanPopulationMapBinding
extends RefCounted

## Deterministic bridge from authored map anchors to urban population records.
## WHY: UrbanPopulationProfile intentionally knows nothing about a concrete map;
## this adapter keeps Lower Town's stable cluster vocabulary at the map boundary
## without spawning actors, mutating GameState, or coupling the profile to rendering.

const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")
const MapVerificationScript := preload("res://scripts/map/map_verification.gd")

const LOWER_TOWN_MAP_ID := &"lower_town_slice"
const CLUSTER_WORKERS := &"workers_carriers"
const CLUSTER_MERCHANTS := &"merchants_customers"
const CLUSTER_WATCH := &"watch_checkpoint"

const _CLUSTER_SPECS: Array[Dictionary] = [
	{
		"cluster_id": CLUSTER_WORKERS,
		"zone_ids": [ProfileScript.ZONE_WORK_YARD, ProfileScript.ZONE_RESIDENTIAL],
		"anchor_ids":
		[
			&"workers_yard",
			&"carriers_lane",
			&"smithy_door",
			&"brewery_door",
			&"street_start",
		],
	},
	{
		"cluster_id": CLUSTER_MERCHANTS,
		"zone_ids": [ProfileScript.ZONE_MARKET, ProfileScript.ZONE_STREET],
		"anchor_ids": [&"merchants_market", &"customers_street", &"mart_street", &"street_start"],
	},
	{
		"cluster_id": CLUSTER_WATCH,
		"zone_ids":
		[
			ProfileScript.ZONE_CHECKPOINT,
			ProfileScript.ZONE_STREET,
			ProfileScript.ZONE_SAFE_INTERIOR
		],
		"anchor_ids":
		[
			&"watch_west_checkpoint",
			&"watch_east_checkpoint",
			&"checkpoint_west",
			&"checkpoint_east"
		],
	},
]


## Returns the authored Lower Town cluster records in canonical order.
## Missing or invalid anchors are omitted rather than replaced with guessed points.
## This makes an incomplete map fail closed while preserving deterministic lookup.
static func clusters_for_map(
	definition: MapDefinition, grid: MapTerrainGrid = null
) -> Array[Dictionary]:
	if definition == null or definition.map_id != LOWER_TOWN_MAP_ID:
		return []
	var present_anchors := _present_anchor_ids(definition, grid)
	var clusters: Array[Dictionary] = []
	for spec: Dictionary in _CLUSTER_SPECS:
		var anchor_ids: Array[StringName] = []
		for anchor_id: StringName in spec["anchor_ids"]:
			if present_anchors.has(anchor_id):
				anchor_ids.append(anchor_id)
		(
			clusters
			. append(
				{
					"cluster_id": spec["cluster_id"],
					"zone_ids": (spec["zone_ids"] as Array).duplicate(),
					"anchor_ids": anchor_ids,
				}
			)
		)
	return clusters


## Alias for callers that treat the map binding as a runtime lookup table.
static func lookup(definition: MapDefinition, grid: MapTerrainGrid = null) -> Array[Dictionary]:
	return clusters_for_map(definition, grid)


## Builds a complete lookup snapshot, including the stable zone and anchor indexes.
## The snapshot contains only copies, so callers cannot mutate the binding contract.
static func build_lookup(definition: MapDefinition, grid: MapTerrainGrid = null) -> Dictionary:
	if definition == null or definition.map_id != LOWER_TOWN_MAP_ID:
		return {
			"map_id": definition.map_id if definition != null else &"",
			"clusters": [],
			"clusters_by_id": {},
			"clusters_by_zone": {},
			"anchors_by_id": {},
		}
	var clusters := clusters_for_map(definition, grid)
	var clusters_by_id := {}
	var clusters_by_zone := {}
	var anchors_by_id := {}
	for anchor: Dictionary in definition.interaction_anchors:
		var anchor_id := StringName(anchor.get("id", &""))
		if not anchor_id.is_empty() and _anchor_is_valid(definition, grid, anchor_id):
			var anchor_position: Vector2 = anchor.get("position", Vector2.ZERO)
			anchors_by_id[anchor_id] = {
				"anchor_id": anchor_id,
				"anchor_position": anchor_position,
			}
	for cluster: Dictionary in clusters:
		var cluster_id: StringName = cluster["cluster_id"]
		clusters_by_id[cluster_id] = cluster.duplicate(true)
		for zone_id: StringName in cluster["zone_ids"]:
			if not clusters_by_zone.has(zone_id):
				clusters_by_zone[zone_id] = []
			(clusters_by_zone[zone_id] as Array).append(cluster_id)
	return {
		"map_id": definition.map_id,
		"clusters": clusters,
		"clusters_by_id": clusters_by_id,
		"clusters_by_zone": clusters_by_zone,
		"anchors_by_id": anchors_by_id,
	}


## Adds map-bound cluster and anchor fields to profile actor records.
## Actor order and anchor selection are derived from the existing actor index, so
## equal profile/map inputs replay the same result without random state.
static func bind_profile(
	profile: Dictionary, definition: MapDefinition, grid: MapTerrainGrid = null
) -> Array[Dictionary]:
	if definition == null or definition.map_id != LOWER_TOWN_MAP_ID:
		return []
	var clusters := clusters_for_map(definition, grid)
	var records: Array[Dictionary] = []
	var raw_records: Variant = profile.get("actor_plan", [])
	if not raw_records is Array:
		return records
	for raw_record: Variant in raw_records:
		if not raw_record is Dictionary:
			continue
		var record: Dictionary = (raw_record as Dictionary).duplicate(true)
		var cluster_id := cluster_id_for_actor(record, clusters)
		if cluster_id.is_empty():
			continue
		var anchor_ids := anchor_ids_for_cluster(cluster_id, clusters)
		if anchor_ids.is_empty():
			continue
		var actor_index := int(record.get("actor_index", records.size()))
		var anchor_id: StringName = &""
		if not anchor_ids.is_empty():
			anchor_id = anchor_ids[posmod(actor_index, anchor_ids.size())]
		record["cluster_id"] = cluster_id
		record["anchor_id"] = anchor_id
		record["anchor_position"] = (
			MapVerificationScript.anchor_position(definition, anchor_id)
			if not anchor_id.is_empty()
			else Vector2.ZERO
		)
		records.append(record)
	return records


## Finds the canonical cluster for an actor record.
## Role-specific matches win over overlapping street zones, avoiding the old test
## helper's accidental dependence on cluster array order.
static func cluster_id_for_actor(actor: Dictionary, clusters: Array[Dictionary]) -> StringName:
	var role := StringName(actor.get("role", &""))
	var occupation := StringName(actor.get("occupation", &""))
	var zone_id := StringName(actor.get("zone_id", &""))
	if role == &"watch":
		return _cluster_for_zone(CLUSTER_WATCH, zone_id, clusters)
	if occupation == &"merchant" or zone_id == ProfileScript.ZONE_MARKET:
		return _cluster_for_zone(CLUSTER_MERCHANTS, zone_id, clusters)
	if zone_id == ProfileScript.ZONE_CHECKPOINT or zone_id == ProfileScript.ZONE_SAFE_INTERIOR:
		return _cluster_for_zone(CLUSTER_WATCH, zone_id, clusters)
	return _cluster_for_zone(CLUSTER_WORKERS, zone_id, clusters)


static func anchor_ids_for_cluster(
	cluster_id: StringName, clusters: Array[Dictionary]
) -> Array[StringName]:
	for cluster: Dictionary in clusters:
		if cluster.get("cluster_id", &"") == cluster_id:
			var result: Array[StringName] = []
			for anchor_id: StringName in cluster.get("anchor_ids", []):
				result.append(anchor_id)
			return result
	return []


static func _cluster_for_zone(
	preferred_cluster: StringName, zone_id: StringName, clusters: Array[Dictionary]
) -> StringName:
	for cluster: Dictionary in clusters:
		if (
			cluster.get("cluster_id", &"") == preferred_cluster
			and (cluster.get("zone_ids", []) as Array).has(zone_id)
		):
			return preferred_cluster
	for cluster: Dictionary in clusters:
		if (cluster.get("zone_ids", []) as Array).has(zone_id):
			return cluster.get("cluster_id", &"")
	return &""


static func _present_anchor_ids(
	definition: MapDefinition, grid: MapTerrainGrid
) -> Array[StringName]:
	var present: Array[StringName] = []
	for anchor: Dictionary in definition.interaction_anchors:
		var anchor_id := StringName(anchor.get("id", &""))
		if anchor_id.is_empty() or not _anchor_is_valid(definition, grid, anchor_id):
			continue
		present.append(anchor_id)
	present.sort_custom(
		func(left: StringName, right: StringName) -> bool: return String(left) < String(right)
	)
	return present


static func _anchor_is_valid(
	definition: MapDefinition, grid: MapTerrainGrid, anchor_id: StringName
) -> bool:
	if definition == null or not MapVerificationScript.has_anchor(definition, anchor_id):
		return false
	if grid == null:
		return true
	return (
		MapVerificationScript
		. is_walkable_point(
			definition,
			grid,
			MapVerificationScript.anchor_position(definition, anchor_id),
		)
	)
