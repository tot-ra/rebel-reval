class_name CityBridges
extends RefCounted

## Timber bridges where the extramural roads cross the Hareapea, and the short
## harbour jetties and beach decks (plan `bridges`, `rails: false` for decks).
## No 1343 bridge is attested; a plank deck on pile trestles is a reversible
## reconstruction (docs/SYSTEMS/FARMLAND.md, Bridges). Kalev walks the deck
## through CityPlan.bridge_deck_height; the water under it is not swimmable there.

const TRESTLE_STEP := 4.0
const DECK_THICKNESS := 0.22
const RAIL_HEIGHT := 1.0


static func build(plan: CityPlan, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Bridges"
	parent.add_child(root)
	var wood := MapViewMaterials.role(&"wood")
	var timber := MapViewMaterials.role(&"timber")
	for b: Dictionary in plan.data.get("bridges", []):
		root.add_child(_bridge(plan, b, wood, timber))
	return root


static func _bridge(plan: CityPlan, b: Dictionary, wood: Material, timber: Material) -> Node3D:
	var node := Node3D.new()
	node.name = String(b["id"]).replace(".", "_")
	var at := Vector2(b["at"][0], b["at"][1])
	var angle := float(b["angle"])
	var length := float(b["length"])
	var width := float(b["width"])
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	var yaw := -angle
	var steps := maxi(int(ceil(length / 2.0)), 2)
	# Deck: short plank boxes following the ramp.
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var p0 := at + along * (t0 - 0.5) * length
		var p1 := at + along * (t1 - 0.5) * length
		var y0 := CityPlan.bridge_deck_at(b, t0)
		var y1 := CityPlan.bridge_deck_at(b, t1)
		var mid := (p0 + p1) * 0.5
		var seg := p0.distance_to(p1)
		var plank := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(seg + 0.05, DECK_THICKNESS, width)
		plank.mesh = box
		plank.material_override = wood
		plank.position = Vector3(mid.x, (y0 + y1) * 0.5 - DECK_THICKNESS * 0.5, mid.y)
		plank.rotation = Vector3(0.0, yaw, atan2(y1 - y0, seg))
		node.add_child(plank)
	# Rails and trestles on both sides.
	var railed: bool = b.get("rails", true)
	for side: float in [-1.0, 1.0]:
		var offset := across * side * (width * 0.5 - 0.1)
		for i in steps if railed else 0:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var p0 := at + along * (t0 - 0.5) * length + offset
			var p1 := at + along * (t1 - 0.5) * length + offset
			var y0 := CityPlan.bridge_deck_at(b, t0) + RAIL_HEIGHT * 0.8
			var y1 := CityPlan.bridge_deck_at(b, t1) + RAIL_HEIGHT * 0.8
			var rail := MeshInstance3D.new()
			var rbox := BoxMesh.new()
			var seg := p0.distance_to(p1)
			rbox.size = Vector3(seg + 0.05, 0.1, 0.1)
			rail.mesh = rbox
			rail.material_override = wood
			var mid := (p0 + p1) * 0.5
			rail.position = Vector3(mid.x, (y0 + y1) * 0.5, mid.y)
			rail.rotation = Vector3(0.0, yaw, atan2(y1 - y0, seg))
			node.add_child(rail)
		var posts := maxi(int(length / TRESTLE_STEP), 1) + 1
		for k in posts:
			var t := float(k) / maxf(posts - 1, 1)
			var p := at + along * (t - 0.5) * length + offset
			var deck := CityPlan.bridge_deck_at(b, t)
			var bed := plan.ground_height(p) - 0.4
			var post_top := deck + (RAIL_HEIGHT if railed else 0.35)
			var post := MeshInstance3D.new()
			var pbox := BoxMesh.new()
			# Post runs from the river bed (or bank) up to the handrail.
			pbox.size = Vector3(0.28, post_top - bed, 0.28)
			post.mesh = pbox
			post.material_override = timber
			post.position = Vector3(p.x, (post_top + bed) * 0.5, p.y)
			node.add_child(post)
	return node
