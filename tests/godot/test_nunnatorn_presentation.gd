extends "res://tests/godot/test_case.gd"

## R-628: Nunnatorn presentation stays view-only, legible across the cycle, and
## uses the shared SFX route without adding gameplay state.

const NunnatornDefinition := preload(
	"res://scripts/map/definitions/prototypes/nunnatorn_interior_definition.gd"
)
const NunnatornPresentation := preload(
	"res://scripts/map/view3d/map_view_nunnatorn_interior.gd"
)
const NunnatornAudio := preload("res://scripts/audio/nunnatorn_audio_controller.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")


func test_nunnatorn_presentation_builds_three_floor_lights_and_open_backed_marker() -> void:
	var definition: MapDefinition = NunnatornDefinition.create()
	var presentation := NunnatornPresentation.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(presentation)
	presentation.configure(definition)

	assert_eq(presentation.get_meta(&"presentation_id"), &"nunnatorn_readability")
	assert_true(
		bool(presentation.get_meta(&"open_backed")),
		"presentation must preserve the city-facing gap"
	)
	assert_eq(presentation.get_meta(&"historical_form"), &"early-14th-century")
	assert_eq(
		presentation.floor_light_count(),
		3,
		"each reconstructed floor needs a local readability pool"
	)
	assert_true(
		presentation.open_backed_marker() != null,
		"open-backed edge marker must be present"
	)
	assert_eq(presentation.get_child_count(), 6, "presentation should stay a small bounded kit")

	var marker := presentation.open_backed_marker()
	assert_true(marker.material_override is StandardMaterial3D, "marker must remain a view material")
	assert_true(
		(marker.material_override as StandardMaterial3D).transparency
			== BaseMaterial3D.TRANSPARENCY_ALPHA,
		"edge marker must not become a solid wall"
	)
	presentation.free()


func test_nunnatorn_day_night_fill_changes_without_mutating_definition() -> void:
	var definition: MapDefinition = NunnatornDefinition.create()
	var fingerprint := definition.fingerprint
	var presentation := NunnatornPresentation.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(presentation)
	presentation.configure(definition)

	presentation.apply_cycle_progress(0.0)
	var night_fill := presentation.get_node("InteriorReadabilityFill") as OmniLight3D
	var night_energy := night_fill.light_energy
	presentation.apply_cycle_progress(0.5)
	var day_energy := night_fill.light_energy
	assert_true(
		day_energy > night_energy,
		"day fill must lift the same route without flattening night"
	)
	assert_eq(definition.fingerprint, fingerprint, "presentation must not mutate map definition")
	assert_eq(DayNightCycle.progress_to_hour(0.5), 12.0)
	presentation.free()


func test_nunnatorn_audio_gain_is_thresholded_and_bounded() -> void:
	assert_eq(NunnatornAudio.target_linear_volume(0.0), 0.0)
	assert_eq(NunnatornAudio.target_linear_volume(0.01), 0.0)
	assert_true(NunnatornAudio.target_linear_volume(0.5) > 0.0)
	assert_true(
		NunnatornAudio.target_linear_volume(1.0)
		<= NunnatornAudio.MAX_LINEAR_VOLUME
	)
	assert_eq(NunnatornAudio.target_linear_volume(1.0, false), 0.0)
