class_name ForgeCommissionPresenter
extends RefCounted

## Presenter contract for ForgeCommissionRunner.


func present_commission(snapshot: Dictionary) -> void:
	pass


func begin_forging(option_id: String, snapshot: Dictionary, on_complete: Callable) -> void:
	if on_complete.is_valid():
		on_complete.call()


func close() -> void:
	pass
