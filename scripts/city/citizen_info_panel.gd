class_name CitizenInfoPanel
extends CanvasLayer

## Who is this? Panel shown when the player clicks (or presses interact next to)
## a census resident of the city. Read-only: the census is static content, there is
## no conversation yet (docs/SYSTEMS/CITIZENS.md).

signal closed

const FACTION_NAMES := {
	"none": "no faction", "hanseatic": "Hanseatic merchants", "danish_crown": "Danish Crown",
	"black_cloaks": "Black Cloaks", "cult_metsik": "forest cult", "church": "the Church",
	"harju_kings": "Harju elders", "pskov_novgorod": "Pskov and Novgorod",
	"livonian_order": "Livonian Order", "vitalienbruder": "Vitalienbrüder", "blackheads": "Blackheads",
}

var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _body: RichTextLabel
var _now: Label


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
		closed.emit()


func show_citizen(r: Dictionary, now: String) -> void:
	_panel.visible = true
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


func update_now(text: String) -> void:
	_now.text = text


static func _sex(r: Dictionary) -> String:
	var adult := int(r["age"]) >= 16
	if r["sex"] == "m":
		return "Man" if adult else "Boy"
	return "Woman" if adult else "Girl"


static func _nice(value: Variant) -> String:
	return String(value).replace("_", " ")
