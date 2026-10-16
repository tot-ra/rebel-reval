extends RefCounted

## site.kalev_smithy (ADR 0032): Kalev's smithy in spring 1343, a stone-footed
## street-front craft house after history/dossiers/architecture/smithy-workshop-layout.md.
## No Reval smithy plan of 1343 survives, so the whole site is a plausible
## composite: limestone rubble walls (the hot trade in stone, Hanseatic fire
## practice) under a steep shingle roof, the forge bay behind the street door,
## the living bay behind a stone partition, a rubble chimney stack in the east
## gable over the raised hearth, wooden shutters (no glass), a fold-down shop
## counter at the street window and an open lean-to with the charcoal crib.
##
## WHY the old smithy's art: the standalone forge interior
## (MapViewKalevSmithyInterior, tools/assets/generate_kalev_smithy_interior.py)
## had the room the maintainer liked, so the walls reuse its photoreal limestone,
## lime wash, beaten-earth and board plates, and the bay is furnished with the
## same GLB kit (hearth with live fire, bellows, anvil, slack tub, stock rack,
## scrap crate, finishing bench, charcoal bin) in the old relative layout. The
## kit was authored in 0.87 m district units, so it is mounted scaled to metres
## and its world-triplanar plates are re-scaled to keep their real span.
##
## Walls come from the manifest fabric (CitySiteKit), so model and walk data
## share one description. Everything above head height is "Smithy/Upper"; the
## roof, loft and stack top are "Smithy/Roof"; both lift while Kalev is inside.

const Kit := preload("res://scripts/city/sites/site_kit.gd")
const Interior := preload("res://scripts/map/view3d/map_view_kalev_smithy_interior.gd")
const PropBuilder := preload("res://scripts/map/view3d/map_view_smithy_prop_builder.gd")
const Footing := preload("res://scripts/city/city_footing.gd")
const FLOOR := 0.12
const CUT := FLOOR + CityBuildingBuilder.CUT_HEIGHT
const EAVE := 4.1
const PITCH := 48.0
const X0 := 0.3
const X1 := 14.3
const Z0 := 0.0
const Z1 := 9.4
const THICK := 0.62
const PARTITION_X := 6.4
const SHED := Rect2(14.3, 0.5, 5.4, 6.8)
const SHED_HIGH := 3.4
const SHED_LOW := 2.3
## R-1933: lean-to post pads, back-wall sill stones (the sill beam sits on
## them), barge-board depth under the rakes and rafter tails past the eave.
const PAD_TOP := 0.18
const SILL_TOP := 0.2
const FASCIA := 0.2
const RAFTER_TAIL := 0.32
## Kit GLBs are in district units (1 unit = 0.87 m).
const KIT_SCALE := 0.87
const KIT_MODELS := {
	"hearth": Interior.HEARTH_PATH,
	"bellows": Interior.BELLOWS_PATH,
	"anvil": Interior.ANVIL_PATH,
	"slack_tub": Interior.SLACK_TUB_PATH,
	"stock_rack": Interior.STOCK_RACK_PATH,
	"scrap_heap": Interior.SCRAP_HEAP_PATH,
	"finishing_bench": Interior.FINISHING_BENCH_PATH,
	"charcoal": "res://assets/props/forge/smithy_charcoal_storage/smithy_charcoal_storage.glb",
}
## Group of fire and candle controllers that follow the city clock
## (CityWorld3D.apply_time calls apply_cycle_progress on them).
const CYCLE_GROUP := &"city_cycle_lights"
const OAK := Kit.OAK
const OAK_DARK := Kit.OAK_DARK
const IRON := Kit.IRON
## Soot on the forge-bay walls: darkest over the hearth and under the rafters.
const HEARTH_XZ := Vector2(12.4, 4.9)

static var _materials: Dictionary = {}


static func build(site: CitySite, _plan: CityPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_kalev_smithy"
	var smithy := Node3D.new()
	smithy.name = "Smithy"
	root.add_child(smithy)
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	var fabric: Array = site.data["fabric"]
	Kit.walls(body, glass, fabric)
	_gable(body, X1, 1.0)
	_gable(body, X0, -1.0)
	_loft_hatch(body)
	var ridge := Kit.gable_roof(roof, X0 - 0.45, X1 + 0.45, Z0, Z1, EAVE, PITCH, 0.5, "roof:shingle")
	var stack_top := _stack(body, roof, ridge)
	_floors(body)
	_beams(body, roof)
	_shutters(body, fabric)
	_soot(body)
	var parts := body.split_at(CUT)
	var lower: CityBuildingBuilder.Shell = parts[0]
	Kit.cut_caps(lower, fabric, CUT)
	smithy.add_child(_mesh("Lower", lower))
	smithy.add_child(_mesh("Upper", parts[1]))
	smithy.add_child(_mesh("Roof", roof))
	var outside := CityBuildingBuilder.Shell.new()
	_shed(outside)
	var furnishings := Node3D.new()
	furnishings.name = "Furnishings"
	smithy.add_child(furnishings)
	for item: Dictionary in site.data.get("dressing", []):
		_dress(furnishings, outside, item)
	root.add_child(_mesh("Yard", outside))
	_lights(smithy)
	# CityWorld3D streams a lit plume over this stack (CityChimneySmoke).
	root.set_meta(&"chimneys", [stack_top])
	return root


## Materials: the old smithy's plates for the `smithy:` keys, the kit's own
## for everything else (shingle roof, timber, ashlar caps, dark).
static func material_for(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]
	var mat: Material
	match key:
		"smithy:limestone":
			# Warm grey-beige Reval limestone, as in the old smithy's firelit room;
			# the bare plate reads cold white under the city's daylight ambient.
			mat = _plate("ksi_limestone", true)
			(mat as StandardMaterial3D).albedo_color = Color(0.8, 0.73, 0.63)
		"smithy:limewash":
			mat = _plate("ksi_limewash", true)
			(mat as StandardMaterial3D).albedo_color = Color(0.86, 0.8, 0.7)
		"smithy:earth":
			# Beaten clay darkened by charcoal dust and scale.
			mat = _plate("ksi_earth", true)
			(mat as StandardMaterial3D).albedo_color = Color(0.62, 0.52, 0.42)
		"smithy:boards":
			mat = _plate("ksi_boards", true)
		"smithy:oak":
			mat = _plate("ksi_oak", true)
		"smithy:charcoal":
			mat = _plate("ksi_charcoal", true)
		"smithy:iron":
			mat = _plate("ksi_iron", true)
		_:
			mat = Kit.material_for(key)
	_materials[key] = mat
	return mat


## A city copy of an old-smithy plate. The originals map one repeat per
## `plate_metres / 0.87` world units (district scale); the city is in metres,
## so world-triplanar density is divided by 0.87. `shell` forces world
## triplanar for the procedural shell (it has no UVs); GLB props keep their
## grain-aligned UVs.
static func _plate(key: String, shell: bool) -> Material:
	var source := Interior.material_for(key)
	if not source is StandardMaterial3D:
		return source
	var mat := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
	if mat.uv1_triplanar and mat.uv1_world_triplanar:
		mat.uv1_scale = mat.uv1_scale / Interior.METERS_PER_WORLD_UNIT
	elif shell and mat.albedo_texture != null:
		# Grain plates (oak, boards) span uv1_scale.x repeats per metre of UV.
		var density := mat.uv1_scale.x
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 6.0
		mat.uv1_scale = Vector3(density, density, density)
	return mat


static func _glb_material(key: String) -> Material:
	var cache_key := "glb:" + key
	if not _materials.has(cache_key):
		if key == "ksi_loft_shadow":
			# Contact-shadow cards under the kit props: the old room multiplied them
			# into dim firelight; on the city's lit earth floor they read as discs
			# (opaque: holes, translucent: blue-grey pools), and the city's real
			# shadows already ground the props, so the cards are drawn clear.
			var shade := StandardMaterial3D.new()
			shade.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
			shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			shade.cull_mode = BaseMaterial3D.CULL_DISABLED
			_materials[cache_key] = shade
		else:
			_materials[cache_key] = _plate(key, false)
	return _materials[cache_key]


static func _mesh(node_name: String, shell: CityBuildingBuilder.Shell) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = shell.to_mesh(material_for)
	return inst


## Plain rubble gable (no crow steps on a craft house): a triangular wall prism
## from the eave to the ridge over the end wall at `x`; `side` points outwards.
static func _gable(shell: CityBuildingBuilder.Shell, x: float, side: float) -> void:
	var zc := (Z0 + Z1) * 0.5
	var apex := EAVE + (Z1 - Z0) * 0.5 * tan(deg_to_rad(PITCH))
	var color := Kit.STONE
	for face: float in [0.0, 1.0]:
		var fx := x - side * THICK * face
		shell.tri_out(
			"smithy:limestone",
			Vector3(fx, EAVE, Z0),
			Vector3(fx, EAVE, Z1),
			Vector3(fx, apex, zc),
			color if face == 0.0 else Color.WHITE,
			Vector3(side if face == 0.0 else -side, 0, 0)
		)


## The loft door in the west gable (hay, charcoal sacks and the apprentice's
## bed go up through it): a plank leaf in a dark recess under a timber lintel.
static func _loft_hatch(shell: CityBuildingBuilder.Shell) -> void:
	var x := X0 - 0.02
	var zc := (Z0 + Z1) * 0.5
	shell.quad_out(
		"dark",
		Vector3(x, 5.0, zc - 0.55),
		Vector3(x, 5.0, zc + 0.55),
		Vector3(x, 6.25, zc + 0.55),
		Vector3(x, 6.25, zc - 0.55),
		Color(0.08, 0.07, 0.06),
		Vector3.LEFT
	)
	for k in 4:
		var z0 := zc - 0.52 + k * 0.26
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(x - 0.05, 5.02, z0),
			Vector3(x - 0.01, 6.22, z0 + 0.25),
			OAK_DARK * (0.9 + 0.05 * float(k % 2))
		)
	CitySiteProps._box(
		shell, "timber", Vector3(x - 0.1, 6.25, zc - 0.75), Vector3(x + 0.1, 6.45, zc + 0.75), OAK_DARK
	)


## Rubble chimney stack built into the east gable: it takes the hood's throat
## from just under the eave up past the ridge (dossier decision 5; no brick
## pot). Below the cut it stays with the walls, above it lifts with the roof.
## Returns the stack top in site-local metres.
static func _stack(
	body: CityBuildingBuilder.Shell, roof: CityBuildingBuilder.Shell, ridge: float
) -> Vector3:
	var lo := Vector3(X1 - 1.35, 3.3, 4.15)
	var hi := Vector3(X1 + 0.18, ridge + 1.1, 5.25)
	CitySiteProps._box(body, "smithy:limestone", lo, Vector3(hi.x, ridge - 0.4, hi.z), Kit.STONE)
	CitySiteProps._box(
		roof, "smithy:limestone", Vector3(lo.x, ridge - 0.4, lo.z), hi, Kit.STONE * 0.86
	)
	# Cap slab with a dark flue mouth.
	CitySiteProps._box(
		roof,
		"ashlar",
		Vector3(lo.x - 0.08, hi.y, lo.z - 0.08),
		Vector3(hi.x + 0.08, hi.y + 0.14, hi.z + 0.08),
		Kit.ASHLAR * 0.7
	)
	roof.quad_out(
		"dark",
		Vector3(lo.x + 0.3, hi.y + 0.145, lo.z + 0.3),
		Vector3(hi.x - 0.3, hi.y + 0.145, lo.z + 0.3),
		Vector3(hi.x - 0.3, hi.y + 0.145, hi.z - 0.3),
		Vector3(lo.x + 0.3, hi.y + 0.145, hi.z - 0.3),
		Color(0.03, 0.03, 0.03),
		Vector3.UP
	)
	return Vector3((lo.x + hi.x) * 0.5, hi.y + 0.3, (lo.z + hi.z) * 0.5)


## Beaten clay and charcoal dust in the forge bay, boards in the living bay,
## worn limestone thresholds in the door passages.
static func _floors(shell: CityBuildingBuilder.Shell) -> void:
	var ix0 := X0 + THICK
	var ix1 := X1 - THICK
	var iz0 := Z0 + THICK
	var iz1 := Z1 - THICK
	_floor_quad(shell, "smithy:earth", Rect2(PARTITION_X, iz0, ix1 - PARTITION_X, iz1 - iz0))
	_floor_quad(shell, "smithy:boards", Rect2(ix0, iz0, PARTITION_X - ix0, iz1 - iz0))
	for r: Rect2 in [
		Rect2(6.6, Z0, 1.6, THICK),
		Rect2(9.45, iz1, 1.5, THICK),
		Rect2(PARTITION_X - 0.42, 1.72, 0.42, 1.45),
	]:
		CitySiteProps._box(
			shell,
			"ashlar",
			Vector3(r.position.x, FLOOR - 0.12, r.position.y),
			Vector3(r.end.x, FLOOR + 0.01, r.end.y),
			Kit.ASHLAR * 0.82
		)


static func _floor_quad(shell: CityBuildingBuilder.Shell, key: String, r: Rect2) -> void:
	shell.quad_out(
		key,
		Vector3(r.position.x, FLOOR, r.position.y),
		Vector3(r.end.x, FLOOR, r.position.y),
		Vector3(r.end.x, FLOOR, r.end.y),
		Vector3(r.position.x, FLOOR, r.end.y),
		Color.WHITE,
		Vector3.UP
	)


## Tie beams across the forge bay (open to the sooted rafters for the smoke)
## and the boarded loft over the living bay on its joists.
static func _beams(body: CityBuildingBuilder.Shell, roof: CityBuildingBuilder.Shell) -> void:
	for x: float in [7.9, 10.4]:
		CitySiteProps._box(
			body,
			"smithy:oak",
			Vector3(x - 0.15, EAVE - 0.3, Z0 + 0.3),
			Vector3(x + 0.15, EAVE, Z1 - 0.3),
			Color(0.42, 0.36, 0.3)
		)
	var x0 := X0 + THICK
	var x1 := PARTITION_X - 0.42
	var z := Z0 + 1.2
	while z < Z1 - 0.8:
		CitySiteProps._box(
			roof,
			"smithy:oak",
			Vector3(x0, EAVE - 0.22, z - 0.09),
			Vector3(x1, EAVE, z + 0.09),
			Color(0.62, 0.55, 0.47)
		)
		z += 1.1
	CitySiteProps._box(
		roof,
		"smithy:boards",
		Vector3(x0, EAVE, Z0 + THICK),
		Vector3(x1, EAVE + 0.05, Z1 - THICK),
		Color(0.82, 0.76, 0.68)
	)


## Plank shutters folded back against the outer face beside every window
## (1343 craft houses were not glazed); the shop window gets the counter and
## awning leaves instead (`shop_counter` dressing).
static func _shutters(shell: CityBuildingBuilder.Shell, fabric: Array) -> void:
	for w: Dictionary in fabric:
		var a := Vector2(w["a"][0], w["a"][1])
		var b := Vector2(w["b"][0], w["b"][1])
		var inside := Vector2(w["inside"][0], w["inside"][1])
		var dir := (b - a).normalized()
		var out := Vector2(-dir.y, dir.x)
		if out.dot(inside - (a + b) * 0.5) > 0.0:
			out = -out
		if String(w["id"]) == "partition":
			continue
		for op: Dictionary in w.get("openings", []):
			if String(op.get("kind", "")) != "window" or String(op.get("note", "")).begins_with("shop"):
				continue
			var half := float(op["w"]) * 0.5
			var y0 := float(op["sill"])
			var y1 := float(op["spring"])
			var mid := a + dir * float(op["s"])
			for side: float in [-1.0, 1.0]:
				var hinge := mid + dir * side * half + out * 0.03
				var tip := hinge + dir * side * half
				var p0 := Vector3(hinge.x, y0, hinge.y)
				var p1 := Vector3(tip.x, y0, tip.y)
				var o3 := Vector3(out.x, 0, out.y)
				shell.quad_out(
					"timber",
					p0 + o3 * 0.04,
					p1 + o3 * 0.04,
					Vector3(p1.x, y1, p1.z) + o3 * 0.04,
					Vector3(p0.x, y1, p0.z) + o3 * 0.04,
					OAK_DARK * 0.95,
					o3
				)
				# Ledges across the leaf and a strap hinge.
				for y: float in [y0 + 0.12, y1 - 0.12]:
					var l0 := p0 + o3 * 0.06
					var l1 := p1 + o3 * 0.06
					Kit.bar(shell, "timber", Vector3(l0.x, y, l0.z), Vector3(l1.x, y, l1.z), 0.05, OAK_DARK * 0.8)
				var s0 := p0 + o3 * 0.07
				var s1 := p0.lerp(p1, 0.7) + o3 * 0.07
				Kit.bar(
					shell,
					"dark",
					Vector3(s0.x, y1 - 0.18, s0.z),
					Vector3(s1.x, y1 - 0.18, s1.z),
					0.025,
					IRON
				)


## Soot and grime baked into the vertex colours of the rubble: smoke stains
## the forge-bay walls towards the rafters and around the hearth; the outer
## faces darken at the foot with damp and splash.
static func _soot(shell: CityBuildingBuilder.Shell) -> void:
	var key := "smithy:limestone"
	if not shell.surfaces.has(key):
		return
	var surf = shell.surfaces[key]
	var colors: PackedColorArray = surf.colors
	for i in surf.verts.size():
		var v: Vector3 = surf.verts[i]
		var inside: bool = (
			v.x > PARTITION_X - 0.01
			and v.x < X1 - THICK + 0.01
			and v.z > Z0 + THICK - 0.01
			and v.z < Z1 - THICK + 0.01
		)
		var k := 1.0
		if inside:
			var near := 1.0 - clampf(Vector2(v.x, v.z).distance_to(HEARTH_XZ) / 6.5, 0.0, 1.0)
			var high := clampf((v.y - 1.2) / (EAVE - 1.2), 0.0, 1.0)
			k = 1.0 - 0.45 * high - 0.3 * near * (0.4 + 0.6 * high)
		else:
			k = 1.0 - 0.22 * (1.0 - clampf((v.y - FLOOR + 0.6) / 1.4, 0.0, 1.0))
		var c: Color = colors[i]
		colors[i] = Color(c.r * k, c.g * k, c.b * (k * 0.97), c.a)
	surf.colors = colors


## Open lean-to against the east gable: shingled pent roof on oak posts and a
## wall plate, boarded at the back. Holds the charcoal crib, cordwood and the
## grindstone (dossier: charcoal in a roofed corner or rear-yard crib).
static func _shed(shell: CityBuildingBuilder.Shell) -> void:
	var x0 := SHED.position.x
	var x1 := SHED.end.x
	var z0 := SHED.position.y
	var z1 := SHED.end.y
	# R-1933: the posts stand on fieldstone pads, not straight in the dirt.
	for z: float in [z0 + 0.1, (z0 + z1) * 0.5, z1 - 0.1]:
		Footing.pad(shell, Vector2(x1 - 0.21, z), 0.0, Vector2(0.2, 0.19), PAD_TOP, int(z * 97.0) + 6113)
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(x1 - 0.32, PAD_TOP - 0.03, z - 0.11),
			Vector3(x1 - 0.1, SHED_LOW, z + 0.11),
			OAK_DARK
		)
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x1 - 0.36, SHED_LOW - 0.02, z0 - 0.1),
		Vector3(x1 - 0.06, SHED_LOW + 0.2, z1 + 0.1),
		OAK_DARK * 0.9
	)
	# Ledger beam on the gable wall and rafters down to the wall plate.
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x0, SHED_HIGH - 0.2, z0 - 0.1),
		Vector3(x0 + 0.2, SHED_HIGH, z1 + 0.1),
		OAK_DARK
	)
	# R-1933: the rafter tails run RAFTER_TAIL past the roof edge, so seen from
	# above the eave is a toothed, shadow-casting edge, not one ruler line.
	var fall := (SHED_HIGH - SHED_LOW) / (x1 - x0)
	var tail_x := x1 + 0.45 + RAFTER_TAIL
	var z := z0
	while z <= z1 + 0.01:
		Kit.bar(
			shell,
			"timber",
			Vector3(x0 + 0.1, SHED_HIGH + 0.02, z),
			Vector3(tail_x, SHED_LOW + 0.12 - (tail_x - x1) * fall, z),
			0.12,
			OAK_DARK * 0.85
		)
		z += 1.13
	# Shingled pent roof.
	var slope := Vector3(x1 + 0.45 - x0, SHED_LOW + 0.05 - SHED_HIGH, 0.0)
	var n := Vector3(-slope.y, slope.x, 0.0).normalized()
	var top0 := Vector3(x0, SHED_HIGH + 0.15, z0 - 0.35)
	var top1 := Vector3(x0, SHED_HIGH + 0.15, z1 + 0.35)
	var run := slope.length()
	shell.tri_out(
		"roof:shingle",
		top0,
		top1,
		top1 + slope,
		Color.WHITE,
		n,
		Vector2(z0, 0),
		Vector2(z1, 0),
		Vector2(z1, run)
	)
	shell.tri_out(
		"roof:shingle",
		top0,
		top1 + slope,
		top0 + slope,
		Color.WHITE,
		n,
		Vector2(z0, 0),
		Vector2(z1, run),
		Vector2(z0, run)
	)
	shell.quad_out("timber", top0, top1, top1 + slope, top0 + slope, OAK_DARK * 0.7, -n)
	# R-1933: barge boards under both rakes and a thick board edge at the
	# eave, so the pent roof shows its depth and reads as a roof, not a wall.
	var drop := Vector3(0.0, -FASCIA, 0.0)
	var eave0 := top0 + slope
	var eave1 := top1 + slope
	var edge := Vector3(0.0, -0.06, 0.0)
	shell.quad_out("timber", eave0 + edge, eave1 + edge, eave1, eave0, OAK_DARK * 0.8, Vector3.RIGHT)
	for rake: Array in [[top0, Vector3.FORWARD], [top1, Vector3.BACK]]:
		var r0: Vector3 = rake[0]
		shell.quad_out("timber", r0 + drop, r0 + slope + drop, r0 + slope, r0, OAK_DARK * 0.75, rake[1])
	# Boarded back wall on a fieldstone sill and sill beam (both faces: the
	# inside shows from the open street front).
	var sill_a := Vector2(x0 + 0.05, z1 - 0.03)
	var sill_b := Vector2(x1 - 0.3, z1 - 0.03)
	Footing.run(shell, sill_a, sill_b, Vector2(0, 1), Footing.Kind.PLANK, SILL_TOP, 0.0, 6211)
	Footing.run(shell, sill_b, sill_a, Vector2(0, -1), Footing.Kind.PLANK, SILL_TOP, 0.0, 6223)
	# Boarded back wall (the yard side), open to the street and the east.
	var bx := x0 + 0.05
	while bx < x1 - 0.3:
		var bx1 := minf(bx + 0.24, x1 - 0.3)
		var top_y := lerpf(SHED_HIGH, SHED_LOW, (bx1 - x0) / (x1 - x0))
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(bx, SILL_TOP + Footing.BEAM_H - 0.02, z1 - 0.06),
			Vector3(bx1 - 0.01, top_y, z1),
			OAK_DARK * (0.85 + 0.1 * float(int(bx * 7.0) % 3) / 2.0)
		)
		bx = bx1


## Places one manifest dressing item (site-local metres, rotation as in
## CitySite._rect): the forge kit GLBs, catalogue furniture and the small
## procedural pieces of the yard and the street front.
static func _dress(parent: Node3D, outside: CityBuildingBuilder.Shell, item: Dictionary) -> void:
	var at := Vector3(item["at"][0], FLOOR + float(item.get("y", 0.0)), item["at"][1])
	var yaw := -deg_to_rad(float(item.get("rotation_deg", 0.0)))
	var kind := String(item["kind"])
	var node: Node3D = null
	match kind:
		"kit":
			node = _kit_model(String(item["model"]))
			node.scale = Vector3.ONE * KIT_SCALE
		"catalog":
			node = CityInteriors._template(String(item["object"]), "")
		"charcoal_crib":
			_charcoal_crib(outside, at, String(item["id"]).hash())
		"grindstone":
			_grindstone(outside, at, yaw)
		"bar_iron":
			_bar_iron(outside, at)
		"shop_counter":
			_shop_counter(outside, at)
		"ladder":
			_ladder(parent, at)
		_:
			push_error("Kalev smithy: unknown dressing kind %s" % kind)
	if node == null:
		return
	node.name = String(item["id"]).replace(".", "_")
	node.position = at
	node.rotation.y = yaw
	parent.add_child(node)


static func _kit_model(model: String) -> Node3D:
	var holder := Node3D.new()
	if model == "hearth":
		# The shared furnace builder adds the hearth GLB with its ember bed,
		# flames, sparks, smoke and the flickering forge light.
		PropBuilder.add_smithy_furnace(holder)
		for controller in holder.find_children("*", "Node", true, false):
			if controller.has_method(&"apply_cycle_progress"):
				controller.add_to_group(CYCLE_GROUP)
	else:
		var scene := MapViewPackedScenes.load_scene(String(KIT_MODELS[model]))
		if scene != null:
			holder.add_child(scene.instantiate())
	_apply_kit_materials(holder)
	return holder


static func _apply_kit_materials(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var inst := child as MeshInstance3D
		if inst.mesh == null:
			continue
		for k in inst.mesh.get_surface_count():
			var source := inst.mesh.surface_get_material(k)
			if source != null and source.resource_name.begins_with("ksi_"):
				inst.set_surface_override_material(k, _glb_material(source.resource_name))


## Plank crib heaped with charcoal lumps under the lean-to.
static func _charcoal_crib(shell: CityBuildingBuilder.Shell, at: Vector3, seed_value: int) -> void:
	var lo := at + Vector3(-0.8, -FLOOR, -1.05)
	var hi := at + Vector3(0.8, 0.85 - FLOOR, 1.05)
	for side: Array in [
		[Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z + 0.06)],
		[Vector3(lo.x, lo.y, hi.z - 0.06), Vector3(hi.x, hi.y, hi.z)],
		[Vector3(lo.x, lo.y, lo.z), Vector3(lo.x + 0.06, hi.y, hi.z)],
		[Vector3(hi.x - 0.06, lo.y, lo.z), Vector3(hi.x, hi.y - 0.35, hi.z)],
	]:
		CitySiteProps._box(shell, "timber", side[0], side[1], OAK_DARK * 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in 70:
		var u := rng.randf_range(-0.7, 0.7)
		var v := rng.randf_range(-0.95, 0.95)
		var h := 0.62 + 0.22 * (1.0 - absf(u) / 0.7) * (1.0 - absf(v) / 0.95)
		var c := at + Vector3(u, h - FLOOR, v)
		var s := rng.randf_range(0.06, 0.13)
		CitySiteProps._box(
			shell,
			"smithy:charcoal",
			c - Vector3(s, s * 0.6, s * 0.8),
			c + Vector3(s, s * 0.6, s * 0.8),
			Color(0.5, 0.5, 0.52)
		)


## Treadle grindstone on an oak trestle over a water trough (a crank-turned
## grindstone is drawn in the Luttrell Psalter, c. 1330).
static func _grindstone(shell: CityBuildingBuilder.Shell, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var c := at + Vector3(0, 0.78 - FLOOR, 0)
	var axis := basis * Vector3(0, 0, 1)
	var up := Vector3.UP
	var side := axis.cross(up)
	var r := 0.42
	var half := 0.07
	var segments := 18
	for k in segments:
		var a0 := TAU * k / segments
		var a1 := TAU * (k + 1) / segments
		var p0 := up * cos(a0) * r + side * sin(a0) * r
		var p1 := up * cos(a1) * r + side * sin(a1) * r
		var tone := Color(0.72, 0.68, 0.6) * (0.92 + 0.08 * float(k % 2))
		shell.quad_out(
			"ashlar",
			c + p0 - axis * half,
			c + p1 - axis * half,
			c + p1 + axis * half,
			c + p0 + axis * half,
			tone,
			p0 + p1
		)
		for face: float in [-1.0, 1.0]:
			shell.tri_out(
				"ashlar",
				c + axis * half * face,
				c + p0 + axis * half * face,
				c + p1 + axis * half * face,
				tone,
				axis * face
			)
	Kit.bar(shell, "dark", c - axis * 0.42, c + axis * 0.55, 0.04, IRON)
	# Crank handle.
	Kit.bar(shell, "dark", c + axis * 0.55, c + axis * 0.55 + up * 0.28, 0.035, IRON)
	Kit.bar(shell, "timber", c + axis * 0.55 + up * 0.28, c + axis * 0.75 + up * 0.28, 0.05, OAK)
	# A-frame trestle legs on both sides and the trough.
	for face: float in [-1.0, 1.0]:
		var top := c + axis * 0.3 * face
		for leg: float in [-1.0, 1.0]:
			Kit.bar(
				shell,
				"timber",
				top,
				top + side * 0.45 * leg + Vector3(0, -0.78 + FLOOR - 0.12, 0),
				0.08,
				OAK_DARK
			)
	var t0 := at + Vector3(0, -FLOOR, 0)
	CitySiteProps._box(
		shell, "timber", t0 + Vector3(-0.32, 0.0, -0.32), t0 + Vector3(0.32, 0.3, 0.32), OAK_DARK * 0.8
	)


## Bar iron and rod stock leaning against the gable under the lean-to.
static func _bar_iron(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	for k in 7:
		var z := at.z - 0.4 + k * 0.13
		var foot := Vector3(at.x + 0.55, -0.05, z)
		var top := Vector3(at.x + 0.06, 1.75 + 0.06 * float(k % 3), z + 0.04 * float(k % 2))
		Kit.bar(shell, "smithy:iron", foot, top, 0.035 if k % 3 else 0.05, Color(0.75, 0.72, 0.7))


## The street window's shutters as a medieval shop front: the lower leaf
## folds down on two brackets as the counter (horseshoes, nails, a knife for
## pickup, dossier zone H), the upper leaf is propped up as an awning.
static func _shop_counter(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	var y := 1.0 - FLOOR
	var w := 1.34
	var x0 := at.x - w * 0.5
	var x1 := at.x + w * 0.5
	CitySiteProps._box(
		shell, "timber", Vector3(x0, at.y + y - 0.05, -0.62), Vector3(x1, at.y + y, 0.0), OAK * 0.85
	)
	for x: float in [x0 + 0.12, x1 - 0.12]:
		Kit.bar(
			shell,
			"timber",
			Vector3(x, at.y + y - 0.05, -0.5),
			Vector3(x, at.y + y - 0.52, 0.0),
			0.06,
			OAK_DARK
		)
	# Awning leaf hinged at the window head, held out on two props.
	var head := 1.95
	var tip := Vector3(0, head + 0.12, -0.72)
	shell.quad_out(
		"timber",
		Vector3(x0, head, -0.02),
		Vector3(x1, head, -0.02),
		Vector3(x1, tip.y, tip.z),
		Vector3(x0, tip.y, tip.z),
		OAK_DARK,
		Vector3(0, 0.98, -0.2)
	)
	for x: float in [x0 + 0.08, x1 - 0.08]:
		Kit.bar(
			shell,
			"timber",
			Vector3(x, at.y + y, -0.58),
			Vector3(x, tip.y, tip.z + 0.04),
			0.035,
			OAK_DARK * 0.9
		)
	# Goods: horseshoes (bent bars), a bundle of nails, a knife.
	var top := at.y + y + 0.01
	for k in 3:
		var c := Vector3(x0 + 0.22 + k * 0.2, top, -0.3)
		for s in 5:
			var a0 := PI * (0.1 + 0.8 * s / 5.0)
			var a1 := PI * (0.1 + 0.8 * (s + 1) / 5.0)
			Kit.bar(
				shell,
				"smithy:iron",
				c + Vector3(cos(a0) * 0.07, 0.012, -sin(a0) * 0.07),
				c + Vector3(cos(a1) * 0.07, 0.012, -sin(a1) * 0.07),
				0.022,
				Color(0.62, 0.6, 0.58)
			)
	CitySiteProps._box(
		shell,
		"smithy:iron",
		Vector3(x1 - 0.42, top, -0.4),
		Vector3(x1 - 0.3, top + 0.05, -0.18),
		Color(0.55, 0.53, 0.5)
	)
	Kit.bar(
		shell,
		"smithy:iron",
		Vector3(x1 - 0.26, top + 0.012, -0.2),
		Vector3(x1 - 0.1, top + 0.012, -0.42),
		0.02,
		Color(0.9, 0.88, 0.85)
	)
	Kit.bar(
		shell,
		"timber",
		Vector3(x1 - 0.26, top + 0.014, -0.2),
		Vector3(x1 - 0.32, top + 0.014, -0.12),
		0.03,
		OAK_DARK
	)


## Ladder up to the loft hatch, leaning on the partition in the living bay.
static func _ladder(parent: Node3D, at: Vector3) -> void:
	var shell := CityBuildingBuilder.Shell.new()
	var foot_x := at.x - 0.55
	for z: float in [at.z - 0.22, at.z + 0.22]:
		Kit.bar(shell, "timber", Vector3(foot_x, FLOOR, z), Vector3(at.x, EAVE, z), 0.07, OAK_DARK)
	var y := FLOOR + 0.3
	while y < EAVE - 0.1:
		var t := (y - FLOOR) / (EAVE - FLOOR)
		var x := lerpf(foot_x, at.x, t)
		Kit.bar(shell, "timber", Vector3(x, y, at.z - 0.24), Vector3(x, y, at.z + 0.24), 0.045, OAK)
		y += 0.32
	var parts := shell.split_at(CUT)
	parent.add_child(_mesh("Ladder", parts[0]))


## Daylight fill at the windows and the table candle; the hearth carries its
## own flickering forge light (ForgeFireLight3D, following the city clock).
static func _lights(node: Node3D) -> void:
	for spot: Array in [
		[Vector3(3.2, FLOOR + 1.45, 4.65), Color(1.0, 0.74, 0.48), 0.7, 4.5],
		[Vector3(8.6, 2.6, 1.4), Color(0.86, 0.88, 0.92), 0.45, 6.0],
		[Vector3(3.0, 2.6, 1.6), Color(0.86, 0.88, 0.92), 0.3, 5.0],
	]:
		var light := OmniLight3D.new()
		light.position = spot[0]
		light.light_color = spot[1]
		light.light_energy = spot[2]
		light.omni_range = spot[3]
		light.shadow_enabled = false
		CityDoors.keep_indoors(light)
		node.add_child(light)
