class_name DialogueTextLayout
extends RefCounted

## Dialogue panel geometry used by overflow checks (P1-014).

const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")

const TARGET_VIEWPORTS: Array[Vector2i] = [
	Vector2i(1600, 900),
	Vector2i(1280, 720),
]

const OUTER_MARGIN_X := 24
const PANEL_MARGIN_X := 16
const PORTRAIT_WIDTH := 96
const BODY_COLUMN_GAP := 16
const DIALOGUE_ROOT_MIN_HEIGHT := 220
const PANEL_MARGIN_Y := 12
const SPEAKER_LINE_HEIGHT_FACTOR := 1.35
const FOOTER_LINE_HEIGHT_FACTOR := 1.2
const DISABLED_REASON_LINE_HEIGHT_FACTOR := 1.2
const CHOICE_LINE_HEIGHT_FACTOR := 1.35
const BODY_SCROLL_MIN_HEIGHT := 72
const BODY_SCROLL_MAX_HEIGHT := 120


static func body_text_width(viewport_width: int) -> int:
	return maxi(
		160,
		viewport_width
			- (OUTER_MARGIN_X * 2)
			- (PANEL_MARGIN_X * 2)
			- PORTRAIT_WIDTH
			- BODY_COLUMN_GAP
	)


static func body_text_max_height(
	viewport_height: int,
	choice_count: int = 0,
	has_disabled_reason: bool = false
) -> int:
	var reserved := (PANEL_MARGIN_Y * 2)
	reserved += int(round(20.0 * SPEAKER_LINE_HEIGHT_FACTOR))
	reserved += int(round(13.0 * FOOTER_LINE_HEIGHT_FACTOR))
	reserved += choice_count * int(round(16.0 * CHOICE_LINE_HEIGHT_FACTOR))
	if has_disabled_reason:
		reserved += int(round(13.0 * DISABLED_REASON_LINE_HEIGHT_FACTOR))
	var available := viewport_height - reserved - DIALOGUE_ROOT_MIN_HEIGHT
	return clampi(available, BODY_SCROLL_MIN_HEIGHT, BODY_SCROLL_MAX_HEIGHT)


static func multiline_text_height(
	font: Font,
	text: String,
	width: int,
	font_size: int
) -> int:
	if text.is_empty():
		return 0
	return int(
		font.get_multiline_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			width,
			font_size
		).y
	)


static func text_fits_or_needs_scroll(
	font: Font,
	text: String,
	viewport_size: Vector2i,
	text_scale: String,
	choice_count: int = 0,
	has_disabled_reason: bool = false
) -> bool:
	var width := body_text_width(viewport_size.x)
	var font_size := TextScaleScript.body_size(text_scale)
	var content_height := multiline_text_height(font, text, width, font_size)
	var visible_height := body_text_max_height(
		viewport_size.y,
		choice_count,
		has_disabled_reason
	)
	if content_height <= visible_height:
		return true
	return visible_height >= BODY_SCROLL_MIN_HEIGHT
