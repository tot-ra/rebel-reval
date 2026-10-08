extends "res://tests/godot/test_case.gd"

## R-1344 LIFE-1: hourly civilian routines and their controller integration.

const ScheduleScript := preload("res://scripts/world/citizen_schedule.gd")
const ControllerScript := preload("res://scripts/world/urban_population_controller.gd")
const PlacementScript := preload("res://scripts/world/urban_population_placement.gd")
const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")
const LowerTownSliceDefinition := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")

const WEEKDAY := 0
const SUNDAY := 6
const DATE_OFF_DAY := {"day": 22, "month": 4, "year": 1343}


func _visible_count(occupation: StringName, hour: int, weekday: int) -> int:
	var count := 0
	for actor_index in 40:
		var activity := ScheduleScript.activity_for(occupation, hour, weekday, 1343, actor_index)
		if ScheduleScript.is_visible(activity):
			count += 1
	return count


func test_activity_is_deterministic() -> void:
	for hour in 24:
		assert_eq(
			ScheduleScript.activity_for(&"artisan", hour, WEEKDAY, 1343, 7),
			ScheduleScript.activity_for(&"artisan", hour, WEEKDAY, 1343, 7),
		)


func test_every_occupation_sleeps_at_night_and_is_out_by_day() -> void:
	for occupation: StringName in ProfileScript.OCCUPATIONS:
		assert_eq(_visible_count(occupation, 2, WEEKDAY), 0, "%s asleep at 02h" % occupation)
		assert_true(_visible_count(occupation, 12, WEEKDAY) > 0, "%s out at noon" % occupation)


func test_artisan_day_runs_home_work_tavern() -> void:
	# Jitter is at most one hour, so mid-block hours are stable for every actor.
	for actor_index in 20:
		assert_eq(
			ScheduleScript.activity_for(&"artisan", 12, WEEKDAY, 1343, actor_index),
			ScheduleScript.ACT_WORK,
		)
		assert_eq(
			ScheduleScript.activity_for(&"artisan", 19, WEEKDAY, 1343, actor_index),
			ScheduleScript.ACT_TAVERN,
		)


func test_sunday_morning_is_church_for_everyone() -> void:
	for occupation: StringName in ProfileScript.OCCUPATIONS:
		assert_eq(
			ScheduleScript.activity_for(occupation, 9, SUNDAY, 1343, 3),
			ScheduleScript.ACT_CHURCH,
			"%s at church on Sunday" % occupation,
		)


func test_zone_mapping() -> void:
	assert_eq(ScheduleScript.zone_for(ScheduleScript.ACT_WORK, &"laborer", WEEKDAY), &"work_yard")
	assert_eq(
		ScheduleScript.zone_for(ScheduleScript.ACT_HOME, &"resident", WEEKDAY), &"residential_yard"
	)
	assert_eq(ScheduleScript.zone_for(ScheduleScript.ACT_MARKET, &"merchant", 2), &"market_lane")
	assert_eq(
		ScheduleScript.zone_for(ScheduleScript.ACT_MARKET, &"merchant", WEEKDAY), &"street_frontage"
	)
	for activity: StringName in ScheduleScript.ACTIVITIES:
		if ScheduleScript.is_visible(activity):
			var zone := ScheduleScript.zone_for(activity, &"artisan", WEEKDAY)
			assert_true(PlacementScript.ZONE_BOUNDS.has(zone), "%s has a placeable zone" % activity)


func test_apply_to_plan_keeps_indices_and_leaves_watch_alone() -> void:
	var profile := ProfileScript.day(&"investigation_morning", DATE_OFF_DAY, 1343)
	var plan: Array = profile["actor_plan"]
	var routed := ScheduleScript.apply_to_plan(plan, 1, WEEKDAY, 1343)
	var routed_watch := 0
	for record: Dictionary in routed:
		assert_eq(StringName(record["role"]), &"watch", "only watch is out at 01h")
		routed_watch += 1
	assert_eq(routed_watch, int(profile["watch_count"]))
	var noon := ScheduleScript.apply_to_plan(plan, 12, WEEKDAY, 1343)
	assert_true(noon.size() > routed.size())
	assert_eq(noon, ScheduleScript.apply_to_plan(plan, 12, WEEKDAY, 1343))


func test_controller_occupancy_changes_over_24_hours() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var controller := ControllerScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	controller.setup(definition, grid, null, &"loc.lower_town_slice", 1343)
	var strip: Array[int] = []
	for hour in 24:
		controller.sync_for_test(&"investigation_morning", 0, false, 1343, hour)
		strip.append(controller.get_active_profile()["actor_plan"].size())
	assert_true(strip.max() > strip.min(), "occupancy must vary across the day: %s" % str(strip))
	assert_true(strip[12] > strip[1], "noon busier than 01h: %s" % str(strip))
	var replay: Array[int] = []
	for hour in 24:
		controller.sync_for_test(&"investigation_morning", 0, false, 1343, hour)
		replay.append(controller.get_active_profile()["actor_plan"].size())
	assert_eq(strip, replay, "same inputs replay the same 24h strip")
	controller.queue_free()
