class_name CityDressingBuilder
extends RefCounted

## Wind-driven dressing for the city (ADR 0031): hoist beams and hemp ropes on
## merchant gables that face the street, the town banner on the council hall
## and the Coastal Gate, Danish crown pennants on the castle towers. Everything
## uses the shared world-wind materials, so flags, ropes, trees, smoke, clouds
## and the sea all agree on where the wind blows (tools/verify_wind_direction.gd).

const TownHallModel := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")
const Fort := preload("res://scripts/city/city_fortification_builder.gd")
const HOIST_ROPE_LENGTH := 4.2
const BEAM_PROJECTION := 0.9


static func build(plan: CityPlan, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	parent.add_child(root)
	var ropes := 0
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if b.get("door") == null or String(b.get("landmark_id", "")) != "":
			continue
		if String(b["material"]) != "limestone" and String(b["material"]) != "plaster":
			continue
		if _hoist(plan, i, b, root):
			ropes += 1
	_town_banners(plan, root)
	_castle_pennants(plan, root)
	root.set_meta(&"hoist_ropes", ropes)
	return root


## Hoist beam under the street gable peak; only when the ridge runs away from
## the street (gable end on the door edge), as on Reval Diele houses.
static func _hoist(plan: CityPlan, index: int, b: Dictionary, root: Node3D) -> bool:
	var ring := CityBuildingBuilder.normalized_ring(plan.footprint(index))
	var door := Vector2(b["door"][0], b["door"][1])
	var edge := CityBuildingBuilder._closest_edge(ring, door)
	var a := ring[edge]
	var c := ring[(edge + 1) % ring.size()]
	var ridge := Vector2(cos(float(b["ridge_angle"])), sin(float(b["ridge_angle"])))
	if absf((c - a).normalized().dot(ridge)) > 0.35:
		return false
	var floor_y := plan.floor_height(index)
	var frame := CityBuildingBuilder.roof_frame(
		ring, float(b["ridge_angle"]), floor_y + float(b["wall_h"]), float(b["roof_pitch_deg"])
	)
	var mid := (a + c) * 0.5
	var out := Vector2(cos(float(b["door"][2])), sin(float(b["door"][2])))
	var peak := CityBuildingBuilder.roof_height(frame, mid)
	var beam_y := lerpf(float(frame["eave"]), peak, 0.55)
	if beam_y - HOIST_ROPE_LENGTH < floor_y + 1.2:
		return false
	var beam := MeshInstance3D.new()
	beam.name = "HoistBeam_%d" % index
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.22, BEAM_PROJECTION + 0.4)
	beam.mesh = box
	beam.material_override = CityBuildingBuilder.timber_material()
	var beam_mid := mid + out * (BEAM_PROJECTION * 0.5 - 0.2)
	beam.position = Vector3(beam_mid.x, beam_y, beam_mid.y)
	beam.basis = Basis(Vector3.UP, atan2(out.x, out.y))
	root.add_child(beam)
	var rope := MapViewHoistRope.create(HOIST_ROPE_LENGTH)
	rope.name = "HoistRope_%d" % index
	var tip := mid + out * BEAM_PROJECTION
	rope.position = Vector3(tip.x, beam_y - 0.12, tip.y)
	root.add_child(rope)
	return true


static func _staff_and_cloth(
	root: Node3D, at: Vector3, staff_h: float, cloth: Mesh, material: Material, cloth_scale: float
) -> void:
	var staff := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.06
	cyl.height = staff_h
	cyl.radial_segments = 8
	staff.mesh = cyl
	staff.material_override = CityBuildingBuilder.timber_material()
	staff.position = at + Vector3(0, staff_h * 0.5, 0)
	root.add_child(staff)
	var flag := MeshInstance3D.new()
	flag.mesh = cloth
	flag.material_override = material
	flag.scale = Vector3.ONE * cloth_scale
	flag.position = at + Vector3(0, staff_h - 0.1, 0)
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flag)


## Reval's red banner with the white cross (docs/CANON.md: plausible composite
## on the council hall) on the hall's ridge end and over the Coastal Gate.
static func _town_banners(plan: CityPlan, root: Node3D) -> void:
	var banner := TownHallModel._banner_mesh(1.5, 1.1, true, 2)
	var material := MapViewMaterials.flag_cloth(true)
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if String(b.get("landmark_id", "")) != "landmark.town_hall":
			continue
		var ring := CityBuildingBuilder.normalized_ring(plan.footprint(i))
		var frame := CityBuildingBuilder.roof_frame(
			ring,
			float(b["ridge_angle"]),
			plan.floor_height(i) + float(b["wall_h"]),
			float(b["roof_pitch_deg"])
		)
		var r: Vector2 = frame["r"]
		var n: Vector2 = frame["n"]
		var end := r * float(frame["amax"]) + n * float(frame["mid"])
		_staff_and_cloth(
			root, Vector3(end.x, float(frame["ridge"]) - 0.2, end.y), 3.4, banner, material, 1.3
		)
	var coastal := plan.gate("gate.coastal")
	if not coastal.is_empty():
		var at := Vector2(coastal["at"][0], coastal["at"][1])
		var top := plan.ground_height(at) + 12.5 + 3.4
		_staff_and_cloth(root, Vector3(at.x, top, at.y), 3.0, banner, material, 1.2)


static func _castle_pennants(plan: CityPlan, root: Node3D) -> void:
	var pennant := FactionHeraldry.pennant_mesh(&"danish_crown")
	var material := MapViewMaterials.flag_cloth()
	for tower: Dictionary in Fort.castle_tower_points(plan):
		var p: Vector2 = tower["at"]
		_staff_and_cloth(root, Vector3(p.x, float(tower["top"]), p.y), 2.6, pennant, material, 2.4)
