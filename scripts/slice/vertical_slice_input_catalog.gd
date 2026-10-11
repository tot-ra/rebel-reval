class_name VerticalSliceInputCatalog
extends RefCounted

## Required player-facing input actions for the vertical slice (P2-017).
## WHY: one catalog keeps keyboard/mouse and gamepad completion tests aligned
## with `InputBindingSettings` and documents every action the slice must support.

const BindingSettings := preload("res://scripts/settings/input_binding_settings.gd")

const FLOW_STEP_PROLOGUE := &"flow.prologue"
const FLOW_STEP_INVESTIGATION := &"flow.investigation"
const FLOW_STEP_COMMISSION := &"flow.commission"
const FLOW_STEP_NIGHT_ENCOUNTER := &"flow.night_encounter"
const FLOW_STEP_REFLECTION := &"flow.reflection"
const FLOW_STEP_OVERLAY_TOGGLES := &"flow.overlay_toggles"

const FLOW_STEPS: Array[StringName] = [
	FLOW_STEP_PROLOGUE,
	FLOW_STEP_INVESTIGATION,
	FLOW_STEP_COMMISSION,
	FLOW_STEP_NIGHT_ENCOUNTER,
	FLOW_STEP_REFLECTION,
	FLOW_STEP_OVERLAY_TOGGLES,
]


static func action_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: Dictionary in BindingSettings.action_definitions():
		ids.append(definition["id"] as StringName)
	return ids


static func overlay_toggle_actions() -> Array[StringName]:
	return [
		&"toggle_inventory",
		&"toggle_journal",
		&"toggle_world_map",
		&"toggle_camera_view",
		&"toggle_minimap",
		&"toggle_controls",
	]
