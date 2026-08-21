extends "res://tests/godot/test_case.gd"

const GLB_PATH := "res://assets/props/architecture/houses/plot_dressing/plot_dressing.glb"
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")
const EXPECTED_COMPONENTS := [
	"CellarNeck",
	"WattleFence",
	"PlotWall",
	"YardGate",
	"Privy",
	"WellSweep",
	"ServantLeanTo",
	"FirewoodStack",
	"HoistBeam",
	"LoadingHatch",
]


func test_plot_dressing_parser_accepts_closed_prop_kinds() -> void:
	var source := """rrmap 1
map plot_dressing loc.plot_dressing 16 12 dirt
building merchant house 5 2 4 4 house_tier=merchant_stone
prop cellar cellar_neck 1 1
prop wall plot_wall 2 1
prop fence wattle_fence 3 1
prop gate yard_gate 4 1
prop privy privy 5 8
prop sweep well_sweep 7 8
prop lean servant_lean_to 9 8
prop hoist hoist_beam 5 2 house_tier=merchant_stone
prop hatch loading_hatch 5 3 house_tier=merchant_timber
spawn spawn.main 1 1
"""
	var parsed := MapRrmapParser.parse(source, "res://plot_dressing.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.definition.props.size(), 9)
	var props_by_id := {}
	for prop in parsed.definition.props:
		props_by_id[prop["id"]] = prop
	assert_eq(props_by_id[&"hatch"].get("house_tier"), PropStyleVariants.HOUSE_TIER_MERCHANT_TIMBER)


func test_plot_dressing_rejects_merchant_hardware_on_craft_boda() -> void:
	var source := """rrmap 1
map plot_dressing loc.plot_dressing 12 10 dirt
building boda house 5 2 3 3 house_tier=craft_boda
prop hoist hoist_beam 5 2 house_tier=craft_boda
spawn spawn.main 1 1
"""
	var rejected := MapRrmapParser.parse(source, "res://invalid_plot_dressing.rrmap")
	assert_false(rejected.is_ok(), "craft_boda must reject merchant hoist hardware")
	assert_true(str(rejected.formatted_diagnostics()).contains("requires merchant_stone or merchant_timber"))


func test_plot_dressing_kit_contains_all_components() -> void:
	var scene := load(GLB_PATH) as PackedScene
	assert_true(scene != null, "plot dressing GLB must import as PackedScene")
	if scene == null:
		return
	var root := scene.instantiate() as Node3D
	assert_true(root != null)
	if root == null:
		return
	var kit := root.get_node_or_null("PlotDressingKit") as Node3D
	assert_true(kit != null, "plot dressing GLB must preserve its named component wrapper")
	if kit == null:
		root.free()
		return
	assert_eq(kit.get_child_count(), EXPECTED_COMPONENTS.size())
	for component in EXPECTED_COMPONENTS:
		assert_true(kit.has_node(component), "missing authored plot dressing component %s" % component)
	root.free()


func test_plot_dressing_props_build_named_models() -> void:
	for spec in [
		{"kind": MapTypes.PROP_KIND_CELLAR_NECK, "model": "CellarNeckModel"},
		{"kind": MapTypes.PROP_KIND_PLOT_WALL, "model": "PlotWallModel"},
		{"kind": MapTypes.PROP_KIND_WATTLE_FENCE, "model": "WattleFenceModel"},
		{"kind": MapTypes.PROP_KIND_YARD_GATE, "model": "YardGateModel"},
		{"kind": MapTypes.PROP_KIND_PRIVY, "model": "PrivyModel"},
		{"kind": MapTypes.PROP_KIND_WELL_SWEEP, "model": "WellSweepModel"},
		{"kind": MapTypes.PROP_KIND_SERVANT_LEAN_TO, "model": "ServantLeanToModel"},
		{"kind": MapTypes.PROP_KIND_HOIST_BEAM, "model": "HoistBeamModel"},
		{"kind": MapTypes.PROP_KIND_LOADING_HATCH, "model": "LoadingHatchModel"},
	]:
		var node := MapViewMeshBuilder.build_prop(
			{"id": spec["kind"], "kind": spec["kind"], "position": Vector2.ZERO, "house_tier": PropStyleVariants.HOUSE_TIER_MERCHANT_STONE},
			MapTypes.DEFAULT_CELL_SIZE
		)
		assert_true(node.has_node(spec["model"]), "missing model for %s" % String(spec["kind"]))
		node.free()
