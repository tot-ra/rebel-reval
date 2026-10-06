extends RefCounted

## St Olaf's parish church (Oleviste) as it stood in spring 1343 (R-1120 / UF-11).
## Built by MapViewMeshBuilderChurches.build_st_olaf_church for the stable record
## `st_olaf_silhouette`; this file owns only the massing and dressing.
##
## Evidence (history/dossiers/religion/churches-and-religious-houses.md,
## "St Olaf"): a short hall church whose vaults were completed c. 1330, a massive
## west tower with walls ~3.2 m thick, a small east chancel, quarter enclosed by
## the town wall in the first half of the 14th century. The upper tower is dated
## 1364+, the record spire to the 15th century, and the basilica with its high
## choir follows the 1433 fire - all three are excluded here.
##
## Phase choices (labelled plausible composite in docs/CANON.md):
## - the west tower stands at its massive lower stage, unfinished: ragged toothed
##   top course, open putlog holes, a putlog scaffold and a hoist jib, with the
##   bells hung meanwhile in a provisional timber frame under a shingle cap;
## - one steep tile roof over the three-aisle hall, stone gables with lime-washed
##   blind niches on the east end (Gotland/Reval practice), two-stage buttresses
##   at the vault bays, tall equilateral-pointed lancets;
## - a lower, narrower square chancel with a stepped east triplet and a lean-to
##   sacristy on its north side;
## - a masons' lodge and stone stack on the tower's free corners of the plot.
##
## Footprint 22 x 14 m (1 world unit = 1 m). The west tower sits at -X, the door
## faces +Z (south) where the `to_oleviste_church` transition leaf is drawn on
## the footprint edge, so the portal is a projecting frontispiece reaching z = +7.
## Nothing may leave the footprint: the Pikk-spine bypass lane runs alongside.

const _Wear := preload("res://scripts/map/view3d/map_view_landmark_weathering.gd")
const _BuildingMaterials := preload("res://scripts/map/view3d/map_view_building_materials.gd")
const _Meshes := preload("res://scripts/map/view3d/map_view_gothic_meshes.gd")

const WALL_STEM := "rubble_pale"
const TRIM_STEM := "ashlar_grey"
const ROOF_STEM := "tile_moss"
const SHINGLE_STEM := "shingle_silver"
const LIMEWASH_STEM := "limewash_chalk"
## Paekivi rubble dulls to a cool grey; old tile loses its kiln orange.
const WALL_TONE := Color(0.88, 0.87, 0.85)
const TRIM_TONE := Color(0.76, 0.74, 0.7)
const ROOF_TONE := Color(0.82, 0.76, 0.7)
const LIMEWASH_TONE := Color(0.86, 0.85, 0.81)
const GLASS_TINT := Color(0.16, 0.19, 0.18)
const REVEAL_TINT := Color(0.1, 0.095, 0.085)
const BRONZE := Color(0.42, 0.3, 0.17)
## Silvered, weathered oak for scaffold, bell frame and lodge.
const TIMBER_TINT := Color(0.36, 0.32, 0.27)

## Authored wall height (6 m) is a house-scale default; the vaulted hall stands
## well above the burgher roofs around it.
const NAVE_EAVE_SCALE := 1.4
const CHANCEL_EAVE_SCALE := 1.1
const TOWER_TOP_SCALE := 3.0
const NAVE_PITCH := 1.05
const CHANCEL_PITCH := 1.1
const ROOF_OVERHANG := 0.3
const PLINTH_HEIGHT := 0.6

## Plan, in metres from the footprint centre (X along the church, Z across).
const TOWER_X := Vector2(-10.8, -4.6)
const TOWER_HALF_Z := 4.2
const NAVE_X := Vector2(-5.0, 6.5)
const NAVE_HALF_Z := 6.2
const CHANCEL_X := Vector2(6.5, 10.6)
const CHANCEL_HALF_Z := 3.9
const SACRISTY_X := Vector2(7.0, 10.0)
const SACRISTY_Z := Vector2(-6.4, -3.9)
## Bay lines of the hall vaults; the door bay (centre x = 1.0) matches the
## `to_oleviste_church` transition centre.
const BUTTRESS_X: Array[float] = [-4.3, -0.9, 3.0, 6.1]
const PORTAL_X := 1.0
const PORTAL_OUTER_ORDER_DEPTH := 0.16
const FOOTPRINT_HALF := Vector2(11.0, 7.0)

static var _cache: Dictionary = {}


static func add_details(root: Node3D, building: Dictionary, height: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = String(building.get("id", "st_olaf")).hash()
	var mats := _materials(building)
	var nave_eave := height * NAVE_EAVE_SCALE
	var chancel_eave := height * CHANCEL_EAVE_SCALE
	var tower_top := height * TOWER_TOP_SCALE
	var ctx := {
		"root": root,
		"rng": rng,
		"mats": mats,
		"nave_eave": nave_eave,
		"chancel_eave": chancel_eave,
		"tower_top": tower_top,
		"window_index": 0,
	}
	_add_nave(ctx)
	_add_chancel(ctx)
	_add_sacristy(ctx)
	_add_tower(ctx)
	_add_works_yard(ctx)


## Height of the nave roof surface at a given |z| (used to keep openings and
## niches clear of roofs).
static func nave_roof_y(nave_eave: float, abs_z: float) -> float:
	return nave_eave + maxf(NAVE_HALF_Z - abs_z, 0.0) * NAVE_PITCH


static func chancel_roof_y(chancel_eave: float, abs_z: float) -> float:
	return chancel_eave + maxf(CHANCEL_HALF_Z - abs_z, 0.0) * CHANCEL_PITCH


# --- Nave -------------------------------------------------------------------


static func _add_nave(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var mats: Dictionary = ctx["mats"]
	var eave: float = ctx["nave_eave"]
	var length := NAVE_X.y - NAVE_X.x
	var center_x := (NAVE_X.x + NAVE_X.y) * 0.5
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(length, eave, NAVE_HALF_Z * 2.0)
	walls.mesh = wall_mesh
	walls.position = Vector3(center_x, eave * 0.5, 0.0)
	walls.material_override = mats["wall"]
	root.add_child(walls)
	_plinth(
		root, "NavePlinth", Vector2(length, NAVE_HALF_Z * 2.0), Vector3(center_x, 0.0, 0.0), mats
	)

	var roof := MeshInstance3D.new()
	roof.name = "NaveRoof"
	roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		Vector2(length, NAVE_HALF_Z * 2.0), true, ROOF_OVERHANG, false, NAVE_PITCH
	)
	# Drop the roof so its plane meets the wall head at the wall line instead of
	# floating one overhang-rise above it.
	roof.position = Vector3(center_x, eave - ROOF_OVERHANG * NAVE_PITCH, 0.0)
	roof.material_override = mats["roof"]
	root.add_child(roof)

	var apex := eave + NAVE_HALF_Z * NAVE_PITCH
	for side: float in [-1.0, 1.0]:
		var face_x := NAVE_X.y if side > 0.0 else NAVE_X.x
		_gable(
			root,
			"NaveGable%s" % ("E" if side > 0.0 else "W"),
			face_x,
			side,
			NAVE_HALF_Z,
			eave,
			apex,
			mats
		)
	_add_east_niches(ctx, apex)
	_iron_cross(root, "NaveGableCross", Vector3(NAVE_X.y + 0.2, apex + 0.2, 0.0), 1.1, mats)

	# Eave cornice and the drip course under the windows, both side walls.
	for side: float in [-1.0, 1.0]:
		var face_z := side * NAVE_HALF_Z
		_trim(
			root,
			"NaveCornice%s" % _ns(side),
			Vector3(length + 0.1, 0.24, 0.2),
			Vector3(center_x, eave - 0.14, face_z + side * 0.06),
			mats
		)
		_trim(
			root,
			"NaveDripCourse%s" % _ns(side),
			Vector3(length, 0.14, 0.14),
			Vector3(center_x, 3.15, face_z + side * 0.06),
			mats
		)
		for index in BUTTRESS_X.size():
			_buttress(
				root,
				"VaultButtress_%s_%02d" % [_ns(side), index],
				BUTTRESS_X[index],
				side,
				NAVE_HALF_Z,
				FOOTPRINT_HALF.y,
				eave,
				mats
			)

	# One tall lancet per vault bay; the south door bay keeps a short light
	# above the portal frontispiece.
	for side: float in [-1.0, 1.0]:
		for bay in BUTTRESS_X.size() - 1:
			var bay_x := (BUTTRESS_X[bay] + BUTTRESS_X[bay + 1]) * 0.5
			var door_bay := side > 0.0 and absf(bay_x - PORTAL_X) < 0.2
			var sill := 6.0 if door_bay else 3.4
			var light_height := eave - 0.8 - sill
			_lancet(
				ctx,
				"VaultLancet_%s_%02d" % [_ns(side), bay],
				Vector3(bay_x, sill, side * NAVE_HALF_Z),
				0.0 if side > 0.0 else PI,
				1.2 if not door_bay else 1.0,
				light_height,
				true
			)
	_add_south_portal(ctx)

	var rng: RandomNumberGenerator = ctx["rng"]
	for side: float in [-1.0, 1.0]:
		_Wear.add_face_wear(
			root,
			rng,
			"NaveWear%s" % _ns(side),
			length,
			Vector3(center_x, 0.0, side * NAVE_HALF_Z),
			0.0 if side > 0.0 else PI,
			eave,
			PLINTH_HEIGHT
		)


## East gable of the nave above the chancel roof: five lime-washed blind niches
## stepping up to the ridge, each kept clear of the chancel roof and the rakes.
static func _add_east_niches(ctx: Dictionary, apex: float) -> void:
	var root: Node3D = ctx["root"]
	var mats: Dictionary = ctx["mats"]
	var chancel_eave: float = ctx["chancel_eave"]
	var face_x := NAVE_X.y + ROOF_OVERHANG + 0.04
	for index in 5:
		var z := (float(index) - 2.0) * 1.8
		var bottom := maxf(chancel_roof_y(chancel_eave, absf(z)) + 0.45, 9.0)
		var top := apex - absf(z) * NAVE_PITCH - 0.75
		if top - bottom < 1.0:
			continue
		var niche := MeshInstance3D.new()
		niche.name = "EastGableNiche%d" % index
		niche.mesh = _Meshes.pointed_panel(1.05, top - bottom, 0.03)
		niche.position = Vector3(face_x, bottom, z)
		niche.rotation.y = PI * 0.5
		niche.material_override = mats["limewash"]
		root.add_child(niche)


## Projecting portal frontispiece with three stepped pointed orders. The door
## leaf itself is the transition door drawn on the footprint edge (z = +7).
static func _add_south_portal(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var mats: Dictionary = ctx["mats"]
	# The outer order (0.16 proud) ends exactly on the plot edge, where the
	# transition leaf is drawn.
	var depth := FOOTPRINT_HALF.y - NAVE_HALF_Z - PORTAL_OUTER_ORDER_DEPTH - 0.005
	var width := 3.8
	var body_height := 4.75
	var gablet_rise := 1.0
	var portal := Node3D.new()
	portal.name = "SouthPortal"
	portal.position = Vector3(PORTAL_X, 0.0, NAVE_HALF_Z)
	root.add_child(portal)
	_box(
		portal,
		"Frontispiece",
		Vector3(width, body_height, depth),
		Vector3(0.0, body_height * 0.5, depth * 0.5),
		mats["wall"]
	)
	# Gablet over the frontispiece, with its coping.
	var gablet := MeshInstance3D.new()
	gablet.name = "Gablet"
	gablet.mesh = _Meshes.prism(
		PackedVector2Array(
			[Vector2(-width * 0.5, 0.0), Vector2(width * 0.5, 0.0), Vector2(0.0, gablet_rise)]
		),
		depth
	)
	gablet.position = Vector3(0.0, body_height, 0.0)
	gablet.material_override = mats["wall"]
	portal.add_child(gablet)
	var rake := Vector2(width * 0.5, gablet_rise)
	for slope: float in [-1.0, 1.0]:
		var coping := _box(
			portal,
			"GabletCoping%s" % ("E" if slope > 0.0 else "W"),
			Vector3(rake.length() + 0.1, 0.14, depth + 0.1),
			Vector3(slope * width * 0.25, body_height + gablet_rise * 0.5 + 0.07, depth * 0.5),
			mats["trim"]
		)
		coping.rotation.z = -slope * atan2(rake.y, rake.x)
	var front := depth + 0.005
	var recess := MeshInstance3D.new()
	recess.name = "PortalRecess"
	recess.mesh = _Meshes.pointed_panel(2.1, 3.7, 0.02)
	recess.position = Vector3(0.0, 0.0, front)
	recess.material_override = mats["reveal"]
	portal.add_child(recess)
	var orders := [
		[3.3, 4.5, 0.32, PORTAL_OUTER_ORDER_DEPTH],
		[2.75, 4.12, 0.24, 0.11],
		[2.3, 3.82, 0.18, 0.07]
	]
	for index in orders.size():
		var order: Array = orders[index]
		var ring := MeshInstance3D.new()
		ring.name = "PortalOrder%d" % index
		ring.mesh = _Meshes.pointed_ring(order[0], order[1], order[2], order[3])
		ring.position = Vector3(0.0, 0.0, front)
		ring.material_override = mats["trim"] if index != 1 else mats["trim_shadow"]
		portal.add_child(ring)
	_Wear.decal(
		portal,
		"PortalDamp",
		Vector2(width, 1.2),
		Vector3(0.0, 1.2, front + 0.01),
		0.0,
		0.45,
		false,
		false
	)


# --- Chancel and sacristy ---------------------------------------------------


static func _add_chancel(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var mats: Dictionary = ctx["mats"]
	var eave: float = ctx["chancel_eave"]
	var length := CHANCEL_X.y - CHANCEL_X.x
	var center_x := (CHANCEL_X.x + CHANCEL_X.y) * 0.5
	_box(
		root,
		"ChancelWalls",
		Vector3(length, eave, CHANCEL_HALF_Z * 2.0),
		Vector3(center_x, eave * 0.5, 0.0),
		mats["wall"]
	)
	_plinth(
		root,
		"ChancelPlinth",
		Vector2(length, CHANCEL_HALF_Z * 2.0),
		Vector3(center_x, 0.0, 0.0),
		mats
	)
	var roof := MeshInstance3D.new()
	roof.name = "ChancelRoof"
	# Extend west into the nave wall so no gap shows at the junction.
	roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		Vector2(length + 0.6, CHANCEL_HALF_Z * 2.0), true, 0.25, false, CHANCEL_PITCH
	)
	roof.position = Vector3(center_x - 0.3, eave - 0.25 * CHANCEL_PITCH, 0.0)
	roof.material_override = mats["roof"]
	root.add_child(roof)
	var apex := eave + CHANCEL_HALF_Z * CHANCEL_PITCH
	_gable(root, "ChancelGableE", CHANCEL_X.y, 1.0, CHANCEL_HALF_Z, eave, apex, mats, 0.25)
	_iron_cross(root, "ChancelGableCross", Vector3(CHANCEL_X.y + 0.15, apex + 0.2, 0.0), 1.0, mats)
	_trim(
		root,
		"ChancelCorniceS",
		Vector3(length, 0.22, 0.18),
		Vector3(center_x, eave - 0.13, CHANCEL_HALF_Z + 0.05),
		mats
	)

	# Stepped east triplet: the centre light rises above its pair.
	var east_yaw := PI * 0.5
	for index in 3:
		var offset := float(index - 1) * 1.35
		var tall := index == 1
		_lancet(
			ctx,
			"ChancelLancetE_%d" % index,
			Vector3(CHANCEL_X.y, 2.3, offset),
			east_yaw,
			0.85 if tall else 0.7,
			3.5 if tall else 2.7,
			false
		)
	_lancet(
		ctx, "ChancelLancetS", Vector3(center_x - 0.3, 2.5, CHANCEL_HALF_Z), 0.0, 0.85, 3.0, false
	)
	# East corner buttresses, single stage: only 0.4 m remains to the plot edge.
	for side: float in [-1.0, 1.0]:
		_box(
			root,
			"ChancelButtressE%s" % _ns(side),
			Vector3(FOOTPRINT_HALF.x - CHANCEL_X.y, eave * 0.7, 0.7),
			Vector3(
				(CHANCEL_X.y + FOOTPRINT_HALF.x) * 0.5, eave * 0.35, side * (CHANCEL_HALF_Z - 0.35)
			),
			mats["wall"]
		)
		_wedge(
			root,
			"ChancelButtressCapE%s" % _ns(side),
			Vector3(
				(CHANCEL_X.y + FOOTPRINT_HALF.x) * 0.5 - 0.2,
				eave * 0.7,
				side * (CHANCEL_HALF_Z - 0.35)
			),
			PI * 0.5,
			0.7,
			FOOTPRINT_HALF.x - CHANCEL_X.y,
			0.45,
			mats["trim"]
		)
	var rng: RandomNumberGenerator = ctx["rng"]
	_Wear.add_face_wear(
		root,
		rng,
		"ChancelWearS",
		length,
		Vector3(center_x, 0.0, CHANCEL_HALF_Z),
		0.0,
		eave,
		PLINTH_HEIGHT
	)
	_Wear.add_face_wear(
		root,
		rng,
		"ChancelWearE",
		CHANCEL_HALF_Z * 2.0,
		Vector3(CHANCEL_X.y, 0.0, 0.0),
		PI * 0.5,
		eave,
		PLINTH_HEIGHT
	)


static func _add_sacristy(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var mats: Dictionary = ctx["mats"]
	var length := SACRISTY_X.y - SACRISTY_X.x
	var depth := SACRISTY_Z.y - SACRISTY_Z.x
	var center := Vector3(
		(SACRISTY_X.x + SACRISTY_X.y) * 0.5, 0.0, (SACRISTY_Z.x + SACRISTY_Z.y) * 0.5
	)
	var low := 3.7
	var high := 4.9
	_box(
		root,
		"SacristyWalls",
		Vector3(length, low, depth),
		center + Vector3(0.0, low * 0.5, 0.0),
		mats["wall"]
	)
	# Wall head rising toward the chancel to carry the lean-to.
	var head := MeshInstance3D.new()
	head.name = "SacristyWallHead"
	head.mesh = _Meshes.prism(
		PackedVector2Array(
			[
				Vector2(-depth * 0.5, 0.0),
				Vector2(depth * 0.5, 0.0),
				Vector2(depth * 0.5, high - low)
			]
		),
		length
	)
	head.position = center + Vector3(length * 0.5, low, 0.0)
	head.rotation.y = -PI * 0.5
	head.material_override = mats["wall"]
	root.add_child(head)
	var slope := Vector2(depth + 0.5, high - low)
	var roof := _box(
		root,
		"SacristyRoof",
		Vector3(length + 0.4, 0.12, slope.length()),
		center + Vector3(0.0, (low + high) * 0.5 + 0.08, -0.25),
		mats["roof"]
	)
	# High edge against the chancel (+Z), falling north.
	roof.rotation.x = -atan2(slope.y, slope.x)
	_slit(root, "SacristySlitN", Vector3(center.x, 1.6, SACRISTY_Z.x), PI, 0.3, 1.0, mats)
	_Wear.add_face_wear(
		root,
		ctx["rng"],
		"SacristyWearN",
		length,
		Vector3(center.x, 0.0, SACRISTY_Z.x),
		PI,
		low,
		PLINTH_HEIGHT
	)


# --- West tower -------------------------------------------------------------


static func _add_tower(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var top: float = ctx["tower_top"]
	var nave_eave: float = ctx["nave_eave"]
	var length := TOWER_X.y - TOWER_X.x
	var width := TOWER_HALF_Z * 2.0
	var cx := (TOWER_X.x + TOWER_X.y) * 0.5
	var tower := Node3D.new()
	tower.name = "WestTower"
	root.add_child(tower)
	var masonry := MeshInstance3D.new()
	masonry.name = "Masonry"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, top, width)
	masonry.mesh = mesh
	masonry.position = Vector3(cx, top * 0.5, 0.0)
	masonry.material_override = mats["wall"]
	tower.add_child(masonry)
	_plinth(tower, "TowerPlinth", Vector2(length, width), Vector3(cx, 0.0, 0.0), mats, 0.9)
	for level: float in [nave_eave + 0.2, top - 4.6]:
		_trim(
			tower,
			"BeltCourse_%d" % int(level),
			Vector3(length + 0.16, 0.18, width + 0.16),
			Vector3(cx, level, 0.0),
			mats
		)
	_tower_quoins(tower, cx, length, width, top, mats)
	_tower_putlogs(tower, rng, cx, length, width, top, nave_eave, mats)
	_tower_ragged_top(tower, rng, cx, length, width, top, mats)

	# West portal into the tower hall, and narrow lights on the free faces.
	var west := Node3D.new()
	west.name = "WestPortal"
	west.position = Vector3(TOWER_X.x, 0.0, 0.0)
	west.rotation.y = -PI * 0.5
	tower.add_child(west)
	var recess := MeshInstance3D.new()
	recess.name = "Recess"
	recess.mesh = _Meshes.pointed_panel(1.8, 3.4, 0.02)
	recess.material_override = mats["reveal"]
	west.add_child(recess)
	_box(
		west,
		"Leaf",
		Vector3(1.4, 2.5, 0.05),
		Vector3(0.0, 1.25, 0.03),
		MapViewMaterials.door_wood("st_olaf_west_portal".hash())
	)
	for index in 2:
		var ring := MeshInstance3D.new()
		ring.name = "Order%d" % index
		ring.mesh = _Meshes.pointed_ring(
			2.6 - index * 0.45, 4.1 - index * 0.35, 0.24, 0.14 - index * 0.05
		)
		ring.material_override = mats["trim"] if index == 0 else mats["trim_shadow"]
		west.add_child(ring)
	for y: float in [6.4, 10.8]:
		_slit(
			tower, "TowerSlitW_%d" % int(y), Vector3(TOWER_X.x, y, 0.0), -PI * 0.5, 0.36, 1.5, mats
		)
	for side: float in [-1.0, 1.0]:
		_slit(
			tower,
			"TowerSlit%s" % _ns(side),
			Vector3(cx, 11.5, side * TOWER_HALF_Z),
			0.0 if side > 0.0 else PI,
			0.36,
			1.5,
			mats
		)
	_slit(tower, "TowerSlitE", Vector3(TOWER_X.y, top - 2.2, 0.0), PI * 0.5, 0.36, 1.2, mats)

	_tower_scaffold(tower, cx, length, top, mats)
	_tower_belfry(tower, cx, top, mats)
	for face: Array in [
		["W", length, width, Vector3(TOWER_X.x, 0.0, 0.0), -PI * 0.5],
		["N", width, length, Vector3(cx, 0.0, -TOWER_HALF_Z), PI],
		["S", width, length, Vector3(cx, 0.0, TOWER_HALF_Z), 0.0]
	]:
		var span: float = length if face[0] != "W" else width
		_Wear.add_face_wear(
			tower, rng, "TowerWear%s" % face[0], span, face[3], face[4], top - 0.6, 0.9
		)


static func _tower_quoins(
	tower: Node3D, cx: float, length: float, width: float, top: float, mats: Dictionary
) -> void:
	var st := _Meshes.begin()
	var course := 0.5
	var count := int((top - 1.0) / course)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for index in count:
				var long_x := index % 2 == 0
				var lx := 0.9 if long_x else 0.5
				var lz := 0.5 if long_x else 0.9
				_Meshes.append_box(
					st,
					Vector3(lx, course - 0.05, lz),
					Vector3(
						cx + sx * (length * 0.5 - lx * 0.5 + 0.03),
						1.0 + course * (float(index) + 0.5),
						sz * (width * 0.5 - lz * 0.5 + 0.03)
					)
				)
	_Meshes.commit(tower, "Quoins", st, mats["trim"])


## Open putlog holes where the scaffold beams were pulled out of finished lifts.
static func _tower_putlogs(
	tower: Node3D,
	rng: RandomNumberGenerator,
	cx: float,
	length: float,
	width: float,
	top: float,
	nave_eave: float,
	mats: Dictionary
) -> void:
	var st := _Meshes.begin()
	var y := 2.2
	while y < top - 1.0:
		for face in 3:
			var span := width if face == 0 else length
			var cols := int(span / 1.5)
			for col in cols:
				if rng.randf() < 0.18:
					continue
				var t := (float(col) + 0.5) / float(cols) - 0.5
				var hole := Vector3(0.22, 0.22, 0.04)
				if face == 0:
					_Meshes.append_box(
						st, Vector3(hole.z, hole.y, hole.x), Vector3(TOWER_X.x - 0.015, y, t * span)
					)
				else:
					var side := -1.0 if face == 1 else 1.0
					# The nave roof hides the lower part of the side faces.
					if y < nave_roof_y(nave_eave, TOWER_HALF_Z) and cx + t * span > TOWER_X.y - 1.0:
						continue
					_Meshes.append_box(
						st, hole, Vector3(cx + t * span, y, side * (TOWER_HALF_Z + 0.015))
					)
		y += 1.7
	_Meshes.commit(tower, "PutlogHoles", st, mats["reveal"])


## Unfinished top: toothed courses left to bond the next lift, highest at the
## corners where masons raise the quoins first.
static func _tower_ragged_top(
	tower: Node3D,
	rng: RandomNumberGenerator,
	cx: float,
	length: float,
	width: float,
	top: float,
	mats: Dictionary
) -> void:
	var st := _Meshes.begin()
	var block := 0.9
	var edges := [
		[Vector3(cx - length * 0.5, top, -width * 0.5), Vector3(1, 0, 0), length],
		[Vector3(cx - length * 0.5, top, width * 0.5), Vector3(1, 0, 0), length],
		[Vector3(cx - length * 0.5, top, -width * 0.5), Vector3(0, 0, 1), width],
		[Vector3(cx + length * 0.5, top, -width * 0.5), Vector3(0, 0, 1), width],
	]
	for edge: Array in edges:
		var start: Vector3 = edge[0]
		var dir: Vector3 = edge[1]
		var span: float = edge[2]
		var count := int(span / block)
		for index in count:
			var t := (float(index) + 0.5) / float(count)
			# Racked back in whole courses: masons lift the quoins first, so the
			# head steps up toward each corner instead of reading as merlons.
			var courses := 1 + roundi(absf(t - 0.5) * 2.0 * 4.0) + (1 if rng.randf() < 0.25 else 0)
			var rise := float(courses) * 0.32
			var size := Vector3(span / float(count), rise, 1.1)
			if dir.z > 0.5:
				size = Vector3(1.1, rise, span / float(count))
			# Blocks sit on the wall head, half a block in from the outer face.
			var inward := Vector3(0.0, 0.0, -signf(start.z) * 0.55)
			if dir.z > 0.5:
				inward = Vector3(signf(cx - start.x) * 0.55, 0.0, 0.0)
			_Meshes.append_box(
				st, size, start + dir * (t * span) + inward + Vector3(0.0, rise * 0.5, 0.0)
			)
	_Meshes.commit(tower, "RaggedTop", st, mats["wall"])


## Putlog scaffold on the south and north faces of the top lift: beams through
## the wall, a board deck, outer standards with a ledger, and a hoist jib.
static func _tower_scaffold(
	tower: Node3D, cx: float, length: float, top: float, mats: Dictionary
) -> void:
	var st := _Meshes.begin()
	var reach := 1.3
	for side: float in [-1.0, 1.0]:
		var face_z := side * TOWER_HALF_Z
		for lift: float in [top - 3.4, top - 1.2]:
			for index in 4:
				var x := cx - length * 0.5 + 0.6 + float(index) * (length - 1.2) / 3.0
				_Meshes.append_box(
					st,
					Vector3(0.14, 0.14, reach + 0.3),
					Vector3(x, lift, face_z + side * (reach * 0.5 - 0.15))
				)
			_Meshes.append_box(
				st,
				Vector3(length - 0.6, 0.06, reach - 0.1),
				Vector3(cx, lift + 0.1, face_z + side * reach * 0.5)
			)
		for index in 3:
			var x := cx - length * 0.5 + 0.4 + float(index) * (length - 0.8) * 0.5
			_Meshes.append_box(
				st, Vector3(0.13, 6.6, 0.13), Vector3(x, top - 1.9, face_z + side * (reach - 0.05))
			)
		_Meshes.append_box(
			st,
			Vector3(length - 0.4, 0.1, 0.1),
			Vector3(cx, top + 0.9, face_z + side * (reach - 0.05))
		)
	# Hoist jib cantilevered off the south face, rope running down to the yard.
	var jib_x := cx + length * 0.5 - 1.2
	_Meshes.append_box(st, Vector3(0.22, 0.22, 2.4), Vector3(jib_x, top + 1.4, TOWER_HALF_Z + 0.6))
	_Meshes.append_box(st, Vector3(0.2, 2.4, 0.2), Vector3(jib_x, top + 0.4, TOWER_HALF_Z - 0.5))
	_Meshes.commit(tower, "Scaffold", st, mats["timber"])
	var rope := _Meshes.begin()
	_Meshes.append_box(
		rope, Vector3(0.04, top + 1.1, 0.04), Vector3(jib_x, (top + 1.3) * 0.5, TOWER_HALF_Z + 1.7)
	)
	_Meshes.commit(tower, "HoistRope", rope, mats["rope"])


## Bells hung meanwhile in a timber frame under a shingle cap until the upper
## tower (1364+) is raised.
static func _tower_belfry(tower: Node3D, cx: float, top: float, mats: Dictionary) -> void:
	var belfry := Node3D.new()
	belfry.name = "ProvisionalBelfry"
	belfry.position = Vector3(cx, top + 0.3, 0.0)
	tower.add_child(belfry)
	var half := 2.1
	var post_h := 3.2
	var st := _Meshes.begin()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_Meshes.append_box(
				st, Vector3(0.26, post_h, 0.26), Vector3(sx * half, post_h * 0.5, sz * half)
			)
	for level: float in [0.1, post_h - 0.1, post_h * 0.5]:
		for sz: float in [-1.0, 1.0]:
			_Meshes.append_box(
				st, Vector3(half * 2.0 + 0.3, 0.2, 0.2), Vector3(0.0, level, sz * half)
			)
		for sx: float in [-1.0, 1.0]:
			_Meshes.append_box(
				st, Vector3(0.2, 0.2, half * 2.0 + 0.3), Vector3(sx * half, level, 0.0)
			)
	# Diagonal braces on every face.
	var brace := sqrt(half * half * 4.0 + post_h * post_h * 0.25)
	var angle := atan2(post_h * 0.5, half * 2.0)
	for sz: float in [-1.0, 1.0]:
		for dir: float in [-1.0, 1.0]:
			_Meshes.append_box(
				st,
				Vector3(brace, 0.14, 0.14),
				Vector3(0.0, post_h * 0.25, sz * (half + 0.02)),
				Basis(Vector3.BACK, dir * angle)
			)
	for sx: float in [-1.0, 1.0]:
		for dir: float in [-1.0, 1.0]:
			_Meshes.append_box(
				st,
				Vector3(0.14, 0.14, brace),
				Vector3(sx * (half + 0.02), post_h * 0.25, 0.0),
				Basis(Vector3.RIGHT, dir * angle)
			)
	_Meshes.append_box(st, Vector3(0.24, 0.24, half * 2.0), Vector3(0.0, post_h - 0.5, 0.0))
	_Meshes.commit(belfry, "Frame", st, mats["timber"])
	for index in 2:
		var bell := MeshInstance3D.new()
		bell.name = "Bell%d" % index
		var bell_mesh := CylinderMesh.new()
		bell_mesh.top_radius = 0.22 - index * 0.04
		bell_mesh.bottom_radius = 0.46 - index * 0.1
		bell_mesh.height = 0.7 - index * 0.14
		bell_mesh.radial_segments = 16
		bell.mesh = bell_mesh
		bell.position = Vector3(
			0.0, post_h - 0.62 - bell_mesh.height * 0.5, (float(index) - 0.5) * 1.6
		)
		bell.material_override = mats["bronze"]
		belfry.add_child(bell)
	var cap := MeshInstance3D.new()
	cap.name = "Cap"
	cap.mesh = _Meshes.pyramid(half + 0.6, 3.2)
	cap.position = Vector3(0.0, post_h, 0.0)
	cap.material_override = mats["shingle"]
	belfry.add_child(cap)
	_iron_cross(belfry, "CapCross", Vector3(0.0, post_h + 3.15, 0.0), 0.9, mats)


# --- Works yard -------------------------------------------------------------


## Masons' lodge (lean-to) on the tower's north-west corner of the plot and a
## stack of dressed blocks on the south-west corner.
static func _add_works_yard(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var mats: Dictionary = ctx["mats"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var lodge := Node3D.new()
	lodge.name = "MasonsLodge"
	lodge.position = Vector3(-7.9, 0.0, -5.6)
	root.add_child(lodge)
	var st := _Meshes.begin()
	for x: float in [-2.6, -0.9, 0.9, 2.6]:
		_Meshes.append_box(st, Vector3(0.18, 2.3, 0.18), Vector3(x, 1.15, -1.1))
	_Meshes.append_box(st, Vector3(5.6, 0.18, 0.2), Vector3(0.0, 2.3, -1.1))
	_Meshes.append_box(st, Vector3(0.08, 1.2, 2.4), Vector3(-2.65, 0.6, 0.0))
	_Meshes.append_box(st, Vector3(1.6, 0.8, 0.8), Vector3(1.4, 0.4, -0.3))
	_Meshes.commit(lodge, "Frame", st, mats["timber"])
	var slope := Vector2(2.6, 1.0)
	var roof := _box(
		lodge, "Roof", Vector3(5.8, 0.08, slope.length()), Vector3(0.0, 2.85, 0.0), mats["shingle"]
	)
	roof.rotation.x = -atan2(slope.y, slope.x)
	var stones := _Meshes.begin()
	# Three, two and one dressed blocks, stepped like a mason's stack.
	for row in 3:
		for col in 3 - row:
			var size := Vector3(rng.randf_range(0.9, 1.15), 0.5, rng.randf_range(0.55, 0.7))
			var spot := Vector3(
				-9.8 + (float(col) + float(row) * 0.5) * 1.25, 0.25 + float(row) * 0.5, 5.6
			)
			spot.z += rng.randf_range(-0.1, 0.1)
			_Meshes.append_box(stones, size, spot, Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)))
	_Meshes.commit(root, "StoneStack", stones, mats["trim"])


# --- Openings ---------------------------------------------------------------


## Equilateral-pointed lancet on a wall face: chamfered surround, dark splay,
## leaded pane (root child named Window<n> so the evening schedule lights it),
## optional mullion, sill and runoff under it.
static func _lancet(
	ctx: Dictionary,
	frame_name: String,
	base: Vector3,
	yaw: float,
	width: float,
	light_height: float,
	mullion: bool
) -> void:
	var root: Node3D = ctx["root"]
	var mats: Dictionary = ctx["mats"]
	var frame := Node3D.new()
	frame.name = frame_name
	frame.position = base
	frame.rotation.y = yaw
	root.add_child(frame)
	var surround := MeshInstance3D.new()
	surround.name = "Surround"
	surround.mesh = _Meshes.pointed_ring(width + 0.34, light_height + 0.17, 0.17, 0.08)
	surround.position = Vector3(0.0, -0.05, 0.0)
	surround.material_override = mats["trim"]
	frame.add_child(surround)
	var reveal := MeshInstance3D.new()
	reveal.name = "Reveal"
	reveal.mesh = _Meshes.pointed_panel(width, light_height, 0.03)
	reveal.material_override = mats["reveal"]
	frame.add_child(reveal)
	var index: int = ctx["window_index"]
	ctx["window_index"] = index + 1
	var glass := MeshInstance3D.new()
	glass.name = "Window%d" % index
	glass.mesh = _Meshes.pointed_panel(width - 0.22, light_height - 0.16, 0.02)
	var basis := Basis(Vector3.UP, yaw)
	glass.transform = Transform3D(basis, base + basis * Vector3(0.0, 0.08, 0.035))
	glass.material_override = mats["glass"]
	root.add_child(glass)
	if mullion:
		_box(
			frame,
			"Mullion",
			Vector3(0.09, light_height - 0.55, 0.07),
			Vector3(0.0, (light_height - 0.55) * 0.5, 0.06),
			mats["trim"]
		)
	_box(frame, "Sill", Vector3(width + 0.5, 0.12, 0.2), Vector3(0.0, -0.08, 0.08), mats["trim"])
	_Wear.add_sill_streaks(root, ctx["rng"], "%sSill" % frame_name, base, width, yaw)


## Unglazed slit light (tower, sacristy).
static func _slit(
	parent: Node3D,
	slit_name: String,
	base: Vector3,
	yaw: float,
	width: float,
	light_height: float,
	mats: Dictionary
) -> void:
	var frame := Node3D.new()
	frame.name = slit_name
	frame.position = base
	frame.rotation.y = yaw
	parent.add_child(frame)
	var ring := MeshInstance3D.new()
	ring.name = "Surround"
	ring.mesh = _Meshes.pointed_ring(width + 0.3, light_height + 0.15, 0.15, 0.07)
	ring.position.y = -0.05
	ring.material_override = mats["trim"]
	frame.add_child(ring)
	var opening := MeshInstance3D.new()
	opening.name = "Opening"
	opening.mesh = _Meshes.pointed_panel(width, light_height, 0.03)
	opening.material_override = mats["reveal"]
	frame.add_child(opening)


# --- Masonry pieces ---------------------------------------------------------


## Stone gable closing a roof end: masonry prism from the wall line out past the
## roof verge, with coping on both rakes and an apex stone.
static func _gable(
	root: Node3D,
	gable_name: String,
	face_x: float,
	side: float,
	half_z: float,
	eave: float,
	apex: float,
	mats: Dictionary,
	overhang: float = ROOF_OVERHANG
) -> void:
	var depth := overhang + 0.04
	var outline := PackedVector2Array(
		[Vector2(-half_z, 0.0), Vector2(half_z, 0.0), Vector2(0.0, apex - eave + 0.06)]
	)
	var gable := MeshInstance3D.new()
	gable.name = gable_name
	gable.mesh = _Meshes.prism(outline, depth)
	gable.position = Vector3(face_x - side * 0.02, eave, 0.0)
	gable.rotation.y = side * PI * 0.5
	gable.material_override = mats["wall"]
	root.add_child(gable)
	var rake := Vector2(half_z, apex - eave)
	for slope: float in [-1.0, 1.0]:
		var coping := _box(
			root,
			"%sCoping%s" % [gable_name, "S" if slope > 0.0 else "N"],
			Vector3(depth + 0.16, 0.16, rake.length() + 0.1),
			Vector3(face_x + side * depth * 0.5, (eave + apex) * 0.5 + 0.1, slope * half_z * 0.5),
			mats["trim"]
		)
		coping.rotation.x = slope * atan2(rake.y, rake.x)
	_box(
		root,
		"%sApexStone" % gable_name,
		Vector3(depth + 0.24, 0.32, 0.44),
		Vector3(face_x + side * depth * 0.5, apex + 0.14, 0.0),
		mats["trim"]
	)


## Two-stage buttress from the wall face out to `outer_z`, each stage capped by
## a sloped weathering.
static func _buttress(
	root: Node3D,
	buttress_name: String,
	x: float,
	side: float,
	wall_z: float,
	outer_z: float,
	eave: float,
	mats: Dictionary
) -> void:
	var node := Node3D.new()
	node.name = buttress_name
	node.position = Vector3(x, 0.0, side * wall_z)
	node.rotation.y = 0.0 if side > 0.0 else PI
	root.add_child(node)
	var depth := outer_z - wall_z
	var low := eave * 0.42
	var high := eave * 0.78
	_box(
		node, "Lower", Vector3(0.85, low, depth), Vector3(0.0, low * 0.5, depth * 0.5), mats["wall"]
	)
	_wedge(node, "LowerCap", Vector3(0.0, low, 0.0), 0.0, 0.85, depth, 0.5, mats["trim"])
	var upper_depth := depth * 0.55
	_box(
		node,
		"Upper",
		Vector3(0.7, high - low, upper_depth),
		Vector3(0.0, (low + high) * 0.5, upper_depth * 0.5),
		mats["wall"]
	)
	_wedge(node, "UpperCap", Vector3(0.0, high, 0.0), 0.0, 0.7, upper_depth, 0.55, mats["trim"])
	_box(
		node,
		"Plinth",
		Vector3(1.0, PLINTH_HEIGHT, depth + 0.05),
		Vector3(0.0, PLINTH_HEIGHT * 0.5, depth * 0.5),
		mats["plinth"]
	)


static func _plinth(
	parent: Node3D,
	plinth_name: String,
	size: Vector2,
	center: Vector3,
	mats: Dictionary,
	plinth_height: float = PLINTH_HEIGHT
) -> void:
	_box(
		parent,
		plinth_name,
		Vector3(size.x + 0.2, plinth_height, size.y + 0.2),
		center + Vector3(0.0, plinth_height * 0.5, 0.0),
		mats["plinth"]
	)


static func _trim(
	parent: Node3D, trim_name: String, size: Vector3, center: Vector3, mats: Dictionary
) -> void:
	_box(parent, trim_name, size, center, mats["trim"])


static func _iron_cross(
	parent: Node3D, cross_name: String, base: Vector3, cross_height: float, mats: Dictionary
) -> void:
	var st := _Meshes.begin()
	_Meshes.append_box(
		st, Vector3(0.07, cross_height, 0.07), base + Vector3(0.0, cross_height * 0.5, 0.0)
	)
	_Meshes.append_box(
		st, Vector3(0.07, 0.07, cross_height * 0.55), base + Vector3(0.0, cross_height * 0.7, 0.0)
	)
	_Meshes.commit(parent, cross_name, st, mats["iron"])


static func _box(
	parent: Node3D, box_name: String, size: Vector3, center: Vector3, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Sloped weathering: right-triangle prism, high edge against the wall (local
## z = 0), falling outward over `depth`.
static func _wedge(
	parent: Node3D,
	wedge_name: String,
	base: Vector3,
	yaw: float,
	width: float,
	depth: float,
	rise: float,
	material: Material
) -> void:
	var wedge := MeshInstance3D.new()
	wedge.name = wedge_name
	wedge.mesh = _Meshes.prism(
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(depth, 0.0), Vector2(0.0, rise)]), width
	)
	wedge.position = base + Basis(Vector3.UP, yaw) * Vector3(width * 0.5, 0.0, 0.0)
	# The prism profile lies in local XY and extrudes along +Z; turn it so the
	# profile's X runs outward (+Z of the parent) and the extrusion runs along X.
	wedge.rotation.y = yaw - PI * 0.5
	wedge.material_override = material
	parent.add_child(wedge)


static func _ns(side: float) -> String:
	return "N" if side < 0.0 else "S"


# --- Materials --------------------------------------------------------------


static func _materials(building: Dictionary) -> Dictionary:
	var building_id := StringName(String(building.get("id", "st_olaf")))
	var wall_color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
	var roof_color := Color(building.get("roof_color", MapViewMeshBuilderConfig.DEFAULT_ROOF_COLOR))
	var wall := _Wear.triplanar(
		_Wear.toned_surface("st_olaf_wall", building_id, WALL_STEM, wall_color, WALL_TONE),
		WALL_STEM
	)
	var trim := _Wear.triplanar(
		_Wear.toned_surface(
			"st_olaf_trim", &"st_olaf_trim", TRIM_STEM, Color(0.95, 0.93, 0.88), TRIM_TONE
		),
		TRIM_STEM
	)
	var roof := _Wear.toned_surface("st_olaf_roof", building_id, ROOF_STEM, roof_color, ROOF_TONE)
	roof.uv1_scale = _BuildingMaterials.library_world_uv_density(ROOF_STEM)
	var shingle := _Wear.toned_surface(
		"st_olaf_shingle",
		building_id,
		SHINGLE_STEM,
		Color(0.62, 0.6, 0.56),
		Color(0.85, 0.84, 0.82)
	)
	shingle.uv1_scale = _BuildingMaterials.library_world_uv_density(SHINGLE_STEM)
	var limewash := _Wear.triplanar(
		_Wear.toned_surface(
			"st_olaf_limewash", building_id, LIMEWASH_STEM, Color(0.94, 0.93, 0.89), LIMEWASH_TONE
		),
		LIMEWASH_STEM
	)
	return {
		"wall": wall,
		"plinth": _darkened("plinth", wall, 0.3),
		"trim": trim,
		"trim_shadow": _darkened("trim_shadow", trim, 0.35),
		"roof": roof,
		"shingle": shingle,
		"limewash": limewash,
		"reveal": _flat("reveal", REVEAL_TINT, 1.0),
		"glass": _flat("glass", GLASS_TINT, 0.7, true),
		"bronze": _flat("bronze", BRONZE, 0.5, false, 0.6),
		"iron": MapViewMaterials.role(&"metal"),
		"timber": _flat("timber", TIMBER_TINT, 0.95),
		"rope": _flat("rope", Color(0.4, 0.34, 0.24), 1.0),
	}


## Footing stones and the shadowed inner portal order: same stone, darker.
static func _darkened(key: String, source: StandardMaterial3D, amount: float) -> StandardMaterial3D:
	var cache_key := "darkened:%s:%d" % [key, source.get_instance_id()]
	if not _cache.has(cache_key):
		var material := source.duplicate() as StandardMaterial3D
		material.albedo_color = material.albedo_color.darkened(amount)
		_cache[cache_key] = material
	return _cache[cache_key]


static func _flat(
	key: String, color: Color, roughness: float, double_sided := false, metallic := 0.0
) -> StandardMaterial3D:
	var cache_key := "flat:%s" % key
	if not _cache.has(cache_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		# Leaded panes read dull from the street, not as sky mirrors.
		material.metallic_specular = 0.2 if double_sided else 0.5
		if double_sided:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[cache_key] = material
	return _cache[cache_key]
