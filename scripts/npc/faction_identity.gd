class_name FactionIdentity
extends RefCounted

## Faction visual identity of the named NPCs (ADR 0044 section 4, task R-1565,
## docs/SYSTEMS/FACTIONS_AND_ECONOMY.md): a primary/secondary dye pair, an
## emblem, one clothing accent, a marker tint and an info-panel chip, all read
## from content/factions/faction_identity.json. Shape is the main channel: the
## chip is the emblem on a plate, never a bare colour.

const PATH := "res://content/factions/faction_identity.json"
const CHIP_PX := 64
const CHIP_PADDING := 10
const ACCENT_NODE := &"FactionAccent"
## Rig-local accent spots as fractions of CharacterScale.VISIBLE_HEIGHT_WORLD:
## (x, height, z) and the emblem edge in metres. +z is the body's front.
const PLACEMENTS := {
	"chest": [Vector3(0.0, 0.76, 0.17), 0.24],
	"shoulder": [Vector3(0.19, 0.80, 0.14), 0.15],
	"belt": [Vector3(0.0, 0.57, 0.27), 0.16],
	"head": [Vector3(0.0, 0.93, 0.15), 0.14],
}

static var _rows: Dictionary = {}
static var _loaded := false
static var _chips: Dictionary = {}  # faction id -> ImageTexture


static func reload() -> void:
	_rows = {}
	_chips = {}
	_loaded = true
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("FactionIdentity: cannot open %s" % PATH)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("FactionIdentity: %s is not a JSON object" % PATH)
		return
	for row: Dictionary in data.get("factions", []):
		_rows[String(row["id"])] = row


static func ids() -> PackedStringArray:
	_ensure()
	return PackedStringArray(_rows.keys())


## The identity row of `faction`, or {} (clergy, no seat, null).
static func row(faction: Variant) -> Dictionary:
	_ensure()
	return _rows.get(String(faction), {}) if faction != null else {}


static func has_identity(faction: Variant) -> bool:
	return not row(faction).is_empty()


static func primary(faction: Variant, fallback := Color.WHITE) -> Color:
	var r := row(faction)
	return Color.html(String(r["primary"])) if not r.is_empty() else fallback


static func secondary(faction: Variant, fallback := Color.WHITE) -> Color:
	var r := row(faction)
	return Color.html(String(r["secondary"])) if not r.is_empty() else fallback


static func marker_tint(faction: Variant, fallback: Color) -> Color:
	var r := row(faction)
	return Color.html(String(r["marker_tint"])) if not r.is_empty() else fallback


static func emblem(faction: Variant) -> Texture2D:
	var r := row(faction)
	return load(String(r["emblem"])) as Texture2D if not r.is_empty() else null


## Whether the emblem may be shown to anyone (marker, panel). The Black Cloaks
## hide theirs until a reveal state exists (none yet, docs Limits).
static func is_public(faction: Variant) -> bool:
	return bool(row(faction).get("public_emblem", false))


static func accent_kind(faction: Variant) -> String:
	return String(row(faction).get("accent", {}).get("kind", ""))


static func relative_luminance(colour: Color) -> float:
	var lin := colour.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b


## The chip plate takes the lighter of the two dyes and the glyph the darker,
## so the emblem keeps the validated primary/secondary contrast on any faction.
static func chip_colours(faction: Variant) -> Array[Color]:
	var a := primary(faction)
	var b := secondary(faction)
	if relative_luminance(a) >= relative_luminance(b):
		return [a, b]
	return [b, a]


## The emblem on a round plate (64 px), cached per faction. Null without identity.
static func chip_texture(faction: Variant) -> Texture2D:
	var key := String(faction) if faction != null else ""
	if _chips.has(key):
		return _chips[key]
	var glyph := emblem(faction)
	if glyph == null:
		return null
	var colours := chip_colours(faction)
	var image := Image.create(CHIP_PX, CHIP_PX, false, Image.FORMAT_RGBA8)
	var centre := Vector2(CHIP_PX, CHIP_PX) * 0.5
	var radius := CHIP_PX * 0.5 - 1.0
	for y in CHIP_PX:
		for x in CHIP_PX:
			var edge := clampf(radius - Vector2(x + 0.5, y + 0.5).distance_to(centre), 0.0, 1.0)
			if edge > 0.0:
				var plate := colours[0]
				plate.a = edge
				image.set_pixel(x, y, plate)
	var source := glyph.get_image()
	source.convert(Image.FORMAT_RGBA8)
	source.resize(CHIP_PX - 2 * CHIP_PADDING, CHIP_PX - 2 * CHIP_PADDING, Image.INTERPOLATE_LANCZOS)
	for y in source.get_height():
		for x in source.get_width():
			var coverage := source.get_pixel(x, y).a
			if coverage <= 0.0:
				continue
			var at := Vector2i(x + CHIP_PADDING, y + CHIP_PADDING)
			var under := image.get_pixelv(at)
			image.set_pixelv(at, under.lerp(Color(colours[1], under.a), coverage))
	var texture := ImageTexture.create_from_image(image)
	_chips[key] = texture
	return texture


## Cloth and under dye as record arrays (CityCitizens.dye reads [r, g, b]), or {}
## when the faction has no identity so the registry body dyes stay.
static func dye_for(faction: Variant) -> Dictionary:
	var r := row(faction)
	if r.is_empty():
		return {}
	var cloth := Color.html(String(r["primary"]))
	var under := Color.html(String(r["secondary"]))
	return {
		"cloth": [cloth.r, cloth.g, cloth.b],
		"under": [under.r, under.g, under.b],
	}


## `record` (census-shaped styling) with the faction's dyes laid over it.
static func styled_record(record: Dictionary, faction: Variant) -> Dictionary:
	var out := record.duplicate()
	out.merge(dye_for(faction), true)
	return out


## Fills the panel's FactionBadge control with the chip. Empty for factions
## without identity or without a public emblem.
static func fill_badge(badge: Control, faction: Variant) -> void:
	for child in badge.get_children():
		badge.remove_child(child)
		child.queue_free()
	badge.visible = false
	if not has_identity(faction) or not is_public(faction):
		return
	var rect := TextureRect.new()
	rect.name = "FactionChip"
	rect.texture = chip_texture(faction)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.add_child(rect)
	badge.visible = true


## Clothing accent on a mirrored rig: the faction emblem in the secondary dye on
## the chest, shoulder, belt or head, so it reads on the census blank bodies too.
## Factions with `emblem_on_body` false (hooded cloaks) get dye only. Idempotent.
static func attach_accent(rig: Node3D, faction: Variant, height_scale: float) -> void:
	if rig.get_node_or_null(NodePath(ACCENT_NODE)) != null:
		return
	var r := row(faction)
	if r.is_empty():
		return
	var accent: Dictionary = r["accent"]
	if not bool(accent["emblem_on_body"]) or not PLACEMENTS.has(accent["placement"]):
		return
	var spec: Array = PLACEMENTS[accent["placement"]]
	var spot: Vector3 = spec[0]
	var holder := Node3D.new()
	holder.name = ACCENT_NODE
	rig.add_child(holder)
	var height := CharacterScale.VISIBLE_HEIGHT_WORLD * height_scale
	var edge: float = spec[1]
	var glyph := emblem(faction)
	for side in [1.0, -1.0]:  # front and back of the body
		var sprite := Sprite3D.new()
		sprite.texture = glyph
		sprite.pixel_size = edge / float(glyph.get_width())
		sprite.modulate = secondary(faction)
		sprite.shaded = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		sprite.position = Vector3(spot.x, spot.y * height, spot.z * side)
		if side < 0.0:
			sprite.rotation.y = PI
		holder.add_child(sprite)


static func _ensure() -> void:
	if not _loaded:
		reload()
