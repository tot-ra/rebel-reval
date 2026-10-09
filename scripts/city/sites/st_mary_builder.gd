extends RefCounted

## site.st_mary (ADR 0032): St Mary's cathedral on Toompea in spring 1343, a
## building site. The chancel of the early-14th-century phase with its
## polygonal apse and the vestry stand finished and in use; the new three-
## aisle basilica nave rises westwards: the easternmost bay is complete
## (arcade, clerestory, vaults, roof) and closed by a plank screen, then walls
## and piers stand at falling heights with ragged tops, the second bay's
## arches are turned on timber centering, the west front is a low wall with a
## site gate. A treadwheel crane works in the nave; scaffolding, a masons'
## lodge, stone stacks, a lime pit and a detached timber belfry fill the yards.
## Later features (the 1779 tower and helm, chapels, hatchments, pews, 1686
## pulpit) are left out; unrecorded details follow the church today,
## simplified: white render, white wash inside with grey stone arch edges,
## tracery windows with stained glass.

const Kit := preload("res://scripts/city/sites/site_kit.gd")
const Furnish := preload("res://scripts/city/sites/church_furnishings.gd")
const FLOOR := 0.12
const CHOIR_FLOOR := 0.57
const CUT := FLOOR + CityBuildingBuilder.CUT_HEIGHT
const W := -36.0
const NO := -18.0
const SO := 8.0
const AN := -10.5
const AS := 0.5
const SCREEN := -14.8
const EAST := -6.0
const CE := 14.0
const AX := -5.0
const APSE: Array[Vector2] = [
	Vector2(14.0, -10.5),
	Vector2(17.4, -9.1),
	Vector2(19.2, -5.0),
	Vector2(17.4, -0.9),
	Vector2(14.0, 0.5)
]
const RIB := Color(0.7, 0.69, 0.65)
const SCAFFOLD := Color(0.55, 0.47, 0.38)


static func build(site: CitySite, plan: CityPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_st_mary"
	var fabric: Array = site.data["fabric"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(site.id))
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	Kit.walls(body, glass, fabric, Kit.GLAZING.get(site.id, 0))
	for w: Dictionary in fabric:
		if bool(w.get("ragged", false)):
			_ragged(body, w, rng)
	_buttresses(body)
	_roofs(roof)
	_vaults(roof)
	_works(body, roof, rng)
	_interior(body, rng)
	var node := Node3D.new()
	node.name = "Cathedral"
	root.add_child(node)
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
	node.add_child(lower_node)
	node.add_child(upper_node)
	node.add_child(roof_node)
	ChurchSunlight.apply(
		node, lower_node, upper_node, roof_node, fabric, Kit.GLAZING.get(site.id, 0)
	)
	Furnish.coronas(upper_node, [Vector2(-10.4, AX), Vector2(4.0, AX)], 5.0, 12.8)
	(
		Furnish
		. lights(
			lower_node,
			[
				Vector3(12.0, CHOIR_FLOOR + 1.8, AX),
				Vector3(1.0, CHOIR_FLOOR + 2.0, AX),
				Vector3(-10.4, 4.0, AX),
				Vector3(6.0, CHOIR_FLOOR + 1.6, -13.2),
			]
		)
	)
	for item: Dictionary in site.data.get("dressing", []):
		var world := site.to_world(Vector2(item["at"][0], item["at"][1]))
		CitySiteProps.add(root, item, plan.ground_height(world) - site.level)
	root.add_child(_yard(site, plan, rng))
	return root


## Unfinished wall head: irregular courses of blocks stepping up and down
## along the top, a few loose stones and mortar tubs on it.
static func _ragged(
	shell: CityBuildingBuilder.Shell, w: Dictionary, rng: RandomNumberGenerator
) -> void:
	var a := Vector2(w["a"][0], w["a"][1])
	var b := Vector2(w["b"][0], w["b"][1])
	var inside := Vector2(w["inside"][0], w["inside"][1])
	var t := float(w["thick"])
	var y := float(w["y1"])
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var n := Vector2(-dir.y, dir.x)
	if n.dot(inside - (a + b) * 0.5) < 0.0:
		n = -n
	var s := 0.0
	while s < length - 0.2:
		var l := minf(rng.randf_range(0.5, 1.1), length - s)
		var h := 0.32 * rng.randi_range(0, 3)
		if h > 0.0:
			var p0 := a + dir * s
			var p1 := a + dir * (s + l - 0.03)
			var q0 := p0 + n * t
			var q1 := p1 + n * t
			var lo := Vector3(
				minf(minf(p0.x, p1.x), minf(q0.x, q1.x)),
				y,
				minf(minf(p0.y, p1.y), minf(q0.y, q1.y))
			)
			var hi := Vector3(
				maxf(maxf(p0.x, p1.x), maxf(q0.x, q1.x)),
				y + h,
				maxf(maxf(p0.y, p1.y), maxf(q0.y, q1.y))
			)
			CitySiteProps._box(
				shell, "wall:limestone", lo, hi, Color.WHITE * rng.randf_range(0.82, 1.0)
			)
		s += l


## Two-stage buttresses on the finished parts: aisle walls of the east bay,
## the chancel walls and the apse corners.
static func _buttresses(shell: CityBuildingBuilder.Shell) -> void:
	for z_face: float in [NO, SO]:
		var out := -1.0 if z_face == NO else 1.0
		for x: float in [SCREEN, EAST]:
			_buttress(shell, Vector3(x, 0.0, z_face), Vector3(0, 0, out), 1.2, 1.4, 8.5)
		for x: float in [-27.8, -21.0]:
			var h := 3.5 if x < -25.0 else 6.0
			_buttress(shell, Vector3(x, 0.0, z_face), Vector3(0, 0, out), 1.2, 1.4, h)
	for x: float in [4.0]:
		_buttress(shell, Vector3(x, 0.0, AS), Vector3(0, 0, 1), 1.1, 1.3, 11.0)
	for k in range(1, APSE.size() - 1):
		var p := APSE[k]
		var o := (p - Vector2(14.0, AX)).normalized()
		_buttress(shell, Vector3(p.x, 0.0, p.y), Vector3(o.x, 0, o.y), 1.0, 1.4, 11.0)
	_buttress(shell, Vector3(APSE[0].x, 0.0, APSE[0].y), Vector3(0, 0, -1), 1.0, 1.3, 11.0)
	_buttress(shell, Vector3(APSE[4].x, 0.0, APSE[4].y), Vector3(0, 0, 1), 1.0, 1.3, 11.0)


static func _buttress(
	shell: CityBuildingBuilder.Shell,
	at: Vector3,
	out: Vector3,
	width: float,
	depth: float,
	height: float
) -> void:
	var side := Vector3(-out.z, 0, out.x)
	for st: Array in [[0.0, height * 0.6, depth], [height * 0.6, height, depth * 0.6]]:
		var y0: float = st[0]
		var y1: float = st[1]
		var d: float = st[2]
		var c := at + out * (d * 0.5)
		var corners := [
			c - side * width * 0.5 - out * d * 0.5,
			c + side * width * 0.5 - out * d * 0.5,
			c + side * width * 0.5 + out * d * 0.5,
			c - side * width * 0.5 + out * d * 0.5,
		]
		for k in 4:
			var p: Vector3 = corners[k]
			var q: Vector3 = corners[(k + 1) % 4]
			var mid := (p + q) * 0.5 - c
			shell.quad_out(
				"render",
				p + Vector3(0, y0 - 0.6, 0),
				q + Vector3(0, y0 - 0.6, 0),
				q + Vector3(0, y1, 0),
				p + Vector3(0, y1, 0),
				Color.WHITE,
				mid
			)
		# Sloped weathering.
		var top_out := at + out * d
		shell.quad_out(
			"roof:tile",
			top_out - side * width * 0.55 + Vector3(0, y1, 0),
			top_out + side * width * 0.55 + Vector3(0, y1, 0),
			at + side * width * 0.55 + Vector3(0, y1 + d * 0.7, 0),
			at - side * width * 0.55 + Vector3(0, y1 + d * 0.7, 0),
			Color(0.9, 0.9, 0.9),
			out + Vector3.UP
		)


## Roofs: the finished east bay (nave gable, aisle lean-tos, a boarded
## temporary gable to the west), the chancel and the apse hip, the vestry.
static func _roofs(roof: CityBuildingBuilder.Shell) -> void:
	var nave_ridge := Kit.gable_roof(
		roof, SCREEN - 0.6, EAST + 0.6, AN - 0.6, AS + 0.6, 15.0, 50.0, 0.4
	)
	for side: Array in [[NO, AN - 0.6, -1.0], [AS + 0.6, SO, 1.0]]:
		var z_out: float = side[0] if side[2] < 0.0 else side[1]
		var z_in: float = side[1] if side[2] < 0.0 else side[0]
		var face := Vector3(0, 1, side[2]).normalized()
		var a := Vector3(SCREEN - 0.4, 13.2, z_in)
		var b := Vector3(EAST + 0.4, 13.2, z_in)
		var c := Vector3(EAST + 0.4, 9.8, z_out + side[2] * 0.4)
		var d := Vector3(SCREEN - 0.4, 9.8, z_out + side[2] * 0.4)
		var run := a.distance_to(d)
		roof.tri_out(
			"roof:tile",
			a,
			b,
			c,
			Color.WHITE,
			face,
			Vector2(a.x, 0),
			Vector2(b.x, 0),
			Vector2(b.x, run)
		)
		roof.tri_out(
			"roof:tile",
			a,
			c,
			d,
			Color.WHITE,
			face,
			Vector2(a.x, 0),
			Vector2(b.x, run),
			Vector2(a.x, run)
		)
	# Temporary boarded gable closing the bay to the west.
	var zc := (AN + AS) * 0.5
	roof.tri_out(
		"timber",
		Vector3(SCREEN - 0.55, 15.0, AN - 0.6),
		Vector3(SCREEN - 0.55, 15.0, AS + 0.6),
		Vector3(SCREEN - 0.55, nave_ridge, zc),
		Kit.OAK_DARK,
		Vector3(-1, 0, 0)
	)
	# Chancel, then the apse hip from the ridge end down to the apse eaves.
	var ridge := Kit.gable_roof(roof, EAST, CE, AN, AS, 14.0, 52.0, 0.4)
	var apex := Vector3(CE, ridge + 0.1, AX)
	var eave := 14.0 - 0.4 * tan(deg_to_rad(52.0))
	for k in APSE.size() - 1:
		var p := APSE[k]
		var q := APSE[k + 1]
		var po := Vector2(14.0, AX) + (p - Vector2(14.0, AX)) * 1.07
		var qo := Vector2(14.0, AX) + (q - Vector2(14.0, AX)) * 1.07
		var mid := (po + qo) * 0.5 - Vector2(14.0, AX)
		var face := Vector3(mid.x, 3.0, mid.y).normalized()
		var run := Vector3(po.x, eave, po.y).distance_to(apex)
		roof.tri_out(
			"roof:tile",
			Vector3(po.x, eave, po.y),
			Vector3(qo.x, eave, qo.y),
			apex,
			Color.WHITE,
			face,
			Vector2(0, run),
			Vector2(po.distance_to(qo), run),
			Vector2(po.distance_to(qo) * 0.5, 0)
		)
	_lean_to(roof, Rect2(2.0, AN - 5.5, 8.0, 5.5), 6.0, 8.4)
	# Ceilings of the vestry (boards).
	roof.quad_out(
		"timber",
		Vector3(2.9, 5.6, AN - 4.6),
		Vector3(9.1, 5.6, AN - 4.6),
		Vector3(9.1, 5.6, AN),
		Vector3(2.9, 5.6, AN),
		Kit.OAK_DARK,
		Vector3.DOWN
	)


static func _lean_to(roof: CityBuildingBuilder.Shell, r: Rect2, low: float, high: float) -> void:
	var a := Vector3(r.position.x - 0.3, high, r.end.y)
	var b := Vector3(r.end.x + 0.3, high, r.end.y)
	var c := Vector3(r.end.x + 0.3, low, r.position.y - 0.4)
	var d := Vector3(r.position.x - 0.3, low, r.position.y - 0.4)
	var run := a.distance_to(d)
	var face := Vector3(0, 1, -1).normalized()
	roof.tri_out(
		"roof:tile", a, b, c, Color.WHITE, face, Vector2(a.x, 0), Vector2(b.x, 0), Vector2(b.x, run)
	)
	roof.tri_out(
		"roof:tile",
		a,
		c,
		d,
		Color.WHITE,
		face,
		Vector2(a.x, 0),
		Vector2(b.x, run),
		Vector2(a.x, run)
	)


## Rib vaults: the finished bay's three cells and the chancel's two bays.
static func _vaults(roof: CityBuildingBuilder.Shell) -> void:
	Kit.rib_vault(roof, Rect2(SCREEN, AN + 0.6, EAST - SCREEN, AS - AN - 1.2), 10.6, 14.4, RIB)
	Kit.rib_vault(roof, Rect2(SCREEN, NO + 1.4, EAST - SCREEN, AN - 0.6 - NO - 1.4), 6.6, 9.4, RIB)
	Kit.rib_vault(roof, Rect2(SCREEN, AS + 0.6, EAST - SCREEN, SO - 1.4 - AS - 0.6), 6.6, 9.4, RIB)
	Kit.rib_vault(roof, Rect2(EAST, AN + 1.3, 10.0, AS - AN - 2.6), 9.6, 13.2, RIB)
	Kit.rib_vault(
		roof, Rect2(EAST + 10.0, AN + 1.3, CE - EAST - 10.0, AS - AN - 2.6), 9.6, 13.2, RIB
	)


## The works: piers rising in the open bays, timber centering under the turned
## arches, a treadwheel crane, putlog scaffolds on the rising walls.
static func _works(
	body: CityBuildingBuilder.Shell, roof: CityBuildingBuilder.Shell, _rng: RandomNumberGenerator
) -> void:
	for z: float in [AN, AS]:
		Kit.square_pier(body, Vector3(-27.8, 0.05, z), 0.7, 4.2, "greystone")
		# Centering under the bay-2 arcade arch (pointed timber frame).
		var pts := Kit.arch(-20.4, 5.6, 5.4, 8.2)
		for k in range(pts.size() - 1):
			for dz: float in [-0.45, 0.45]:
				Kit.bar(
					roof,
					"timber",
					Vector3(pts[k].x, pts[k].y - 0.1, z + dz),
					Vector3(pts[k + 1].x, pts[k + 1].y - 0.1, z + dz),
					0.12,
					SCAFFOLD
				)
		for k in range(0, pts.size(), 2):
			Kit.bar(
				roof,
				"timber",
				Vector3(pts[k].x, pts[k].y - 0.1, z),
				Vector3(pts[k].x, 0.05, z),
				0.14,
				SCAFFOLD
			)
	_crane(roof, Vector3(-24.4, 0.05, AX))
	# Scaffolds against the rising walls (outside faces of bays 2 and 3).
	for z_face: float in [NO, SO]:
		var out := -1.0 if z_face == NO else 1.0
		var zs := z_face + out * 1.3
		for x: float in [-27.0, -24.0, -21.4, -18.4, -15.6]:
			Kit.bar(roof, "timber", Vector3(x, 0.0, zs), Vector3(x, 8.5, zs), 0.13, SCAFFOLD)
		for level: float in [2.4, 4.8, 7.2]:
			Kit.bar(
				roof, "timber", Vector3(-27.4, level, zs), Vector3(-15.2, level, zs), 0.11, SCAFFOLD
			)
			CitySiteProps._box(
				roof,
				"timber",
				Vector3(-27.4, level + 0.06, minf(z_face, zs)),
				Vector3(-15.2, level + 0.1, maxf(z_face, zs)),
				SCAFFOLD * 0.9
			)
	# Ladders.
	_ladder(roof, Vector3(-26.0, 0.0, NO - 1.4), 7.4)
	_ladder(roof, Vector3(-18.0, 0.0, SO + 1.4), 7.4)


## Treadwheel crane: a man-driven wheel on a timber frame, a mast with a jib,
## the rope over the jib head and a stone block in a lewis.
static func _crane(roof: CityBuildingBuilder.Shell, at: Vector3) -> void:
	var r := 1.9
	var c := at + Vector3(0.0, r + 0.25, 0.0)
	for dz: float in [-0.6, 0.6]:
		for k in 16:
			var a0 := TAU * k / 16.0
			var a1 := TAU * (k + 1) / 16.0
			Kit.bar(
				roof,
				"timber",
				c + Vector3(cos(a0) * r, sin(a0) * r, dz),
				c + Vector3(cos(a1) * r, sin(a1) * r, dz),
				0.12,
				SCAFFOLD
			)
		for k in 8:
			var a := TAU * k / 8.0
			Kit.bar(
				roof,
				"timber",
				c + Vector3(0, 0, dz),
				c + Vector3(cos(a) * r, sin(a) * r, dz),
				0.08,
				SCAFFOLD
			)
	for k in 16:
		var a := TAU * (k + 0.5) / 16.0
		Kit.bar(
			roof,
			"timber",
			c + Vector3(cos(a) * r, sin(a) * r, -0.6),
			c + Vector3(cos(a) * r, sin(a) * r, 0.6),
			0.06,
			SCAFFOLD * 0.9
		)
	Kit.bar(roof, "timber", c + Vector3(0, 0, -1.0), c + Vector3(0, 0, 1.0), 0.18, Kit.OAK_DARK)
	for dz: float in [-0.95, 0.95]:
		for dx: float in [-1.2, 1.2]:
			Kit.bar(
				roof, "timber", at + Vector3(dx, 0, dz), c + Vector3(0, 0, dz), 0.16, Kit.OAK_DARK
			)
	var mast := at + Vector3(0, 0, -1.6)
	Kit.bar(roof, "timber", mast, mast + Vector3(0, 9.0, 0), 0.25, Kit.OAK_DARK)
	var tip := mast + Vector3(0, 8.6, -4.5)
	Kit.bar(roof, "timber", mast + Vector3(0, 5.0, 0), tip, 0.2, Kit.OAK_DARK)
	Kit.bar(roof, "timber", mast + Vector3(0, 9.0, 0), tip, 0.08, Kit.OAK_DARK)
	Kit.bar(roof, "timber", c, mast + Vector3(0, 8.8, 0), 0.03, Color(0.7, 0.62, 0.48))
	Kit.bar(roof, "timber", mast + Vector3(0, 8.8, 0), tip, 0.03, Color(0.7, 0.62, 0.48))
	Kit.bar(roof, "timber", tip, tip - Vector3(0, 5.2, 0), 0.03, Color(0.7, 0.62, 0.48))
	CitySiteProps._box(
		roof, "ashlar", tip - Vector3(0.4, 5.75, 0.3), tip - Vector3(-0.4, 5.25, -0.3), Kit.ASHLAR
	)


static func _ladder(roof: CityBuildingBuilder.Shell, at: Vector3, h: float) -> void:
	for dx: float in [-0.25, 0.25]:
		Kit.bar(roof, "timber", at + Vector3(dx, 0, 0), at + Vector3(dx, h, 0.4), 0.07, SCAFFOLD)
	var y := 0.3
	while y < h:
		Kit.bar(
			roof,
			"timber",
			at + Vector3(-0.25, y, y / h * 0.4),
			at + Vector3(0.25, y, y / h * 0.4),
			0.05,
			SCAFFOLD
		)
		y += 0.3


static func _interior(shell: CityBuildingBuilder.Shell, rng: RandomNumberGenerator) -> void:
	Kit.flag_floor(shell, Rect2(SCREEN, NO + 1.4, EAST - SCREEN, SO - NO - 2.8), FLOOR, rng, 0.08)
	Kit.flag_floor(
		shell, Rect2(EAST, AN + 1.3, CE - EAST + 3.5, AS - AN - 2.6), CHOIR_FLOOR, rng, 0.15
	)
	Kit.flag_floor(shell, Rect2(2.9, AN - 4.6, 6.2, 4.6), CHOIR_FLOOR, rng)
	# Packed earth, rubble and stone chips on the site floor.
	var site := Rect2(W + 1.4, NO + 1.4, SCREEN - W - 1.4, SO - NO - 2.8)
	shell.quad_out(
		"earth",
		Vector3(site.position.x, 0.05, site.position.y),
		Vector3(site.end.x, 0.05, site.position.y),
		Vector3(site.end.x, 0.05, site.end.y),
		Vector3(site.position.x, 0.05, site.end.y),
		Color.WHITE,
		Vector3.UP
	)
	for k in 40:
		var p := Vector3(
			rng.randf_range(site.position.x, site.end.x),
			0.05,
			rng.randf_range(site.position.y, site.end.y)
		)
		var s := rng.randf_range(0.1, 0.3)
		CitySiteProps._box(
			shell,
			"ashlar",
			p - Vector3(s, 0.0, s * 0.7),
			p + Vector3(s, s * 0.6, s * 0.7),
			Kit.ASHLAR * rng.randf_range(0.8, 1.0)
		)
	for k in 3:
		var x0 := EAST - 1.4 + k * 0.5
		var h := FLOOR + (CHOIR_FLOOR - FLOOR) * (k + 1) / 3.0
		CitySiteProps._box(
			shell,
			"ashlar",
			Vector3(x0, FLOOR - 0.01, -8.6),
			Vector3(EAST + 0.2, h, -1.4),
			Kit.ASHLAR
		)
	# Choir stalls of the chapter along both sides (a gap on the south side at
	# the priests' door), the high altar, the rood, the font.
	for run: Array in [[-8.6, -5.2, 8.0], [-1.4, -5.2, 2.8], [-1.4, 5.2, 8.0]]:
		_stalls(shell, float(run[0]), float(run[1]), float(run[2]))
	Furnish.altar(shell, Vector3(11.8, CHOIR_FLOOR, AX), 2.4, true)
	Furnish.rood(shell, EAST - 0.3, 8.0, AX - 4.6, AX + 4.6)
	Furnish.font(shell, Vector3(-12.0, FLOOR, -15.0))
	# Vestry: vestment press and the chapter's chest.
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(3.2, CHOIR_FLOOR, AN - 4.4),
		Vector3(6.4, CHOIR_FLOOR + 0.85, AN - 3.6),
		Kit.OAK_DARK
	)
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(8.2, CHOIR_FLOOR, AN - 4.2),
		Vector3(8.9, CHOIR_FLOOR + 2.0, AN - 2.2),
		Kit.OAK_DARK
	)


## A row of choir stalls from x0 to x1 against the chancel wall side of `z`:
## seat, high panelled back, armrest divisions.
static func _stalls(shell: CityBuildingBuilder.Shell, z: float, x0: float, x1: float) -> void:
	var out := -1.0 if z < AX else 1.0
	var back := z + out * 0.55
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x0, CHOIR_FLOOR + 0.44, minf(z, back) + 0.12),
		Vector3(x1, CHOIR_FLOOR + 0.5, maxf(z, back) - 0.12),
		Kit.OAK
	)
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x0, CHOIR_FLOOR, minf(back, back - out * 0.12)),
		Vector3(x1, CHOIR_FLOOR + 2.2, maxf(back, back - out * 0.12)),
		Kit.OAK_DARK
	)
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x0, CHOIR_FLOOR, minf(z, z + out * 0.1)),
		Vector3(x1, CHOIR_FLOOR + 0.44, maxf(z, z + out * 0.1)),
		Kit.OAK_DARK
	)
	var n := int((x1 - x0) / 0.8)
	for k in n + 1:
		var x := x0 + k * (x1 - x0) / n
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(x - 0.04, CHOIR_FLOOR, minf(z, back)),
			Vector3(x + 0.04, CHOIR_FLOOR + 1.0, maxf(z, back)),
			Kit.OAK_DARK
		)


## The yards: masons' lodge (lean-to with a banker bench, templates and
## tools), the lime pit, and the detached timber belfry.
static func _yard(site: CitySite, plan: CityPlan, _rng: RandomNumberGenerator) -> Node3D:
	var shell := CityBuildingBuilder.Shell.new()
	var lodge := Vector3(
		-30.0, plan.ground_height(site.to_world(Vector2(-30.0, 14.0))) - site.level, 14.0
	)
	for dx: float in [-3.0, 3.0]:
		for dz: float in [-1.6, 1.6]:
			Kit.bar(
				shell,
				"timber",
				lodge + Vector3(dx, 0, dz),
				lodge + Vector3(dx, 2.6 if dz < 0 else 3.4, dz),
				0.16,
				Kit.OAK_DARK
			)
	var a := lodge + Vector3(-3.4, 2.6, -2.0)
	var b := lodge + Vector3(3.4, 2.6, -2.0)
	var c := lodge + Vector3(3.4, 3.4, 2.0)
	var d := lodge + Vector3(-3.4, 3.4, 2.0)
	shell.quad_out("roof:shingle", a, b, c, d, Color.WHITE, Vector3(0, 1, -0.3))
	shell.quad_out(
		"timber",
		lodge + Vector3(-3.0, 0, 1.6),
		lodge + Vector3(3.0, 0, 1.6),
		lodge + Vector3(3.0, 3.3, 1.6),
		lodge + Vector3(-3.0, 3.3, 1.6),
		Kit.OAK_DARK * 0.9,
		Vector3(0, 0, -1)
	)
	for x: float in [-1.8, 0.4]:
		CitySiteProps._box(
			shell,
			"timber",
			lodge + Vector3(x - 0.5, 0, -0.4),
			lodge + Vector3(x + 0.5, 0.75, 0.4),
			Kit.OAK
		)
		CitySiteProps._box(
			shell,
			"ashlar",
			lodge + Vector3(x - 0.35, 0.75, -0.25),
			lodge + Vector3(x + 0.35, 1.1, 0.25),
			Kit.ASHLAR
		)
	for k in 4:
		CitySiteProps._box(
			shell,
			"timber",
			lodge + Vector3(-2.6 + k * 0.6, 1.2, 1.5),
			lodge + Vector3(-2.2 + k * 0.6, 2.1, 1.55),
			Color(0.78, 0.7, 0.55)
		)
	# Lime pit with boarding and a rake.
	var pit := Vector3(
		-36.0, plan.ground_height(site.to_world(Vector2(-36.0, 16.6))) - site.level, 16.6
	)
	CitySiteProps._box(
		shell,
		"limewash",
		pit + Vector3(-1.2, -0.05, -0.8),
		pit + Vector3(1.2, 0.02, 0.8),
		Color(0.95, 0.94, 0.9)
	)
	for side: float in [-1.0, 1.0]:
		CitySiteProps._box(
			shell,
			"timber",
			pit + Vector3(-1.3, -0.05, side * 0.85 - 0.05),
			pit + Vector3(1.3, 0.3, side * 0.85 + 0.05),
			Kit.OAK_DARK
		)
	Kit.bar(
		shell, "timber", pit + Vector3(0.8, 0.3, 0.0), pit + Vector3(2.2, 1.4, 0.4), 0.05, SCAFFOLD
	)
	# Detached timber belfry: four posts, braces, a shingled cap, two bells.
	var bel := Vector3(
		-14.0, plan.ground_height(site.to_world(Vector2(-14.0, 15.5))) - site.level, 15.5
	)
	var h := 6.5
	for dx: float in [-1.4, 1.4]:
		for dz: float in [-1.4, 1.4]:
			Kit.bar(
				shell,
				"timber",
				bel + Vector3(dx * 1.4, 0, dz * 1.4),
				bel + Vector3(dx, h, dz),
				0.26,
				Kit.OAK_DARK
			)
	for y: float in [2.2, h - 0.6]:
		for dz: float in [-1.4, 1.4]:
			Kit.bar(
				shell,
				"timber",
				bel + Vector3(-1.5, y, dz),
				bel + Vector3(1.5, y, dz),
				0.2,
				Kit.OAK_DARK
			)
			Kit.bar(
				shell,
				"timber",
				bel + Vector3(dz, y, -1.5),
				bel + Vector3(dz, y, 1.5),
				0.2,
				Kit.OAK_DARK
			)
	for k in 2:
		var bc := bel + Vector3(-0.6 + k * 1.2, h - 1.6, 0.0)
		for j in 8:
			var a0 := TAU * j / 8.0
			var a1 := TAU * (j + 1) / 8.0
			var p0 := Vector3(cos(a0), 0, sin(a0))
			var p1 := Vector3(cos(a1), 0, sin(a1))
			shell.quad_out(
				"dark",
				bc + p0 * 0.45,
				bc + p1 * 0.45,
				bc + p1 * 0.25 + Vector3(0, 0.6, 0),
				bc + p0 * 0.25 + Vector3(0, 0.6, 0),
				Color(0.42, 0.3, 0.17),
				(p0 + p1).normalized()
			)
	Kit.pyramid_roof(shell, Vector2(bel.x, bel.z), 1.8, bel.y + h, bel.y + h + 3.0)
	return Kit.mesh("Yard", shell)
