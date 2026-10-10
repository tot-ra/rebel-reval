class_name CitizenInfoPanel
extends CanvasLayer

## Who is this? Panel shown when the player clicks (or presses interact next to)
## a census resident of the city. Read-only: the census is static content, there is
## no conversation yet (docs/SYSTEMS/CITIZENS.md). Named NPCs (CityNamedNpcs,
## docs/SYSTEMS/NAMED_NPCS.md) use the same panel with their portrait, title and
## a faction row whose badge slot NPC-5 (R-1565) fills.

signal closed

const FACTION_NAMES := {
	"none": "no faction", "hanseatic": "Hanseatic merchants", "danish_crown": "Danish Crown",
	"black_cloaks": "Black Cloaks", "cult_metsik": "forest cult", "church": "the Church",
	"harju_kings": "Harju elders", "pskov_novgorod": "Pskov and Novgorod",
	"livonian_order": "Livonian Order", "vitalienbruder": "Vitalienbrüder", "blackheads": "Blackheads",
}

## Empty slot for the faction emblem chip (ADR 0044 section 4, task R-1565).
var faction_badge: Control
## Stable id (cit.* or char.*) of the person shown; spawners only refresh their own.
var shown_id := ""

var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _body: RichTextLabel
var _now: Label
var _identity: HBoxContainer
var _portrait: TextureRect
var _faction_label: Label


func _init() -> void:
	layer = 20
	name = "CitizenInfoPanel"
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 1.0
	# Large and lifted clear of the spell overlay along the bottom edge.
	_panel.offset_left = 24.0
	_panel.offset_top = -820.0
	_panel.offset_right = 584.0
	_panel.offset_bottom = -180.0
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide_panel)
	head.add_child(close)
	_subtitle = Label.new()
	_subtitle.modulate = Color(1, 1, 1, 0.75)
	_subtitle.add_theme_font_size_override("font_size", 22)
	box.add_child(_subtitle)
	_identity = HBoxContainer.new()
	_identity.add_theme_constant_override("separation", 14)
	box.add_child(_identity)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(150, 150)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_identity.add_child(_portrait)
	var faction_row := HBoxContainer.new()
	faction_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	faction_row.add_theme_constant_override("separation", 8)
	_identity.add_child(faction_row)
	faction_badge = Control.new()
	faction_badge.name = "FactionBadge"
	faction_badge.custom_minimum_size = Vector2(32, 32)
	faction_row.add_child(faction_badge)
	_faction_label = Label.new()
	_faction_label.add_theme_font_size_override("font_size", 22)
	faction_row.add_child(_faction_label)
	_identity.visible = false
	_now = Label.new()
	_now.add_theme_color_override("font_color", Color(0.95, 0.82, 0.5))
	_now.add_theme_font_size_override("font_size", 22)
	box.add_child(_now)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	for font in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		_body.add_theme_font_size_override(font, 22)
	_body.fit_content = false
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	_panel.visible = false


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func is_open() -> bool:
	return _panel.visible


func hide_panel() -> void:
	if _panel.visible:
		_panel.visible = false
		shown_id = ""
		closed.emit()


func show_citizen(r: Dictionary, now: String) -> void:
	_panel.visible = true
	shown_id = String(r["id"])
	_identity.visible = false
	_title.text = String(r["name"])
	_subtitle.text = "%s, %d · %s" % [_sex(r), int(r["age"]), String(r["ethnicity"]).capitalize()]
	update_now(now)
	var ap: Dictionary = r["appearance"]
	var lines: PackedStringArray = []
	if not String(r["blurb"]).is_empty():
		lines.append("[i]%s[/i]\n" % String(r["blurb"]).replace("[", "(").replace("]", ")"))
	lines.append("[b]Trade[/b]  %s (%s)" % [_nice(r["trade"]), _nice(r["status"])])
	lines.append("[b]Faction[/b]  %s%s" % [
		FACTION_NAMES.get(r["faction"], r["faction"]),
		"" if String(r["faction_role"]) == "none" else ", " + _nice(r["faction_role"]),
	])
	lines.append("[b]Household[/b]  %s, %s" % [_nice(r["household_role"]), r["street"]])
	lines.append(
		"[b]Languages[/b]  %s · literacy: %s"
		% [", ".join(r["languages"]), _nice(r["literacy"])]
	)
	lines.append("")
	lines.append("[b]Looks[/b]  %d cm, %s build; %s hair, %s eyes" % [
		int(ap["height_cm"]), ap["build"], ap["hair"], ap["eyes"]])
	var complexion := String(ap["complexion"])
	lines.append(
		"%s; voice %s"
		% [complexion.substr(0, 1).to_upper() + complexion.substr(1), ap["voice"]]
	)
	if ap["facial_hair"] != null:
		lines.append("Facial hair: %s" % ap["facial_hair"])
	for mark: String in ap["marks"]:
		lines.append("• %s" % mark.replace("[", "("))
	lines.append("")
	var card_note := (
		"deep card: " + String(r["card"]).get_file()
		if not String(r["card"]).is_empty()
		else "census entry only"
	)
	lines.append("[color=#8a8a8a]%s · %s[/color]" % [r["id"], card_note])
	_body.text = "\n".join(lines)


## A named NPC (registry row, docs/SYSTEMS/NAMED_NPCS.md): portrait when the
## registry has one, title and faction. `census` is the census record when the
## NPC replaces a resident (its trade and household follow), else empty.
func show_named(npc: Dictionary, census: Dictionary, now: String) -> void:
	_panel.visible = true
	shown_id = String(npc["id"])
	_title.text = String(npc["display_name"])
	var title := String(npc["title"])
	_subtitle.text = title.substr(0, 1).to_upper() + title.substr(1)
	var portrait: Variant = npc.get("portrait")
	_portrait.texture = load(String(portrait)) as Texture2D if portrait != null else null
	_portrait.visible = _portrait.texture != null
	_faction_label.text = faction_name(npc.get("faction"))
	_identity.visible = true
	update_now(now)
	var lines: PackedStringArray = []
	if not census.is_empty():
		lines.append("[b]Trade[/b]  %s (%s)" % [_nice(census["trade"]), _nice(census["status"])])
		lines.append("[b]Household[/b]  %s, %s" % [_nice(census["household_role"]), census["street"]])
		lines.append("")
	var sheet := String(npc["source_sheet"]).get_file()
	lines.append("[color=#8a8a8a]%s · %s[/color]" % [npc["id"], sheet])
	_body.text = "\n".join(lines)


## The portrait on show, or null (census resident, or a named NPC without one).
func portrait_texture() -> Texture2D:
	return _portrait.texture if _identity.visible and _portrait.visible else null


func faction_text() -> String:
	return _faction_label.text if _identity.visible else ""


static func faction_name(faction: Variant) -> String:
	if faction == null:
		return "no faction seat"
	var id := FactionLedger.faction_id_from_key(StringName(String(faction)))
	if FactionCandidateSeats.DISPLAY_NAMES.has(id):
		return String(FactionCandidateSeats.DISPLAY_NAMES[id])
	return FactionLedger.display_name(id)


func update_now(text: String) -> void:
	_now.text = text


static func _sex(r: Dictionary) -> String:
	var adult := int(r["age"]) >= 16
	if r["sex"] == "m":
		return "Man" if adult else "Boy"
	return "Woman" if adult else "Girl"


static func _nice(value: Variant) -> String:
	return String(value).replace("_", " ")
