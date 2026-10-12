extends RefCounted

## site.st_michael (ADR 0032, task R-1719): the Cistercian nunnery of
## St Michael in spring 1343, a walled close on the west belt of the Lower
## Town. Attested: the institution (founded 1249, patron of St Olaf's since
## 1267) and a refectory room of 9.25 x 8.1 m in the north wing; everything
## else is a plausible composite after the precinct dossier. The church keeps
## the footprint of the surviving nunnery church: a two-aisled vaulted hall
## with a short flat-ended chancel, plain gables and a ridge bell-cote (no
## tower), lime-washed inside, grisaille glass only. The nuns hear the office
## on a screened west gallery; lay people use the nave from the south portal.
## North of it the claustral ranges stand round a small garth with timber
## lean-to walks; one gate house (porta) leads from the church square into the
## lay sisters' yard with the service wing; kitchen-garden beds and orchard
## rows (plan trees, see build_reval_city_plan.site_closes) fill the rest of
## the high close wall, which follows the ground.

const Kit := preload("res://scripts/city/sites/site_kit.gd")
const Furnish := preload("res://scripts/city/sites/church_furnishings.gd")
const KitchenGardenModels := preload("res://scripts/map/view3d/map_view_kitchen_garden_models.gd")
const FLOOR := 0.12
const CHOIR_FLOOR := 0.45
const CUT := FLOOR + CityBuildingBuilder.CUT_HEIGHT
const NX := 28.0
const CX := 38.0
const NZ0 := -5.0
const NZ1 := 12.5
const NZC := 3.75
const CZ0 := -2.25
const CZ1 := 9.75
const EAVE := 11.0
const CHOIR_EAVE := 9.0
const PITCH := 45.0
const CHOIR_PITCH := 50.0
const SPRING := 6.0
const CROWN := 9.6
const PIER_X: Array[float] = [9.8, 18.2]
## West gallery (Nonnenempore): front beam line and deck height.
const GALLERY_X := 7.0
const GALLERY_Y := 4.2
const RANGE_EAVE := 6.8
const RANGE_PITCH := 45.0
const SERVICE_EAVE := 4.2
const PORTA_EAVE := 5.2
## Cloister garth inside the ranges and the depth of its walks.
const GARTH := Rect2(8.0, -25.5, 12.0, 20.5)
const WALK := 2.5
## Close wall above the ground, and the length of one draped wall piece.
const PIECE := 2.5
const COPING := Color(0.8, 0.78, 0.72)
## April seedlings in the kitchen-garden beds (CityFarmland garden start).
const GARDEN_GROWTH := 0.35


static func build(site: CitySite, plan: CityPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_st_michael"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(site.id))
	var glazing: int = Kit.GLAZING.get(site.id, 0)
	root.add_child(_church(site, _fabric(site, ["nave.", "choir."]), glazing, rng))
	root.add_child(_porta(site, _fabric(site, ["porta."]), rng))
	root.add_child(_claustrum(site, _fabric(site, ["range."]), glazing))
	root.add_child(_service(site, _fabric(site, ["service."])))
	root.add_child(_close(site, plan))
	_gardens(root, site, plan)
	for item: Dictionary in site.data.get("dressing", []):
		var world := site.to_world(Vector2(item["at"][0], item["at"][1]))
		CitySiteProps.add(root, item, plan.ground_height(world) - site.level)
	# Kitchen and brewhouse stacks; CityWorld3D streams a lit plume over each.
	var tops: Array[Vector3] = []
	for c: Array in site.data.get("chimneys", []):
		tops.append(Vector3(c[0], c[1], c[2]))
	root.set_meta(&"chimneys", tops)
	return root


static func _fabric(site: CitySite, prefixes: Array) -> Array:
	var out: Array = []
	for w: Dictionary in site.data["fabric"]:
		for prefix: String in prefixes:
			if String(w["id"]).begins_with(prefix):
				out.append(w)
	return out


static func _church(
	site: CitySite, fabric: Array, glazing: int, rng: RandomNumberGenerator
) -> Node3D:
	var church := Node3D.new()
	church.name = "Church"
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	Kit.walls(body, glass, fabric, glazing)
	var apex := _gable(body, 0.0, 1.0, NZ0, NZ1, EAVE, PITCH, 1.4)
	_gable(body, NX, -1.0, NZ0, NZ1, EAVE, PITCH, 1.4)
	_gable(body, CX, -1.0, CZ0, CZ1, CHOIR_EAVE, CHOIR_PITCH, 1.3)
	Kit.gable_roof(roof, -0.3, NX + 0.3, NZ0, NZ1, EAVE, PITCH, 0.5)
	Kit.gable_roof(roof, NX + 0.3, CX + 0.3, CZ0, CZ1, CHOIR_EAVE, CHOIR_PITCH, 0.4)
	_bell_cote(roof, apex)
	_vaults(roof)
	var occluders := _church_interior(body, rng)
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
	church.add_child(lower_node)
	church.add_child(upper_node)
	church.add_child(roof_node)
	ChurchSunlight.apply(church, lower_node, upper_node, roof_node, fabric, glazing, occluders)
	(
		Furnish
		. lights(
			lower_node,
			[
				Vector3(35.0, CHOIR_FLOOR + 1.8, NZC),
				Vector3(14.0, 4.5, NZC),
				Vector3(22.0, 3.0, NZC),
				Vector3(4.0, GALLERY_Y + 1.6, NZC),
			]
		)
	)
	return church


## Plain triangular gable (no crow-steps: Cistercian restraint) standing on a
## wall head at `x`, `inward` towards the building; returns the apex height.
static func _gable(
	shell: CityBuildingBuilder.Shell,
	x: float,
	inward: float,
	z0: float,
	z1: float,
	base: float,
	pitch: float,
	thick: float
) -> float:
	var zc := (z0 + z1) * 0.5
	var apex := base + (z1 - z0) * 0.5 * tan(deg_to_rad(pitch))
	var xi := x + inward * thick
	shell.tri_out(
		"wall:limestone",
		Vector3(x, base, z0),
		Vector3(x, base, z1),
		Vector3(x, apex, zc),
		Kit.STONE,
		Vector3(-inward, 0, 0)
	)
	shell.tri_out(
		"wall:limestone",
		Vector3(xi, base, z0),
		Vector3(xi, base, z1),
		Vector3(xi, apex, zc),
		Kit.STONE,
		Vector3(inward, 0, 0)
	)
	return apex


## Ridge bell-cote over the west gable: four oak posts, one bell, a shingled
## cap. Cistercian churches had no towers.
static func _bell_cote(roof: CityBuildingBuilder.Shell, apex: float) -> void:
	var c := Vector2(1.4, NZC)
	var f := 0.75
	var top := apex + 2.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Kit.bar(
				roof,
				"timber",
				Vector3(c.x + sx * f, apex - 0.6, c.y + sz * f),
				Vector3(c.x + sx * f, top, c.y + sz * f),
				0.2,
				Kit.OAK_DARK
			)
	Kit.bar(
		roof,
		"timber",
		Vector3(c.x, top - 0.25, c.y - f),
		Vector3(c.x, top - 0.25, c.y + f),
		0.18,
		Kit.OAK_DARK
	)
	# The bell: a bronze bell-shaped stack of tapering rings.
	var bronze := Color(0.42, 0.32, 0.18)
	for k in 4:
		var r := 0.42 - k * 0.08
		var y := top - 1.25 + k * 0.22
		CitySiteProps._box(
			roof,
			"dark",
			Vector3(c.x - r, y, c.y - r),
			Vector3(c.x + r, y + 0.22, c.y + r),
			bronze
		)
	Kit.pyramid_roof(roof, c, f + 0.35, top, top + 1.6)


## Rib vaults: three bays of each aisle of the hall and the chancel bay.
static func _vaults(roof: CityBuildingBuilder.Shell) -> void:
	var xs: Array[float] = [1.4, PIER_X[0], PIER_X[1], NX - 1.4]
	var zs: Array[float] = [NZ0 + 1.4, NZC, NZ1 - 1.4]
	for i in 3:
		for j in 2:
			Kit.rib_vault(
				roof, Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j]), SPRING, CROWN
			)
	Kit.rib_vault(roof, Rect2(NX, CZ0 + 1.3, CX - 1.3 - NX, (CZ1 - CZ0) - 2.6), 5.6, 8.0)


## Flags, chancel steps, the two piers, the screened west gallery with the
## nuns' stalls, a plain altar and the rood. Returns the piers, posts and
## stalls as boxes that shade the window light.
static func _church_interior(
	shell: CityBuildingBuilder.Shell, rng: RandomNumberGenerator
) -> Array[AABB]:
	var occluders: Array[AABB] = []
	Kit.flag_floor(shell, Rect2(1.4, NZ0 + 1.4, NX - 2.8, NZ1 - NZ0 - 2.8), FLOOR, rng, 0.05)
	Kit.flag_floor(
		shell, Rect2(28.5, CZ0 + 1.3, CX - 1.3 - 28.5, CZ1 - CZ0 - 2.6), CHOIR_FLOOR, rng, 0.1
	)
	for k in 3:
		var x0 := 25.2 + k * 1.1
		var h := FLOOR + (CHOIR_FLOOR - FLOOR) * (k + 1) / 3.0
		CitySiteProps._box(
			shell, "ashlar", Vector3(x0, FLOOR - 0.01, 0.6), Vector3(28.5, h, 6.9), Kit.ASHLAR
		)
	for x: float in PIER_X:
		occluders.append_array(Kit.square_pier(shell, Vector3(x, FLOOR, NZC), 0.7, SPRING - FLOOR))
	# West gallery: oak deck on two posts and the west wall, a front beam, a
	# solid parapet with a lattice grille over it (the nuns are not seen).
	var z0 := NZ0 + 1.4
	var z1 := NZ1 - 1.4
	var deck := GALLERY_Y + 0.25
	CitySiteProps._box(
		shell, "timber", Vector3(1.4, GALLERY_Y, z0), Vector3(GALLERY_X, deck, z1), Kit.OAK_DARK
	)
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(GALLERY_X - 0.3, GALLERY_Y - 0.35, z0),
		Vector3(GALLERY_X, GALLERY_Y, z1),
		Kit.OAK_DARK * 0.9
	)
	for z: float in [-0.1, 7.6]:
		Kit.bar(
			shell,
			"timber",
			Vector3(GALLERY_X - 0.15, FLOOR, z),
			Vector3(GALLERY_X - 0.15, GALLERY_Y, z),
			0.32,
			Kit.OAK_DARK
		)
		occluders.append(AABB(Vector3(GALLERY_X - 0.31, FLOOR, z - 0.16), Vector3(0.32, 4.1, 0.32)))
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(GALLERY_X - 0.12, deck, z0),
		Vector3(GALLERY_X, deck + 0.6, z1),
		Kit.OAK * 0.8
	)
	var z := z0 + 0.1
	while z < z1:
		Kit.bar(
			shell,
			"timber",
			Vector3(GALLERY_X - 0.06, deck + 0.6, z),
			Vector3(GALLERY_X - 0.06, deck + 1.35, z),
			0.05,
			Kit.OAK_DARK
		)
		z += 0.16
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(GALLERY_X - 0.14, deck + 1.35, z0),
		Vector3(GALLERY_X, deck + 1.45, z1),
		Kit.OAK_DARK
	)
	occluders.append(AABB(Vector3(1.4, GALLERY_Y, z0), Vector3(GALLERY_X - 1.4, 1.6, z1 - z0)))
	for x: float in [3.0, 5.1]:
		for zc: float in [0.6, 6.9]:
			Furnish.bench(shell, Vector3(x, deck, zc), 5.6)
	Furnish.altar(shell, Vector3(35.4, CHOIR_FLOOR, NZC), 2.2, false)
	Furnish.rood(shell, NX - 0.7, 5.2, NZC - 3.4, NZC + 3.4)
	return occluders


## Gate house (porta): a vaulted-through passage on the close wall line, gable
## to the church square, the portress's turn window on the north side.
static func _porta(site: CitySite, fabric: Array, rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "Porta"
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	Kit.walls(body, glass, fabric)
	_gable(body, 0.0, -1.0, 18.0, 24.0, PORTA_EAVE, 50.0, 0.75)
	_gable(body, -7.0, 1.0, 18.0, 24.0, PORTA_EAVE, 50.0, 0.75)
	Kit.gable_roof(roof, -7.3, 0.3, 18.0, 24.0, PORTA_EAVE, 50.0, 0.45)
	Kit.flag_floor(body, Rect2(-6.25, 18.75, 5.5, 4.5), FLOOR, rng)
	# Plank ceiling under the portress's chamber.
	CitySiteProps._box(
		body, "timber", Vector3(-6.25, 3.9, 18.75), Vector3(-0.75, 4.05, 23.25), Kit.OAK_DARK
	)
	var parts := body.split_at(CUT)
	var lower: CityBuildingBuilder.Shell = parts[0]
	Kit.cut_caps(lower, fabric, CUT)
	var lower_node := Kit.mesh("Lower", lower)
	var upper_node := Kit.mesh("Upper", parts[1])
	var roof_node := Kit.mesh("Roof", roof)
	Kit.bind_site_washes([lower_node, upper_node, roof_node], site, FLOOR, 1e9)
	node.add_child(lower_node)
	node.add_child(upper_node)
	node.add_child(roof_node)
	Furnish.lights(lower_node, [Vector3(-3.5, 2.6, 21.0)])
	return node


## Claustral ranges (closed to the player: the enclosure) round the garth:
## west range, north range with the refectory and kitchen, east range with the
## chapter house and dormitory; timber lean-to walks on a low sill wall.
static func _claustrum(site: CitySite, fabric: Array, glazing: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Claustrum"
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	Kit.walls(body, glass, fabric, glazing)
	_gable(body, 0.0, 1.0, -34.0, -25.5, RANGE_EAVE, RANGE_PITCH, 0.9)
	_gable(body, NX, -1.0, -34.0, -25.5, RANGE_EAVE, RANGE_PITCH, 0.9)
	Kit.gable_roof(roof, -0.3, NX + 0.3, -34.0, -25.5, RANGE_EAVE, RANGE_PITCH, 0.4)
	node.add_child(_roof_along_z(Rect2(0.0, -25.5, 8.0, 20.5), RANGE_EAVE, RANGE_PITCH))
	node.add_child(_roof_along_z(Rect2(20.0, -25.5, 8.0, 20.5), RANGE_EAVE, RANGE_PITCH))
	_cloister_walks(body, roof)
	_niche_doors(body, fabric)
	_stacks(body, site, [0])
	var body_node := Kit.mesh("Ranges", body)
	body_node.add_child(Kit.mesh("Glass", glass))
	var roof_node := Kit.mesh("Roof", roof)
	Kit.bind_site_washes([body_node, roof_node], site, FLOOR, 1e9)
	node.add_child(body_node)
	node.add_child(roof_node)
	return node


## A gable roof whose ridge runs along site z over `r` (x, z, w, d): the kit's
## roof is built along x in a frame turned a quarter about y (frame u = -z,
## frame v = x), so its tile UVs and ridge tiles stay the same.
static func _roof_along_z(r: Rect2, eave: float, pitch: float) -> MeshInstance3D:
	var shell := CityBuildingBuilder.Shell.new()
	Kit.gable_roof(shell, -r.end.y, -r.position.y, r.position.x, r.end.x, eave, pitch, 0.4)
	var inst := Kit.mesh("RoofZ", shell)
	inst.rotation.y = PI * 0.5
	return inst


static func _cloister_walks(
	body: CityBuildingBuilder.Shell, roof: CityBuildingBuilder.Shell
) -> void:
	var g := GARTH
	var inner := g.grow(-WALK)
	var hi := 4.2
	var lo := 3.1
	# Lean-to roofs from the range (or church) walls down to the arcade line.
	var sides := [
		[Vector2(g.position.x, g.position.y), Vector2(g.position.x, g.end.y), Vector2(1, 0)],
		[Vector2(g.end.x, g.position.y), Vector2(g.end.x, g.end.y), Vector2(-1, 0)],
		[Vector2(g.position.x, g.position.y), Vector2(g.end.x, g.position.y), Vector2(0, 1)],
		[Vector2(g.position.x, g.end.y), Vector2(g.end.x, g.end.y), Vector2(0, -1)],
	]
	for s: Array in sides:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var n: Vector2 = s[2]
		var d := n * (WALK + 0.3)
		var slope := (hi - lo) / WALK
		var low := hi - slope * (WALK + 0.3)
		var run := sqrt((WALK + 0.3) * (WALK + 0.3) + (hi - low) * (hi - low))
		var along := a.distance_to(b)
		var face := Vector3(n.x * slope, 1.0, n.y * slope).normalized()
		var p0 := Vector3(a.x, hi, a.y)
		var p1 := Vector3(b.x, hi, b.y)
		var p2 := Vector3(b.x + d.x, low, b.y + d.y)
		var p3 := Vector3(a.x + d.x, low, a.y + d.y)
		roof.tri_out(
			"roof:tile",
			p0,
			p1,
			p2,
			Color.WHITE,
			face,
			Vector2(0, 0),
			Vector2(along, 0),
			Vector2(along, run)
		)
		roof.tri_out(
			"roof:tile",
			p0,
			p2,
			p3,
			Color.WHITE,
			face,
			Vector2(0, 0),
			Vector2(along, run),
			Vector2(0, run)
		)
		roof.quad_out("timber", p0, p1, p2, p3, Kit.OAK_DARK * 0.8, -face)
	# Arcade: a low sill wall round the garth with oak posts carrying a plate;
	# an opening in the middle of each side.
	var corners := [
		Vector2(inner.position.x, inner.position.y),
		Vector2(inner.end.x, inner.position.y),
		Vector2(inner.end.x, inner.end.y),
		Vector2(inner.position.x, inner.end.y),
	]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var mid := length * 0.5
		for span: Vector2 in [Vector2(0.0, mid - 0.7), Vector2(mid + 0.7, length)]:
			var q0 := a + dir * span.x
			var q1 := a + dir * span.y
			CitySiteProps._box(
				body,
				"wall:limestone",
				Vector3(minf(q0.x, q1.x) - 0.25, -0.2, minf(q0.y, q1.y) - 0.25),
				Vector3(maxf(q0.x, q1.x) + 0.25, 0.65, maxf(q0.y, q1.y) + 0.25),
				Kit.STONE
			)
		var posts := int(length / 2.2)
		for j in posts + 1:
			var p := a + dir * (length * j / posts)
			Kit.bar(
				body, "timber", Vector3(p.x, 0.65, p.y), Vector3(p.x, lo, p.y), 0.2, Kit.OAK_DARK
			)
		Kit.bar(
			body,
			"timber",
			Vector3(a.x, lo + 0.1, a.y),
			Vector3(b.x, lo + 0.1, b.y),
			0.22,
			Kit.OAK_DARK
		)
	# Lavabo well in the garth: a stone kerb with a dark shaft.
	var c := inner.get_center()
	Kit.pillar(body, Vector3(c.x, 0.0, c.y), 0.75, 0.75)
	CitySiteProps._box(
		body,
		"dark",
		Vector3(c.x - 0.5, 0.76, c.y - 0.5),
		Vector3(c.x + 0.5, 0.78, c.y + 0.5),
		Color(0.05, 0.05, 0.06)
	)


## Plank leaves in the door niches of the closed ranges: the enclosure is shut
## to the player, so its doors are blind niches with a board door set in them.
static func _niche_doors(shell: CityBuildingBuilder.Shell, fabric: Array) -> void:
	for w: Dictionary in fabric:
		var a := Vector2(w["a"][0], w["a"][1])
		var b := Vector2(w["b"][0], w["b"][1])
		var dir := (b - a).normalized()
		var out := Vector2(-dir.y, dir.x)
		var inside := Vector2(w["inside"][0], w["inside"][1])
		if out.dot(inside - (a + b) * 0.5) > 0.0:
			out = -out
		for op: Dictionary in w.get("openings", []):
			if String(op.get("kind", "")) != "niche" or float(op["w"]) < 0.9:
				continue
			var half := float(op["w"]) * 0.5 - 0.04
			var c := a + dir * float(op["s"])
			var p0 := c - dir * half - out * 0.2
			var p1 := c + dir * half - out * 0.12
			CitySiteProps._box(
				shell,
				"timber",
				Vector3(minf(p0.x, p1.x), float(op.get("sill", 0.12)), minf(p0.y, p1.y)),
				Vector3(maxf(p0.x, p1.x), float(op["spring"]), maxf(p0.y, p1.y)),
				Kit.OAK_DARK * 0.85
			)


## Rubble chimney stacks for the manifest `chimneys` listed by index.
static func _stacks(body: CityBuildingBuilder.Shell, site: CitySite, indices: Array) -> void:
	var tops: Array = site.data.get("chimneys", [])
	for i: int in indices:
		var t: Array = tops[i]
		var x := float(t[0])
		var y := float(t[1])
		var z := float(t[2])
		CitySiteProps._box(
			body,
			"wall:limestone",
			Vector3(x - 0.6, y - 4.0, z - 0.6),
			Vector3(x + 0.6, y - 0.15, z + 0.6),
			Kit.STONE
		)
		CitySiteProps._box(
			body,
			"ashlar",
			Vector3(x - 0.72, y - 0.15, z - 0.72),
			Vector3(x + 0.72, y, z + 0.72),
			COPING
		)


## Service wing in the lay sisters' yard: granary, brewhouse and stable under
## one shingle roof, with the brewhouse stack.
static func _service(site: CitySite, fabric: Array) -> Node3D:
	var node := Node3D.new()
	node.name = "Service"
	var body := CityBuildingBuilder.Shell.new()
	var glass := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	Kit.walls(body, glass, fabric)
	_gable(body, -38.0, 1.0, 3.0, 11.0, SERVICE_EAVE, 50.0, 0.9)
	_gable(body, -14.0, -1.0, 3.0, 11.0, SERVICE_EAVE, 50.0, 0.9)
	Kit.gable_roof(roof, -38.35, -13.65, 3.0, 11.0, SERVICE_EAVE, 50.0, 0.45, "roof:shingle")
	_niche_doors(body, fabric)
	_stacks(body, site, [1])
	var body_node := Kit.mesh("Body", body)
	var roof_node := Kit.mesh("Roof", roof)
	Kit.bind_site_washes([body_node, roof_node], site, FLOOR, 1e9)
	node.add_child(body_node)
	node.add_child(roof_node)
	return node


## The close wall: every `walk.walls` entry marked `close`, built from the
## same segments the logic plane blocks with, draped over the ground in short
## pieces (the close falls about 3 m to the north-west). The thickness lies on
## the side CityCollisionBuilder gives a wall with no floor beside it,
## (dir.y, -dir.x), so model and collision agree. Square piers stand at the
## corners where two close walls meet.
static func _close(site: CitySite, plan: CityPlan) -> Node3D:
	var shell := CityBuildingBuilder.Shell.new()
	var height := float(site.data["close"].get("wall_h", 4.4))
	var ground := func(p: Vector2) -> float:
		return plan.ground_height(site.to_world(p)) - site.level
	var ends := {}
	for w: Dictionary in site.data["walk"]["walls"]:
		if not bool(w.get("close", false)):
			continue
		var a := Vector2(w["from"][0], w["from"][1])
		var b := Vector2(w["to"][0], w["to"][1])
		var t := float(w["thickness"])
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var m := Vector2(dir.y, -dir.x) * t
		var pieces := maxi(1, ceili(length / PIECE))
		for k in pieces:
			var p0 := a + dir * (length * k / pieces)
			var p1 := a + dir * (length * (k + 1) / pieces)
			var g0: float = ground.call(p0 + m * 0.5)
			var g1: float = ground.call(p1 + m * 0.5)
			_wall_piece(shell, p0, p1, m, minf(g0, g1) - 0.6, g0 + height, g1 + height)
		for p: Vector2 in [a, b]:
			var key := Vector2i(roundi(p.x * 10.0), roundi(p.y * 10.0))
			ends[key] = int(ends.get(key, 0)) + 1
	for key: Vector2i in ends:
		if int(ends[key]) < 2:
			continue
		var p := Vector2(key) / 10.0
		var g: float = ground.call(p)
		CitySiteProps._box(
			shell,
			"wall:limestone",
			Vector3(p.x - 0.65, g - 0.6, p.y - 0.65),
			Vector3(p.x + 0.65, g + height + 0.25, p.y + 0.65),
			Kit.STONE
		)
		CitySiteProps._box(
			shell,
			"ashlar",
			Vector3(p.x - 0.75, g + height + 0.25, p.y - 0.75),
			Vector3(p.x + 0.75, g + height + 0.45, p.y + 0.75),
			COPING
		)
	var node := Kit.mesh("CloseWall", shell)
	return node


## One draped piece of the close wall between p0 and p1 (outer line), `m` the
## thickness vector into the close, tops at y0/y1 with a sloped ashlar coping.
static func _wall_piece(
	shell: CityBuildingBuilder.Shell,
	p0: Vector2,
	p1: Vector2,
	m: Vector2,
	bottom: float,
	y0: float,
	y1: float
) -> void:
	var q0 := p0 + m
	var q1 := p1 + m
	var out := Vector3(-m.x, 0, -m.y)
	shell.quad_out(
		"wall:limestone",
		Vector3(p0.x, bottom, p0.y),
		Vector3(p1.x, bottom, p1.y),
		Vector3(p1.x, y1, p1.y),
		Vector3(p0.x, y0, p0.y),
		Kit.STONE,
		out
	)
	shell.quad_out(
		"wall:limestone",
		Vector3(q0.x, bottom, q0.y),
		Vector3(q1.x, bottom, q1.y),
		Vector3(q1.x, y1, q1.y),
		Vector3(q0.x, y0, q0.y),
		Kit.STONE,
		-out
	)
	# Coping: a slab a little wider than the wall, laid along the top.
	var e := m.normalized() * 0.1
	var c0 := p0 - e
	var c1 := p1 - e
	var d0 := q0 + e
	var d1 := q1 + e
	var h := 0.18
	shell.quad_out(
		"ashlar",
		Vector3(c0.x, y0 + h, c0.y),
		Vector3(c1.x, y1 + h, c1.y),
		Vector3(d1.x, y1 + h, d1.y),
		Vector3(d0.x, y0 + h, d0.y),
		COPING,
		Vector3.UP
	)
	for side: Array in [[c0, c1, out], [d0, d1, -out]]:
		var s0: Vector2 = side[0]
		var s1: Vector2 = side[1]
		shell.quad_out(
			"ashlar",
			Vector3(s0.x, y0 - 0.02, s0.y),
			Vector3(s1.x, y1 - 0.02, s1.y),
			Vector3(s1.x, y1 + h, s1.y),
			Vector3(s0.x, y0 + h, s0.y),
			COPING,
			side[2]
		)


## Wattle-edged kitchen-garden beds (the farmstead garden kit), each patch set
## on its lowest corner so no bed floats.
static func _gardens(root: Node3D, site: CitySite, plan: CityPlan) -> void:
	var gardens := Node3D.new()
	gardens.name = "Gardens"
	root.add_child(gardens)
	for g: Dictionary in site.data.get("garden_beds", []):
		var size := Vector2(g["bed"][0], g["bed"][1])
		var count := int(g["beds"])
		var patch := KitchenGardenModels.patch_size(size, count, 0.6)
		var at := Vector2(g["at"][0], g["at"][1])
		var yaw := deg_to_rad(float(g.get("rotation_deg", 0.0)))
		var low := INF
		for corner: Vector2 in [
			Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)
		]:
			var p := at + (corner * patch * 0.5).rotated(yaw)
			low = minf(low, plan.ground_height(site.to_world(p)) - site.level)
		var patch_node := Node3D.new()
		patch_node.name = String(g["id"]).replace(".", "_")
		patch_node.position = Vector3(at.x, low, at.y)
		patch_node.rotation.y = -yaw
		gardens.add_child(patch_node)
		KitchenGardenModels.add_model(patch_node, String(g["id"]), size, count, 0.6, GARDEN_GROWTH)
