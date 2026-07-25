extends "res://tests/godot/test_case.gd"

## P3-012: supported-platform contract must stay aligned across the Godot model,
## export preset, and Python manifest.

const PlatformModel := preload("res://scripts/slice/vertical_slice_platform_model.gd")


func test_manifest_matches_platform_model() -> void:
	assert_true(
		PlatformModel.manifest_matches_model(),
		"vertical_slice_platform_model.gd must match slice_platform_manifest.json"
	)


func test_supported_platform_declares_macos_universal_only() -> void:
	assert_eq(PlatformModel.SUPPORTED_PLATFORMS.size(), 1)
	var platform: Dictionary = PlatformModel.SUPPORTED_PLATFORMS[0]
	assert_eq(String(platform.get("id", "")), "macos_universal")
	assert_eq(String(platform.get("os", "")), "macOS")
	assert_eq(String(platform.get("architecture", "")), "universal")
	assert_eq(String(platform.get("export_preset", "")), PlatformModel.EXPORT_PRESET_NAME)


func test_export_preset_contract_files_exist() -> void:
	for path in PlatformModel.export_preset_contract_paths():
		var filesystem_path := ProjectSettings.globalize_path(path)
		assert_true(FileAccess.file_exists(filesystem_path), "missing export contract file: %s" % path)


func test_maintainer_report_exists() -> void:
	var filesystem_path := ProjectSettings.globalize_path(PlatformModel.MAINTAINER_REPORT_PATH)
	assert_true(FileAccess.file_exists(filesystem_path))
