class_name VegetationEcology
extends RefCounted

## R-1322 (VEGR-3): where plants grow, as a pure function of the compiled
## MapDefinition and its terrain grid.
##
## Per cell it derives distance to water, to trodden road or path, to walls, to
## bare limestone and to field ground; woodland shade and its conifer share
## (from tree zones and authored tree props); and a low-frequency fertility
## noise from the map seed. From those it returns density multipliers per layer
## and the understory picks (nettle, sedge, fern, moss, juniper, field weeds).
##
## Determinism and chunk independence: every field is capped at a radius of at
## most MARGIN cells and is computed over the requested region grown by MARGIN,
## so any chunk split gives byte-identical values for the same cell. Nothing is
## stored on the map; the authored override mask (`MapDefinition.vegetation_masks`)
## is the only ecology input that is map data. Authored props and buildings
## still block scatter in MapViewMeshBuilderScatter, so they always win.

const LAYER_GROUND_COVER := &"ground_cover"
const LAYER_GRASS := &"grass"
const LAYER_FLOWERS := &"flowers"
const LAYER_SHRUBS := &"shrubs"
const LAYER_TREES := &"trees"
## Mask-only alias: one multiplier for every layer.
const LAYER_ALL := &"all"
const LAYERS: Array[StringName] = [
	LAYER_GROUND_COVER, LAYER_GRASS, LAYER_FLOWERS, LAYER_SHRUBS, LAYER_TREES
]
const MASK_LAYERS: Array[StringName] = [
	LAYER_GROUND_COVER, LAYER_GRASS, LAYER_FLOWERS, LAYER_SHRUBS, LAYER_TREES, LAYER_ALL
]
const MASK_MAX_DENSITY := 4.0

## Understory picks returned by understory().
const UNDERSTORY_NONE := &""
const UNDERSTORY_NETTLE := &"nettle"
const UNDERSTORY_SEDGE := &"sedge"
const UNDERSTORY_FERN := &"fern"
const UNDERSTORY_MOSS := &"moss"
const UNDERSTORY_FIELD_WEED := &"field_weed"
const UNDERSTORY_JUNIPER := &"juniper"

## Influence radii in cells (one cell is one metre in the 3D view).
const WATER_RADIUS := 8
const ROAD_RADIUS := 3
const WALL_RADIUS := 3
const STONE_RADIUS := 3
const FIELD_RADIUS := 3
const SHADE_RADIUS := 2
const MARGIN := 8
## Nettle grows within this many cells of a wall foot or a water edge.
const NETTLE_REACH := 2
## Sedge crowds the first cells of a bank.
const SEDGE_REACH := 2
## Juniper wants thin soil over limestone that is not near water.
const JUNIPER_STONE_REACH := 2
const JUNIPER_DRY_WATER := 6
## Fern and moss need at least this much conifer shade.
const FERN_CONIFER_SHADE := 0.35
## Fertility noise wavelength in cells.
const FERTILITY_SCALE := 14.0

## Trodden surfaces: nothing grows on them. Mud is not one of them: it is
## mostly an authored bank (`reed.shore`), where sedge belongs.
const TRODDEN_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_DIRT,
	MapTypes.TERRAIN_COBBLESTONE,
	MapTypes.TERRAIN_CASTLE_PAVING,
]
## Soil that can take understory planting (not quays, floors or sand).
const PLANTABLE_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_GRASS,
	MapTypes.TERRAIN_MEADOW,
	MapTypes.TERRAIN_FOREST_FLOOR,
	MapTypes.TERRAIN_BOG,
	MapTypes.TERRAIN_MUD,
]
const FIELD_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_FARM_SOIL, MapTypes.TERRAIN_HAY, MapTypes.TERRAIN_STRAW
]
## Bare limestone in this project's terrain vocabulary.
const LIMESTONE_TERRAINS: Array[StringName] = [MapTypes.TERRAIN_STONE]
const CONIFER_TREE_VARIANTS: Array[StringName] = [&"tree.spruce", &"tree.pine"]

var region := Rect2i()
var _window := Rect2i()
var _water := PackedByteArray()
var _road := PackedByteArray()
var _wall := PackedByteArray()
var _stone := PackedByteArray()
var _field := PackedByteArray()
var _woods := PackedFloat32Array()
var _conifer := PackedFloat32Array()
var _fertility := PackedFloat32Array()
var _trodden := PackedByteArray()
var _plantable := PackedByteArray()
var _authored := PackedByteArray()
var _masks := {}


## Ecology for `rect` (cells). Fields are evaluated over `rect` grown by MARGIN.
static func for_region(
	definition: MapDefinition, grid: MapTerrainGrid, rect: Rect2i
) -> VegetationEcology:
	var ecology := VegetationEcology.new()
	ecology._build(definition, grid, rect)
	return ecology


func _build(definition: MapDefinition, grid: MapTerrainGrid, rect: Rect2i) -> void:
	var map_rect := Rect2i(Vector2i.ZERO, grid.size_cells)
	region = rect.intersection(map_rect)
	_window = region.grow(MARGIN).intersection(map_rect)
	var count := _window.size.x * _window.size.y
	var water_src := PackedByteArray()
	var road_src := PackedByteArray()
	var wall_src := PackedByteArray()
	var stone_src := PackedByteArray()
	var field_src := PackedByteArray()
	var wood := PackedFloat32Array()
	var conifer_wood := PackedFloat32Array()
	# Packed arrays are values in GDScript: resize each one in place.
	water_src.resize(count)
	road_src.resize(count)
	wall_src.resize(count)
	stone_src.resize(count)
	field_src.resize(count)
	_trodden.resize(count)
	_plantable.resize(count)
	_authored.resize(count)
	wood.resize(count)
	conifer_wood.resize(count)
	for y in _window.size.y:
		for x in _window.size.x:
			var cell := _window.position + Vector2i(x, y)
			var i := y * _window.size.x + x
			var terrain := grid.get_terrain(cell)
			var variant := grid.get_style_variant(cell)
			water_src[i] = 1 if MapTypes.WATER_TERRAINS.has(terrain) else 0
			road_src[i] = 1 if TRODDEN_TERRAINS.has(terrain) else 0
			_trodden[i] = road_src[i]
			_plantable[i] = 1 if PLANTABLE_TERRAINS.has(terrain) else 0
			stone_src[i] = 1 if LIMESTONE_TERRAINS.has(terrain) else 0
			field_src[i] = 1 if FIELD_TERRAINS.has(terrain) else 0
			_authored[i] = 0 if variant.is_empty() else 1
			if TerrainVegetation.is_tree_variant(variant):
				wood[i] = 1.0
				conifer_wood[i] = 1.0 if CONIFER_TREE_VARIANTS.has(variant) else 0.0
			elif terrain == MapTypes.TERRAIN_FOREST_FLOOR:
				# Implicit forest floor scatters spruce at this ratio.
				wood[i] = 1.0
				conifer_wood[i] = float(
					MapViewMeshBuilderConfig.SCATTER_TREE_SPRUCE_RATIO.get(terrain, 0.0)
				)
	_stamp_buildings(definition, wall_src)
	_stamp_tree_props(definition, wood, conifer_wood)
	_water = _distance(water_src, WATER_RADIUS)
	_road = _distance(road_src, ROAD_RADIUS)
	_wall = _distance(wall_src, WALL_RADIUS)
	_stone = _distance(stone_src, STONE_RADIUS)
	_field = _distance(field_src, FIELD_RADIUS)
	_woods = _box_mean(wood, SHADE_RADIUS)
	var conifer_mean := _box_mean(conifer_wood, SHADE_RADIUS)
	_conifer.resize(count)
	_fertility.resize(count)
	for i in count:
		_conifer[i] = conifer_mean[i] / _woods[i] if _woods[i] > 0.001 else 0.0
		var cell := _window.position + Vector2i(i % _window.size.x, i / _window.size.x)
		_fertility[i] = fertility_at(cell, definition.seed)
	_masks = _mask_lookup(definition)


func _stamp_buildings(definition: MapDefinition, wall_src: PackedByteArray) -> void:
	for rect in MapViewMeshBuilderPrimitives.building_cell_rects(definition):
		_fill(wall_src, _cell_rect(rect), 1)


func _stamp_tree_props(
	definition: MapDefinition, wood: PackedFloat32Array, conifer_wood: PackedFloat32Array
) -> void:
	for prop in definition.props:
		var kind: StringName = prop.get("kind", &"")
		if kind != &"tree":
			continue
		var cell := _prop_cell(definition, prop)
		var conifer := 0.0
		var species := MapViewTreeSpecies.parse_variant(StringName(prop.get("style_variant", &"")))
		if species.get("species", &"") in [&"spruce", &"pine"]:
			conifer = 1.0
		# A crown shades about a 3 x 3 cell patch around its trunk.
		var crown := Rect2i(cell - Vector2i.ONE, Vector2i(3, 3)).intersection(_window)
		for y in range(crown.position.y, crown.end.y):
			for x in range(crown.position.x, crown.end.x):
				var i := _index(Vector2i(x, y))
				wood[i] = 1.0
				conifer_wood[i] = maxf(conifer_wood[i], conifer)


static func _prop_cell(definition: MapDefinition, prop: Dictionary) -> Vector2i:
	var scale := MapViewBridge.world_scale(definition.cell_size)
	var world: Vector2 = prop.get("position", Vector2.ZERO)
	if prop.get("footprint") is Rect2:
		world = (prop["footprint"] as Rect2).get_center()
	var cell := world * scale
	return Vector2i(floori(cell.x), floori(cell.y))


func _cell_rect(world_rect: Rect2) -> Rect2i:
	var start := Vector2i(floori(world_rect.position.x), floori(world_rect.position.y))
	var finish := Vector2i(ceili(world_rect.end.x), ceili(world_rect.end.y))
	return Rect2i(start, finish - start)


func _fill(array: PackedByteArray, rect: Rect2i, value: int) -> void:
	var clipped := rect.intersection(_window)
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			array[_index(Vector2i(x, y))] = value


## Two-pass chamfer (3-4) distance in cells, capped at `radius`. Sources farther
## than the cap never matter, and every cell of the region sees its full radius
## inside the window, so the result does not depend on the region size.
func _distance(sources: PackedByteArray, radius: int) -> PackedByteArray:
	var w := _window.size.x
	var h := _window.size.y
	var far := (radius + 1) * 3
	var d := PackedInt32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0 if sources[i] != 0 else far
	for y in h:
		for x in w:
			var i := y * w + x
			var v := d[i]
			if x > 0:
				v = mini(v, d[i - 1] + 3)
			if y > 0:
				v = mini(v, d[i - w] + 3)
				if x > 0:
					v = mini(v, d[i - w - 1] + 4)
				if x < w - 1:
					v = mini(v, d[i - w + 1] + 4)
			d[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := d[i]
			if x < w - 1:
				v = mini(v, d[i + 1] + 3)
			if y < h - 1:
				v = mini(v, d[i + w] + 3)
				if x < w - 1:
					v = mini(v, d[i + w + 1] + 4)
				if x > 0:
					v = mini(v, d[i + w - 1] + 4)
			d[i] = v
	var out := PackedByteArray()
	out.resize(w * h)
	for i in w * h:
		out[i] = mini(roundi(d[i] / 3.0), radius + 1)
	return out


func _box_mean(values: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var w := _window.size.x
	var h := _window.size.y
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var total := 0.0
			var samples := 0
			for dy in range(-radius, radius + 1):
				var yy := y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-radius, radius + 1):
					var xx := x + dx
					if xx < 0 or xx >= w:
						continue
					total += values[yy * w + xx]
					samples += 1
			out[y * w + x] = total / float(samples)
	return out


## Low-frequency value noise in 0..1 from the map seed and cell only.
static func fertility_at(cell: Vector2i, map_seed: int) -> float:
	var p := Vector2(cell) / FERTILITY_SCALE
	var base := Vector2i(floori(p.x), floori(p.y))
	var f := p - Vector2(base)
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := MapViewMeshBuilderPrimitives.hash01(base.x, base.y, map_seed + 6151)
	var b := MapViewMeshBuilderPrimitives.hash01(base.x + 1, base.y, map_seed + 6151)
	var c := MapViewMeshBuilderPrimitives.hash01(base.x, base.y + 1, map_seed + 6151)
	var d := MapViewMeshBuilderPrimitives.hash01(base.x + 1, base.y + 1, map_seed + 6151)
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)


## Authored override mask: per layer, the product of every mask covering a
## cell, applied in stable-ID order (multiplication commutes; the order only
## documents determinism).
func _mask_lookup(definition: MapDefinition) -> Dictionary:
	var lookup := {}
	for mask in definition.vegetation_masks:
		var rect: Rect2i = mask["rect"]
		if not rect.intersects(region):
			continue
		lookup[mask["id"]] = mask
	return lookup


func mask_multiplier(layer: StringName, cell: Vector2i) -> float:
	var value := 1.0
	for key: Variant in _masks.keys():
		var mask: Dictionary = _masks[key]
		if mask["layer"] != layer and mask["layer"] != LAYER_ALL:
			continue
		if (mask["rect"] as Rect2i).has_point(cell):
			value *= float(mask["density"])
	return value


func _index(cell: Vector2i) -> int:
	var local := cell - _window.position
	return local.y * _window.size.x + local.x


# --- Per-cell fields -------------------------------------------------------


func water_distance(cell: Vector2i) -> int:
	return _water[_index(cell)]


func road_distance(cell: Vector2i) -> int:
	return _road[_index(cell)]


func wall_distance(cell: Vector2i) -> int:
	return _wall[_index(cell)]


func stone_distance(cell: Vector2i) -> int:
	return _stone[_index(cell)]


func field_distance(cell: Vector2i) -> int:
	return _field[_index(cell)]


func woodland_shade(cell: Vector2i) -> float:
	return _woods[_index(cell)]


func conifer_shade(cell: Vector2i) -> float:
	var i := _index(cell)
	return _woods[i] * _conifer[i]


func fertility(cell: Vector2i) -> float:
	return _fertility[_index(cell)]


func is_trodden(cell: Vector2i) -> bool:
	return _trodden[_index(cell)] != 0


func is_field_margin(cell: Vector2i) -> bool:
	var d := field_distance(cell)
	return d >= 1 and d <= 2


func is_dry_limestone(cell: Vector2i) -> bool:
	var d := stone_distance(cell)
	return d >= 1 and d <= JUNIPER_STONE_REACH and water_distance(cell) >= JUNIPER_DRY_WATER


## Litter under deciduous crowns (0..1). Data for VEGR-8; not drawn yet.
func litter(cell: Vector2i) -> float:
	var i := _index(cell)
	return _woods[i] * (1.0 - _conifer[i])


# --- Layer densities -------------------------------------------------------


## Multiplier on the authored or terrain scatter chance of `layer` at `cell`.
## 1.0 keeps the old density; 0 forbids the layer.
func density(layer: StringName, cell: Vector2i) -> float:
	if is_trodden(cell):
		return 0.0
	var i := _index(cell)
	var fert := _fertility[i]
	var woods := _woods[i]
	var value := 1.0
	match layer:
		LAYER_GRASS:
			var verge := [0.0, 0.5, 0.8]
			var road := int(_road[i])
			value = (verge[road] if road < verge.size() else 1.0)
			# Crowns starve grass of light; fertility makes patches, not a carpet.
			value *= lerpf(1.0, 0.35, woods) * lerpf(0.55, 1.35, fert)
		LAYER_FLOWERS:
			value = lerpf(1.0, 0.2, woods) * lerpf(0.4, 1.4, fert)
			if is_field_margin(cell) or int(_road[i]) == 2:
				value *= 1.6
		LAYER_GROUND_COVER:
			value = lerpf(0.6, 1.3, fert)
		LAYER_SHRUBS:
			value = lerpf(0.6, 1.3, fert)
			# Thickets gather at the wood edge, not deep inside it.
			if woods > 0.15 and woods < 0.7:
				value *= 1.4
			if int(_road[i]) <= 1:
				value *= 0.4
		LAYER_TREES:
			# Never above the authored density: trees are the costliest layer
			# (R-1320 budget), so ecology only thins them.
			value = lerpf(0.5, 1.0, fert)
			if int(_road[i]) <= 1 or int(_wall[i]) <= 1:
				value = 0.0
	# A designer's authored zone keeps at least half its density.
	if _authored[i] != 0:
		value = maxf(value, 0.5)
	return value * mask_multiplier(layer, cell)


## Extra understory planting at `cell` and its chance (0..1). Exactly one pick
## per cell so the rules stay readable and the same cell never stacks species.
func understory(cell: Vector2i) -> Dictionary:
	var i := _index(cell)
	if _trodden[i] != 0 or _plantable[i] == 0:
		return {"kind": UNDERSTORY_NONE, "chance": 0.0}
	var fert := _fertility[i]
	var cover := mask_multiplier(LAYER_GROUND_COVER, cell)
	var shrubs := mask_multiplier(LAYER_SHRUBS, cell)
	var water := int(_water[i])
	if water >= 1 and water <= SEDGE_REACH:
		return {"kind": UNDERSTORY_SEDGE, "chance": 0.30 * cover}
	if conifer_shade(cell) >= FERN_CONIFER_SHADE:
		# Damp conifer floor: fern on the fertile half, moss cushions elsewhere.
		var kind := UNDERSTORY_FERN if fert >= 0.45 else UNDERSTORY_MOSS
		return {"kind": kind, "chance": (0.26 if kind == UNDERSTORY_FERN else 0.22) * cover}
	if int(_wall[i]) >= 1 and int(_wall[i]) <= NETTLE_REACH:
		return {"kind": UNDERSTORY_NETTLE, "chance": 0.12 * lerpf(0.6, 1.4, fert) * cover}
	if water >= 1 and water <= NETTLE_REACH + 1:
		return {"kind": UNDERSTORY_NETTLE, "chance": 0.08 * cover}
	if is_dry_limestone(cell):
		return {"kind": UNDERSTORY_JUNIPER, "chance": 0.10 * shrubs}
	if is_field_margin(cell):
		return {"kind": UNDERSTORY_FIELD_WEED, "chance": 0.14 * cover}
	return {"kind": UNDERSTORY_NONE, "chance": 0.0}
