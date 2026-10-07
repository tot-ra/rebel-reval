class_name CitySiteProps
extends RefCounted

## Prop catalogue for landmark site dressing (ADR 0032). Each `kind` maps to an
## existing authored model of the game (market stall GLB with its goods
## modules, wooden cart, trade-goods clusters) or a small procedural piece
## (pillory). The district props were authored in 0.87 m world units, so they
## are mounted under a node scaled to metres.

const LEGACY_UNIT_M := 0.87
const KINDS: Array[StringName] = [&"market_stall", &"cart", &"trade_goods", &"pillory"]


## Adds the model for one manifest dressing item under `parent` (site-local
## metres, y = 0 at the site level); `ground_y` is the item's ground height
## relative to that level. Returns the node, or null for an unknown kind.
static func add(parent: Node3D, item: Dictionary, ground_y: float) -> Node3D:
	var node := Node3D.new()
	node.name = String(item["id"]).replace(".", "_")
	node.position = Vector3(item["at"][0], ground_y, item["at"][1])
	node.rotation.y = -deg_to_rad(float(item.get("rotation_deg", 0.0)))
	var legacy := Node3D.new()
	legacy.scale = Vector3.ONE * LEGACY_UNIT_M
	node.add_child(legacy)
	match StringName(item["kind"]):
		&"market_stall":
			MapViewMarketStallModels.add_model(
				legacy, {"display_goods": String(item.get("goods", "none"))}
			)
		&"cart":
			MapViewCartModels.add_model(legacy)
		&"trade_goods":
			MapViewTradeGoodsModels.add_model(legacy, StringName(item.get("variant", item["id"])))
		&"pillory":
			_pillory(node)
		_:
			push_error("CitySiteProps: unknown dressing kind %s" % item["kind"])
			node.free()
			return null
	parent.add_child(node)
	return node


## Free-standing timber pillory (Schandpfahl): a squared oak post on a stone
## footing, a crossbar and a hinged two-board neck yoke at head height.
static func _pillory(node: Node3D) -> void:
	var shell := CityBuildingBuilder.Shell.new()
	var oak := Color(0.62, 0.55, 0.47)
	var iron := Color(0.2, 0.19, 0.18)
	_box(
		shell,
		"stone",
		Vector3(-0.45, -0.3, -0.45),
		Vector3(0.45, 0.18, 0.45),
		Color(0.85, 0.83, 0.8)
	)
	_box(shell, "timber", Vector3(-0.12, 0.18, -0.12), Vector3(0.12, 2.9, 0.12), oak)
	_box(shell, "timber", Vector3(-0.55, 2.55, -0.08), Vector3(0.55, 2.68, 0.08), oak * 0.9)
	_box(shell, "timber", Vector3(-0.42, 1.48, -0.16), Vector3(0.42, 1.62, -0.1), oak)
	_box(shell, "timber", Vector3(-0.42, 1.64, -0.16), Vector3(0.42, 1.78, -0.1), oak * 0.95)
	_box(shell, "dark", Vector3(-0.07, 1.6, -0.17), Vector3(0.07, 1.66, -0.15), iron)
	_box(shell, "dark", Vector3(-0.03, 1.2, 0.12), Vector3(0.03, 2.3, 0.14), iron)
	var mesh := MeshInstance3D.new()
	mesh.name = "Pillory"
	mesh.mesh = shell.to_mesh(CityBuildingBuilder.material_for_key)
	node.add_child(mesh)


static func _box(
	shell: CityBuildingBuilder.Shell, key: String, lo: Vector3, hi: Vector3, color: Color
) -> void:
	var c := (lo + hi) * 0.5
	var p := [
		Vector3(lo.x, lo.y, lo.z),
		Vector3(hi.x, lo.y, lo.z),
		Vector3(hi.x, hi.y, lo.z),
		Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z),
		Vector3(hi.x, lo.y, hi.z),
		Vector3(hi.x, hi.y, hi.z),
		Vector3(lo.x, hi.y, hi.z),
	]
	for f: Array in [
		[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]
	]:
		var a: Vector3 = p[f[0]]
		var b: Vector3 = p[f[1]]
		var cc: Vector3 = p[f[2]]
		var d: Vector3 = p[f[3]]
		shell.quad_out(key, a, b, cc, d, color, (a + b + cc + d) * 0.25 - c)
