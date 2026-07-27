class_name MapViewMedievalAnimalModels
extends RefCounted

## Shared access to approved game-ready livestock GLBs. The same assets are used
## by authored map props and visual-only ambient actors so animal quality cannot
## drift between static and moving placements.

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")

# Runtime loading avoids a clean-clone parse cycle before Godot has imported the
# new GLBs for the first time.
const MODEL_PATHS: Dictionary = {
	MammalSpecies.SPECIES_COW: "res://assets/animals/medieval/medieval_cattle.glb",
	MammalSpecies.SPECIES_SHEEP: "res://assets/animals/medieval/medieval_sheep.glb",
	MammalSpecies.SPECIES_HORSE: "res://assets/animals/medieval/medieval_pack_horse.glb",
}


static func has_model(species: StringName) -> bool:
	return MODEL_PATHS.has(species)


static func add_model(parent: Node3D, species: StringName) -> Node3D:
	var path := String(MODEL_PATHS.get(species, ""))
	if path.is_empty():
		return null
	var scene := load(path) as PackedScene
	assert(scene != null, "Medieval animal GLB must be imported before map assembly: %s" % path)
	var model := scene.instantiate() as Node3D
	assert(model != null, "Medieval animal GLB root must be Node3D: %s" % path)
	model.name = "Model"
	model.set_meta(&"production_animal_model", true)
	model.set_meta(&"species", species)
	parent.add_child(model)
	return model
