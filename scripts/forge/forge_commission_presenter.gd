class_name ForgeCommissionPresenter
extends RefCounted

## Presenter contract for ForgeCommissionRunner.


func present_commission(_snapshot: Dictionary) -> void:
	pass


func begin_forging(_option_id: String, _snapshot: Dictionary, on_complete: Callable) -> void:
	if on_complete.is_valid():
		on_complete.call()


func close() -> void:
	pass
