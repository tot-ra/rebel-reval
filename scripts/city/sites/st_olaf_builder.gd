extends RefCounted

## site.st_olaf (ADR 0032): St Olaf's parish church in spring 1343, set into
## the surviving church's site with its west tower on the tower's position.
## Period rule: the upper tower (1364+), the record spire (c. 1450), the
## post-1433 basilica with clerestory, star vaults and long choir, and the
## later fittings are left out. Attested for 1343: a short church with a
## massive west tower (walls ~3.2 m), a vaulted hall nave (vaults c. 1330) and
## a small chancel, the tower unfinished. Unrecorded details use a plainer
## form of the later church: grey limestone rubble outside; inside a three-
## aisle hall of four bays on square piers under quadripartite rib vaults
## with red-ochre brick ribs, lime-washed walls, lancets with stained glass,
## plank floor and benches. The tower stops at its lower stage with a
## provisional timber belfry under a shingle cap, a putlog scaffold and a
## hoist; a masons' yard stands at its foot.

const Kit := preload("res://scripts/city/sites/site_kit.gd")
const Furnish := preload("res://scripts/city/sites/church_furnishings.gd")
const FLOOR := 0.12
const CHOIR_FLOOR := 0.57
const CUT := FLOOR + CityBuildingBuilder.CUT_HEIGHT
const TX := 14.0
const NX := 44.0
const CX := 54.0
const NZ := 12.0
const CZ := 5.0
const TZ := 7.0
const EAVE := 13.0
const CHOIR_EAVE := 10.0
const TOWER_TOP := 30.0
const PITCH := 42.0
const SPRING := 8.0
const CROWN := 12.3
const PIER_X: Array[float] = [21.5, 29.0, 36.5]
const PIER_Z := 4.0


static func build(site: CitySite, _plan: CityPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_st_olaf"
	var church := Node3D.new()
	church.name = "Church"
	root.add_child(church)
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(site.id))
	var fabric: Array = site.data["fabric"]
	Kit.walls(body, glass, fabric, Kit.GLAZING.get(site.id, 0))
	_gables(body)
	_tower_top(body, roof, rng)
	_roofs(roof)
	_vaults(roof)
	var occluders := _interior(body, rng, site.data.get("benches", []))
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
	church.add_child(lower_node)
	church.add_child(upper_node)
	church.add_child(roof_node)
	ChurchSunlight.apply(
		church, lower_node, upper_node, roof_node, fabric, Kit.GLAZING.get(site.id, 0), occluders
	)
	Furnish.coronas(
		upper_node,
		[Vector2(18.6, 0.0), Vector2(25.25, 0.0), Vector2(32.75, 0.0), Vector2(39.4, 0.0)],
		4.8,
		CROWN - 0.1
	)
	(
		Furnish
		. lights(
			lower_node,
			[
				Vector3(51.6, CHOIR_FLOOR + 1.8, 0.0),
				Vector3(40.6, FLOOR + 1.6, -7.6),
				Vector3(40.6, FLOOR + 1.6, 7.6),
				Vector3(22.0, 4.5, 0.0),
				Vector3(32.0, 4.5, 0.0),
				Vector3(7.0, 3.0, 0.0),
			]
		)
	)
	for item: Dictionary in site.data.get("dressing", []):
		var world := site.to_world(Vector2(item["at"][0], item["at"][1]))
		CitySiteProps.add(root, item, _plan.ground_height(world) - site.level)
	return root


## Crow-stepped east gables of the hall and the chancel, with blind niches.
static func _gables(shell: CityBuildingBuilder.Shell) -> void:
	var slope := tan(deg_to_rad(PITCH))
	Kit.stepped_gable(shell, NX, 1.0, -NZ, NZ, EAVE, EAVE + NZ * slope + 0.8, 8, 1.6, 5)
	var cslope := tan(deg_to_rad(50.0))
	Kit.stepped_gable(
		shell, CX, 1.0, -CZ, CZ, CHOIR_EAVE, CHOIR_EAVE + CZ * cslope + 0.5, 4, 1.3, 3
	)


static func _roofs(roof: CityBuildingBuilder.Shell) -> void:
	Kit.gable_roof(roof, TX, NX - 0.8, -NZ, NZ, EAVE, PITCH, 0.5)
	Kit.gable_roof(roof, NX, CX - 0.65, -CZ, CZ, CHOIR_EAVE, 50.0, 0.4)


## Rib vaults: twelve bays of the hall, the chancel, the tower hall.
static func _vaults(roof: CityBuildingBuilder.Shell) -> void:
	var xs: Array[float] = [TX + 1.6, PIER_X[0], PIER_X[1], PIER_X[2], NX - 1.6]
	var zs: Array[float] = [-NZ + 1.6, -PIER_Z, PIER_Z, NZ - 1.6]
	for i in 4:
		for j in 3:
			Kit.rib_vault(
				roof, Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j]), SPRING, CROWN
			)
	Kit.rib_vault(roof, Rect2(NX, -CZ + 1.3, CX - 1.3 - NX, (CZ - 1.3) * 2.0), 6.4, 9.4)
	Kit.rib_vault(roof, Rect2(3.2, -3.8, 7.6, 7.6), 6.0, 9.0)


## The unfinished tower head: the top courses racked back in steps, a
## provisional timber belfry under a shingled cap, a putlog scaffold on the
## north and west faces with a hoist jib.
static func _tower_top(
	body: CityBuildingBuilder.Shell, roof: CityBuildingBuilder.Shell, rng: RandomNumberGenerator
) -> void:
	var t := 3.2
	# Racked-back courses: irregular stone blocks on the wall heads.
	for side in 4:
		for k in 9:
			var h := TOWER_TOP + 0.45 * rng.randi_range(0, 3) * (1.0 - absf(k - 4) / 5.0)
			var u := 0.3 + k * (14.0 - 0.6) / 9.0
			var lo: Vector3
			var hi: Vector3
			match side:
				0:
					lo = Vector3(0.0, TOWER_TOP, u - TZ)
					hi = Vector3(t, h + 0.05, u - TZ + 1.4)
				1:
					lo = Vector3(TX - t, TOWER_TOP, u - TZ)
					hi = Vector3(TX, h + 0.05, u - TZ + 1.4)
				2:
					lo = Vector3(u, TOWER_TOP, -TZ)
					hi = Vector3(u + 1.4, h + 0.05, -TZ + t)
				_:
					lo = Vector3(u, TOWER_TOP, TZ - t)
					hi = Vector3(u + 1.4, h + 0.05, TZ)
			if h > TOWER_TOP + 0.1:
				CitySiteProps._box(
					body, "wall:limestone", lo, hi, Color.WHITE * rng.randf_range(0.85, 1.0)
				)
	# Bell frame: four oak posts and braces inside the walls, bells hanging.
	var c := Vector2(7.0, 0.0)
	var f := 2.3
	var top := TOWER_TOP + 4.2
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Kit.bar(
				roof,
				"timber",
				Vector3(c.x + sx * f, TOWER_TOP - 2.0, c.y + sz * f),
				Vector3(c.x + sx * f, top, c.y + sz * f),
				0.3,
				Kit.OAK_DARK
			)
		Kit.bar(
			roof,
			"timber",
			Vector3(c.x + sx * f, top - 1.6, c.y - f),
			Vector3(c.x + sx * f, top - 1.6, c.y + f),
			0.25,
			Kit.OAK_DARK
		)
		Kit.bar(
			roof,
			"timber",
			Vector3(c.x - f, top - 1.6, c.y + sx * f),
			Vector3(c.x + f, top - 1.6, c.y + sx * f),
			0.25,
			Kit.OAK_DARK
		)
	for b in 2:
		var bc := Vector3(c.x + (b - 0.5) * 2.0, top - 2.6, c.y)
		for j in 8:
			var a0 := TAU * j / 8.0
			var a1 := TAU * (j + 1) / 8.0
			var p0 := Vector3(cos(a0), 0, sin(a0))
			var p1 := Vector3(cos(a1), 0, sin(a1))
			roof.quad_out(
				"dark",
				bc + p0 * 0.75,
				bc + p1 * 0.75,
				bc + p1 * 0.42 + Vector3(0, 0.95, 0),
				bc + p0 * 0.42 + Vector3(0, 0.95, 0),
				Color(0.42, 0.3, 0.17),
				(p0 + p1).normalized()
			)
	# Shingled cap over the frame, louvred boards round it.
	Kit.pyramid_roof(roof, c, f + 0.6, top, top + 4.5)
	for side: float in [-1.0, 1.0]:
		for k in 6:
			var y := TOWER_TOP + 0.6 + k * 0.55
			roof.quad_out(
				"timber",
				Vector3(c.x - f - 0.3, y, c.y + side * (f + 0.3)),
				Vector3(c.x + f + 0.3, y, c.y + side * (f + 0.3)),
				Vector3(c.x + f + 0.3, y + 0.35, c.y + side * (f + 0.45)),
				Vector3(c.x - f - 0.3, y + 0.35, c.y + side * (f + 0.45)),
				Kit.OAK_DARK * 0.8,
				Vector3(0, 0.3, side)
			)
	# Putlog scaffold on the north and west faces: standards, ledgers, boards.
	var sc := Color(0.55, 0.47, 0.38)
	for k in 6:
		var x := 0.6 + k * 2.6
		Kit.bar(
			roof,
			"timber",
			Vector3(x, 0.0, -TZ - 1.4),
			Vector3(x, TOWER_TOP + 1.5, -TZ - 1.4),
			0.14,
			sc
		)
		Kit.bar(
			roof,
			"timber",
			Vector3(-1.4, 0.0, -TZ + x),
			Vector3(-1.4, TOWER_TOP + 1.5, -TZ + x),
			0.14,
			sc
		)
	for level: float in [6.0, 12.0, 18.0, 24.0, 29.0]:
		Kit.bar(
			roof, "timber", Vector3(-1.4, level, -TZ - 1.4), Vector3(TX, level, -TZ - 1.4), 0.12, sc
		)
		Kit.bar(roof, "timber", Vector3(-1.4, level, -TZ - 1.4), Vector3(-1.4, level, TZ), 0.12, sc)
		CitySiteProps._box(
			roof,
			"timber",
			Vector3(-1.4, level + 0.06, -TZ - 1.4),
			Vector3(TX, level + 0.1, -TZ - 0.05),
			sc * 0.9
		)
		CitySiteProps._box(
			roof,
			"timber",
			Vector3(-1.4, level + 0.06, -TZ - 1.4),
			Vector3(-0.05, level + 0.1, TZ),
			sc * 0.9
		)
		for k in 6:
			var x := 0.6 + k * 2.6
			Kit.bar(
				roof, "timber", Vector3(x, level, -TZ - 1.5), Vector3(x, level, -TZ + 0.6), 0.1, sc
			)
	# Hoist jib on the scaffold top with a rope to the yard.
	Kit.bar(
		roof,
		"timber",
		Vector3(3.0, TOWER_TOP + 1.5, -TZ - 1.4),
		Vector3(3.0, TOWER_TOP + 1.5, -TZ - 4.6),
		0.18,
		sc
	)
	Kit.bar(
		roof,
		"timber",
		Vector3(3.0, TOWER_TOP + 1.5, -TZ - 4.5),
		Vector3(3.0, 1.2, -TZ - 4.5),
		0.035,
		Color(0.7, 0.62, 0.48)
	)


## Returns the piers and benches as boxes that shade the window light.
static func _interior(
	shell: CityBuildingBuilder.Shell, rng: RandomNumberGenerator, benches: Array
) -> Array[AABB]:
	var occluders: Array[AABB] = []
	Furnish.planks(shell, Rect2(TX + 1.6, -NZ + 1.6, NX - TX - 3.2, (NZ - 1.6) * 2.0), FLOOR, rng)
	Kit.flag_floor(shell, Rect2(3.2, -3.8, 7.6, 7.6), FLOOR, rng)
	Kit.flag_floor(
		shell, Rect2(NX, -CZ + 1.3, CX - 1.3 - NX, (CZ - 1.3) * 2.0), CHOIR_FLOOR, rng, 0.15
	)
	for k in 3:
		var x0 := NX - 2.6 + k * 0.6
		var h := FLOOR + (CHOIR_FLOOR - FLOOR) * (k + 1) / 3.0
		CitySiteProps._box(
			shell, "ashlar", Vector3(x0, FLOOR - 0.01, -3.4), Vector3(NX + 0.4, h, 3.4), Kit.ASHLAR
		)
	for x: float in PIER_X:
		for z: float in [-PIER_Z, PIER_Z]:
			occluders.append_array(
				Kit.square_pier(shell, Vector3(x, FLOOR, z), 0.75, SPRING - FLOOR)
			)
	for b: Dictionary in benches:
		occluders.append_array(
			Furnish.bench(
				shell, Vector3(float(b["at"][0]), FLOOR, float(b["at"][1])), float(b["len"])
			)
		)
	Furnish.font(shell, Vector3(17.0, FLOOR, -9.0))
	Furnish.altar(shell, Vector3(52.0, CHOIR_FLOOR, 0.0), 2.4, true)
	Furnish.altar(shell, Vector3(41.3, FLOOR, -7.6), 1.4, false)
	Furnish.altar(shell, Vector3(41.3, FLOOR, 7.6), 1.4, false)
	Furnish.rood(shell, NX - 0.8, 7.4, -3.7, 3.7)
	Furnish.pulpit(shell, Vector3(29.0, FLOOR, -4.95), -4.8, FLOOR)
	for x: float in PIER_X:
		Furnish.statue(
			shell,
			Vector3(x, 3.4, -PIER_Z + 0.75),
			Vector3(0, 0, 1),
			Furnish.RED if x < 30.0 else Furnish.BLUE
		)
		Furnish.statue(
			shell,
			Vector3(x, 3.4, PIER_Z - 0.75),
			Vector3(0, 0, -1),
			Furnish.BLUE if x < 30.0 else Furnish.RED
		)
	# Bell ropes down into the tower hall.
	for z: float in [-0.5, 0.5]:
		Kit.bar(
			shell,
			"timber",
			Vector3(7.0, 9.0, z),
			Vector3(7.0, 1.0, z),
			0.035,
			Color(0.68, 0.6, 0.45)
		)
	return occluders
