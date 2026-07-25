class_name VerticalSliceInformationDesignModel
extends RefCounted

## Authored slice information-beat catalog for P3-008.
## WHY: slice validation needs one matrix proving every critical player decision
## and state change is reachable through text, shape, layout, or mechanic gates -
## never through color tint or audio alone, and never through off-game history.

const COLOR_ONLY_CHANNEL := "color_tint"
const AUDIO_ONLY_CHANNEL := "audio_cue"

const VALID_CHANNELS: Array[String] = [
	"text_dialogue",
	"text_prompt",
	"text_ui_button",
	"text_commission",
	"text_journal",
	"text_tooltip",
	"text_plain_summary",
	"shape_silhouette",
	"spatial_world_state",
	"mechanic_gate",
]

## Each beat documents how the player learns or acts without relying on a single
## sensory or historical channel. Supplementary color or audio may exist, but
## beats must always expose at least one non-color, non-audio carrier.
const INFORMATION_BEATS: Array[Dictionary] = [
	{
		"id": "prologue.movement_tutorial",
		"phase": "prologue_day",
		"channels": ["text_prompt", "text_dialogue"],
		"content_ids": ["dialogue.makers_mark.henning_arrival"],
	},
	{
		"id": "prologue.watch_buckle_commission",
		"phase": "prologue_day",
		"channels": ["text_commission", "text_ui_button"],
		"content_ids": ["commission.watch_buckle_repair"],
	},
	{
		"id": "prologue.chest_discovery",
		"phase": "prologue_day",
		"channels": ["text_dialogue"],
		"content_ids": ["dialogue.makers_mark.chest_discovery"],
	},
	{
		"id": "prologue.ledger_choice",
		"phase": "prologue_day",
		"channels": ["text_dialogue", "text_ui_button"],
		"content_ids": ["dialogue.makers_mark.ledger_choice"],
	},
	{
		"id": "investigation.cistern",
		"phase": "investigation_morning",
		"channels": ["text_prompt", "text_dialogue"],
		"content_ids": ["dialogue.bitter_brew.inspect_cistern"],
	},
	{
		"id": "investigation.brewery",
		"phase": "investigation_morning",
		"channels": ["text_prompt", "text_dialogue"],
		"content_ids": ["dialogue.bitter_brew.inspect_brewery"],
	},
	{
		"id": "investigation.supply",
		"phase": "investigation_morning",
		"channels": ["text_prompt", "text_dialogue"],
		"content_ids": ["dialogue.bitter_brew.inspect_supply"],
	},
	{
		"id": "investigation.checkpoint",
		"phase": "investigation_morning",
		"channels": ["text_prompt", "text_dialogue"],
		"content_ids": ["dialogue.bitter_brew.inspect_checkpoint"],
	},
	{
		"id": "investigation.quest_journal",
		"phase": "investigation_morning",
		"channels": ["text_journal", "mechanic_gate"],
		"content_ids": ["quest.bitter_brew"],
	},
	{
		"id": "forge.bitter_brew_commission",
		"phase": "investigation_morning",
		"channels": ["text_commission", "text_ui_button"],
		"content_ids": ["commission.bitter_brew"],
	},
	{
		"id": "forge.bitter_brew_honest",
		"phase": "investigation_morning",
		"channels": ["text_ui_button", "mechanic_gate"],
		"content_ids": ["commission.bitter_brew"],
	},
	{
		"id": "forge.bitter_brew_subtle",
		"phase": "investigation_morning",
		"channels": ["text_ui_button", "mechanic_gate"],
		"content_ids": ["commission.bitter_brew"],
	},
	{
		"id": "forge.bitter_brew_secret",
		"phase": "investigation_morning",
		"channels": ["text_ui_button", "mechanic_gate"],
		"content_ids": ["commission.bitter_brew"],
	},
	{
		"id": "night.checkpoint_prompt",
		"phase": "investigation_night",
		"channels": ["text_prompt", "text_ui_button"],
		"content_ids": ["encounter.watch_checkpoint"],
	},
	{
		"id": "night.route_surrender",
		"phase": "investigation_night",
		"channels": ["text_ui_button", "text_tooltip"],
		"content_ids": ["encounter.watch_checkpoint"],
	},
	{
		"id": "night.route_bypass",
		"phase": "investigation_night",
		"channels": ["text_ui_button", "text_tooltip", "mechanic_gate"],
		"content_ids": ["encounter.watch_checkpoint"],
	},
	{
		"id": "night.route_escape",
		"phase": "investigation_night",
		"channels": ["text_ui_button", "text_tooltip", "mechanic_gate"],
		"content_ids": ["encounter.watch_checkpoint"],
	},
	{
		"id": "aftermath.brewery_world_state",
		"phase": "consequence_night",
		"channels": ["spatial_world_state", "text_prompt"],
		"content_ids": ["mechanism.bitter_brew_crisis"],
	},
	{
		"id": "aftermath.mart_reaction",
		"phase": "consequence_night",
		"channels": ["text_dialogue"],
		"content_ids": [
			"dialogue.bitter_brew.mart_exonerated",
			"dialogue.bitter_brew.mart_escaped",
			"dialogue.bitter_brew.mart_monopolized",
		],
	},
	{
		"id": "aftermath.watch_barks",
		"phase": "consequence_night",
		"channels": ["text_dialogue"],
		"content_ids": ["bark.bitter_brew.aftermath_watch"],
	},
	{
		"id": "reflection.recap",
		"phase": "reflection_morning",
		"channels": ["text_plain_summary", "text_dialogue"],
		"content_ids": ["slicephase.reflection_morning"],
	},
	{
		"id": "reflection.conviction",
		"phase": "reflection_morning",
		"channels": ["text_ui_button", "mechanic_gate"],
		"content_ids": ["slicephase.reflection_morning"],
	},
	{
		"id": "combat.enemy_silhouettes",
		"phase": "investigation_night",
		"channels": ["shape_silhouette"],
		"content_ids": ["encounter.watch_checkpoint"],
	},
]

## Terms that could read as off-game Baltic history unless the slice explains them
## in authored dialogue, commission text, or journal summaries first.
const HISTORICAL_CONCEPTS: Array[Dictionary] = [
	{
		"id": "concept.tainted_municipal_water",
		"term": "municipal water line",
		"context_beat_id": "investigation.brewery",
		"content_id": "dialogue.bitter_brew.inspect_brewery",
	},
	{
		"id": "concept.watch_ward",
		"term": "watch ward",
		"context_beat_id": "forge.bitter_brew_commission",
		"content_id": "commission.bitter_brew",
	},
	{
		"id": "concept.watch_checkpoint",
		"term": "watch checkpoint",
		"context_beat_id": "night.checkpoint_prompt",
		"content_id": "encounter.watch_checkpoint",
	},
	{
		"id": "concept.inspection_seal",
		"term": "inspection seal",
		"context_beat_id": "forge.bitter_brew_subtle",
		"content_id": "commission.bitter_brew",
	},
	{
		"id": "concept.detention_cart",
		"term": "detention cart",
		"context_beat_id": "forge.bitter_brew_secret",
		"content_id": "commission.bitter_brew",
	},
	{
		"id": "concept.cistern_neglect",
		"term": "cistern neglect",
		"context_beat_id": "investigation.checkpoint",
		"content_id": "dialogue.bitter_brew.inspect_checkpoint",
	},
]


static func beat_ids() -> Array[String]:
	var ids: Array[String] = []
	for beat: Dictionary in INFORMATION_BEATS:
		ids.append(String(beat["id"]))
	return ids


static func beat_count() -> int:
	return INFORMATION_BEATS.size()


static func historical_concept_count() -> int:
	return HISTORICAL_CONCEPTS.size()


static func beat_for_id(beat_id: String) -> Dictionary:
	for beat: Dictionary in INFORMATION_BEATS:
		if String(beat["id"]) == beat_id:
			return beat
	return {}


static func _channels_are_valid(channels: Array) -> bool:
	for channel in channels:
		if not VALID_CHANNELS.has(String(channel)):
			return false
	return true


static func _has_non_color_non_audio_channel(channels: Array) -> bool:
	for channel in channels:
		var channel_id := String(channel)
		if channel_id != COLOR_ONLY_CHANNEL and channel_id != AUDIO_ONLY_CHANNEL:
			return true
	return false


static func validate_beats() -> Dictionary:
	var errors: Array[String] = []
	for beat: Dictionary in INFORMATION_BEATS:
		var beat_id := String(beat["id"])
		var channels: Array = beat.get("channels", [])
		if channels.is_empty():
			errors.append("%s: missing channels" % beat_id)
			continue
		if not _channels_are_valid(channels):
			errors.append("%s: invalid channel id in %s" % [beat_id, str(channels)])
		if not _has_non_color_non_audio_channel(channels):
			errors.append("%s: relies on color or audio only" % beat_id)
		if COLOR_ONLY_CHANNEL in channels and channels.size() == 1:
			errors.append("%s: color_tint is the only channel" % beat_id)
		if AUDIO_ONLY_CHANNEL in channels and channels.size() == 1:
			errors.append("%s: audio_cue is the only channel" % beat_id)
	return {
		"beat_count": beat_count(),
		"errors": errors,
		"all_beats_valid": errors.is_empty(),
	}


static func validate_historical_concepts() -> Dictionary:
	var errors: Array[String] = []
	var beat_lookup: Dictionary = {}
	for beat: Dictionary in INFORMATION_BEATS:
		beat_lookup[String(beat["id"])] = beat

	for concept: Dictionary in HISTORICAL_CONCEPTS:
		var concept_id := String(concept["id"])
		var context_beat_id := String(concept.get("context_beat_id", ""))
		if context_beat_id.is_empty():
			errors.append("%s: missing context_beat_id" % concept_id)
			continue
		if not beat_lookup.has(context_beat_id):
			errors.append(
				"%s: context beat %s is not catalogued" % [concept_id, context_beat_id]
			)
	return {
		"concept_count": historical_concept_count(),
		"errors": errors,
		"all_concepts_valid": errors.is_empty(),
	}


static func build_report() -> Dictionary:
	var beat_validation := validate_beats()
	var concept_validation := validate_historical_concepts()
	var errors: Array[String] = []
	errors.append_array(beat_validation["errors"])
	errors.append_array(concept_validation["errors"])
	return {
		"beat_count": beat_count(),
		"historical_concept_count": historical_concept_count(),
		"errors": errors,
		"all_beats_valid": beat_validation["all_beats_valid"],
		"all_concepts_valid": concept_validation["all_concepts_valid"],
		"valid": errors.is_empty(),
	}
