extends RefCounted

## site.holy_spirit (ADR 0032): the Holy Spirit parish church and almshouse as
## they stood in spring 1343, after
## history/dossiers/religion/churches-and-religious-houses.md. A two-aisle hall
## church under one steep tile roof between crow-stepped gables, three octagonal
## pillars down the middle and a flat painted timber ceiling (the star vaults
## are 1360); a square choir on the north nave's axis behind the triumphal
## arch with its rood beam; the almshouse (1334) in the south-east, open to the
## church; the 1360 west tower with a shingled helm as a recorded presentation
## choice. Lancets carry leaded stained glass (plausible composite after Gotland
## parish glazing). The walls come from the manifest fabric (CitySiteKit), so
## the model and the walk data share one description. Everything above head
## height goes to "Church/Upper", roofs and ceilings to "Church/Roof", both
## hidden while Kalev is inside (except in first person).

const Kit := preload("res://scripts/city/sites/site_kit.gd")
const FLOOR := 0.12
const CHOIR_FLOOR := 0.37
const CUT := FLOOR + CityBuildingBuilder.CUT_HEIGHT
const NAVE := Rect2(6.6, -8.0, 24.0, 16.0)
const NAVE_EAVE := 9.5
const CHOIR := Rect2(30.6, -8.0, 9.0, 9.0)
const CHOIR_EAVE := 8.0
const ALMS := Rect2(30.6, 1.0, 7.4, 7.0)
const ALMS_EAVE := 4.5
const TOWER := Rect2(0.0, -3.3, 6.6, 6.6)
const TOWER_EAVE := 21.0
const PITCH := 52.0
const PILLARS: Array[float] = [12.6, 18.6, 24.6]
const CEILING := 8.6


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
	Kit.walls(body, glass, fabric)
	_gables(body)
	_roofs(roof)
	_interior(body, roof, rng)
	var parts := body.split_at(CUT)
	var lower: CityBuildingBuilder.Shell = parts[0]
	Kit.cut_caps(lower, fabric, CUT)
	var lower_node := Kit.mesh("Lower", lower)
	var upper_node := Kit.mesh("Upper", parts[1])
	# Glass sits in the windows (all above head height): it lifts with the walls.
	var glass_parts := glass.split_at(CUT)
	upper_node.add_child(Kit.mesh("Glass", glass_parts[1]))
	lower_node.add_child(Kit.mesh("GlassLow", glass_parts[0]))
	var painted := Kit.painted_for(site, FLOOR, CHOIR.position.x - 0.6)
	for inst: MeshInstance3D in [lower_node, upper_node]:
		for k in inst.mesh.get_surface_count():
			if inst.mesh.surface_get_material(k) == Kit.material_for("painted"):
				inst.set_surface_override_material(k, painted)
	church.add_child(lower_node)
	church.add_child(upper_node)
	church.add_child(Kit.mesh("Roof", roof))
	_lights(lower_node)
	return root


## Crow-stepped gables with blind niches: nave west and east, choir east,
## almshouse east; the tower helm.
static func _gables(shell: CityBuildingBuilder.Shell) -> void:
	var nave_slope := tan(deg_to_rad(PITCH))
	var nave_apex := NAVE_EAVE + NAVE.size.y * 0.5 * nave_slope + 0.6
	Kit.stepped_gable(
		shell, NAVE.position.x, -1.0, NAVE.position.y, NAVE.end.y, NAVE_EAVE, nave_apex, 6, 1.2, 3
	)
	Kit.stepped_gable(
		shell, NAVE.end.x, 1.0, NAVE.position.y, NAVE.end.y, NAVE_EAVE, nave_apex, 6, 1.2, 0
	)
	var choir_apex := CHOIR_EAVE + CHOIR.size.y * 0.5 * nave_slope + 0.5
	Kit.stepped_gable(
		shell, CHOIR.end.x, 1.0, CHOIR.position.y, CHOIR.end.y, CHOIR_EAVE, choir_apex, 4, 1.1, 3
	)
	var alms_apex := ALMS_EAVE + ALMS.size.y * 0.5 * tan(deg_to_rad(45.0)) + 0.4
	Kit.stepped_gable(
		shell, ALMS.end.x, 1.0, ALMS.position.y, ALMS.end.y, ALMS_EAVE, alms_apex, 2, 0.8, 0
	)


static func _roofs(roof: CityBuildingBuilder.Shell) -> void:
	Kit.gable_roof(
		roof,
		NAVE.position.x + 0.6,
		NAVE.end.x - 0.6,
		NAVE.position.y,
		NAVE.end.y,
		NAVE_EAVE,
		PITCH,
		0.5
	)
	Kit.gable_roof(
		roof,
		CHOIR.position.x,
		CHOIR.end.x - 0.55,
		CHOIR.position.y,
		CHOIR.end.y,
		CHOIR_EAVE,
		PITCH,
		0.45
	)
	Kit.gable_roof(
		roof, ALMS.position.x, ALMS.end.x - 0.4, ALMS.position.y, ALMS.end.y, ALMS_EAVE, 45.0, 0.35
	)
	var c := TOWER.get_center()
	Kit.pyramid_roof(roof, c, TOWER.size.x * 0.5, TOWER_EAVE, TOWER_EAVE + 7.5)
	# Ceilings: flat painted boards over nave and choir, boards in the almshouse.
	_ceiling(roof, Rect2(7.8, -6.8, 21.6, 13.6), CEILING, true)
	_ceiling(roof, Rect2(30.6, -6.9, 7.9, 6.8), CHOIR_EAVE - 0.4, true)
	_ceiling(roof, Rect2(30.6, 1.0, 6.6, 6.2), ALMS_EAVE, false)
	_ceiling(roof, Rect2(1.3, -2.0, 5.3, 4.0), 9.0, false)


## Board ceiling with beams; `painted` alternates red-ochre and white boards
## under the beams, as flat church ceilings were decorated.
static func _ceiling(roof: CityBuildingBuilder.Shell, r: Rect2, y: float, painted: bool) -> void:
	var x := r.position.x
	var k := 0
	while x < r.end.x - 0.01:
		var x1 := minf(x + 0.45, r.end.x)
		var tone := (
			(Color(0.55, 0.2, 0.14) if k % 2 == 0 else Color(0.82, 0.78, 0.68))
			if painted
			else Kit.OAK
		)
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
	var b := r.position.x + 0.6
	while b < r.end.x:
		CitySiteProps._box(
			roof,
			"timber",
			Vector3(b - 0.12, y - 0.32, r.position.y),
			Vector3(b + 0.12, y, r.end.y),
			Kit.OAK_DARK
		)
		b += 2.0


static func _interior(
	shell: CityBuildingBuilder.Shell, roof: CityBuildingBuilder.Shell, rng: RandomNumberGenerator
) -> void:
	# Floors: flags with ledger slabs in nave and choir; the choir one step up.
	Kit.flag_floor(shell, Rect2(1.3, -2.0, 5.3, 4.0), FLOOR, rng)
	Kit.flag_floor(shell, Rect2(6.6, -6.8, 24.0, 13.6), FLOOR, rng, 0.06)
	Kit.flag_floor(shell, Rect2(30.6, -6.9, 7.9, 6.8), CHOIR_FLOOR, rng, 0.1)
	Kit.flag_floor(shell, Rect2(30.6, 1.0, 6.6, 6.2), FLOOR, rng)
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(29.4, FLOOR - 0.01, -5.8),
		Vector3(30.6, CHOIR_FLOOR - 0.12, -1.2),
		Kit.ASHLAR
	)
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(29.9, FLOOR - 0.01, -5.8),
		Vector3(30.6, CHOIR_FLOOR - 0.005, -1.2),
		Kit.ASHLAR
	)
	# Pillars down the middle and the beam they carry.
	for x: float in PILLARS:
		Kit.pillar(shell, Vector3(x, FLOOR, 0.0), 0.42, CEILING - 0.4 - FLOOR)
	CitySiteProps._box(
		roof,
		"timber",
		Vector3(7.8, CEILING - 0.6, -0.25),
		Vector3(29.4, CEILING - 0.2, 0.25),
		Kit.OAK_DARK
	)
	# Wall benches of stone for the weak (the congregation stands).
	CitySiteProps._box(
		shell, "ashlar", Vector3(7.8, FLOOR, -6.8), Vector3(29.4, FLOOR + 0.45, -6.4), Kit.ASHLAR
	)
	CitySiteProps._box(
		shell, "ashlar", Vector3(7.8, FLOOR, 6.4), Vector3(11.8, FLOOR + 0.45, 6.8), Kit.ASHLAR
	)
	CitySiteProps._box(
		shell, "ashlar", Vector3(13.4, FLOOR, 6.4), Vector3(29.4, FLOOR + 0.45, 6.8), Kit.ASHLAR
	)
	_font(shell, Vector3(9.5, FLOOR, -4.6))
	_altar(shell, Vector3(38.0, CHOIR_FLOOR, -3.5), 2.0, true)
	_altar(shell, Vector3(29.0, FLOOR, 1.6), 1.4, false)
	_rood(shell)
	_lectern(shell, Vector3(28.3, FLOOR, -1.2))
	_consecration_crosses(shell)
	# Holy-water stoup by the south door; bell ropes in the tower porch.
	Kit.pillar(shell, Vector3(14.2, FLOOR, 6.1), 0.12, 0.85)
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(13.95, FLOOR + 0.85, 5.85),
		Vector3(14.45, FLOOR + 1.0, 6.35),
		Kit.ASHLAR
	)
	for z: float in [-0.5, 0.0, 0.5]:
		Kit.bar(
			shell,
			"timber",
			Vector3(4.4, 9.0, z),
			Vector3(4.4, 1.1, z),
			0.035,
			Color(0.68, 0.6, 0.45)
		)
	_almshouse(shell)


## Octagonal stone font on a stem, with a wooden lid.
static func _font(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	CitySiteProps._box(
		shell, "ashlar", at + Vector3(-0.55, 0.0, -0.55), at + Vector3(0.55, 0.15, 0.55), Kit.ASHLAR
	)
	Kit.pillar(shell, at + Vector3(0, 0.15, 0), 0.18, 0.45)
	Kit.pillar(shell, at + Vector3(0, 0.6, 0), 0.42, 0.35)
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.4, 0.95, -0.4), at + Vector3(0.4, 1.0, 0.4), Kit.OAK_DARK
	)


## Stone mensa with linen, a red frontal, candlesticks and a cross; the high
## altar gets a painted retable panel behind.
static func _altar(shell: CityBuildingBuilder.Shell, at: Vector3, width: float, high: bool) -> void:
	var h := 1.02
	CitySiteProps._box(
		shell,
		"ashlar",
		at + Vector3(-0.5, 0.0, -width * 0.5),
		at + Vector3(0.5, h - 0.05, width * 0.5),
		Kit.ASHLAR
	)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.52, h - 0.05, -width * 0.5 - 0.02),
		at + Vector3(0.52, h, width * 0.5 + 0.02),
		Color(0.95, 0.93, 0.86)
	)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.53, 0.15, -width * 0.45),
		at + Vector3(-0.51, h - 0.06, width * 0.45),
		Color(0.6, 0.1, 0.1)
	)
	for z: float in [-width * 0.35, width * 0.35]:
		Kit.bar(
			shell,
			"dark",
			at + Vector3(0.1, h, z),
			at + Vector3(0.1, h + 0.35, z),
			0.04,
			Color(0.62, 0.48, 0.2)
		)
		CitySiteProps._box(
			shell,
			"limewash",
			at + Vector3(0.08, h + 0.35, z - 0.025),
			at + Vector3(0.12, h + 0.55, z + 0.025),
			Color(0.95, 0.9, 0.75)
		)
	Kit.bar(
		shell,
		"dark",
		at + Vector3(0.2, h, 0),
		at + Vector3(0.2, h + 0.6, 0),
		0.04,
		Color(0.62, 0.48, 0.2)
	)
	Kit.bar(
		shell,
		"dark",
		at + Vector3(0.2, h + 0.42, -0.15),
		at + Vector3(0.2, h + 0.42, 0.15),
		0.04,
		Color(0.62, 0.48, 0.2)
	)
	if high:
		# Retable: a gilded frame with painted panels (Virgin, saints).
		CitySiteProps._box(
			shell,
			"timber",
			at + Vector3(0.35, h, -width * 0.45),
			at + Vector3(0.45, h + 1.3, width * 0.45),
			Color(0.72, 0.56, 0.22)
		)
		var panels := [Color(0.16, 0.25, 0.5), Color(0.6, 0.12, 0.1), Color(0.16, 0.25, 0.5)]
		for k in 3:
			var z0 := -width * 0.42 + k * width * 0.28
			CitySiteProps._box(
				shell,
				"limewash",
				at + Vector3(0.33, h + 0.12, z0 + 0.03),
				at + Vector3(0.35, h + 1.18, z0 + width * 0.28 - 0.03),
				panels[k]
			)


## Rood beam across the triumphal arch with the crucifix between Mary and John.
static func _rood(shell: CityBuildingBuilder.Shell) -> void:
	var x := 30.3
	var y := 5.4
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x - 0.15, y - 0.25, -5.8),
		Vector3(x + 0.15, y, -1.2),
		Color(0.5, 0.18, 0.12)
	)
	Kit.bar(shell, "timber", Vector3(x, y, -3.5), Vector3(x, y + 2.0, -3.5), 0.14, Kit.OAK_DARK)
	Kit.bar(
		shell, "timber", Vector3(x, y + 1.45, -4.3), Vector3(x, y + 1.45, -2.7), 0.12, Kit.OAK_DARK
	)
	CitySiteProps._box(
		shell,
		"limewash",
		Vector3(x - 0.12, y + 0.55, -3.62),
		Vector3(x - 0.08, y + 1.55, -3.38),
		Color(0.82, 0.74, 0.62)
	)
	for z: float in [-4.9, -2.1]:
		CitySiteProps._box(
			shell,
			"limewash",
			Vector3(x - 0.1, y, z - 0.18),
			Vector3(x + 0.1, y + 1.1, z + 0.18),
			Color(0.2, 0.3, 0.55) if z < -3.5 else Color(0.55, 0.15, 0.12)
		)


static func _lectern(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	CitySiteProps._box(
		shell,
		"timber",
		at + Vector3(-0.06, 0.0, -0.06),
		at + Vector3(0.06, 1.0, 0.06),
		Kit.OAK_DARK
	)
	CitySiteProps._box(
		shell,
		"timber",
		at + Vector3(-0.25, 0.0, -0.25),
		at + Vector3(0.25, 0.06, 0.25),
		Kit.OAK_DARK
	)
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.24, 1.0, -0.3), at + Vector3(0.24, 1.06, 0.3), Kit.OAK
	)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.18, 1.06, -0.24),
		at + Vector3(0.18, 1.1, 0.24),
		Color(0.88, 0.82, 0.66)
	)


## Twelve painted consecration crosses (red circles) on the nave walls.
static func _consecration_crosses(shell: CityBuildingBuilder.Shell) -> void:
	for x: float in [10.0, 16.0, 22.0, 27.6]:
		for z: float in [-6.79, 6.79]:
			var out := Vector3(0, 0, 1.0 if z < 0 else -1.0)
			var c := Vector3(x, 2.7, z)
			for k in 12:
				var a0 := TAU * k / 12.0
				var a1 := TAU * (k + 1) / 12.0
				shell.tri_out(
					"limewash",
					c + out * 0.004,
					c + Vector3(cos(a0) * 0.28, sin(a0) * 0.28, 0) + out * 0.004,
					c + Vector3(cos(a1) * 0.28, sin(a1) * 0.28, 0) + out * 0.004,
					Color(0.6, 0.16, 0.12),
					out
				)
			CitySiteProps._box(
				shell,
				"limewash",
				c + Vector3(-0.2, -0.04, 0) + out * 0.006,
				c + Vector3(0.2, 0.04, 0) + out * 0.008,
				Color(0.9, 0.86, 0.76)
			)
			CitySiteProps._box(
				shell,
				"limewash",
				c + Vector3(-0.04, -0.2, 0) + out * 0.006,
				c + Vector3(0.04, 0.2, 0) + out * 0.008,
				Color(0.9, 0.86, 0.76)
			)


## Almshouse: box beds with straw ticks and wool blankets, chests, a candle.
static func _almshouse(shell: CityBuildingBuilder.Shell) -> void:
	# Beds along the south and north walls, the door side (east) kept clear.
	for x: float in [31.65, 33.75, 35.85]:
		_bed(shell, Vector3(x, FLOOR, 6.7), false)
	for x: float in [32.9, 35.1]:
		_bed(shell, Vector3(x, FLOOR, 1.5), false)
	CitySiteProps._box(
		shell, "timber", Vector3(30.8, FLOOR, 1.3), Vector3(31.9, FLOOR + 0.55, 1.9), Kit.OAK_DARK
	)


static func _bed(shell: CityBuildingBuilder.Shell, at: Vector3, along_z: bool) -> void:
	var l := 2.0
	var w := 0.95
	var lo := Vector3(-l * 0.5, 0.0, -w * 0.5)
	var hi := Vector3(l * 0.5, 0.45, w * 0.5)
	if along_z:
		lo = Vector3(lo.z, lo.y, lo.x)
		hi = Vector3(hi.z, hi.y, hi.x)
	CitySiteProps._box(shell, "timber", at + lo, at + hi, Kit.OAK_DARK)
	CitySiteProps._box(
		shell,
		"limewash",
		at + lo * 0.95 + Vector3(0, 0.45, 0),
		at + hi * 0.95 + Vector3(0, 0.15, 0),
		Color(0.78, 0.7, 0.5)
	)
	var blanket_lo := Vector3(lo.x * 0.95, 0.6, lo.z * 0.95)
	var blanket_hi := Vector3(hi.x * 0.95, 0.63, hi.z * 0.95)
	if along_z:
		blanket_hi.z *= 0.2
	else:
		blanket_hi.x *= 0.2
	CitySiteProps._box(shell, "limewash", at + blanket_lo, at + blanket_hi, Color(0.45, 0.2, 0.15))


static func _lights(node: Node3D) -> void:
	for spot: Vector3 in [
		Vector3(37.6, CHOIR_FLOOR + 1.6, -3.5),
		Vector3(28.8, FLOOR + 1.5, 1.6),
		Vector3(34.0, FLOOR + 1.6, 4.0)
	]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.45)
		light.light_energy = 1.4
		light.omni_range = 9.0
		light.position = spot
		node.add_child(light)
