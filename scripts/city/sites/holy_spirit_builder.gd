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
const LifeProps := preload("res://scripts/map/view3d/map_view_mesh_builder_district_life_props.gd")
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
## The district life props (herb rack) were authored in 0.87 m world units.
const LEGACY_UNIT_M := 0.87
## Almshouse sick-room fixtures (site-local): the brazier and the altar niche
## on the west wall, north of the arch into the south aisle.
const BRAZIER := Vector3(44.0, FLOOR, 2.75)
const ALMS_ALTAR := Vector3(38.0, FLOOR, 3.05)


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
	var occluders := _interior(body, roof, rng, site.data.get("benches", []))
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
		[lower_node, upper_node, roof_node], site, FLOOR, NAVE_LEN - 1.2, Kit.CHURCH_WASH_BRIGHTNESS
	)
	# The painted walls carry their own dado and frieze (city_limewash.gdshader).
	ChurchMurals.paint(
		lower_node, upper_node, site, fabric, CUT, FLOOR, _consecration_crosses(), false
	)
	church.add_child(lower_node)
	church.add_child(upper_node)
	church.add_child(roof_node)
	ChurchSunlight.apply(
		church, lower_node, upper_node, roof_node, fabric, Kit.GLAZING.get(site.id, 0), occluders
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
	root.add_child(_dressing(site))
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
) -> Array[AABB]:
	var occluders: Array[AABB] = []
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
		occluders.append_array(
			Furnish.bench(
				shell, Vector3(float(b["at"][0]), FLOOR, float(b["at"][1])), float(b["len"])
			)
		)
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
	return occluders


## Consecration crosses on the aisle walls, as [centre, into_room].
static func _consecration_crosses() -> Array:
	var spots: Array = []
	for x: float in [6.0, 17.0, 24.5, 31.0]:
		for z: float in [-6.99, 6.99]:
			spots.append([Vector3(x, 3.3, z), Vector3(0, 0, 1.0 if z < 0 else -1.0)])
	return spots


## Almshouse sick-room (ADR 0052 opening): the straw-tick beds, table, bench,
## shelf and herb rack are catalogue dressing in the manifest; the fixed pieces
## are built here: a small altar niche with a plain crucifix on the west wall
## (the arch beside it opens on the south aisle and its side altar, so the sick
## hear mass) and an iron brazier, since the range has no chimney.
static func _almshouse(shell: CityBuildingBuilder.Shell) -> void:
	var a := ALMS_ALTAR
	# Shallow painted niche in the wall face behind the mensa.
	CitySiteProps._box(
		shell,
		"limewash",
		a + Vector3(0.0, 0.95, -0.55),
		a + Vector3(0.02, 2.55, 0.55),
		Color(0.62, 0.3, 0.2)
	)
	CitySiteProps._box(
		shell,
		"limewash",
		a + Vector3(0.0, 2.55, -0.65),
		a + Vector3(0.05, 2.65, 0.65),
		Color(0.85, 0.82, 0.74)
	)
	# Plank mensa on a masonry block, a linen cloth over it.
	CitySiteProps._box(
		shell, "ashlar", a + Vector3(0.0, 0.0, -0.6), a + Vector3(0.5, 0.88, 0.6), Kit.ASHLAR
	)
	CitySiteProps._box(
		shell,
		"limewash",
		a + Vector3(0.0, 0.88, -0.64),
		a + Vector3(0.54, 0.92, 0.64),
		Color(0.95, 0.93, 0.86)
	)
	CitySiteProps._box(
		shell,
		"limewash",
		a + Vector3(0.53, 0.55, -0.64),
		a + Vector3(0.545, 0.92, 0.64),
		Color(0.95, 0.93, 0.86)
	)
	Furnish.wall_crucifix(shell, a + Vector3(0.02, 1.85, 0.0), Vector3.RIGHT)
	# Brazier: three iron legs, a shallow iron pan of glowing charcoal.
	var b := BRAZIER
	for k in 3:
		var ang := TAU * k / 3.0
		var foot := b + Vector3(cos(ang) * 0.26, 0.0, sin(ang) * 0.26)
		var top := b + Vector3(cos(ang) * 0.2, 0.5, sin(ang) * 0.2)
		Kit.bar(shell, "dark", foot, top, 0.04, Kit.IRON)
	# Iron pan: a thin bottom plate and a low rim round the coals.
	CitySiteProps._box(
		shell, "dark", b + Vector3(-0.25, 0.48, -0.25), b + Vector3(0.25, 0.52, 0.25), Kit.IRON
	)
	for k in 4:
		var d := Vector3.RIGHT.rotated(Vector3.UP, PI * 0.5 * k)
		var e := d.cross(Vector3.UP)
		var p0 := b + Vector3(0, 0.52, 0) + d * 0.24 - e * 0.25
		var p1 := b + Vector3(0, 0.66, 0) + d * 0.27 + e * 0.25
		CitySiteProps._box(shell, "dark", p0.min(p1), p0.max(p1), Kit.IRON)


## Catalogue dressing (obj.* with GLB models) and district life props (the
## herb drying rack) from the manifest, standing on their room floor.
static func _dressing(site: CitySite) -> Node3D:
	var node := Node3D.new()
	node.name = "Almshouse"
	for item: Dictionary in site.data.get("dressing", []):
		var local := Vector2(item["at"][0], item["at"][1])
		var room_floor := site.floor_at(site.to_world(local))
		var ground := FLOOR
		if not room_floor.is_empty():
			ground = float(room_floor["height"]) - site.level
		ground += float(item.get("y", 0.0))
		var model: Node3D = null
		match String(item["kind"]):
			"catalog":
				model = CityInteriors._template(String(item["object"]), "")
			"life_prop":
				model = Node3D.new()
				var legacy := Node3D.new()
				legacy.scale = Vector3.ONE * LEGACY_UNIT_M
				model.add_child(legacy)
				LifeProps.add_to(legacy, StringName(item["prop"]), {"id": StringName(item["id"])})
			_:
				push_error("Holy Spirit: unknown dressing kind %s" % item["kind"])
		if model == null:
			continue
		model.name = String(item["id"]).replace(".", "_")
		model.position = Vector3(local.x, ground, local.y)
		model.rotation.y = -deg_to_rad(float(item.get("rotation_deg", 0.0)))
		node.add_child(model)
	return node


static func _lights(node: Node3D) -> void:
	for spot: Vector3 in [
		Vector3(46.4, CHOIR_FLOOR + 1.8, -3.2),
		Vector3(36.0, FLOOR + 1.5, 3.0),
		Vector3(43.0, FLOOR + 1.6, 4.6),
		Vector3(38.9, FLOOR + 1.4, 3.05),
		Vector3(17.0, 4.0, -3.4),
		Vector3(29.0, 4.0, -3.4)
	]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.45)
		light.light_energy = 1.5
		light.omni_range = 10.0
		light.position = spot
		CityDoors.keep_indoors(light)
		node.add_child(light)
	# Glowing charcoal in the brazier pan, and its low ember light.
	var coals := MeshInstance3D.new()
	coals.name = "BrazierCoals"
	var box := BoxMesh.new()
	box.size = Vector3(0.44, 0.06, 0.44)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.35, 0.08, 0.02)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.36, 0.08)
	glow.emission_energy_multiplier = 1.6
	box.material = glow
	coals.mesh = box
	coals.position = BRAZIER + Vector3(0, 0.56, 0)
	node.add_child(coals)
	# Low ember glow over the brazier.
	var ember := OmniLight3D.new()
	ember.light_color = Color(1.0, 0.45, 0.18)
	ember.light_energy = 0.8
	ember.omni_range = 3.5
	ember.position = BRAZIER + Vector3(0, 0.9, 0)
	CityDoors.keep_indoors(ember)
	node.add_child(ember)
