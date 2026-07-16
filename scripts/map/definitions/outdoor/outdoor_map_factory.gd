class_name OutdoorMapFactory
extends RefCounted

## Shared authoring factory for inactive outdoor prototypes. Location files provide
## composition only, so geometry, IDs, scope and fingerprints follow one contract.

const PALETTE := &"clean_painted_outdoor"
const INSPECTION_ROUTE := &"prototype_inspection_route"


static func create(spec: Dictionary) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = spec["map_id"]
	definition.location = spec["location"]
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = PALETTE
	definition.seed = int(spec.get("seed", MapTypes.DEFAULT_SEED + abs(String(spec["map_id"]).hash()) % 10000))
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = spec.get("size", Vector2i(50, 28))
	definition.base_terrain = spec.get("base", MapTypes.TERRAIN_MEADOW)
	definition.player_spawn = cell_center(definition, spec.get("spawn", Vector2i(3, 3)))
	definition.camera_bounds = definition.cell_rect_to_world_rect(Rect2i(Vector2i.ZERO, definition.size_cells))
	definition.source_references.assign(spec.get("sources", []))
	definition.zones.append_array(spec.get("zones", []))
	definition.excluded_areas.assign(spec.get("excluded", []))
	definition.set_meta("package", spec.get("package", &"outdoor"))
	definition.set_meta("phases", spec.get("phases", [&"default"]))
	definition.set_meta("canonical_phase", spec.get("canonical_phase", &"concept"))
	definition.set_meta("playable", false)
	definition.set_meta("inspection_spawn_id", &"prototype_inspection")

	for structure in spec.get("structures", []):
		definition.buildings.append(_structure(definition, structure))
	for prop in spec.get("props", []):
		definition.props.append(_prop(definition, prop))

	var route_points: Array[Vector2] = []
	for cell in spec.get("route", []):
		route_points.append(cell_center(definition, cell))
	definition.patrols.append({"id": INSPECTION_ROUTE, "points": route_points})

	for landmark in spec.get("landmarks", []):
		definition.interaction_anchors.append({
			"id": StringName("landmark_%s" % String(landmark["id"])),
			"position": cell_center(definition, landmark["cell"]),
			"kind": landmark.get("kind", &"landmark"),
		})

	definition.fingerprint = _fingerprint(definition)
	return definition


static func zone(terrain: StringName, rect: Rect2i) -> Dictionary:
	return {"terrain": terrain, "rect": rect}


static func structure(id: StringName, primitive: StringName, rect: Rect2i, height: float = 56.0) -> Dictionary:
	return {"id": id, "primitive": primitive, "rect": rect, "height": height}


static func prop(id: StringName, primitive: StringName, cell: Vector2i) -> Dictionary:
	return {"id": id, "primitive": primitive, "cell": cell}


static func landmark(id: StringName, kind: StringName, cell: Vector2i) -> Dictionary:
	return {"id": id, "kind": kind, "cell": cell}


static func cell_center(definition: MapDefinition, cell: Vector2i) -> Vector2:
	return definition.cell_rect_center(Rect2i(cell, Vector2i.ONE))


static func _structure(definition: MapDefinition, source: Dictionary) -> Dictionary:
	var primitive: StringName = source["primitive"]
	var wall_like := primitive in [&"wall", &"palisade", &"pier", &"bridge", &"ditch_edge"]
	return {
		"id": source["id"],
		"kind": MapTypes.BUILDING_KIND_WALL if wall_like else MapTypes.BUILDING_KIND_HOUSE,
		"primitive": primitive,
		"footprint": definition.cell_rect_to_world_rect(source["rect"]),
		"wall_height": float(source.get("height", 56.0)),
	}


static func _prop(definition: MapDefinition, source: Dictionary) -> Dictionary:
	return {
		"id": source["id"],
		"kind": MapTypes.PROP_KIND_BARRELS,
		"primitive": source["primitive"],
		"position": cell_center(definition, source["cell"]),
	}


static func _fingerprint(definition: MapDefinition) -> String:
	var payload := "%s|%s|%s|%s|%s|%s|%s" % [
		definition.map_id,
		definition.size_cells,
		definition.base_terrain,
		definition.zones,
		definition.buildings,
		definition.props,
		definition.patrols,
	]
	return payload.sha256_text()
