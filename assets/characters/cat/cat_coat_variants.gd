class_name CatCoatVariants
extends RefCounted

## Coat and size variation for the shared storybook forge-cat model.
##
## Town cats reuse Kalev's mesh and rig; coats are tinted in
## `assets/storybook/storybook_cat.gd` via `apply_coat()`. This helper only
## centralises the coat IDs and deterministic size jitter.

const COAT_FORGE := &"forge"

## Historically plausible unimproved medieval European coats: mackerel tabby is
## the common wild type, with self-black, red and bicolour beside it.
const TOWN_COATS: Array[StringName] = [
	&"tabby_brown",
	&"tabby_grey",
	&"black",
	&"ginger",
	&"white_black",
]

const SCALE_RANGE := Vector2(0.90, 1.10)


static func coat_for_seed(variant_seed: int) -> StringName:
	return TOWN_COATS[absi(variant_seed) % TOWN_COATS.size()]


static func scale_for_seed(variant_seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed
	return rng.randf_range(SCALE_RANGE.x, SCALE_RANGE.y)


## Legacy entry point for debug tooling; runtime cats use `apply_coat()` on the rig.
static func apply(model: Node3D, variant_seed: int) -> StringName:
	if model != null and model.has_method("apply_coat"):
		return model.apply_coat(variant_seed)
	return coat_for_seed(variant_seed)
