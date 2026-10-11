extends "res://scenes/world/sites/site_level.gd"

## Padise (docs/SYSTEMS/REGIONAL_SITES.md): the regional site level plus the
## monastery's phase hook. PadiseMonasteryController places the choir and lay
## monks on the plan's anchor points of interest before the St George's Night
## attack, clears them after it, and owns the soundscape, so the site's zone
## music is left to it.
##
## Start directly:
##   godot --path . res://scenes/world/sites/padise.tscn -- --city-spawn=from_reval_west

const MonasteryController := preload("res://scripts/world/padise_monastery_controller.gd")

var monastery: PadiseMonasteryController


func _ready() -> void:
	super()
	monastery = MonasteryController.new()
	monastery.name = "PadiseMonastery"
	add_child(monastery)
	monastery.configure(MonasteryController.definition_from_plan(plan), actors, player)


## The controller sets the phase theme; the site music must not clear it.
func _update_music(_xz: Vector2) -> void:
	pass
