extends RefCounted

## site.st_nicholas (ADR 0032): St Nicholas' merchant parish church in spring
## 1343, set into the surviving church's site. Period rule: the basilica nave
## and ambulatory choir (1405-20 and later), the high tower and baroque spire,
## the later side chapels (1470s+), Rode's altar and the later fittings are
## left out. Attested for 1343: a hall church of nave and two aisles (1230s to
## c. 1290) with a square chancel, a sacristy and a low west tower with
## defensive loopholes, the north porch (first half 14th c.) and the St Barbara
## charnel chapel at the cemetery edge (1342). Unrecorded details follow the
## later church, simplified: bare grey limestone piers, arches and vault ribs
## against whitewashed walls and webs, buttressed grey rubble outside, a
## whitewashed tower with blind arcading under a shingled helm, stone flags
## with ledger slabs, lancets with stained glass, benches and candle crowns.

const Kit := preload("res://scripts/city/sites/site_kit.gd")
const Furnish := preload("res://scripts/city/sites/church_furnishings.gd")
const FLOOR := 0.12
const CHOIR_FLOOR := 0.57
const CUT := FLOOR + CityBuildingBuilder.CUT_HEIGHT
const W0 := -34.0
const TX := -24.0
const NX := 10.0
const CX := 22.0
const NN := -20.0
const NS := 4.0
const AX := -8.0
const CZ0 := -13.0
const CZ1 := -3.0
const EAVE := 12.0
const CHOIR_EAVE := 9.5
const TOP := 22.0
const PITCH := 45.0
const SPRING := 7.2
const CROWN := 11.3
const PIER_X: Array[float] = [-16.2, -8.4, -0.6]
const PIER_Z: Array[float] = [-11.6, -4.4]
const RIB := Color(0.72, 0.71, 0.67)


static func build(site: CitySite, plan: CityPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_st_nicholas"
	var fabric: Array = site.data["fabric"]
	var church_fabric: Array = []
	var chapel_fabric: Array = []
	for w: Dictionary in fabric:
		(chapel_fabric if String(w["id"]).begins_with("barbara.") else church_fabric).append(w)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(site.id))
	# The church.
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	Kit.walls(body, glass, church_fabric, Kit.GLAZING.get(site.id, 0))
	_gables(body)
	_buttresses(body)
	_tower(body, roof)
	_roofs(roof)
	_vaults(roof)
	_interior(body, rng, site.data.get("benches", []))
	root.add_child(_assemble("Church", site, body, glass, roof, church_fabric))
	var church := root.get_node("Church")
	Furnish.coronas(
		church.get_node("Upper"),
		[Vector2(-18.0, AX), Vector2(-10.4, AX), Vector2(-2.6, AX), Vector2(5.0, AX)],
		4.6,
		CROWN - 0.1
	)
	(
		Furnish
		. lights(
			church.get_node("Lower"),
			[
				Vector3(19.6, CHOIR_FLOOR + 1.8, AX),
				Vector3(7.0, FLOOR + 1.6, -16.8),
				Vector3(7.0, FLOOR + 1.6, 0.8),
				Vector3(-14.0, 4.5, AX),
				Vector3(-2.0, 4.5, AX),
				Vector3(-29.0, 3.0, AX),
			]
		)
	)
	# The St Barbara charnel chapel.
	var cbody := CityBuildingBuilder.Shell.new()
	var cglass := CityBuildingBuilder.Shell.new()
	var croof := CityBuildingBuilder.Shell.new()
	Kit.walls(cbody, cglass, chapel_fabric, Kit.GLAZING.get(site.id, 0))
	Kit.stepped_gable(
		cbody, 6.0, -1.0, 10.0, 16.0, 5.5, 5.5 + 3.0 * tan(deg_to_rad(50.0)) + 0.4, 2, 0.8, 1
	)
	Kit.stepped_gable(
		cbody, 14.0, 1.0, 10.0, 16.0, 5.5, 5.5 + 3.0 * tan(deg_to_rad(50.0)) + 0.4, 2, 0.8, 0
	)
	Kit.gable_roof(croof, 6.4, 13.6, 10.0, 16.0, 5.5, 50.0, 0.35)
	_charnel(cbody, rng)
	root.add_child(_assemble("Barbara", site, cbody, cglass, croof, chapel_fabric))
	Furnish.lights(root.get_node("Barbara/Lower"), [Vector3(12.0, 1.6, 13.0)])
	_cemetery(root, site, plan)
	return root


## One building: walls cut at head height into Lower/Upper, roof separate.
static func _assemble(
	node_name: String,
	site: CitySite,
	body: CityBuildingBuilder.Shell,
	glass: CityBuildingBuilder.Shell,
	roof: CityBuildingBuilder.Shell,
	fabric: Array
) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	var parts := body.split_at(CUT)
	var lower: CityBuildingBuilder.Shell = parts[0]
	Kit.cut_caps(lower, fabric, CUT)
	var lower_node := Kit.mesh("Lower", lower)
	var upper_node := Kit.mesh("Upper", parts[1])
	var glass_parts := glass.split_at(CUT)
	upper_node.add_child(Kit.mesh("Glass", glass_parts[1]))
	lower_node.add_child(Kit.mesh("GlassLow", glass_parts[0]))
	var roof_node := Kit.mesh("Roof", roof)
	Kit.bind_site_washes([lower_node, upper_node, roof_node], site, FLOOR)
	ChurchMurals.paint(lower_node, upper_node, site, fabric, CUT, FLOOR)
	node.add_child(lower_node)
	node.add_child(upper_node)
	node.add_child(roof_node)
	return node


## Crow-stepped east gables of the hall and the chancel, the west gable
## shoulders either side of the tower.
static func _gables(shell: CityBuildingBuilder.Shell) -> void:
	var slope := tan(deg_to_rad(PITCH))
	Kit.stepped_gable(shell, NX, 1.0, NN, NS, EAVE, EAVE + 12.0 * slope + 0.8, 8, 1.4, 5)
	Kit.stepped_gable(shell, TX, -1.0, NN, NS, EAVE, EAVE + 12.0 * slope + 0.8, 8, 1.4, 0)
	var cs := tan(deg_to_rad(50.0))
	Kit.stepped_gable(shell, CX, 1.0, CZ0, CZ1, CHOIR_EAVE, CHOIR_EAVE + 5.0 * cs + 0.5, 4, 1.2, 3)


static func _roofs(roof: CityBuildingBuilder.Shell) -> void:
	Kit.gable_roof(roof, TX, NX - 0.7, NN, NS, EAVE, PITCH, 0.5)
	Kit.gable_roof(roof, NX, CX - 0.6, CZ0, CZ1, CHOIR_EAVE, 50.0, 0.4)
	# Sacristy and porch lean-to roofs.
	_lean_to(roof, Rect2(NX + 1.0, CZ0 - 5.0, 7.0, 5.0), 5.0, 7.4, true)
	_lean_to(roof, Rect2(-12.6, NN - 4.2, 5.2, 4.2), 6.0, 8.6, true)


## Mono-pitch roof over `r` falling to the far (low z) side when `north`.
static func _lean_to(
	roof: CityBuildingBuilder.Shell, r: Rect2, low: float, high: float, north: bool
) -> void:
	var z_low := r.position.y - 0.4 if north else r.end.y + 0.4
	var z_high := r.end.y if north else r.position.y
	var a := Vector3(r.position.x - 0.3, high, z_high)
	var b := Vector3(r.end.x + 0.3, high, z_high)
	var c := Vector3(r.end.x + 0.3, low, z_low)
	var d := Vector3(r.position.x - 0.3, low, z_low)
	var run := a.distance_to(d)
	var face := Vector3(0, 1, -1 if north else 1).normalized()
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
	roof.quad_out("timber", a, b, c, d, Kit.OAK_DARK * 0.8, -face)


## Stepped buttresses against the aisle walls between the windows and at the
## chancel corners (grey rubble with sloped weatherings).
static func _buttresses(shell: CityBuildingBuilder.Shell) -> void:
	for x: float in [-16.2, -8.4, -0.6]:
		for z_face: float in [NN, NS]:
			var out := -1.0 if z_face == NN else 1.0
			if z_face == NN and absf(x - (-10.0)) < 3.4:
				continue  # the porch stands here
			_buttress(shell, Vector3(x, 0.0, z_face), out, 1.3, 1.6, EAVE - 2.0)
	for z: float in [CZ0, CZ1]:
		_buttress(
			shell, Vector3(CX - 0.6, 0.0, z), -1.0 if z == CZ0 else 1.0, 1.0, 1.2, CHOIR_EAVE - 2.0
		)


static func _buttress(
	shell: CityBuildingBuilder.Shell,
	at: Vector3,
	out: float,
	width: float,
	depth: float,
	height: float
) -> void:
	var stages: Array = [[0.0, height * 0.55, depth], [height * 0.55, height, depth * 0.65]]
	for st: Array in stages:
		var y0: float = st[0]
		var y1: float = st[1]
		var d: float = st[2]
		var z0 := at.z
		var z1 := at.z + out * d
		CitySiteProps._box(
			shell,
			"wall:limestone",
			Vector3(at.x - width * 0.5, y0 - 0.6, minf(z0, z1)),
			Vector3(at.x + width * 0.5, y1, maxf(z0, z1)),
			Color.WHITE
		)
		# Sloped weathering on top of the stage.
		var zt := at.z + out * d
		shell.quad_out(
			"ashlar",
			Vector3(at.x - width * 0.5 - 0.05, y1, zt + out * 0.05),
			Vector3(at.x + width * 0.5 + 0.05, y1, zt + out * 0.05),
			Vector3(at.x + width * 0.5 + 0.05, y1 + d * 0.6, at.z),
			Vector3(at.x - width * 0.5 - 0.05, y1 + d * 0.6, at.z),
			Kit.ASHLAR,
			Vector3(0, 1, out)
		)


## The low west tower: whitewashed, with tall blind pointed arcades on its
## faces, a cornice, and a steep shingled helm with a cross; bell ropes inside.
static func _tower(shell: CityBuildingBuilder.Shell, roof: CityBuildingBuilder.Shell) -> void:
	var c := Vector2((W0 + TX) * 0.5, AX)
	# Blind arcades: shallow white recess frames on the three free faces.
	for k in 3:
		var u := -3.0 + k * 3.0
		var y0 := 9.0
		var y1 := 15.0
		for face: Array in [
			[Vector3(W0 - 0.02, 0, c.y + u), Vector3(-1, 0, 0)],
			[Vector3(c.x + u, 0, AX - 5.02), Vector3(0, 0, -1)],
			[Vector3(c.x + u, 0, AX + 5.02), Vector3(0, 0, 1)]
		]:
			var p: Vector3 = face[0]
			var n: Vector3 = face[1]
			var side := Vector3(-n.z, 0, n.x)
			for e: float in [-1.0, 1.0]:
				CitySiteProps._box(
					shell,
					"render",
					p + side * (e * 1.1 - 0.12) + Vector3(0, y0, 0) + n * 0.0,
					p + side * (e * 1.1 + 0.12) + Vector3(0, y1, 0) + n * 0.12,
					Color.WHITE
				)
			var pts := Kit.arch(-1.1, 2.2, y1, y1 + 1.4)
			for j in range(pts.size() - 1):
				var a := p + side * pts[j].x + Vector3(0, pts[j].y, 0)
				var b := p + side * pts[j + 1].x + Vector3(0, pts[j + 1].y, 0)
				Kit.bar(shell, "render", a + n * 0.06, b + n * 0.06, 0.2, Color.WHITE)
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(W0 - 0.15, TOP - 0.3, AX - 5.15),
		Vector3(TX + 0.15, TOP, AX + 5.15),
		Kit.ASHLAR
	)
	Kit.pyramid_roof(roof, c, 5.0, TOP, TOP + 11.0)
	for z: float in [-0.5, 0.5]:
		Kit.bar(
			shell,
			"timber",
			Vector3(c.x, 9.0, AX + z),
			Vector3(c.x, 1.0, AX + z),
			0.035,
			Color(0.68, 0.6, 0.45)
		)


## Rib vaults over the twelve hall bays, the chancel, the tower hall; grey
## stone ribs as in the church today.
static func _vaults(roof: CityBuildingBuilder.Shell) -> void:
	var xs: Array[float] = [TX + 1.4, PIER_X[0], PIER_X[1], PIER_X[2], NX - 1.4]
	var zs: Array[float] = [NN + 1.4, PIER_Z[0], PIER_Z[1], NS - 1.4]
	for i in 4:
		for j in 3:
			Kit.rib_vault(
				roof, Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j]), SPRING, CROWN, RIB
			)
	Kit.rib_vault(roof, Rect2(NX, CZ0 + 1.2, CX - 1.2 - NX, CZ1 - CZ0 - 2.4), 6.0, 8.8, RIB)
	Kit.rib_vault(roof, Rect2(W0 + 2.4, AX - 2.6, 5.2, 5.2), 5.6, 8.4, RIB)


static func _interior(
	shell: CityBuildingBuilder.Shell, rng: RandomNumberGenerator, benches: Array
) -> void:
	Kit.flag_floor(shell, Rect2(TX + 1.4, NN + 1.4, NX - TX - 2.8, NS - NN - 2.8), FLOOR, rng, 0.14)
	Kit.flag_floor(shell, Rect2(W0 + 2.4, AX - 2.6, 5.2, 5.2), FLOOR, rng)
	Kit.flag_floor(shell, Rect2(-11.8, NN - 3.4, 3.6, 3.4), FLOOR, rng)
	Kit.flag_floor(
		shell, Rect2(NX, CZ0 + 1.2, CX - 1.2 - NX, CZ1 - CZ0 - 2.4), CHOIR_FLOOR, rng, 0.2
	)
	Kit.flag_floor(shell, Rect2(NX + 1.9, CZ0 - 4.1, 5.2, 4.0), CHOIR_FLOOR, rng)
	for k in 3:
		var x0 := NX - 2.4 + k * 0.6
		var h := FLOOR + (CHOIR_FLOOR - FLOOR) * (k + 1) / 3.0
		CitySiteProps._box(
			shell,
			"ashlar",
			Vector3(x0, FLOOR - 0.01, -11.0),
			Vector3(NX + 0.4, h, -5.0),
			Kit.ASHLAR
		)
	for x: float in PIER_X:
		for z: float in PIER_Z:
			Kit.square_pier(shell, Vector3(x, FLOOR, z), 0.8, SPRING - FLOOR, "greystone")
	for b: Dictionary in benches:
		Furnish.bench(shell, Vector3(float(b["at"][0]), FLOOR, float(b["at"][1])), float(b["len"]))
	Furnish.font(shell, Vector3(-20.8, FLOOR, -16.4))
	Furnish.altar(shell, Vector3(20.2, CHOIR_FLOOR, AX), 2.4, true)
	Furnish.altar(shell, Vector3(8.0, FLOOR, -16.8), 1.4, false)
	Furnish.altar(shell, Vector3(8.0, FLOOR, 0.8), 1.4, false)
	Furnish.rood(shell, NX - 0.7, 6.6, AX - 3.0, AX + 3.0)
	Furnish.pulpit(shell, Vector3(-0.6, FLOOR, -12.45), -12.4, FLOOR)
	for x: float in PIER_X:
		Furnish.statue(shell, Vector3(x, 3.2, PIER_Z[0] + 0.8), Vector3(0, 0, 1), Furnish.RED)
		Furnish.statue(shell, Vector3(x, 3.2, PIER_Z[1] - 0.8), Vector3(0, 0, -1), Furnish.BLUE)
	# Sacristy: vestment chest and a cupboard for the plate.
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(NX + 2.2, CHOIR_FLOOR, CZ0 - 4.0),
		Vector3(NX + 4.6, CHOIR_FLOOR + 0.8, CZ0 - 3.3),
		Kit.OAK_DARK
	)
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(NX + 6.4, CHOIR_FLOOR, CZ0 - 3.9),
		Vector3(NX + 7.0, CHOIR_FLOOR + 1.9, CZ0 - 2.3),
		Kit.OAK_DARK
	)


## Charnel: bones stacked along the walls on low benches, skulls in rows, an
## altar of St Barbara on the east wall.
static func _charnel(shell: CityBuildingBuilder.Shell, rng: RandomNumberGenerator) -> void:
	var bone := Color(0.84, 0.8, 0.68)
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(6.8, FLOOR, 10.8),
		Vector3(13.2, FLOOR + 0.02, 15.2),
		Kit.ASHLAR * 0.8
	)
	for z: float in [11.1, 14.9]:
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(7.6, FLOOR, z - 0.3),
			Vector3(11.6, FLOOR + 0.5, z + 0.3),
			Kit.OAK_DARK
		)
		for k in 14:
			var x := 7.8 + k * 0.27
			var c := Vector3(x, FLOOR + 0.5, z)
			CitySiteProps._box(
				shell,
				"limewash",
				c + Vector3(-0.1, 0.0, -0.1),
				c + Vector3(0.1, 0.19, 0.1),
				bone * rng.randf_range(0.85, 1.0)
			)
		for k in 10:
			var x := 7.8 + rng.randf() * 3.6
			Kit.bar(
				shell,
				"limewash",
				Vector3(x, FLOOR + 0.72, z - 0.2),
				Vector3(x + rng.randf_range(-0.2, 0.2), FLOOR + 0.72, z + 0.2),
				0.05,
				bone
			)
	Furnish.altar(shell, Vector3(12.6, FLOOR, 13.0), 1.4, false)


## Cemetery south of the church: wooden grave crosses and a few slabs.
static func _cemetery(root: Node3D, site: CitySite, plan: CityPlan) -> void:
	var shell := CityBuildingBuilder.Shell.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1342
	for g: Array in site.data.get("graves", []):
		var p := Vector2(g[0], g[1])
		var y := plan.ground_height(site.to_world(p)) - site.level
		if rng.randf() < 0.75:
			var h := rng.randf_range(0.9, 1.25)
			var tone := Kit.OAK_DARK * rng.randf_range(0.7, 1.05)
			tone.a = 1.0
			Kit.bar(
				shell, "timber", Vector3(p.x, y - 0.2, p.y), Vector3(p.x, y + h, p.y), 0.09, tone
			)
			Kit.bar(
				shell,
				"timber",
				Vector3(p.x, y + h * 0.75, p.y - 0.28),
				Vector3(p.x, y + h * 0.75, p.y + 0.28),
				0.08,
				tone
			)
		else:
			CitySiteProps._box(
				shell,
				"ashlar",
				Vector3(p.x - 0.45, y - 0.1, p.y - 0.9),
				Vector3(p.x + 0.45, y + 0.12, p.y + 0.9),
				Kit.ASHLAR * 0.85
			)
		# Grave mound.
		CitySiteProps._box(
			shell,
			"ashlar",
			Vector3(p.x + 0.2, y - 0.25, p.y - 0.4),
			Vector3(p.x + 1.9, y + 0.12, p.y + 0.4),
			Color(0.42, 0.36, 0.28)
		)
	var node := Kit.mesh("Cemetery", shell)
	root.add_child(node)
