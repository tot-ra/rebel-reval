class_name WorldItemPickupLabels
extends RefCounted

## User-facing pickup capacity messages shared by tooltips and interactable prompts.


static func label_for(result: InventoryBag.AddResult) -> String:
	match result:
		InventoryBag.AddResult.OK:
			return "Pick up"
		InventoryBag.AddResult.NO_SPACE:
			return "Bag is full"
		InventoryBag.AddResult.OVER_WEIGHT:
			return "Too heavy to carry"
		InventoryBag.AddResult.STACK_FULL:
			return "Stack is full"
		_:
			return "Cannot pick up"
