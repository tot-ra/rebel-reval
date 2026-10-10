extends "res://tests/godot/test_case.gd"

## Faction visual identity for named NPCs (docs/SYSTEMS/FACTIONS_AND_ECONOMY.md,
## task R-1565): every ledger faction and candidate seat has an identity, the
## shapes differ, the chip, dyes, accent, marker tint and panel badge follow it.


func _expected_factions() -> Array[String]:
	var out: Array[String] = []
	for id: StringName in FactionLedger.ACTIVE_FACTIONS:
		out.append("faction.%s" % id)
	for id: StringName in FactionCandidateSeats.CANDIDATE_FACTIONS:
		out.append("faction.%s" % id)
	return out


func test_every_launch_faction_and_candidate_seat_is_covered() -> void:
	for faction in _expected_factions():
		assert_true(FactionIdentity.has_identity(faction), "identity for %s" % faction)
		assert_true(FactionIdentity.emblem(faction) != null, "emblem for %s" % faction)
	assert_true(FactionIdentity.has_identity("faction.dorpat"))
	assert_true(FactionIdentity.has_identity("faction.osel_wiek"))


func test_no_identity_for_clergy_or_no_seat() -> void:
	assert_false(FactionIdentity.has_identity("faction.church"))
	assert_false(FactionIdentity.has_identity(null))
	assert_eq(FactionIdentity.dye_for(null), {})
	assert_true(FactionIdentity.chip_texture(null) == null)


func test_emblems_are_distinct_files() -> void:
	var seen := {}
	for faction in FactionIdentity.ids():
		var path := String(FactionIdentity.row(faction)["emblem"])
		assert_false(seen.has(path), "%s shares an emblem with %s" % [faction, seen.get(path)])
		seen[path] = faction


func test_dyes_keep_contrast_and_avoid_hero_crimson() -> void:
	var hero := Color.html("#D9364D")
	for faction in FactionIdentity.ids():
		var a := FactionIdentity.primary(faction)
		var b := FactionIdentity.secondary(faction)
		var lo := minf(FactionIdentity.relative_luminance(a), FactionIdentity.relative_luminance(b))
		var hi := maxf(FactionIdentity.relative_luminance(a), FactionIdentity.relative_luminance(b))
		assert_true((hi + 0.05) / (lo + 0.05) >= 3.0, "contrast %s" % faction)
		assert_true(a != hero and b != hero, "hero crimson reserved: %s" % faction)


func test_chip_plate_is_the_lighter_dye() -> void:
	for faction in FactionIdentity.ids():
		var colours := FactionIdentity.chip_colours(faction)
		assert_true(
			FactionIdentity.relative_luminance(colours[0])
			>= FactionIdentity.relative_luminance(colours[1]),
			"plate lighter than glyph: %s" % faction
		)
		var texture := FactionIdentity.chip_texture(faction)
		assert_eq(texture.get_width(), FactionIdentity.CHIP_PX)
		# Corner is transparent (round plate), centre is opaque.
		var image := texture.get_image()
		assert_eq(image.get_pixel(0, 0).a, 0.0)
		assert_true(image.get_pixel(FactionIdentity.CHIP_PX / 2, 2).a > 0.9)


func test_styled_record_lays_faction_dyes_over_the_body() -> void:
	var base := {"cloth": [0.5, 0.5, 0.5], "under": [0.1, 0.1, 0.1], "body": "citizen_m_adult_average"}
	var styled := FactionIdentity.styled_record(base, "faction.danish_crown")
	var red := FactionIdentity.primary("faction.danish_crown")
	assert_eq(styled["cloth"], [red.r, red.g, red.b])
	assert_eq(styled["body"], "citizen_m_adult_average")
	assert_eq(base["cloth"], [0.5, 0.5, 0.5], "input record is not mutated")
	assert_eq(FactionIdentity.styled_record(base, "faction.church")["cloth"], base["cloth"])


func test_marker_tint_comes_from_identity() -> void:
	for faction in FactionIdentity.ids():
		assert_eq(
			NamedNpcMarker.tint_for(faction),
			Color.html(String(FactionIdentity.row(faction)["marker_tint"]))
		)


func test_marker_chip_follows_public_emblem() -> void:
	var order := NamedNpcMarker.new()
	order.setup({"id": "char.x", "faction": "faction.livonian_order", "marker": "available"}, 1.0)
	assert_true(order._chip != null, "Order shows its chip")
	order.free()
	var cloaks := NamedNpcMarker.new()
	cloaks.setup({"id": "char.y", "faction": "faction.black_cloaks", "marker": "available"}, 1.0)
	assert_true(cloaks._chip == null, "Black Cloaks hide their emblem")
	cloaks.free()
	var none := NamedNpcMarker.new()
	none.setup({"id": "char.z", "faction": null, "marker": "available"}, 1.0)
	assert_true(none._chip == null)
	none.free()


func test_accent_attaches_once_and_respects_placement() -> void:
	var rig := Node3D.new()
	FactionIdentity.attach_accent(rig, "faction.danish_crown", 1.0)
	FactionIdentity.attach_accent(rig, "faction.danish_crown", 1.0)
	var holder := rig.get_node(NodePath(FactionIdentity.ACCENT_NODE))
	assert_eq(holder.get_child_count(), 2, "front and back emblem, added once")
	var front := holder.get_child(0) as Sprite3D
	assert_eq(front.modulate, FactionIdentity.secondary("faction.danish_crown"))
	assert_true(front.position.z > 0.0)
	rig.free()
	var cloaked := Node3D.new()
	FactionIdentity.attach_accent(cloaked, "faction.black_cloaks", 1.0)
	assert_true(cloaked.get_node_or_null(NodePath(FactionIdentity.ACCENT_NODE)) == null)
	FactionIdentity.attach_accent(cloaked, null, 1.0)
	assert_eq(cloaked.get_child_count(), 0)
	cloaked.free()


func test_panel_badge_shows_chip_only_for_public_emblems() -> void:
	var badge := Control.new()
	FactionIdentity.fill_badge(badge, "faction.hanseatic")
	assert_true(badge.visible)
	var chip := badge.get_node("FactionChip") as TextureRect
	assert_true(chip.texture == FactionIdentity.chip_texture("faction.hanseatic"))
	FactionIdentity.fill_badge(badge, "faction.black_cloaks")
	assert_false(badge.visible)
	FactionIdentity.fill_badge(badge, null)
	assert_false(badge.visible)
	badge.free()
