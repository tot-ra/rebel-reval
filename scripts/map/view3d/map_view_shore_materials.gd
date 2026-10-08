extends RefCounted

## WS-08 shore-field and beach-swash material cache for the 3D map view.
##
## WHY: shore uniforms, swash-sheet mirrors, and quality gating change on the
## WS-08 axis independently of the weather-presentation adapter on
## MapViewMaterials. Keep that adapter on the facade; this module owns the
## shore cache so water/terrain weather peels do not reopen the same file.

const WATER_MATERIALS := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const TERRAIN_MATERIALS := preload("res://scripts/map/view3d/map_view_terrain_materials.gd")
const SKY_WEATHER := preload("res://scripts/map/view3d/sky_weather_3d.gd")

## WS-08 shore swash strength per water family. Open sea runs up beaches; ponds
## and moats only slosh at their banks; rivers keep their own bank treatment.
const SHORE_STRENGTH_BY_TERRAIN := {
	MapTypes.TERRAIN_WATER: 0.3,
	MapTypes.TERRAIN_SHALLOW_WATER: 1.0,
	MapTypes.TERRAIN_DEEP_WATER: 1.0,
	MapTypes.TERRAIN_RIVER_WATER: 0.0,
}
## World units of retreat per unit of the water shader's shore-factor tide clip.
## High tide fills the authored contour exactly; only the ebb moves the waterline
## (seaward), so the swash origin follows the water's own tide_shore_retreat.
const SHORE_TIDE_SHIFT := 1.6
## Uniforms a swash sheet must not inherit from its source water material.
const SWASH_SHEET_OWN_UNIFORMS: Array[StringName] = [
	&"swash_sheet", &"ripple_state", &"ripple_window", &"ripple_texel_count"
]

## Beach swash sheets reuse the water shader; one material per source water family.
static var _swash_sheet_materials: Dictionary = {}
static var _shore_swash_quality_tier: StringName = SKY_WEATHER.QUALITY_RECOMMENDED


static func reset() -> void:
	# Quality tier is a session build choice, not a material cache. Clearing
	# sheets must not snap a MINIMUM-tier view back to recommended.
	_swash_sheet_materials.clear()


## Pushes the shared FFT sea-state scalar onto every shore-drawing material and
## mirrors it onto already-built swash sheets.
static func apply_sea_state(wind: float, rain: float) -> void:
	var sea := clampf(WATER_MATERIALS.fft_sea_state_scalar(wind, rain), 0.0, 1.0)
	_set_shore_uniform(&"shore_sea_state", sea)
	_sync_swash_sheets()


## The swash rides on top of the current tide line. Only ebb retreats seaward.
static func apply_tide(level: float) -> void:
	var retreat := float(
		WATER_MATERIALS.WATER_WAVE_BASE[MapTypes.TERRAIN_SHALLOW_WATER]["tide_shore_retreat"]
	)
	var ebb := maxf(-clampf(level, -1.0, 1.0), 0.0)
	_set_shore_uniform(&"shore_tide_offset", -ebb * retreat * SHORE_TIDE_SHIFT)
	_sync_swash_sheets()


## Binds one map's shore distance field to every material that draws the shore.
## A null texture (no sea, interiors) turns every swash path off.
static func apply_shore_field(texture: Texture2D, origin: Vector2, size: Vector2) -> void:
	var valid := 1.0 if texture != null else 0.0
	var extent := Vector2(maxf(size.x, 0.001), maxf(size.y, 0.001))
	for material in _shore_materials():
		if texture != null:
			material.set_shader_parameter("shore_field", texture)
		material.set_shader_parameter("shore_field_origin", origin)
		material.set_shader_parameter("shore_field_size", extent)
		material.set_shader_parameter("shore_field_valid", valid)
	for terrain_id: StringName in WATER_MATERIALS.WATER_WAVE_BASE.keys():
		var water := WATER_MATERIALS.water_surface(
			terrain_id, WATER_MATERIALS.WATER_WAVE_BASE
		)
		var strength: Variant = SHORE_STRENGTH_BY_TERRAIN.get(terrain_id, 0.0)
		water.set_shader_parameter("shore_strength", float(strength))


## Minimum tier drops the sheet mesh but keeps the bore foam and wet sand. Like
## the FFT cascades, the tier applies to map views built afterwards.
static func set_shore_swash_quality_tier(requested: Variant) -> void:
	_shore_swash_quality_tier = SKY_WEATHER.resolve_quality_tier(requested)


static func shore_swash_sheet_enabled() -> bool:
	return _shore_swash_quality_tier != SKY_WEATHER.QUALITY_MINIMUM


## Water-shader material for the beach film. It mirrors its source water family's
## uniforms on every weather sync, so sun, sky, tide and sea state stay identical.
static func swash_sheet_material(terrain_id: StringName) -> ShaderMaterial:
	if _swash_sheet_materials.has(terrain_id):
		return _swash_sheet_materials[terrain_id]
	var source := WATER_MATERIALS.water_surface(terrain_id, WATER_MATERIALS.WATER_WAVE_BASE)
	var material := source.duplicate() as ShaderMaterial
	material.set_shader_parameter("swash_sheet", true)
	material.set_shader_parameter("ripple_state", WATER_MATERIALS.ripple_off_texture())
	material.set_shader_parameter("ripple_window", Vector4(0.0, 0.0, 64.0, 0.0))
	material.render_priority = 1
	_swash_sheet_materials[terrain_id] = material
	return material


## R-1400: per-frame cloud cells for the beach film. A full _sync_swash_sheets()
## mirror every frame would copy every uniform for one changed array.
static func apply_cloud_cells(cells: PackedVector4Array) -> void:
	for sheet: ShaderMaterial in _swash_sheet_materials.values():
		sheet.set_shader_parameter("cloud_cells", cells)


static func _sync_swash_sheets() -> void:
	for terrain_id: StringName in _swash_sheet_materials.keys():
		var source := WATER_MATERIALS.water_surface(
			terrain_id, WATER_MATERIALS.WATER_WAVE_BASE
		)
		var sheet := _swash_sheet_materials[terrain_id] as ShaderMaterial
		for uniform: Dictionary in source.shader.get_shader_uniform_list():
			var uniform_name := StringName(uniform["name"])
			if uniform_name in SWASH_SHEET_OWN_UNIFORMS:
				continue
			var value: Variant = source.get_shader_parameter(uniform_name)
			if value != null:
				sheet.set_shader_parameter(uniform_name, value)


static func _set_shore_uniform(uniform_name: StringName, value: Variant) -> void:
	for material in _shore_materials():
		material.set_shader_parameter(uniform_name, value)


static func _shore_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = TERRAIN_MATERIALS.blended_ground_materials()
	for terrain_id: StringName in WATER_MATERIALS.WATER_WAVE_BASE.keys():
		materials.append(
			WATER_MATERIALS.water_surface(terrain_id, WATER_MATERIALS.WATER_WAVE_BASE)
		)
	for sheet: ShaderMaterial in _swash_sheet_materials.values():
		materials.append(sheet)
	return materials
