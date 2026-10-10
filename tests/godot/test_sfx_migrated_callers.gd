extends "res://tests/godot/test_case.gd"

## R-1356: callers address sounds by catalog ID, never by stream path.

const PickupFeedback := preload("res://scripts/world/world_item_pickup_feedback.gd")


func test_catalog_has_migrated_ids() -> void:
	var catalog := SfxCatalog.load_default()
	for id in [
		&"sfx.item.pickup",
		&"sfx.social.reaction.harju_kings_trusted",
		&"sfx.water.submerge",
		&"sfx.water.emerge",
	]:
		assert_true(catalog.has_entry(id), "catalog missing %s" % id)


func test_pickup_defaults_to_catalog_id_and_plays() -> void:
	assert_true(SfxCatalog.load_default().has_entry(PickupFeedback.DEFAULT_PICKUP_SFX))
	var sfx := SfxPlayer.new()
	sfx.setup(SfxCatalog.load_default(), 5)
	var player := sfx.play(&"sfx.item.pickup")
	assert_true(player != null)
	assert_true(is_equal_approx((player as AudioStreamPlayer).pitch_scale, 1.35))
	assert_true(is_equal_approx((player as AudioStreamPlayer).volume_db, -8.0))
	sfx.free()


func test_pickup_with_null_player_is_safe() -> void:
	PickupFeedback.play_pickup_sfx(null, {})


func test_social_event_names_catalog_sound() -> void:
	for event in SocialReputationModel.EVENTS:
		var id := StringName(String(event.get("sfx_id", "")))
		assert_true(SfxCatalog.load_default().has_entry(id), "event sound %s" % id)
