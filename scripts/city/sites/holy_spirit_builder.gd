extends RefCounted

## site.holy_spirit (ADR 0032): the Holy Spirit parish church and almshouse in
## spring 1343, on the footprint of the surviving church. The maintainer's
## period rule decides each element: features dated after 1343 are left out
## (rib vaults, big Gothic windows and the stone tower of the 1360s, the 1597
## portal, the 1684 clock, the 17th-century galleries, Notke's 1483 altar);
## where the 1343 state is unrecorded, a slightly simplified form of the later,
## documented church is used (white render, square piers with pointed arches,
## two-light lancets with stained glass, plank floor, benches, candle crowns,
## pulpit, winged retable, the bells in a timber turret on the west gable).
## Walls come from the manifest fabric (CitySiteKit), so model and walk data
## share one description. Everything above head height is "Church/Upper";
## roofs and ceilings are "Church/Roof"; both lift while Kalev is inside.

const Kit := preload("res://scripts/city/sites/site_kit.gd")
const Furnish := preload("res://scripts/city/sites/church_furnishings.gd")
const FLOOR := 0.12
const CHOIR_FLOOR := 0.57
const CUT := FLOOR + CityBuildingBuilder.CUT_HEIGHT
const NAVE_LEN := 38.0
const END_X := 48.8
const HALF := 8.2
const ARCADE_Z := 1.24
const NAVE_EAVE := 9.5
const CHOIR_EAVE := 8.0
const ALMS_EAVE := 4.5
const PITCH := 55.0
const CEILING := 8.7
const CHOIR_CEILING := 7.6
const PIERS: Array[float] = [7.6, 13.6, 19.6, 25.6, 31.6]
const RED := Furnish.RED
const BLUE := Furnish.BLUE


static func build(site: CitySite, _plan: CityPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_holy_spirit"
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
	_roofs(roof)
	_turret(roof)
	_interior(body, roof, rng, site.data.get("benches", []))
	var parts := body.split_at(CUT)
	var lower: CityBuildingBuilder.Shell = parts[0]
	Kit.cut_caps(lower, fabric, CUT)
	var lower_node := Kit.mesh("Lower", lower)
	var upper_node := Kit.mesh("Upper", parts[1])
	var glass_parts := glass.split_at(CUT)
	upper_node.add_child(Kit.mesh("Glass", glass_parts[1]))
	lower_node.add_child(Kit.mesh("GlassLow", glass_parts[0]))
	var roof_node := Kit.mesh("Roof", roof)
	Kit.bind_site_washes([lower_node, upper_node, roof_node], site, FLOOR, NAVE_LEN - 1.2)
	# The painted walls carry their own dado and frieze (city_limewash.gdshader).
	ChurchMurals.paint(
		lower_node, upper_node, site, fabric, CUT, FLOOR, _consecration_crosses(), false
	)
	church.add_child(lower_node)
	church.add_child(upper_node)
	church.add_child(roof_node)
	ChurchSunlight.apply(
		church, lower_node, upper_node, roof_node, fabric, Kit.GLAZING.get(site.id, 0)
	)
	Furnish.coronas(
		upper_node,
		[
			Vector2(9.0, -3.4),
			Vector2(17.0, -3.4),
			Vector2(25.0, -3.4),
			Vector2(33.0, -3.4),
			Vector2(21.0, 4.6)
		],
		4.3,
		CEILING - 0.35
	)
	_lights(lower_node)
	return root


## Crow-stepped gables in white render with their coping: the nave's west
## and east gables, the lower choir's east gable, the almshouse gable.
static func _gables(shell: CityBuildingBuilder.Shell) -> void:
	var slope := tan(deg_to_rad(PITCH))
	var nave_apex := NAVE_EAVE + HALF * slope + 0.7
	Kit.stepped_gable(shell, 0.0, -1.0, -HALF, HALF, NAVE_EAVE, nave_apex, 7, 1.2, 3, "render")
	Kit.stepped_gable(shell, NAVE_LEN, 1.0, -HALF, HALF, NAVE_EAVE, nave_apex, 7, 1.2, 0, "render")
	var choir_half := (HALF + 1.84) * 0.5
	var choir_apex := CHOIR_EAVE + choir_half * slope + 0.5
	Kit.stepped_gable(shell, END_X, 1.0, -HALF, 1.84, CHOIR_EAVE, choir_apex, 5, 1.1, 3, "render")
	var alms_apex := ALMS_EAVE + (HALF - 1.84) * 0.5 + 0.4
	Kit.stepped_gable(shell, END_X, 1.0, 1.84, HALF, ALMS_EAVE, alms_apex, 2, 0.8, 0, "render")


static func _roofs(roof: CityBuildingBuilder.Shell) -> void:
	Kit.gable_roof(roof, 0.6, NAVE_LEN - 0.6, -HALF, HALF, NAVE_EAVE, PITCH, 0.5)
	Kit.gable_roof(roof, NAVE_LEN, END_X - 0.55, -HALF, 1.84, CHOIR_EAVE, PITCH, 0.45)
	Kit.gable_roof(roof, NAVE_LEN, END_X - 0.4, 1.84, HALF, ALMS_EAVE, 45.0, 0.35)
	_ceiling(roof, Rect2(1.2, -7.0, 35.6, 14.0), CEILING, true)
	_ceiling(roof, Rect2(36.8, -7.1, 10.9, 7.84), CHOIR_CEILING, true)
	_ceiling(roof, Rect2(38.0, 1.84, 10.0, 5.56), ALMS_EAVE, false)


## Board ceiling on beams; `painted` alternates red-ochre and white boards.
static func _ceiling(roof: CityBuildingBuilder.Shell, r: Rect2, y: float, painted: bool) -> void:
	var x := r.position.x
	var k := 0
	while x < r.end.x - 0.01:
		var x1 := minf(x + 0.42, r.end.x)
		# Plain oak boards; painted ceilings get a lime-washed board every fourth.
		var tone := Kit.OAK * (0.92 + 0.12 * float(k % 3) / 2.0)
		if painted and k % 4 == 0:
			tone = Color(0.8, 0.76, 0.66)
		tone.a = 1.0
		roof.quad_out(
			"timber",
			Vector3(x, y, r.position.y),
			Vector3(x1, y, r.position.y),
			Vector3(x1, y, r.end.y),
			Vector3(x, y, r.end.y),
			tone,
			Vector3.DOWN
		)
		x = x1
		k += 1
	var b := r.position.x + 0.8
	while b < r.end.x:
		CitySiteProps._box(
			roof,
			"timber",
			Vector3(b - 0.13, y - 0.34, r.position.y),
			Vector3(b + 0.13, y, r.end.y),
			Kit.OAK_DARK
		)
		if painted:
			# Red-ochre band painted along each beam's soffit.
			CitySiteProps._box(
				roof,
				"limewash",
				Vector3(b - 0.08, y - 0.345, r.position.y),
				Vector3(b + 0.08, y - 0.34, r.end.y),
				RED
			)
		b += 2.2


## The bells before the 1360 tower: an octagonal timber turret astride the
## ridge at the west gable, louvred belfry, shingled spire, iron cross.
static func _turret(roof: CityBuildingBuilder.Shell) -> void:
	var ridge := NAVE_EAVE + HALF * tan(deg_to_rad(PITCH))
	var c := Vector3(2.6, ridge - 2.2, 0.0)
	var r := 1.15
	var top := ridge + 3.6
	for j in 8:
		var a0 := TAU * (j + 0.5) / 8.0
		var a1 := TAU * (j + 1.5) / 8.0
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var n := (p0 + p1).normalized()
		roof.quad_out(
			"timber",
			c + p0,
			c + p1,
			c + p1 + Vector3(0, top - c.y, 0),
			c + p0 + Vector3(0, top - c.y, 0),
			Kit.OAK_DARK,
			n
		)
		# Louvred belfry opening on each face.
		var mid := (p0 + p1) * 0.5 + n * 0.02
		var side := (p1 - p0).normalized()
		var y := ridge + 1.0
		while y < top - 0.4:
			roof.quad_out(
				"dark",
				c + mid - side * 0.3 + Vector3(0, y - c.y, 0),
				c + mid + side * 0.3 + Vector3(0, y - c.y, 0),
				c + mid + side * 0.3 + n * 0.1 + Vector3(0, y + 0.14 - c.y, 0),
				c + mid - side * 0.3 + n * 0.1 + Vector3(0, y + 0.14 - c.y, 0),
				Kit.OAK_DARK * 0.6,
				n + Vector3.UP
			)
			y += 0.24
		# Spire.
		var tip := Vector3(c.x, top + 6.0, c.z)
		var e0 := c + Vector3(cos(a0) * (r + 0.25), top - c.y, sin(a0) * (r + 0.25))
		var e1 := c + Vector3(cos(a1) * (r + 0.25), top - c.y, sin(a1) * (r + 0.25))
		roof.tri_out(
			"roof:shingle",
			e0,
			e1,
			tip,
			Color.WHITE,
			n + Vector3(0, 0.3, 0),
			Vector2(0, 6),
			Vector2(0.9, 6),
			Vector2(0.45, 0)
		)
	CitySiteProps._box(
		roof,
		"dark",
		Vector3(c.x - 0.04, top + 5.9, -0.04),
		Vector3(c.x + 0.04, top + 7.3, 0.04),
		Kit.IRON
	)
	CitySiteProps._box(
		roof,
		"dark",
		Vector3(c.x - 0.3, top + 6.8, -0.03),
		Vector3(c.x + 0.3, top + 6.86, 0.03),
		Kit.IRON
	)


static func _interior(
	shell: CityBuildingBuilder.Shell,
	_roof: CityBuildingBuilder.Shell,
	rng: RandomNumberGenerator,
	benches: Array
) -> void:
	Furnish.planks(shell, Rect2(1.2, -7.0, 35.6, 14.0), FLOOR, rng)
	Furnish.planks(shell, Rect2(38.0, 1.84, 10.0, 5.56), FLOOR, rng)
	Kit.flag_floor(shell, Rect2(36.8, -7.1, 10.9, 7.84), CHOIR_FLOOR, rng, 0.12)
	# Three steps up to the choir before the triumphal arch.
	for k in 3:
		var x0 := 35.8 + k * 0.34
		var h := FLOOR + (CHOIR_FLOOR - FLOOR) * (k + 1) / 3.0
		CitySiteProps._box(
			shell, "ashlar", Vector3(x0, FLOOR - 0.01, -6.2), Vector3(36.82, h, -0.2), Kit.ASHLAR
		)
	for b: Dictionary in benches:
		Furnish.bench(shell, Vector3(float(b["at"][0]), FLOOR, float(b["at"][1])), float(b["len"]))
	Furnish.font(shell, Vector3(4.2, FLOOR, -4.6))
	Furnish.altar(shell, Vector3(END_X - 1.6, CHOIR_FLOOR, -3.18), 2.4, true)
	Furnish.altar(shell, Vector3(36.2, FLOOR, 3.0), 1.4, false)
	Furnish.rood(shell, 37.2, 4.8, -6.4, 0.0)
	Furnish.pulpit(shell, Vector3(25.6, FLOOR, 0.75), ARCADE_Z, FLOOR)
	for x: float in [10.6, 22.6]:
		Furnish.statue(
			shell, Vector3(x, 3.0, ARCADE_Z - 0.02), Vector3(0, 0, -1), RED if x < 15.0 else BLUE
		)
		Furnish.statue(
			shell,
			Vector3(x + 6.0, 3.0, ARCADE_Z + 1.22),
			Vector3(0, 0, 1),
			BLUE if x < 15.0 else RED
		)
	# Holy-water stoup by the north portal; bell ropes under the turret.
	Kit.pillar(shell, Vector3(12.6, FLOOR, -6.6), 0.11, 0.85)
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(12.35, FLOOR + 0.85, -6.85),
		Vector3(12.85, FLOOR + 1.0, -6.35),
		Kit.ASHLAR
	)
	for z: float in [-0.4, 0.4]:
		Kit.bar(
			shell,
			"timber",
			Vector3(2.6, CEILING, z),
			Vector3(2.6, 1.0, z),
			0.035,
			Color(0.68, 0.6, 0.45)
		)
	_almshouse(shell)


## Consecration crosses on the aisle walls, as [centre, into_room].
static func _consecration_crosses() -> Array:
	var spots: Array = []
	for x: float in [6.0, 17.0, 24.5, 31.0]:
		for z: float in [-6.99, 6.99]:
			spots.append([Vector3(x, 3.3, z), Vector3(0, 0, 1.0 if z < 0 else -1.0)])
	return spots


## Almshouse: box beds with straw ticks and blankets, a chest, a table.
static func _almshouse(shell: CityBuildingBuilder.Shell) -> void:
	for x: float in [39.6, 41.8, 44.0]:
		_bed(shell, Vector3(x, FLOOR, HALF - 1.3))
	for x: float in [41.3, 43.5]:
		_bed(shell, Vector3(x, FLOOR, 2.8))
	CitySiteProps._box(
		shell, "timber", Vector3(46.2, FLOOR, 6.4), Vector3(47.3, FLOOR + 0.55, 7.0), Kit.OAK_DARK
	)


static func _bed(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	CitySiteProps._box(
		shell, "timber", at + Vector3(-1.0, 0.0, -0.47), at + Vector3(1.0, 0.45, 0.47), Kit.OAK_DARK
	)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.95, 0.45, -0.43),
		at + Vector3(0.95, 0.58, 0.43),
		Color(0.78, 0.7, 0.5)
	)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.2, 0.58, -0.44),
		at + Vector3(0.95, 0.62, 0.44),
		Color(0.45, 0.2, 0.15)
	)


static func _lights(node: Node3D) -> void:
	for spot: Vector3 in [
		Vector3(46.4, CHOIR_FLOOR + 1.8, -3.2),
		Vector3(36.0, FLOOR + 1.5, 3.0),
		Vector3(43.0, FLOOR + 1.6, 4.6),
		Vector3(17.0, 4.0, -3.4),
		Vector3(29.0, 4.0, -3.4)
	]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.45)
		light.light_energy = 1.5
		light.omni_range = 10.0
		light.position = spot
		node.add_child(light)
