extends "res://tests/godot/test_case.gd"

## R-1400: discrete world-space clouds, their ground shadows, and storm-cell lightning.

const CloudCellsScript := preload("res://scripts/map/view3d/cloud_cells.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const CLOUD_SHADOW_SHADER := preload("res://scripts/map/view3d/cloud_shadow_pass.gdshader")
const WATER_SHADER := preload("res://scripts/map/view3d/map_view_water.gdshader")
const GOD_RAY_SHADER := preload("res://scripts/map/view3d/god_ray_pass.gdshader")


func test_cell_field_is_a_pure_function_of_clock_drift_and_counts() -> void:
	var a := CloudCellsScript.new()
	var b := CloudCellsScript.new()
	a.update(123.4, Vector2(0.03, -0.01), Vector2(6.5, 1.2))
	b.update(123.4, Vector2(0.03, -0.01), Vector2(6.5, 1.2))
	assert_eq(a.uniforms(), b.uniforms(), "same inputs must rebuild the same cells")
	assert_eq(
		a.uniforms().size(), CloudCellsScript.SLOTS * CloudCellsScript.STRIDE + 1,
		"four vec4 per slot and one for the hotspot"
	)


func test_weather_decides_how_many_cells_show() -> void:
	var clear := CloudCellsScript.counts_for(0.30, 0.0)
	var cloudy := CloudCellsScript.counts_for(0.66, 0.16)
	var storm := CloudCellsScript.counts_for(0.40, 1.0)
	assert_true(clear.x >= 3.0 and clear.x < cloudy.x, "fair weather shows a few cumulus")
	assert_eq(clear.y, 0.0, "a clear sky grows no thunderhead")
	assert_eq(cloudy.y, 0.0, "plain cloud cover grows no thunderhead")
	assert_true(storm.y >= 2.0, "a storm grows cumulonimbus cells")


## R-1481: every cumulus rides the wind at its own speed and slight veer, faster
## than the dome deck, so clouds overtake each other instead of hanging in place.
func test_cells_drift_with_the_wind_at_their_own_speed() -> void:
	var cells := CloudCellsScript.new()
	cells.update(10.0, Vector2.ZERO, Vector2(13.0, 0.0))
	var before := cells.centers.duplicate()
	var towered := cells.towers.duplicate()
	cells.update(10.0, Vector2(0.002, 0.0), Vector2(13.0, 0.0))
	var deck := 0.002 * CloudCellsScript.METRES_PER_UV
	var speeds := {}
	for slot in CloudCellsScript.CUMULUS_SLOTS:
		# Merging pulls a tower off its own track; check free cells only.
		if towered[slot] > 0.0 or cells.towers[slot] > 0.0:
			continue
		var a: Vector3 = before[slot]
		var b: Vector3 = cells.centers[slot]
		var moved := CloudCellsScript.wrap_delta(Vector2(b.x, b.z), Vector2(a.x, a.z))
		assert_true(moved.length() > deck * 1.5, "cumulus outpace the deck drift")
		assert_true(
			absf(moved.angle()) <= CloudCellsScript.CUMULUS_VEER + 0.001,
			"each cell keeps close to the wind bearing"
		)
		speeds[snappedf(moved.length(), 1.0)] = true
	assert_true(speeds.size() >= 5, "cells drift at different speeds")


## R-1481: a dissolving cumulus shrinks and flattens first and only then fades.
func test_a_cumulus_shrinks_before_it_fades() -> void:
	var cells := CloudCellsScript.new()
	var full_radius := 0.0
	var radius_at_fade_start := -1.0
	for step in 2000:
		cells.update(float(step) * 0.1, Vector2.ZERO, Vector2(1.0, 0.0))
		var life: float = cells.lives[0]
		if life > 0.3 and life < 0.45:
			full_radius = maxf(full_radius, cells.radii[0])
		if (
			full_radius > 0.0 and radius_at_fade_start < 0.0
			and life >= CloudCellsScript.CUMULUS_FADE_START
		):
			radius_at_fade_start = cells.radii[0]
			assert_true(cells.weights[0] > 0.95, "the cloud is still solid when it starts to fade")
			break
	assert_true(radius_at_fade_start > 0.0, "precondition: the cell reached its fade")
	assert_true(
		radius_at_fade_start < full_radius * 0.75, "the cloud has shrunk well before it fades"
	)


func test_cells_live_grow_and_dissipate() -> void:
	var cells := CloudCellsScript.new()
	var seen_born := false
	var seen_full := false
	for step in 400:
		cells.update(float(step) * 0.5, Vector2.ZERO, Vector2(1.0, 0.0))
		var w: float = cells.weights[0]
		if w < 0.05:
			seen_born = true
		if w > 0.95:
			seen_full = true
	assert_true(seen_born and seen_full, "a cell must appear, mature, and fade over its life")


func test_a_cell_shadows_the_ground_under_it_along_the_sun() -> void:
	var cells := CloudCellsScript.new()
	cells.update(0.0, Vector2.ZERO, Vector2(1.0, 0.0))
	# Pin slot 0 mid-life so the test does not depend on the hashed phase.
	cells.weights[0] = 1.0
	cells.centers[0] = Vector3(1000.0, 700.0, 1000.0)
	cells.radii[0] = 300.0
	cells.heights[0] = 300.0
	var sun := Vector3(0.5, 0.8, 0.0).normalized()
	var layer: float = 700.0 + 300.0 * 0.35
	# Ground point whose sun ray passes through the cell centre at its shadow layer.
	var under := Vector3(1000.0 - sun.x / sun.y * layer, 0.0, 1000.0)
	assert_true(cells.shadow_at(under, sun) > 0.7, "the ground under a cumulus is shadowed")
	assert_true(
		cells.shadow_at(Vector3(1000.0, 0.0, 1000.0) + Vector3(0.0, 0.0, 900.0), sun) < 0.05,
		"ground well beside the cloud stays in sun"
	)
	# The shadow follows the sun, not the point straight below the cloud.
	assert_true(
		cells.shadow_at(under, sun) > cells.shadow_at(Vector3(1600.0, 0.0, 1000.0), sun),
		"a low sun throws the shadow away from the point under the cloud"
	)


## Pins cumulus 0..3 grown and touching (0 in the middle, the most crowded), 4
## alone far away, the rest gone, with a convective hotspot over the cluster.
func _crowded_cluster() -> CloudCellsScript:
	var cells := CloudCellsScript.new()
	cells.update(0.0, Vector2.ZERO, Vector2(13.0, 0.0))
	for slot in CloudCellsScript.SLOTS:
		cells.weights[slot] = 0.0
		cells.towers[slot] = 0.0
	var spots := [
		Vector2(1100, 1100), Vector2(1350, 1100), Vector2(850, 1100), Vector2(1100, 1350),
		Vector2(2600, 2600),
	]
	for slot in spots.size():
		cells.weights[slot] = 1.0
		cells.lives[slot] = 0.4
		cells.radii[slot] = 250.0
		cells.heights[slot] = 250.0
		cells.centers[slot] = Vector3(spots[slot].x, 700.0, spots[slot].y)
	for slot in CloudCellsScript.SLOTS:
		cells.tower_pulls[slot] = Vector2.ZERO
		cells.tower_radii[slot] = cells.radii[slot]
		cells.tower_heights[slot] = cells.heights[slot]
	cells.hot_centre = Vector2(1100, 1100)
	cells._merge_crowded_cumulus()
	return cells


## R-1481 / R-1501: crowded cumulus merge into one wide thunderstorm, but only in
## the copy that sits in a convective hotspot.
func test_crowded_cumulus_merge_into_a_thunderstorm() -> void:
	var cells := _crowded_cluster()
	for slot in 4:
		assert_true(cells.towers[slot] > CloudCellsScript.TOWER_MATURE, "ready to storm")
		assert_true(cells.tower_level(slot) > CloudCellsScript.TOWER_MATURE, "it storms in the hotspot")
	assert_eq(cells.towers[4], 0.0, "a lone cumulus stays fair-weather")
	assert_eq(cells.tower_level(4), 0.0, "a lone cumulus never storms")
	# One leader grows into the storm; the others shrink into its base.
	assert_true(cells.tower_radii[0] >= CloudCellsScript.TOWER_RADIUS.x, "the leader is storm-wide")
	for slot in [1, 2, 3]:
		assert_true(cells.tower_radii[slot] < cells.radii[slot], "the rest fold into the leader")
	var storm := cells.copy_shape(0, Vector2(1100, 1100))
	assert_true(storm[5] > CloudCellsScript.TOWER_MATURE, "the hotspot copy is a storm")
	assert_true(storm[3] >= 900.0, "a storm is about a kilometre or more in radius: %.0f" % storm[3])
	assert_true(storm[4] >= 1100.0, "and over a kilometre tall")
	assert_almost_eq(storm[1], CloudCellsScript.TOWER_BASE, 60.0, "its base drops")
	var fair := cells.copy_shape(0, Vector2(1100 + CloudCellsScript.DOMAIN, 1100))
	assert_eq(fair[5], 0.0, "the same cluster's next copy stays ordinary cumulus")
	assert_eq(fair[3], 250.0, "and keeps its size")
	assert_true(cells.mature_storm_cells().has(0), "a mature storm can charge lightning")
	assert_true(cells.max_tower() > CloudCellsScript.TOWER_MATURE, "tower level is exposed")
	cells.hot_centre += Vector2(CloudCellsScript.DOMAIN * 0.5, 0.0)
	assert_eq(cells.tower_level(0), 0.0, "away from a hotspot the cluster does not storm")
	assert_false(cells.mature_storm_cells().has(0), "and throws no lightning")


## R-1481: a cumulus is a lobed cluster stretched along its axis, not a round disc.
func test_cumulus_footprint_is_lobed_and_elongated() -> void:
	var cells := CloudCellsScript.new()
	cells.update(0.0, Vector2.ZERO, Vector2(13.0, 0.0))
	var longest := 0.0
	for slot in CloudCellsScript.CUMULUS_SLOTS:
		cells.towers[slot] = 0.0
		var lo := INF
		var hi := 0.0
		for i in 36:
			var dir := Vector2.from_angle(TAU * float(i) / 36.0)
			var r := 0.0
			while r < cells.radii[slot] * 4.0 and cells.footprint_distance(slot, dir * r) < 1.0:
				r += 5.0
			lo = minf(lo, r)
			hi = maxf(hi, r)
		longest = maxf(longest, hi / maxf(lo, 1.0))
		assert_true(
			hi <= cells.radii[slot] * CloudCellsScript.CUMULUS_REACH,
			"the footprint stays inside the shader march box"
		)
	assert_true(longest > 1.8, "some cumulus are drawn out well over twice as long as wide")


## R-1493: far visibility cannot be implemented by widening the nearest-copy fade.
func test_mature_towers_stay_solid_at_five_kilometres() -> void:
	for distance in [1600.0, 4000.0, 5000.0]:
		assert_almost_eq(CloudCellsScript.view_fade(
			distance, 0, CloudCellsScript.TOWER_MATURE
		), 1.0, 0.001, "a mature tower stays solid through 5 km")
		assert_eq(CloudCellsScript.view_fade(distance, 0, 0.5), 0.0,
			"ordinary cumulus retain their seam fade")
	assert_almost_eq(CloudCellsScript.view_fade(4000.0, 0, 0.625), 0.5, 0.001,
		"distant tower copies fade in smoothly, not at a binary maturity switch")
	assert_almost_eq(CloudCellsScript.view_fade(5500.0, 0, 1.0), 0.5, 0.001,
		"mature towers fade between 5 and 6 km")
	assert_eq(CloudCellsScript.view_fade(6000.0, 0, 1.0), 0.0, "finite far reach")
	for distance in [1000.0, 4000.0, 4800.0, 5000.0]:
		var domain: float = CloudCellsScript.STORM_DOMAIN
		assert_almost_eq(CloudCellsScript.view_fade(distance, 1, 0.0),
			1.0 - smoothstep(0.36 * domain, 0.5 * domain, distance), 0.001,
			"native storm slots keep their existing visibility")


func _visible_tower_copies(eye: Vector2) -> Dictionary:
	var nearest := eye + CloudCellsScript.wrap_delta(Vector2.ZERO, eye)
	var copies := {}
	for copy in CloudCellsScript.TOWER_COPIES:
		var center := nearest + CloudCellsScript.view_copy_offset(copy)
		var fade := CloudCellsScript.view_fade(center.distance_to(eye), 0, 1.0)
		if fade > 0.0:
			copies[center] = fade
	return copies


func test_tower_copies_cover_far_bearings_and_cross_seams_without_teleporting() -> void:
	assert_eq(CloudCellsScript.view_copy_offset(0), Vector2.ZERO, "nearest fast path")
	var unique := {}
	for copy in CloudCellsScript.TOWER_COPIES:
		unique[CloudCellsScript.view_copy_offset(copy)] = true
	assert_eq(unique.size(), 25, "no duplicate copy or double opacity")
	for angle in 32:
		var eye := Vector2.from_angle(float(angle) * TAU / 32.0) * 5000.0
		var visible := _visible_tower_copies(eye)
		assert_true(visible.has(Vector2.ZERO), "original tower remains at its world position")
		# Compare against a deliberately oversized reference neighbourhood.
		for x in range(-4, 5):
			for z in range(-4, 5):
				var center := Vector2(x, z) * CloudCellsScript.DOMAIN
				if center.distance_to(eye) < CloudCellsScript.TOWER_FADE.y:
					assert_true(visible.has(center), "every in-range periodic copy is drawn")
	for seam in [Vector2(1600, 0), Vector2(0, -1600), Vector2(1600, 1600)]:
		var before := _visible_tower_copies(seam - Vector2.ONE * 0.01)
		var after := _visible_tower_copies(seam + Vector2.ONE * 0.01)
		assert_eq(before.size(), after.size(), "crossing a seam preserves visible copies")
		for center: Vector2 in before:
			assert_true(after.has(center), "world centres do not jump at the nearest-copy seam")
			assert_almost_eq(before[center], after.get(center, -1.0), 0.001,
				"opacity stays continuous across the seam")


func test_tower_visibility_rebuild_is_history_independent() -> void:
	var cells := CloudCellsScript.new()
	var counts := Vector2(13.0, 0.0)
	cells.update(123.4, Vector2(0.03, -0.01), counts, 0.7)
	var saved := cells.uniforms()
	cells.update(900.0, Vector2(1.2, -0.3), Vector2(2.0, 3.0), 0.2)
	cells.update(123.4, Vector2(0.03, -0.01), counts, 0.7)
	assert_eq(cells.uniforms(), saved, "restore needs no tower handoff or camera state")
	var shader := FileAccess.get_file_as_string("res://scripts/map/view3d/sky_weather_3d.gdshader")
	assert_eq(shader.count("cell_view_fade(length(c - ro.xz), b.z, cc.y)"), 2,
		"volume and sky-beam occlusion use the same fade")
	assert_eq(shader.count("copy < CELL_TOWER_COPIES"), 2,
		"volume and sky-beam occlusion enumerate the same world copies")
	var shared := FileAccess.get_file_as_string("res://scripts/map/view3d/cloud_cells.gdshaderinc")
	assert_true("CELL_TOWER_COPIES = 25" in shared, "CPU/GPU neighbourhood matches")
	assert_true("CELL_TOWER_MATURE = 0.75" in shared, "CPU/GPU maturity matches")
	assert_true("CELL_TOWER_FADE = vec2(5000.0, 6000.0)" in shared,
		"CPU/GPU fade range matches")


func test_wrap_delta_takes_the_nearest_periodic_copy() -> void:
	var d := CloudCellsScript.wrap_delta(
		Vector2(10.0, 0.0), Vector2(CloudCellsScript.DOMAIN - 10.0, 0.0)
	)
	assert_almost_eq(d.x, 20.0, 0.001, "a cell across the seam is 20 units away, not a domain")


## R-1495: a cloudless sky has no cumulus; a cloudy one fills every slot.
func test_cloudless_sky_has_no_cumulus_and_cloudy_fills_the_slots() -> void:
	var cloudless := CloudCellsScript.counts_for(
		float(SkyWeather.PROFILES[SkyWeather.WEATHER_CLOUDLESS]["coverage"]), 0.0
	)
	assert_eq(cloudless, Vector2.ZERO, "a cloudless sky shows no cell at all")
	var clear := CloudCellsScript.counts_for(0.30, 0.0)
	assert_almost_eq(clear.x, 8.0, 0.5, "a fair day keeps its scattered cumulus")
	var cloudy := CloudCellsScript.counts_for(0.66, 0.16)
	assert_true(cloudy.x > 16.0, "a cloudy sky is crowded enough for cumulus to merge")


## R-1501: a merged cluster storms in exactly one copy per hotspot, and every copy
## still has its own shape seed.
func test_a_cluster_storms_only_in_its_hotspot_copy() -> void:
	var cells := _crowded_cluster()
	var storming := 0
	var copy_seeds := {}
	for x in range(-1, 2):
		for z in range(-1, 2):
			var fair := Vector2(1100, 1100) + Vector2(x, z) * CloudCellsScript.DOMAIN
			copy_seeds[snappedf(cells.copy_seed(0, fair), 0.0001)] = true
			if cells.copy_shape(0, fair)[5] > 0.5:
				storming += 1
	assert_eq(storming, 1, "one storm per hotspot, not one per copy")
	assert_true(copy_seeds.size() >= 8, "every copy draws its own shape seed")
	assert_true(CloudCellsScript.HOT_RADIUS.y < CloudCellsScript.DOMAIN * 0.5,
		"two copies of one cluster can never share a hotspot")


## R-1495: a copy keeps its shape seed while the wrapped centre crosses the seam.
func test_copy_seed_survives_the_tile_wrap() -> void:
	var cells := CloudCellsScript.new()
	var counts := Vector2(13.0, 0.0)
	var drift := Vector2.ZERO
	# The clock stays put, so slot 0 keeps one generation while the drift carries
	# its wrapped centre across the tile seam several times.
	cells.update(0.0, drift, counts)
	var wrapped_seen := false
	for step in 4000:
		var prev := Vector2(cells.centers[0].x, cells.centers[0].z)
		var prev_seed := cells.copy_seed(0, prev)
		drift += Vector2(0.0002, 0.0)
		cells.update(0.0, drift, counts)
		var now := Vector2(cells.centers[0].x, cells.centers[0].z)
		# Follow the same physical copy, which may now be a neighbouring tile.
		var followed := prev + CloudCellsScript.wrap_delta(now, prev)
		assert_almost_eq(cells.copy_seed(0, followed), prev_seed, 0.0005,
			"a drifting copy keeps its seed")
		if now.x < prev.x - CloudCellsScript.DOMAIN * 0.5:
			wrapped_seen = true
	assert_true(wrapped_seen, "the probe must actually cross the tile seam")


## R-1495: a merged tower keeps a lobed outline instead of folding into a disc.
func test_merged_tower_keeps_its_lobes() -> void:
	var cells := _crowded_cluster()
	var hot := Vector2(1100, 1100)
	var shape := cells.copy_shape(0, hot)
	assert_true(shape[7] < 0.5, "a tower folds its lobes only partly")
	var storm_slot := CloudCellsScript.CUMULUS_SLOTS
	assert_eq(cells.copy_shape(storm_slot, hot)[7], 1.0, "storm slots fold fully")
	var lo := INF
	var hi := 0.0
	for i in 36:
		var dir := Vector2.from_angle(TAU * float(i) / 36.0)
		var r := 0.0
		while r < shape[3] * 4.0 and cells.copy_footprint(0, hot, dir * r) < 1.0:
			r += 20.0
		lo = minf(lo, r)
		hi = maxf(hi, r)
	assert_true(hi / lo > 1.2, "the tower footprint is not round: %.2f" % (hi / lo))
	assert_true(
		hi <= shape[3] * lerpf(CloudCellsScript.CUMULUS_REACH, CloudCellsScript.STORM_REACH, shape[7]),
		"the tower stays inside its march box"
	)


## R-1501: lightning strikes from the storming copy in the hotspot nearest the eye.
func test_tower_lightning_uses_the_hotspot_copy() -> void:
	var cells := _crowded_cluster()
	for angle in 16:
		var eye := Vector2.from_angle(float(angle) * TAU / 16.0) * 2300.0 + Vector2(1100, 1100)
		var fair := cells.tower_copy_centre(0, eye)
		assert_true(cells.copy_shape(0, fair)[5] > CloudCellsScript.TOWER_MATURE,
			"the strike copy is the storm")
		assert_true(fair.distance_to(eye) < 6000.0, "and the nearest one")


func test_lightning_is_born_only_in_a_mature_storm_cell() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_STORM)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var strikes := 0
	var was_flashing := false
	for step in 3000:
		sky.advance(0.05)
		var flashing: bool = sky.lightning_flash() > 0.0
		if flashing and not was_flashing:
			strikes += 1
			var origin: Vector3 = sky.lightning_origin()
			var cells = sky.cloud_cells()
			var inside := false
			for slot in cells.mature_storm_cells():
				# Headless: the camera is the world origin. A merged storm is its
				# hotspot copy (R-1501).
				var c0: Vector3 = cells.centers[slot]
				var fair := Vector2(c0.x, c0.z)
				if CloudCellsScript.kind_of(slot) == CloudCellsScript.KIND_CUMULUS:
					fair = cells.tower_copy_centre(slot, Vector2.ZERO)
				var shape: PackedFloat32Array = cells.copy_shape(slot, fair)
				var c := Vector3(shape[0], shape[1], shape[2])
				var offset := CloudCellsScript.wrap_delta(
					Vector2(origin.x, origin.z), Vector2(c.x, c.z), CloudCellsScript.kind_of(slot)
				)
				if (
					offset.length() <= shape[3] * 0.5
					and origin.y >= c.y
					and origin.y <= c.y + shape[4]
					and float(cells.weights[slot]) >= CloudCellsScript.STORM_MATURE_WEIGHT
				):
					inside = true
			assert_true(inside, "every strike must start inside a charged cumulonimbus or tower")
			if sky.lightning_kind() == SkyWeather.LIGHTNING_KIND_GROUND:
				assert_almost_eq(sky.lightning_ground().y, 0.0, 0.001, "a ground stroke ends on the ground")
		was_flashing = flashing
	assert_true(strikes >= 3, "a thunderstorm must keep striking from its cells")
	sky.free()


func test_no_storm_cell_means_no_lightning_even_with_thunder() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.advance(1.0)
	# Thunder without storm development: the profile asks for strikes, but no
	# cumulonimbus grows, so the sky must hold its charge instead of striking.
	sky._current[&"thunder"] = 1.0
	for step in 2000:
		var flashing_before: bool = sky.lightning_flash() > 0.0
		sky.advance(0.05)
		assert_eq(sky.cloud_cells().max_weight(CloudCellsScript.KIND_STORM), 0.0, "no storm cells")
		# R-1481: a merged cumulus tower may charge; with none, nothing strikes.
		if not flashing_before and sky.cloud_cells().mature_storm_cells().is_empty():
			assert_eq(sky.lightning_flash(), 0.0, "lightning must never strike without a storm cell")
	sky.free()


func test_cell_clock_and_strike_survive_save_and_load() -> void:
	var source = SkyWeather.new()
	source.auto_weather = false
	source.set_weather(SkyWeather.WEATHER_STORM)
	for step in 400:
		source.advance(0.05)
	var restored = SkyWeather.new()
	assert_true(restored.restore_state(source.snapshot_state().to_dict()), "state must restore")
	assert_almost_eq(
		restored.cloud_cell_clock(), source.cloud_cell_clock(), 0.0001, "cell clock persists"
	)
	assert_eq(
		restored.cloud_cells().uniforms(), source.cloud_cells().uniforms(), "cells rebuild exactly"
	)
	assert_eq(restored.lightning_origin(), source.lightning_origin(), "strike origin persists")
	assert_eq(restored.lightning_kind(), source.lightning_kind(), "strike kind persists")
	source.free()
	restored.free()


func test_sun_behind_a_cell_dims_the_sun_glint() -> void:
	var sky = SkyWeather.new()
	var cells = sky.cloud_cells()
	for slot in CloudCellsScript.SLOTS:
		cells.weights[slot] = 0.0
	var sun := Vector3(0.0, 0.8, -0.6).normalized()
	assert_almost_eq(sky.cells_clear_toward(sun), 1.0, 0.0001, "no cells: the sun is clear")
	cells.weights[0] = 1.0
	cells.radii[0] = 300.0
	cells.heights[0] = 300.0
	var layer := 700.0 + 300.0 * 0.35
	cells.centers[0] = Vector3(0.0, 700.0, sun.z / sun.y * layer)
	assert_true(sky.cells_clear_toward(sun) < 0.3, "a cell in front of the sun blocks it")
	sky.free()


func test_shaders_consume_the_cells() -> void:
	assert_true(
		"cells_ground_shadow" in CLOUD_SHADOW_SHADER.code, "ground shadows come from the cells"
	)
	assert_true("cells_ground_shadow" in GOD_RAY_SHADER.code, "god rays are cut by the cells")
	var sky_code: String = SkyWeather.SKY_SHADER.code
	assert_true("cells_volume" in sky_code, "the dome ray-marches the cells")
	assert_true("lightning_origin" in sky_code, "the bolt starts in its storm cell")


## The shadow pass draws before transparents, so water dims its own sun under a cell.
func test_water_dims_its_own_sun_under_the_cells() -> void:
	var sea_code: String = WATER_SHADER.code
	assert_true("cells_ground_shadow" in sea_code, "the sea reads the cell shadow")
	assert_true("cloud_lit" in sea_code, "the sea's light() scales sun diffuse and glints")
	for path in [
		"res://scripts/city/city_water.gdshader", "res://scripts/city/city_moat_water.gdshader",
	]:
		var code: String = load(path).code
		assert_true("city_water_light.gdshaderinc" in code, "%s uses the cell-aware light()" % path)
		assert_true("city_water_cloud_shadow" in code, "%s samples the cell shadow" % path)
	var cells := CloudCellsScript.new()
	cells.update(50.0, Vector2.ZERO, Vector2(6.0, 1.0))
	MapViewMaterials.apply_cloud_cells(cells.uniforms())
	var sea := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	assert_eq(sea.get_shader_parameter("cloud_cells"), cells.uniforms(), "cells reach the sea")


## R-1437: lightweight city water retains the deck/cell union; FFT sea has no spare
## fragment samplers. GPU captures verify this source contract on real GL.
func test_water_deck_shadow_shares_the_pass_field_and_stays_vertex_only() -> void:
	var shared := FileAccess.get_file_as_string(
		"res://scripts/map/view3d/water_cloud_shadow.gdshaderinc"
	)
	for token in [
		"sky_cloud_shadow_soft", "cells_ground_shadow", "cloud_shape_tex", "cloud_noise_tex",
		"cloud_detail_offset_g", "cloud_coverage_g", "cloud_chaos_g", "cloud_shadow_strength",
		"(q / WATER_CLOUD_LAYER_H) * 0.12 - cloud_offset_g",
		"WATER_CLOUD_LAYER_H = 400.0", "WATER_CLOUD_SHADOW_MIP_BIAS = 1.5",
		"WATER_CELL_SHADOW_STRENGTH = 0.85",
		"1.0 - (1.0 - deck) * (1.0 - cell * WATER_CELL_SHADOW_STRENGTH)",
		"smoothstep(WATER_SUN_HANDOFF_Y, 0.0, cloud_sun_dir.y)",
	]:
		assert_true(token in shared, "shared water shadow contract: %s" % token)
	assert_false("hint_screen_texture" in shared, "cloud shading never reads the framebuffer")
	assert_false("TIME" in shared, "cloud shading uses the restored sky state, not shader time")
	var sea_code: String = WATER_SHADER.code
	var vertex := sea_code.get_slice("void vertex()", 1).get_slice("void fragment()", 0)
	var fragment_and_light := sea_code.get_slice("void fragment()", 1)
	assert_true("cells_ground_shadow(undisplaced_world" in vertex, "map sea samples per vertex")
	assert_false("water_cloud_shadow.gdshaderinc" in sea_code, "FFT sea avoids extra deck sampler")
	assert_false("water_cloud_shadow(" in fragment_and_light, "no fragment cloud samplers")
	assert_true(
		"LIGHT_IS_DIRECTIONAL ? 1.0 - cloud_cell_shadow : 1.0" in fragment_and_light,
		"apply the combined shadow once, leaving local lights alone"
	)
	var city := FileAccess.get_file_as_string("res://scripts/city/city_water_light.gdshaderinc")
	assert_true("water_cloud_shadow.gdshaderinc" in city, "city and map share the field")
	assert_true("return water_cloud_shadow(world);" in city, "city samples the same union")
	assert_true(
		"LIGHT_IS_DIRECTIONAL ? 1.0 - cloud_cell_shadow : 1.0" in city,
		"city applies the combined shadow once, leaving local lights alone"
	)


## R-1400 follow-up: a configured sky whose camera sits in the tree, so rain reads
## the camera position. Storm cells are grown, then pinned (advance(0.0) keeps them).
func _storm_sky_with_camera(weather: StringName) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var sky = SkyWeather.new()
	tree.root.add_child(sky)
	var camera := Camera3D.new()
	sky.add_child(camera)
	sky.configure(camera, Environment.new())
	sky.auto_weather = false
	sky.set_weather(weather)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 0.1)
	# Walk the cell clock until one cumulonimbus is well grown.
	for step in 400:
		if sky.cloud_cells().max_weight(CloudCellsScript.KIND_STORM) > 0.8:
			break
		sky.advance(0.5)
	return [sky, camera]


func _strongest_storm_center(sky) -> Vector3:
	var cells = sky.cloud_cells()
	var best := CloudCellsScript.CUMULUS_SLOTS
	for slot in range(CloudCellsScript.CUMULUS_SLOTS, CloudCellsScript.SLOTS):
		if cells.weights[slot] > cells.weights[best]:
			best = slot
	return cells.centers[best]


## A ground point `distance` from `center` that no storm shaft covers.
func _dry_point(sky, center: Vector3, distance: float) -> Vector3:
	for i in 16:
		var p := Vector3(center.x, 0.0, center.z) + Vector3.FORWARD.rotated(
			Vector3.UP, TAU * float(i) / 16.0
		) * distance
		if sky.storm_rain_cover_at(p) == 0.0:
			return p
	return Vector3.INF


func test_storm_rain_falls_only_under_a_storm_cell() -> void:
	var made := _storm_sky_with_camera(SkyWeather.WEATHER_STORM)
	var sky = made[0]
	var camera: Camera3D = made[1]
	assert_true(
		sky.cloud_cells().max_weight(CloudCellsScript.KIND_STORM) > 0.8, "precondition: a grown cell"
	)
	var center := _strongest_storm_center(sky)
	camera.global_position = Vector3(center.x, 2.0, center.z)
	sky.advance(0.0)
	assert_true(sky.rain_emitter_visible(), "rain falls under the cumulonimbus")
	assert_true(sky.local_rain_factor() > 0.75, "the shaft core carries most of the storm rain")
	var far := _dry_point(sky, center, 3000.0)
	assert_true(far != Vector3.INF, "precondition: open sky 3 km from the cell")
	camera.global_position = far + Vector3.UP * 2.0
	sky.advance(0.0)
	assert_false(sky.rain_emitter_visible(), "no rain falls 3 km from the storm cell")
	assert_almost_eq(
		sky.rain_intensity(), float(SkyWeather.PROFILES[SkyWeather.WEATHER_STORM]["rain"]), 0.001,
		"the weather-wide rain field does not depend on the camera"
	)
	sky.queue_free()


func test_roof_rain_audio_follows_the_storm_cell() -> void:
	var made := _storm_sky_with_camera(SkyWeather.WEATHER_STORM)
	var sky = made[0]
	var camera: Camera3D = made[1]
	var center := _strongest_storm_center(sky)
	sky.rain_suppressed = true
	camera.global_position = Vector3(center.x, 2.0, center.z)
	sky.advance(0.0)
	assert_true(sky.roof_audio_active(), "a roof under the storm cell drums")
	var far := _dry_point(sky, center, 3000.0)
	assert_true(far != Vector3.INF, "precondition: open sky 3 km from the cell")
	camera.global_position = far + Vector3.UP * 2.0
	sky.advance(0.0)
	assert_false(sky.roof_audio_active(), "a roof 3 km from the storm stays quiet")
	sky.queue_free()


func test_rain_front_rains_everywhere() -> void:
	var made := _storm_sky_with_camera(SkyWeather.WEATHER_RAIN)
	var sky = made[0]
	var camera: Camera3D = made[1]
	var center := _strongest_storm_center(sky)
	for offset in [Vector3.ZERO, Vector3(3000.0, 0.0, 0.0), Vector3(-4100.0, 0.0, 2300.0)]:
		camera.global_position = Vector3(center.x, 2.0, center.z) + offset
		sky.advance(0.0)
		assert_almost_eq(sky.local_rain_factor(), 1.0, 0.0001, "a rain front falls everywhere")
		assert_true(sky.rain_emitter_visible(), "rain weather rains away from the cells too")
	sky.queue_free()


func test_puddles_stay_weather_wide_and_save_compatible() -> void:
	var made := _storm_sky_with_camera(SkyWeather.WEATHER_STORM)
	var sky = made[0]
	var camera: Camera3D = made[1]
	var headless = SkyWeather.new()
	headless.auto_weather = false
	headless.restore_state(sky.snapshot_state().to_dict())
	assert_almost_eq(headless.local_rain_factor(), 1.0, 0.0001, "no camera: counts as under the storm")
	# Put the camera in open sky: local rain stops, ground water keeps filling.
	var center := _strongest_storm_center(sky)
	var far := _dry_point(sky, center, 3000.0)
	assert_true(far != Vector3.INF, "precondition: open sky 3 km from the cell")
	camera.global_position = far + Vector3.UP * 2.0
	for step in 20:
		sky.advance(0.1)
		headless.advance(0.1)
	assert_false(sky.rain_emitter_visible(), "precondition: dry where the camera stands")
	assert_almost_eq(
		sky.puddle_wetness(), headless.puddle_wetness(), 0.0001,
		"puddles follow the weather, not where the camera stands"
	)
	assert_true(sky.puddle_wetness() > 0.0, "storm rain still fills puddles")
	var restored = SkyWeather.new()
	assert_true(restored.restore_state(sky.snapshot_state().to_dict()), "state must restore")
	assert_almost_eq(restored.puddle_wetness(), sky.puddle_wetness(), 0.0001, "puddles persist")
	sky.queue_free()
	headless.free()
	restored.free()
