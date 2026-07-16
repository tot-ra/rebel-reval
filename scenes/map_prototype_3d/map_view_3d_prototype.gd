extends Node3D

## P0-052 viewer: renders one declarative map definition through the 3D
## orthographic view layer. Prototype-scoped; not an active Start destination.
## Attach to a Node3D root in the editor to inspect a map; no .tscn ships with
## P0-052 so the scene inventory stays untouched until D-001 wires the demo
## boot scene. Captured evidence: tools/capture_map_view_3d.gd.

@export var map_id: String = "smithy_courtyard"
@export_enum("day", "night") var time_of_day: String = "day"


func _ready() -> void:
	var definitions := MapAuditRegistry.by_id()
	if not definitions.has(map_id):
		push_error("Unknown map id for 3D view prototype: %s" % map_id)
		return
	var definition: MapDefinition = definitions[map_id]
	add_child(MapView3D.create(definition, MapBuilder.build(definition), StringName(time_of_day)))
