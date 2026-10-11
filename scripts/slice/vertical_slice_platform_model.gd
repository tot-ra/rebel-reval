class_name VerticalSlicePlatformModel
extends RefCounted

## Authored supported-platform contract for the vertical-slice release (P3-012).
## WHY: slice validation needs one matrix that export presets, packaged smoke,
## and the Python report tool can reference without duplicating platform claims.

const MANIFEST_PATH := "res://docs/data/slice_platform_manifest.json"
const EXPORT_PRESET_NAME := "rr"
const EXPORT_PRESET_PLATFORM := "macOS"
const EXPORT_ARCHITECTURE := "universal"
const PACKAGED_SMOKE_USER_ARGUMENT := "--verify-packaged-platform"
const PACKAGED_SMOKE_SCRIPT := "res://scripts/demo/packaged_platform_smoke.gd"
const VERIFY_SCRIPT_PATH := "tools/verify_supported_platform.sh"
const MAINTAINER_REPORT_PATH := "res://docs/reports/p3_012_supported_platforms.md"

const SUPPORTED_PLATFORMS: Array[Dictionary] = [
	{
		"id": "macos_universal",
		"os": "macOS",
		"architecture": "universal",
		"minimum_os": "macOS 11.0 (Apple Silicon) / macOS 10.12 (Intel)",
		"artifact": "build/rr.dmg",
		"export_preset": "rr",
		"smoke_steps": ["install", "start", "save", "load", "exit"],
	}
]

const UNSUPPORTED_DECLARATIONS: Array[Dictionary] = [
	{
		"id": "windows",
		"reason": "No export preset or packaged smoke harness yet",
	},
	{
		"id": "linux",
		"reason": "No export preset or packaged smoke harness yet",
	},
]


static func load_manifest() -> Dictionary:
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func supported_platform_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in SUPPORTED_PLATFORMS:
		ids.append(String(entry.get("id", "")))
	return ids


static func manifest_matches_model() -> bool:
	var manifest := load_manifest()
	if manifest.is_empty():
		return false
	if String(manifest.get("export_preset_name", "")) != EXPORT_PRESET_NAME:
		return false
	if String(manifest.get("export_preset_platform", "")) != EXPORT_PRESET_PLATFORM:
		return false
	if String(manifest.get("export_architecture", "")) != EXPORT_ARCHITECTURE:
		return false
	if String(manifest.get("packaged_smoke_user_argument", "")) != PACKAGED_SMOKE_USER_ARGUMENT:
		return false
	if (
		String(manifest.get("packaged_smoke_script", ""))
		!= PACKAGED_SMOKE_SCRIPT.trim_prefix("res://")
	):
		return false
	if String(manifest.get("verify_script", "")) != VERIFY_SCRIPT_PATH:
		return false
	if int(manifest.get("supported_platform_count", 0)) != SUPPORTED_PLATFORMS.size():
		return false
	var manifest_platforms: Variant = manifest.get("supported_platforms", [])
	if not manifest_platforms is Array:
		return false
	if (manifest_platforms as Array).size() != SUPPORTED_PLATFORMS.size():
		return false
	return true


static func export_preset_contract_paths() -> PackedStringArray:
	return PackedStringArray(
		[
			"res://export_presets.cfg",
			"res://.godot-version",
		]
	)
