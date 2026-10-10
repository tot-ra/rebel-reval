extends "res://tests/godot/test_case.gd"

## WR-9 (R-1514, docs/SYSTEMS/CITY_SEA.md "Beach response"): sand darkens and
## glistens behind the swash and dries; shingle drains the backwash film and its
## foam; wet pebbles sheen, dry pebbles above the berm stay matte.

const SWASH_INCLUDE := "res://scripts/map/view3d/shore_swash.gdshaderinc"
const GROUND_SHADER := "res://scripts/city/city_ground.gdshader"
const WATER_SHADER := "res://scripts/map/view3d/map_view_water.gdshader"
const SANDBOX := "res://tools/water_sandbox/water_sandbox.gd"
const ShoreDebris := preload("res://scripts/map/view3d/map_view_shore_debris.gd")
const CityWorld3DScript := preload("res://scripts/city/city_world_3d.gd")
const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")


func after_each() -> void:
	# The sandbox build changes the shared water materials; undo the city storm
	# swell boost and the shore field for later tests.
	WaterMaterials.set_wave_height_boost(1.0)
	MapViewMaterials.apply_shore_field(null, Vector2.ZERO, Vector2.ONE)
	super.after_each()


func test_swash_include_exposes_backwash_and_beach_response() -> void:
	var include := FileAccess.get_file_as_string(SWASH_INCLUDE)
	_expect(include, {
		"float backwash;": "ShoreState carries the backwash progress",
		"s.backwash = clamp((u - SHORE_UPRUSH)": "backwash follows the cycle",
		"ShoreBeach shore_beach(ShoreState s, float porosity)": "beach response",
		"float shore_porosity(float tan_beta)": "porosity from slope",
		"float shore_pebble_cover(": "pebbles poke through a thin film",
	})
	# Sand dries over about 30 s; shingle drains much faster.
	var sand_dry := _const(include, "SHORE_DRY_TIME")
	var shingle_dry := _const(include, "SHORE_SHINGLE_DRY_TIME")
	assert_true(sand_dry >= 25.0 and sand_dry <= 35.0, "sand dries over ~30 s: %f" % sand_dry)
	assert_true(shingle_dry < sand_dry * 0.5, "shingle drains faster than sand")
	assert_true(
		_const(include, "SHORE_SHINGLE_GLISTEN_TIME") < _const(include, "SHORE_GLISTEN_TIME"),
		"a standing film lasts longer on sand than on pebbles"
	)


func test_ground_reads_the_swash_history_instead_of_a_static_strand() -> void:
	var ground := FileAccess.get_file_as_string(GROUND_SHADER)
	_expect(ground, {
		'#include "res://scripts/map/view3d/shore_swash.gdshaderinc"': "swash include",
		"shore_beach(swash, beach_porous)": "beach response on the ground",
		"* sand * (1.0 - swash_live)": "static wet strand only without a shore field",
		"shore * 0.5 * (1.0 - swash_live)": "static shore damp only without a shore field",
		"ROUGHNESS = mix(ROUGHNESS, 0.06, beach_glisten)": "fresh film glistens",
		"ROUGHNESS = mix(ROUGHNESS, 0.95, shingle * (1.0 - beach_wet))": "dry shingle stays matte",
	})


func test_water_drains_the_runup_film_over_shingle() -> void:
	var water := FileAccess.get_file_as_string(WATER_SHADER)
	assert_true(water.contains("shore_porosity(length(sea_bed_slope))"), "porosity from the bed slope")
	assert_true(water.contains("drain.foam_keep"), "foam bubbles drain into the gaps")
	assert_true(water.contains("shore_pebble_cover(film_metres, porous)"), "pebble crowns")
	assert_true(
		water.contains("ALPHA *= max(city_coverage, tip_foam) * runup_drain;"),
		"film thins over shingle"
	)


func test_ground_mirrors_every_shore_uniform_the_include_declares() -> void:
	var include := FileAccess.get_file_as_string(SWASH_INCLUDE)
	var names: PackedStringArray = CityWorld3DScript.shore_uniform_names(load(GROUND_SHADER))
	var uniform := RegEx.create_from_string("(?m)^uniform\\s+\\w+\\s+(shore_\\w+)")
	var declared := uniform.search_all(include)
	assert_true(declared.size() >= 12, "swash uniforms found in the include")
	for found: RegExMatch in declared:
		assert_true(names.has(found.get_string(1)), "%s mirrored to the ground" % found.get_string(1))


func test_ground_stays_inside_its_texture_unit_budget() -> void:
	# Godot binds a texture unit to every declared sampler; one past 13 made GL
	# Compatibility drop the whole city ground draw on macOS without an error.
	var pattern := RegEx.create_from_string("(?m)^uniform\\s+sampler")
	var count := 0
	var sources := [
		GROUND_SHADER,
		SWASH_INCLUDE,
		"res://scripts/city/city_grass_ground.gdshaderinc",
		"res://scripts/map/view3d/water_capillary.gdshaderinc",
		"res://scripts/map/view3d/fieldstone_paving.gdshaderinc",
	]
	for path: String in sources:
		count += pattern.search_all(FileAccess.get_file_as_string(path)).size()
	assert_true(count <= 13, "city ground declares %d samplers (max 13)" % count)
	var ground := FileAccess.get_file_as_string(GROUND_SHADER)
	assert_false(
		ground.contains("uniform sampler2D rock_normal"), "rock_normal unit went to shore_field"
	)


func test_wet_stone_variant_is_darker_and_glossier_than_dry() -> void:
	var dry := ShoreDebris.shore_debris_mesh(&"pebble_patch_a")
	if dry == null:
		skip("shore debris GLB unavailable")
		return
	var wet := ShoreDebris.wet_shore_debris_mesh(&"pebble_patch_a")
	assert_ne(wet, dry, "wet mesh is a separate resource")
	for surface in dry.get_surface_count():
		var dry_mat := dry.surface_get_material(surface) as StandardMaterial3D
		var wet_mat := wet.surface_get_material(surface) as StandardMaterial3D
		if dry_mat == null:
			continue
		assert_ne(wet_mat, dry_mat, "shared dry material untouched")
		assert_true(wet_mat.roughness < dry_mat.roughness, "wet stone is glossier")
		assert_true(wet_mat.metallic_specular > dry_mat.metallic_specular, "wet stone has a sheen")
		assert_eq(wet_mat.albedo_texture, dry_mat.albedo_texture, "same stone plate")
	assert_true(ShoreDebris.WET_STONE_TINT < 0.8, "wet stones darken")


func test_sandbox_shingle_has_wet_pebbles_below_the_berm_and_dry_above() -> void:
	var builder: Script = load(SANDBOX)
	var line: float = builder.SHINGLE_WET_LINE
	var blend: float = builder.SHINGLE_WET_BLEND
	for i in 40:
		var x := float(i) * 3.7
		assert_true(builder.shingle_pebble_wet(x, line - blend * 0.6), "pebble in the swash is wet")
		assert_false(builder.shingle_pebble_wet(x, line + blend * 0.6), "pebble above the berm is dry")
	var sandbox: Node3D = builder.create()
	var wet := 0
	var dry := 0
	for child in sandbox.get_children():
		var node_name := String(child.name)
		if child is MultiMeshInstance3D and node_name.begins_with("Pebbles_"):
			var count := (child as MultiMeshInstance3D).multimesh.instance_count
			if node_name.ends_with("_wet"):
				wet += count
			else:
				dry += count
	assert_true(wet > 100 and dry > 100, "both wet and dry pebbles: %d / %d" % [wet, dry])
	assert_eq(wet + dry, 660, "pebble count unchanged by the wet split")
	sandbox.free()


func _expect(source: String, needles: Dictionary) -> void:
	for needle: String in needles:
		assert_true(source.contains(needle), needles[needle])


static func _const(source: String, name: String) -> float:
	var found := RegEx.create_from_string("const float %s = ([0-9.]+);" % name).search(source)
	return float(found.get_string(1)) if found != null else -1.0
