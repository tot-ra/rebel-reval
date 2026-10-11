extends "res://tests/godot/test_case.gd"


func test_layered_world_item_grab_overrides_interactable_talk() -> void:
	CursorService.clear_layer(CursorService.LAYER_INTERACTABLE)
	CursorService.clear_layer(CursorService.LAYER_WORLD_ITEM)

	CursorService.set_layer_cursor(CursorService.LAYER_INTERACTABLE, &"talk")
	assert_eq(CursorService.get_active_kind(), &"talk")

	CursorService.set_layer_cursor(CursorService.LAYER_WORLD_ITEM, &"grab")
	assert_eq(CursorService.get_active_kind(), &"grab")

	CursorService.clear_layer(CursorService.LAYER_WORLD_ITEM)
	assert_eq(CursorService.get_active_kind(), &"talk")

	CursorService.clear_layer(CursorService.LAYER_INTERACTABLE)
	assert_eq(CursorService.get_active_kind(), &"")


func test_clearing_layers_restores_default_cursor() -> void:
	CursorService.set_layer_cursor(CursorService.LAYER_INTERACTABLE, &"talk")
	CursorService.clear_layer(CursorService.LAYER_INTERACTABLE)
	assert_eq(CursorService.get_active_kind(), &"")
