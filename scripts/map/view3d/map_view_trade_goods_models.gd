class_name MapViewTradeGoodsModels
extends RefCounted

## Historically grounded Spring 1343 Reval cargo clusters. The authored rrmap
## footprint remains the sole collision/navigation authority; these GLBs only
## replace the generic sack-and-box silhouette in the 3D presentation.

const VARIANT_EASTERN_FURS_WAX := &"eastern_furs_wax"
const VARIANT_WESTERN_CLOTH_SALT := &"western_cloth_salt"
const VARIANT_LIVONIAN_GRAIN_FLAX := &"livonian_grain_flax"
const VARIANT_BARRELLED_HERRING_METAL := &"barrelled_herring_metal"

const MODEL_PATHS: Dictionary = {
	VARIANT_EASTERN_FURS_WAX: "res://assets/props/trade/eastern_furs_wax.glb",
	VARIANT_WESTERN_CLOTH_SALT: "res://assets/props/trade/western_cloth_salt.glb",
	VARIANT_LIVONIAN_GRAIN_FLAX: "res://assets/props/trade/livonian_grain_flax.glb",
	VARIANT_BARRELLED_HERRING_METAL: "res://assets/props/trade/barrelled_herring_metal.glb",
}
const VARIANT_ORDER: Array[StringName] = [
	VARIANT_EASTERN_FURS_WAX,
	VARIANT_WESTERN_CLOTH_SALT,
	VARIANT_LIVONIAN_GRAIN_FLAX,
	VARIANT_BARRELLED_HERRING_METAL,
]

# Existing stable map IDs deliberately tell four different parts of the trade
# corridor. Unknown future IDs still resolve deterministically instead of
# collapsing back to one repeated cluster.
const VARIANT_BY_PROP_ID: Dictionary = {
	&"cargo_shed_west_goods": VARIANT_EASTERN_FURS_WAX,
	&"warehouse_mid_goods": VARIANT_WESTERN_CLOTH_SALT,
	&"tally_ground_goods": VARIANT_BARRELLED_HERRING_METAL,
	&"market_goods": VARIANT_LIVONIAN_GRAIN_FLAX,
}


static func variant_for(prop_id: StringName) -> StringName:
	if VARIANT_BY_PROP_ID.has(prop_id):
		return VARIANT_BY_PROP_ID[prop_id]
	return VARIANT_ORDER[posmod(int(String(prop_id).hash()), VARIANT_ORDER.size())]


static func add_model(parent: Node3D, prop_id: StringName) -> Node3D:
	var variant := variant_for(prop_id)
	var scene := load(String(MODEL_PATHS[variant])) as PackedScene
	assert(scene != null, "Hanseatic trade-goods GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Hanseatic trade-goods GLB root must be Node3D")
	model.name = "TradeGoodsModel"
	model.set_meta(&"production_trade_goods_model", true)
	model.set_meta(&"cargo_variant", variant)
	parent.add_child(model)
	return model
