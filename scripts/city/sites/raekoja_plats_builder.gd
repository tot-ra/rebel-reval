extends RefCounted

## Interim model of site.raekoja_plats (ADR 0032): the forum and the council
## hall as they stood in spring 1343, per
## history/dossiers/topography/raekoja-plats-extents-1343.md.
##
## The hall is a hollow, enterable CityBuildingBuilder shell (one storey of
## grey limestone, tile gable roof at the old model's pitch, interior floor and
## ceiling) dressed with the authored 1343 hall details of the district maps
## (MapViewTownHallModel: stone gables with coping, footing plinth, dressed
## quoins, pointed portal, shuttered market lights and barred cellar lights,
## attic hoist, the red-and-white banners, rain streaks and grime). Those
## details are authored in 0.87 m units, so the hall is built in those units
## under one scaled node. No arcade, tower or upper storey (all after 1343).
## A Blender-generated GLB replaces this builder later (ADR 0032 decision 3).

const TownHallModel := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")
const UNIT_M := 0.87
## Old-model roof pitch (rise over run) and the hall's colours from
## market_civic_quarter (style house.town_hall).
const ROOF_SLOPE := 0.9
const WALL_COLOR := Color("aaa398")
const ROOF_COLOR := Color("873f2d")


static func build(site: CitySite, plan: CityPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_%s" % String(site.id).replace(".", "_")
	for spec: Dictionary in site.data.get("buildings", []):
		root.add_child(_hall(site, spec))
	for item: Dictionary in site.data.get("dressing", []):
		var world := site.to_world(Vector2(item["at"][0], item["at"][1]))
		CitySiteProps.add(root, item, plan.ground_height(world) - site.level)
	return root


static func _hall(site: CitySite, spec: Dictionary) -> Node3D:
	var hall := Node3D.new()
	hall.name = "CouncilHall"
	hall.scale = Vector3.ONE * UNIT_M
	var ring := PackedVector2Array()
	for p: Array in spec["footprint"]:
		ring.append(Vector2(p[0], p[1]) / UNIT_M)
	var size := Vector2(ring[1].x - ring[0].x, ring[2].y - ring[1].y)
	var height := float(spec["wall_h"]) / UNIT_M
	var floor_y := 0.12 / UNIT_M
	for f: Dictionary in site.data["walk"]["floors"]:
		floor_y = float(f.get("height", 0.12)) / UNIT_M
	var record := {
		"id": String(spec["id"]),
		"kind": "hall",
		"openings": false,
		"material": "limestone",
		"roof": String(spec.get("roof", "tile")),
		"base_h": 0.0,
		"base_span": 0.0,
		"wall_h": height - floor_y,
		"roof_pitch_deg": rad_to_deg(atan(ROOF_SLOPE)),
		"ridge_angle": 0.0,
		# Door in the middle of the market (north, -z) front.
		"door": [0.0, -size.y * 0.5, -PI * 0.5],
	}
	var built := CityBuildingBuilder.build_building(record, ring, floor_y, true)
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	walls.mesh = (built["shell"] as CityBuildingBuilder.Shell).to_mesh(
		CityBuildingBuilder.material_for_key
	)
	hall.add_child(walls)
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	roof.mesh = (built["roof"] as CityBuildingBuilder.Shell).to_mesh(
		CityBuildingBuilder.material_for_key
	)
	hall.add_child(roof)
	var details := Node3D.new()
	details.name = "Details"
	hall.add_child(details)
	TownHallModel.add_details(
		details,
		{"id": String(spec["id"]), "wall_color": WALL_COLOR, "roof_color": ROOF_COLOR},
		size,
		height
	)
	return hall
