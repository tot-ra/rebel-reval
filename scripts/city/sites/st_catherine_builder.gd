extends RefCounted

## site.st_catherine (ADR 0032; tasks R-1718, R-1727, R-1124): the Dominican
## friary of St Catherine in spring 1343, a walled close between Katariina
## kaik, the Munga houses and Muurivahe. Attested: the friary (refounded 1246),
## a stone church and the east range largely complete c. 1300, church to the
## south and cloister to its north. Everything else is a plausible composite
## after Kuehnert's plan reduced to the c. 1300 phase: a long, plain, buttressed
## limestone preaching hall under one tile roof (mendicant statutes: no tower,
## a small ridge bell turret only), a stone rood screen before the friars'
## choir, a cloister walk round a garth with the well, closed west, north and
## east ranges, and a service yard with the brewhouse, casks, carts and fish.
## Left out as later: the eight-bay hall and its vaults, the c. 1500 north-wing
## refectory, the two-storey cloister, Black Heads patronage, the 1520s works.

const Kit := preload("res://scripts/city/sites/site_kit.gd")
const Furnish := preload("res://scripts/city/sites/church_furnishings.gd")
const LifeProps := preload("res://scripts/map/view3d/map_view_mesh_builder_district_life_props.gd")
const WellModels := preload("res://scripts/map/view3d/map_view_well_models.gd")
const FLOOR := 0.12
const CHOIR_FLOOR := 0.57
const CUT := FLOOR + CityBuildingBuilder.CUT_HEIGHT
const X0 := 14.0
const X1 := 64.0
const ZN := -18.5
const ZS := -1.5
const THICK := 1.3
const AXIS := -10.0
const EAVE := 11.0
const PITCH := 45.0
const SCREEN_X := 49.0
const STEPS_X := 50.6
const TIE_Y := 10.6
const BUTTRESS_X: Array[float] = [21.0, 28.0, 35.0, 42.0, 49.0, 56.0]
## Shallow enough to leave Katariina kaik passable (manifest walk solids match).
const BUTTRESS_DEPTH := 0.9
## Cloister walk: the lean-to roof runs from the range walls down to the arcade.
const WALK_HIGH := 5.4
const WALK_LOW := 3.3
## Kitchen stack on the north range (site-local top, always-lit plume).
const KITCHEN_STACK := Vector3(22.0, 13.6, -50.5)
## Ground-floor rooms of the ranges: ceiling under the dormitory floor, and the
## chapter-house vault on its central pillar.
const RANGE_CEIL := 4.2
const CHAPTER_SPRING := 2.4
const CHAPTER_CROWN := 4.0
## The district props were authored in 0.87 m world units (CitySiteProps).
const LEGACY_UNIT_M := 0.87


static func build(site: CitySite, plan: CityPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_st_catherine"
	var groups := {"church": [], "range": [], "cloister": [], "precinct": []}
	for w: Dictionary in site.data["fabric"]:
		var id := String(w["id"])
		if id.begins_with("church."):
			groups["church"].append(w)
		elif id.begins_with("cloister."):
			groups["cloister"].append(w)
		elif id.begins_with("precinct."):
			groups["precinct"].append(w)
		else:
			groups["range"].append(w)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(site.id))
	root.add_child(_church(site, groups["church"], rng))
	root.add_child(_ranges(site, groups["range"], rng))
	root.add_child(_cloister(groups["cloister"], rng))
	root.add_child(_precinct(groups["precinct"]))
	_garth(root, site, plan)
	_yard(root, site, plan)
	# CityWorld3D streams a lit plume over the kitchen stack.
	root.set_meta(&"chimneys", [KITCHEN_STACK])
	return root


## The preaching hall: walls cut at head height into Lower/Upper for the
## cutaway, roof (with the tie beams) separate.
static func _church(site: CitySite, fabric: Array, rng: RandomNumberGenerator) -> Node3D:
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	Kit.walls(body, glass, fabric, Kit.GLAZING.get(site.id, 0))
	var ridge := EAVE + (ZS - ZN) * 0.5 * tan(deg_to_rad(PITCH))
	_gable(body, Vector3(X0, EAVE, ZS), Vector3(X0, EAVE, ZN), ridge + 0.3, Vector3(-1, 0, 0), 1.0)
	_gable(body, Vector3(X1, EAVE, ZN), Vector3(X1, EAVE, ZS), ridge + 0.3, Vector3(1, 0, 0), 1.0)
	for x: float in BUTTRESS_X:
		_buttress(body, Vector3(x, 0.0, ZS), Vector3(0, 0, 1), 1.1, BUTTRESS_DEPTH, EAVE - 2.5)
	for z: float in [-14.5, -5.5]:
		_buttress(body, Vector3(X1, 0.0, z), Vector3(1, 0, 0), 1.1, BUTTRESS_DEPTH, EAVE - 2.5)
	Kit.gable_roof(roof, X0 - 0.4, X1 + 0.4, ZN, ZS, EAVE, PITCH, 0.5)
	_tie_beams(roof, ridge)
	_bell_turret(roof, ridge)
	var occluders := _interior(body, rng)
	var node := Node3D.new()
	node.name = "Church"
	var parts := body.split_at(CUT)
	var lower: CityBuildingBuilder.Shell = parts[0]
	Kit.cut_caps(lower, fabric, CUT)
	var lower_node := Kit.mesh("Lower", lower)
	var upper_node := Kit.mesh("Upper", parts[1])
	var glass_parts := glass.split_at(CUT)
	upper_node.add_child(Kit.mesh("Glass", glass_parts[1]))
	lower_node.add_child(Kit.mesh("GlassLow", glass_parts[0]))
	var roof_node := Kit.mesh("Roof", roof)
	Kit.bind_site_washes(
		[lower_node, upper_node, roof_node], site, FLOOR, 1e9, Kit.CHURCH_WASH_BRIGHTNESS
	)
	ChurchMurals.paint(lower_node, upper_node, site, fabric, CUT, FLOOR)
	node.add_child(lower_node)
	node.add_child(upper_node)
	node.add_child(roof_node)
	ChurchSunlight.apply(
		node, lower_node, upper_node, roof_node, fabric, Kit.GLAZING.get(site.id, 0), occluders
	)
	var nave := [Vector2(22.0, AXIS), Vector2(30.0, AXIS), Vector2(38.0, AXIS), Vector2(45.0, AXIS)]
	Furnish.coronas(upper_node, nave, 4.8, TIE_Y)
	(
		Furnish
		. lights(
			lower_node,
			[
				Vector3(61.0, CHOIR_FLOOR + 1.8, AXIS),
				Vector3(55.0, CHOIR_FLOOR + 2.6, AXIS),
				Vector3(47.6, FLOOR + 1.6, -13.5),
				Vector3(47.6, FLOOR + 1.6, -6.5),
				Vector3(24.0, 4.5, AXIS),
				Vector3(36.0, 4.5, AXIS),
				Vector3(16.6, 3.0, AXIS),
			]
		)
	)
	return node


## Plain (unstepped) gable: base corners `a`, `b`, apex over their middle,
## `thick` deep behind the outward face `out`. Mendicant and claustral gables
## stayed plain; the crow-stepped burgher gable is a later urban fashion here.
static func _gable(
	shell: CityBuildingBuilder.Shell,
	a: Vector3,
	b: Vector3,
	apex_y: float,
	out: Vector3,
	thick: float,
	key := "wall:limestone"
) -> void:
	var top := (a + b) * 0.5
	top.y = apex_y
	var back := -out * thick
	shell.tri_out(key, a, b, top, Kit.STONE, out)
	shell.tri_out(key, a + back, b + back, top + back, Kit.STONE, -out)
	for edge: Array in [[a, top], [top, b]]:
		var p: Vector3 = edge[0]
		var q: Vector3 = edge[1]
		var up := (q - p).cross(out).normalized()
		if up.y < 0.0:
			up = -up
		shell.quad_out("ashlar", p, q, q + back, p + back, Kit.ASHLAR, up)


## Two-stage buttress against a wall at `at` (foot on the wall face), standing
## out along `out`, with sloped ashlar weatherings.
static func _buttress(
	shell: CityBuildingBuilder.Shell,
	at: Vector3,
	out: Vector3,
	width: float,
	depth: float,
	height: float
) -> void:
	var side := Vector3(-out.z, 0, out.x)
	var stages: Array = [[0.0, height * 0.55, depth], [height * 0.55, height, depth * 0.65]]
	for st: Array in stages:
		var y0: float = st[0]
		var y1: float = st[1]
		var d: float = st[2]
		var p0 := at - side * width * 0.5 + Vector3(0, y0 - 0.6, 0)
		var p1 := at + side * width * 0.5 + out * d + Vector3(0, y1, 0)
		CitySiteProps._box(
			shell,
			"wall:limestone",
			Vector3(minf(p0.x, p1.x), p0.y, minf(p0.z, p1.z)),
			Vector3(maxf(p0.x, p1.x), p1.y, maxf(p0.z, p1.z)),
			Color.WHITE
		)
		var e := side * (width * 0.5 + 0.05)
		var foot := at + out * (d + 0.05) + Vector3(0, y1, 0)
		var head := at + Vector3(0, y1 + d * 0.6, 0)
		shell.quad_out(
			"ashlar",
			foot - e,
			foot + e,
			head + e,
			head - e,
			Kit.ASHLAR,
			(out + Vector3.UP).normalized()
		)


## Open timber roof: tie beams with king posts every bay (mendicant halls of
## the period were often unvaulted; the vaults here are later).
static func _tie_beams(roof: CityBuildingBuilder.Shell, ridge: float) -> void:
	var x := X0 + THICK + 1.4
	while x < X1 - THICK:
		var south := Vector3(x, TIE_Y, ZS - THICK + 0.2)
		Kit.bar(roof, "timber", Vector3(x, TIE_Y, ZN + THICK - 0.2), south, 0.32, Kit.OAK_DARK)
		var post := Vector3(x, TIE_Y, AXIS)
		Kit.bar(roof, "timber", post, Vector3(x, ridge - 0.3, AXIS), 0.22, Kit.OAK_DARK)
		x += 3.6


## Small timber bell turret on the ridge over the rood screen, louvred, under
## a shingled helm with an iron cross.
static func _bell_turret(roof: CityBuildingBuilder.Shell, ridge: float) -> void:
	var c := Vector2(SCREEN_X, AXIS)
	var h := 0.7
	CitySiteProps._box(
		roof,
		"timber",
		Vector3(c.x - h, ridge - 0.9, c.y - h),
		Vector3(c.x + h, ridge + 2.4, c.y + h),
		Kit.OAK_DARK * 0.9
	)
	for n: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var f := c + n * (h + 0.01)
		var t := Vector2(-n.y, n.x) * 0.3
		var lo := (
			Vector2(minf(f.x - t.x, f.x + t.x), minf(f.y - t.y, f.y + t.y)) - Vector2.ONE * 0.005
		)
		var hi := (
			Vector2(maxf(f.x - t.x, f.x + t.x), maxf(f.y - t.y, f.y + t.y)) + Vector2.ONE * 0.005
		)
		CitySiteProps._box(
			roof,
			"dark",
			Vector3(lo.x, ridge + 0.9, lo.y),
			Vector3(hi.x, ridge + 2.0, hi.y),
			Color(0.08, 0.07, 0.06)
		)
	Kit.pyramid_roof(roof, c, h, ridge + 2.4, ridge + 4.4)


## Nave flags with ledger slabs of buried patrons, steps up into the choir,
## altars, the rood over the screen, a pulpit for the preachers and the
## friars' stalls. Returns the boxes that shade the window light.
static func _interior(shell: CityBuildingBuilder.Shell, rng: RandomNumberGenerator) -> Array[AABB]:
	var occluders: Array[AABB] = []
	var zn := ZN + THICK
	var zs := ZS - THICK
	var nave := Rect2(X0 + THICK, zn, SCREEN_X + 0.4 - X0 - THICK, zs - zn)
	Kit.flag_floor(shell, nave, FLOOR, rng, 0.12)
	Kit.flag_floor(shell, Rect2(STEPS_X, zn, X1 - THICK - STEPS_X, zs - zn), CHOIR_FLOOR, rng, 0.2)
	# Through the west portal and the cloister door.
	Kit.flag_floor(shell, Rect2(X0, AXIS - 1.2, THICK, 2.4), FLOOR, rng)
	Kit.flag_floor(shell, Rect2(40.0, ZN, 2.0, THICK), FLOOR, rng)
	for k in 3:
		var x0 := SCREEN_X + 0.4 + k * 0.4
		var h := FLOOR + (CHOIR_FLOOR - FLOOR) * (k + 1) / 3.0
		CitySiteProps._box(
			shell, "ashlar", Vector3(x0, FLOOR - 0.01, zn), Vector3(STEPS_X, h, zs), Kit.ASHLAR
		)
	# Friars' stalls along both choir walls: seat, desk and a tall back. The
	# north row leaves a gap at the sacristy door (x 56..58).
	var runs := [[zn, 51.2, 56.0], [zn, 58.0, 60.2], [zs, 51.2, 60.2]]
	for run: Array in runs:
		var z_wall: float = run[0]
		var x0: float = run[1]
		var length: float = float(run[2]) - x0
		var inward := 1.0 if z_wall == zn else -1.0
		var seat := AABB(
			Vector3(x0, CHOIR_FLOOR, minf(z_wall, z_wall + inward * 0.62)),
			Vector3(length, 0.46, 0.62)
		)
		CitySiteProps._box(shell, "timber", seat.position, seat.end, Kit.OAK_DARK)
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(x0, CHOIR_FLOOR, minf(z_wall, z_wall + inward * 0.12)),
			Vector3(x0 + length, CHOIR_FLOOR + 2.3, maxf(z_wall, z_wall + inward * 0.12)),
			Kit.OAK_DARK * 0.8
		)
		var desk := AABB(
			Vector3(x0, CHOIR_FLOOR, minf(z_wall + inward * 1.2, z_wall + inward * 1.5)),
			Vector3(length, 1.0, 0.3)
		)
		CitySiteProps._box(shell, "timber", desk.position, desk.end, Kit.OAK)
		occluders.append(seat)
		occluders.append(desk)
	Furnish.altar(shell, Vector3(62.1, CHOIR_FLOOR, AXIS), 2.4, true)
	Furnish.altar(shell, Vector3(48.4, FLOOR, -13.6), 1.4, false)
	Furnish.altar(shell, Vector3(48.4, FLOOR, -6.4), 1.4, false)
	Furnish.rood(shell, SCREEN_X + 0.2, 6.4, AXIS - 3.0, AXIS + 3.0)
	Furnish.pulpit(shell, Vector3(33.0, FLOOR, zs - 0.6), zs - 0.2, FLOOR)
	Furnish.statue(shell, Vector3(X0 + THICK + 0.1, 3.2, -14.0), Vector3(1, 0, 0), Furnish.RED)
	Furnish.statue(shell, Vector3(X0 + THICK + 0.1, 3.2, -6.0), Vector3(1, 0, 0), Furnish.BLUE)
	return occluders


## West, north and east ranges and the brewhouse, tile roofs meeting in
## valleys, plain gables where an end shows. Ground floors after Kuehnert's
## plan are enterable (sacristy, chapter house, dormitory stair, old refectory,
## kitchen, stores, granary, lay brothers' hall); the dormitory upstairs is not.
## Walls are cut at head height (`Ranges/Upper`) and the roofs, ceilings and
## the chapter-house vault are separate meshes, so the room cutaway lifts them.
static func _ranges(site: CitySite, fabric: Array, rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "Ranges"
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	var ceilings := CityBuildingBuilder.Shell.new()
	Kit.walls(body, glass, fabric, Kit.GLAZING.get(site.id, 0))
	for w: Dictionary in fabric:
		_shutters(body, w)
	_range_rooms(body, ceilings, rng)
	# West range (6.5..15 x -52..-21), eave 7.5: its roof runs along z.
	var w_ridge := 7.5 + 4.25 * tan(deg_to_rad(50.0))
	var south := Vector3(0, 0, 1)
	var north := Vector3(0, 0, -1)
	_gable(body, Vector3(6.5, 7.5, -21.0), Vector3(15.0, 7.5, -21.0), w_ridge, south, 0.8)
	_gable(body, Vector3(15.0, 7.5, -52.0), Vector3(6.5, 7.5, -52.0), w_ridge, north, 0.8)
	# North range (15..52 x -52..-43), eave 6.5: the roof runs on into the
	# west and east ranges' roofs, so the valleys form where they cross.
	Kit.gable_roof(roof, 10.75, 57.0, -52.0, -43.0, 6.5, 50.0, 0.4)
	CitySiteProps._box(
		body,
		"wall:limestone",
		Vector3(KITCHEN_STACK.x - 0.6, 5.0, KITCHEN_STACK.z - 0.6),
		Vector3(KITCHEN_STACK.x + 0.6, KITCHEN_STACK.y, KITCHEN_STACK.z + 0.6),
		Color(0.72, 0.68, 0.62)
	)
	# East range (52..62 x -52..-18.5), eave 8: the roof dies into the church
	# roof's north slope.
	var e_ridge := 8.0 + 5.0 * tan(deg_to_rad(50.0))
	_gable(body, Vector3(62.0, 8.0, -52.0), Vector3(52.0, 8.0, -52.0), e_ridge, north, 0.8)
	# Brewhouse (63.5..71.2 x -51.2..-42), shingled, ridge along x.
	var b_ridge := 4.2 + 4.6 * tan(deg_to_rad(45.0))
	_gable(body, Vector3(63.5, 4.2, -42.0), Vector3(63.5, 4.2, -51.2), b_ridge, Vector3.LEFT, 0.6)
	_gable(body, Vector3(71.2, 4.2, -51.2), Vector3(71.2, 4.2, -42.0), b_ridge, Vector3.RIGHT, 0.6)
	Kit.gable_roof(roof, 63.2, 71.5, -51.2, -42.0, 4.2, 45.0, 0.4, "roof:shingle")
	var parts := body.split_at(CUT)
	var lower: CityBuildingBuilder.Shell = parts[0]
	Kit.cut_caps(lower, fabric, CUT)
	var lower_node := Kit.mesh("Lower", lower)
	var upper_node := Kit.mesh("Upper", parts[1])
	var glass_parts := glass.split_at(CUT)
	lower_node.add_child(Kit.mesh("GlassLow", glass_parts[0]))
	upper_node.add_child(Kit.mesh("Glass", glass_parts[1]))
	var ceiling_node := Kit.mesh("Ceilings", ceilings)
	Kit.bind_site_washes([lower_node, upper_node, ceiling_node], site, FLOOR)
	node.add_child(lower_node)
	node.add_child(upper_node)
	node.add_child(ceiling_node)
	node.add_child(Kit.mesh("RangeRoofs", roof))
	node.add_child(_roof_along_z("WestRoof", 6.5, 15.0, -52.0, -21.0, 7.5, 50.0, 0.4))
	node.add_child(_roof_along_z("EastRoof", 52.0, 62.0, -52.0, -15.5, 8.0, 50.0, 0.4))
	(
		Furnish
		. lights(
			lower_node,
			[
				Vector3(57.0, 2.6, -29.1),
				Vector3(57.0, 3.0, -44.5),
				Vector3(22.0, 1.6, -49.2),
				Vector3(10.75, 2.8, -42.0),
			]
		)
	)
	return node


## Ground-floor rooms of the ranges: floors, boarded ceilings under the upper
## floor, and the fixed furniture that is masonry or joinery (movable pieces
## are catalogue dressing in the manifest). Chapter house: a vault on one
## central pillar over a stone bench round the walls, the prior's seat and a
## lectern; the day stair to the dormitory.
static func _range_rooms(
	body: CityBuildingBuilder.Shell, ceilings: CityBuildingBuilder.Shell, rng: RandomNumberGenerator
) -> void:
	var flags: Array[Rect2] = [
		Rect2(52.8, -24.0, 8.4, 5.5),
		Rect2(52.8, -33.6, 8.4, 9.0),
		Rect2(52.8, -37.2, 8.4, 3.0),
		Rect2(52.8, -51.2, 8.4, 13.4),
		Rect2(7.3, -51.2, 6.9, 21.2),
	]
	for k in flags.size():
		var y := CHOIR_FLOOR if k == 0 else FLOOR
		Kit.flag_floor(body, flags[k], y, rng, 0.0)
	# Beaten earth in the kitchen, stores and granary.
	var earth: Array[Rect2] = [
		Rect2(15.0, -51.2, 15.0, 7.4), Rect2(30.6, -51.2, 21.4, 7.4), Rect2(7.3, -29.4, 6.9, 7.6)
	]
	for r: Rect2 in earth:
		var a := Vector3(r.position.x, FLOOR, r.position.y)
		var b := Vector3(r.end.x, FLOOR, r.end.y)
		body.quad_out(
			"earth",
			a,
			Vector3(b.x, FLOOR, a.z),
			b,
			Vector3(a.x, FLOOR, b.z),
			Color.WHITE,
			Vector3.UP
		)
	# Boarded ceilings with joists (the chapter house is vaulted instead).
	for r: Rect2 in [
		Rect2(52.8, -24.0, 8.4, 5.5),
		Rect2(52.8, -51.2, 8.4, 17.0),
		Rect2(15.0, -51.2, 37.0, 7.4),
		Rect2(7.3, -51.2, 6.9, 29.4),
	]:
		var y := RANGE_CEIL
		ceilings.quad_out(
			"timber",
			Vector3(r.position.x, y, r.position.y),
			Vector3(r.end.x, y, r.position.y),
			Vector3(r.end.x, y, r.end.y),
			Vector3(r.position.x, y, r.end.y),
			Kit.OAK_DARK * 0.85,
			Vector3.DOWN
		)
		var long_x := r.size.x > r.size.y
		var t := 0.6
		while t < (r.size.x if long_x else r.size.y) - 0.3:
			var p0 := (
				Vector3(r.position.x + t, y - 0.12, r.position.y)
				if long_x
				else Vector3(r.position.x, y - 0.12, r.position.y + t)
			)
			var p1 := (
				Vector3(r.position.x + t, y - 0.12, r.end.y)
				if long_x
				else Vector3(r.end.x, y - 0.12, r.position.y + t)
			)
			Kit.bar(ceilings, "timber", p0, p1, 0.2, Kit.OAK_DARK)
			t += 1.1
	# Chapter house: four rib-vaulted bays on one octagonal pillar.
	var c := Vector2(57.0, -29.1)
	for bay: Rect2 in [
		Rect2(52.8, -33.6, 4.2, 4.5),
		Rect2(57.0, -33.6, 4.2, 4.5),
		Rect2(52.8, -29.1, 4.2, 4.5),
		Rect2(57.0, -29.1, 4.2, 4.5),
	]:
		Kit.rib_vault(ceilings, bay, CHAPTER_SPRING, CHAPTER_CROWN, Color(0.72, 0.71, 0.67))
	Kit.pillar(body, Vector3(c.x, FLOOR, c.y), 0.38, CHAPTER_SPRING - FLOOR)
	for r: Rect2 in [
		Rect2(52.8, -33.6, 8.4, 0.5),
		Rect2(52.8, -25.1, 8.4, 0.5),
		Rect2(60.7, -33.1, 0.5, 8.0),
		Rect2(52.8, -33.1, 0.5, 2.9),
		Rect2(52.8, -28.0, 0.5, 2.9),
	]:
		CitySiteProps._box(
			body,
			"ashlar",
			Vector3(r.position.x, FLOOR, r.position.y),
			Vector3(r.end.x, FLOOR + 0.45, r.end.y),
			Kit.ASHLAR
		)
	# The prior's seat: a raised back in the middle of the east bench.
	CitySiteProps._box(
		body,
		"ashlar",
		Vector3(61.0, FLOOR, c.y - 0.6),
		Vector3(61.2, FLOOR + 1.9, c.y + 0.6),
		Kit.ASHLAR
	)
	# Lectern for the reading of the martyrology and the rule.
	var post := Vector3(59.6, FLOOR, c.y)
	Kit.bar(body, "timber", post, post + Vector3(0, 1.05, 0), 0.12, Kit.OAK_DARK)
	CitySiteProps._box(
		body,
		"timber",
		Vector3(59.35, FLOOR + 1.05, c.y - 0.3),
		Vector3(59.85, FLOOR + 1.12, c.y + 0.3),
		Kit.OAK_DARK
	)
	# Lay brothers' stair to their dormitory over the hall: rising west along
	# the north wall.
	for k in 8:
		CitySiteProps._box(
			body,
			"timber",
			Vector3(7.3, FLOOR, -51.2),
			Vector3(12.0 - k * 0.55, FLOOR + (k + 1) * (RANGE_CEIL - FLOOR) / 8.0, -50.2),
			Kit.OAK_DARK * (0.9 if k % 2 == 0 else 0.8)
		)
	# Day stair to the dormitory: solid timber flight rising east.
	var steps := 10
	for k in steps:
		var x0 := 55.0 + k * 0.62
		CitySiteProps._box(
			body,
			"timber",
			Vector3(x0, FLOOR, -37.2),
			Vector3(61.2, FLOOR + (k + 1) * (RANGE_CEIL - FLOOR) / steps, -34.2),
			Kit.OAK_DARK * (0.9 if k % 2 == 0 else 0.8)
		)


## Gable roof with its ridge along z over x0..x1, z0..z1. Kit.gable_roof only
## runs ridges along x, so it is built along x and the node turned a quarter
## (+90 degrees about y maps local x to world -z and local z to world x).
static func _roof_along_z(
	node_name: String,
	x0: float,
	x1: float,
	z0: float,
	z1: float,
	eave: float,
	pitch: float,
	overhang: float
) -> MeshInstance3D:
	var shell := CityBuildingBuilder.Shell.new()
	Kit.gable_roof(shell, -z1, -z0, x0, x1, eave, pitch, overhang)
	var inst := Kit.mesh(node_name, shell)
	inst.rotation.y = PI * 0.5
	return inst


## Closed plank shutters (windows) and shut ledged doors in a range wall's
## blind openings marked `shutter`, set back in the recess.
static func _shutters(shell: CityBuildingBuilder.Shell, w: Dictionary) -> void:
	var a := Kit._v2(w["a"])
	var b := Kit._v2(w["b"])
	var dir := (b - a).normalized()
	var out := Vector2(-dir.y, dir.x)
	if out.dot(Kit._v2(w["inside"]) - (a + b) * 0.5) > 0.0:
		out = -out
	for op: Dictionary in w.get("openings", []):
		if not bool(op.get("shutter", false)):
			continue
		var half := float(op["w"]) * 0.5 - 0.04
		var c := a + dir * float(op["s"]) - out * 0.16
		var p := c - dir * half
		var q := c + dir * half - out * 0.06
		var sill := float(op.get("sill", 0.0))
		var top := float(op.get("spring", sill + 1.0))
		var door := sill < 0.05
		var tone := Kit.OAK_DARK * (0.75 if door else 0.62)
		tone.a = 1.0
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(minf(p.x, q.x), sill, minf(p.y, q.y)),
			Vector3(maxf(p.x, q.x), top, maxf(p.y, q.y)),
			tone
		)
		if door:
			# Two iron strap hinges across the leaf.
			for y: float in [0.5, top - 0.5]:
				var r := c - dir * half + out * 0.02
				var s := c + dir * half * 0.6 + out * 0.04
				CitySiteProps._box(
					shell,
					"dark",
					Vector3(minf(r.x, s.x), y, minf(r.y, s.y)),
					Vector3(maxf(r.x, s.x), y + 0.06, maxf(r.y, s.y)),
					Kit.IRON
				)


## Cloister: the arcade walls round the garth (from the fabric), flagged walks
## and their lean-to roofs (`Cloister/Roof`, lifted while Kalev is in a walk).
static func _cloister(fabric: Array, rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "Cloister"
	var body := CityBuildingBuilder.Shell.new()
	var unused_glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	Kit.walls(body, unused_glass, fabric)
	Kit.flag_floor(body, Rect2(15.0, -21.5, 37.0, 3.0), FLOOR, rng)
	Kit.flag_floor(body, Rect2(15.0, -43.0, 37.0, 3.0), FLOOR, rng)
	Kit.flag_floor(body, Rect2(15.0, -40.0, 3.0, 18.5), FLOOR, rng)
	Kit.flag_floor(body, Rect2(49.0, -40.0, 3.0, 18.5), FLOOR, rng)
	var hi := WALK_HIGH
	var lo := WALK_LOW
	# South walk against the church, north walk against the north range,
	# west and east walks against their ranges; each drips onto the garth.
	var south := [Vector3(15, hi, -18.5), Vector3(52, hi, -18.5)]
	_lean(roof, south[0], south[1], Vector3(52, lo, -21.8), Vector3(15, lo, -21.8))
	var north := [Vector3(15, hi, -43), Vector3(52, hi, -43)]
	_lean(roof, north[0], north[1], Vector3(52, lo, -39.7), Vector3(15, lo, -39.7))
	var west := [Vector3(15, hi, -43), Vector3(15, hi, -18.5)]
	_lean(roof, west[0], west[1], Vector3(18.3, lo, -18.5), Vector3(18.3, lo, -43))
	var east := [Vector3(52, hi, -43), Vector3(52, hi, -18.5)]
	_lean(roof, east[0], east[1], Vector3(48.7, lo, -18.5), Vector3(48.7, lo, -43))
	node.add_child(Kit.mesh("Arcade", body))
	node.add_child(Kit.mesh("Roof", roof))
	return node


## Mono-pitch tile roof from the high edge hi_a-hi_b down to lo_b-lo_a, with
## a boarded underside.
static func _lean(
	roof: CityBuildingBuilder.Shell, hi_a: Vector3, hi_b: Vector3, lo_b: Vector3, lo_a: Vector3
) -> void:
	var face := (hi_b - hi_a).cross(lo_a - hi_a).normalized()
	if face.y < 0.0:
		face = -face
	var run := hi_a.distance_to(lo_a)
	var span := hi_a.distance_to(hi_b)
	var uv_b := Vector2(span, 0)
	var uv_c := Vector2(span, run)
	var uv_d := Vector2(0, run)
	roof.tri_out("roof:tile", hi_a, hi_b, lo_b, Color.WHITE, face, Vector2.ZERO, uv_b, uv_c)
	roof.tri_out("roof:tile", hi_a, lo_b, lo_a, Color.WHITE, face, Vector2.ZERO, uv_c, uv_d)
	roof.quad_out("timber", hi_a, hi_b, lo_b, lo_a, Kit.OAK_DARK * 0.8, -face)


static func _precinct(fabric: Array) -> MeshInstance3D:
	var body := CityBuildingBuilder.Shell.new()
	var unused_glass := CityBuildingBuilder.Shell.new()
	Kit.walls(body, unused_glass, fabric)
	return Kit.mesh("Precinct", body)


## The garth: the friary well (poi.well.dominican) and three plank-edged herb
## beds on the grass.
static func _garth(root: Node3D, site: CitySite, plan: CityPlan) -> void:
	var garth: Dictionary = site.data.get("garth", {})
	if garth.is_empty():
		return
	var at := Vector2(garth["well"][0], garth["well"][1])
	var well := Node3D.new()
	well.name = "GarthWell"
	well.position = Vector3(at.x, plan.ground_height(site.to_world(at)) - site.level, at.y)
	well.scale = Vector3.ONE * LEGACY_UNIT_M
	WellModels.add_model(well)
	root.add_child(well)
	var shell := CityBuildingBuilder.Shell.new()
	var beds: Array[Rect2] = [
		Rect2(21.0, -37.5, 6.0, 3.2), Rect2(21.0, -25.6, 6.0, 3.2), Rect2(41.0, -37.5, 5.4, 3.2)
	]
	for bed: Rect2 in beds:
		var y := plan.ground_height(site.to_world(bed.get_center())) - site.level
		# Dug soil: "dark" takes the vertex tone ("earth" ignores it and reads as sand).
		CitySiteProps._box(
			shell,
			"dark",
			Vector3(bed.position.x, y - 0.2, bed.position.y),
			Vector3(bed.end.x, y + 0.14, bed.end.y),
			Color(0.26, 0.2, 0.15)
		)
		for edge: Array in [
			[bed.position, Vector2(bed.end.x, bed.position.y)],
			[Vector2(bed.position.x, bed.end.y), bed.end],
			[bed.position, Vector2(bed.position.x, bed.end.y)],
			[Vector2(bed.end.x, bed.position.y), bed.end],
		]:
			var p: Vector2 = edge[0]
			var q: Vector2 = edge[1]
			var p3 := Vector3(p.x, y + 0.1, p.y)
			Kit.bar(shell, "timber", p3, Vector3(q.x, y + 0.1, q.y), 0.08, Kit.OAK_DARK)
	root.add_child(Kit.mesh("GarthBeds", shell))


## Service yard dressing: the shared site props (cart, trade goods), the
## district life props (keg stack, malt, staves, firewood, fish table, tub)
## and catalogue baskets. No new models.
static func _yard(root: Node3D, site: CitySite, plan: CityPlan) -> void:
	var yard := Node3D.new()
	yard.name = "Yard"
	root.add_child(yard)
	for item: Dictionary in site.data.get("dressing", []):
		var local := Vector2(item["at"][0], item["at"][1])
		var world := site.to_world(local)
		# Indoors (refectory, kitchen...) the item stands on the room floor.
		var room_floor := site.floor_at(world)
		var ground := (
			float(room_floor["height"]) - site.level
			if not room_floor.is_empty()
			else plan.ground_height(world) - site.level
		)
		ground += float(item.get("y", 0.0))
		match String(item["kind"]):
			"life_prop":
				var node := Node3D.new()
				node.name = String(item["id"]).replace(".", "_")
				node.position = Vector3(local.x, ground, local.y)
				node.rotation.y = -deg_to_rad(float(item.get("rotation_deg", 0.0)))
				var legacy := Node3D.new()
				legacy.scale = Vector3.ONE * LEGACY_UNIT_M
				node.add_child(legacy)
				LifeProps.add_to(legacy, StringName(item["prop"]), {"id": StringName(item["id"])})
				yard.add_child(node)
			"catalog":
				var model := CityInteriors._template(String(item["object"]), "")
				if model == null:
					continue
				model.name = String(item["id"]).replace(".", "_")
				model.position = Vector3(local.x, ground, local.y)
				model.rotation.y = -deg_to_rad(float(item.get("rotation_deg", 0.0)))
				yard.add_child(model)
			_:
				CitySiteProps.add(yard, item, ground)
