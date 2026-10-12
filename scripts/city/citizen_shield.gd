class_name CitizenShield
extends RefCounted

## Heater shields of armed census residents (docs/SYSTEMS/CITIZEN_WARDROBE.md, WD-4).
## Built in code (a flat lime-wood board with a painted face), so no art file is needed and a
## shield is a plain prop on the left hand slot, not a skinned layer. Kinds come from the
## wardrobe rules (`shield` in content/world/reval_city/citizens.json):
##   order - white field with the Order's black cross
##   crown - plain red (the Danish crown's colour, no invented heraldry)
##   field - the knight's own surcoat colour, plain
##   plain - bare wood with an iron boss
## Dimensions follow a heater shield of the 1340s: about 0.46 m wide, 0.62 m tall.

const HALF_WIDTH := 0.23
const TOP := 0.30
const THICKNESS := 0.018
const WOOD := Color(0.42, 0.31, 0.19)
const IRON := Color(0.36, 0.36, 0.37)
const CROWN_RED := Color(0.58, 0.11, 0.09)
const ORDER_WHITE := Color(0.86, 0.85, 0.80)
const ORDER_BLACK := Color(0.07, 0.07, 0.07)
## Heater outline, clockwise from the top left (x, y); the point is at the bottom.
const OUTLINE: Array[Vector2] = [
	Vector2(-0.23, 0.30), Vector2(0.23, 0.30), Vector2(0.23, 0.06), Vector2(0.21, -0.06),
	Vector2(0.16, -0.18), Vector2(0.09, -0.27), Vector2(0.0, -0.32), Vector2(-0.09, -0.27),
	Vector2(-0.16, -0.18), Vector2(-0.21, -0.06), Vector2(-0.23, 0.06),
]

static var _cache: Dictionary = {}


## PackedScene of one shield; `field` is only read for kind "field".
static func scene(kind: String, field: Color = Color(0.4, 0.4, 0.4)) -> PackedScene:
	var key := "%s:%s" % [kind, field.to_html(false) if kind == "field" else ""]
	if not _cache.has(key):
		var root := Node3D.new()
		root.name = "Shield_" + kind
		var colour := _field_colour(kind, field)
		root.add_child(_board(colour))
		if kind == "order":
			for size: Vector2 in [Vector2(0.07, 0.50), Vector2(0.38, 0.07)]:
				var at := Vector3(0.0, 0.03, THICKNESS * 0.5 + 0.0025)
				root.add_child(_bar(size, ORDER_BLACK, at))
		else:
			root.add_child(_boss())
		for child: Node in root.get_children():
			child.owner = root
		var packed := PackedScene.new()
		packed.pack(root)
		root.free()
		_cache[key] = packed
	return _cache[key]


static func _field_colour(kind: String, field: Color) -> Color:
	match kind:
		"order":
			return ORDER_WHITE
		"crown":
			return CROWN_RED
		"field":
			return field
	return WOOD


static func _material(
	colour: Color, metallic: float = 0.0, roughness: float = 0.85
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = roughness
	return material


## Front (face colour) and back plus rim (wood) as two surfaces of one mesh.
static func _board(face: Color) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var half := THICKNESS * 0.5
	var front := SurfaceTool.new()
	front.begin(Mesh.PRIMITIVE_TRIANGLES)
	front.set_material(_material(face))
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_material(_material(WOOD))
	var centre := Vector3(0.0, 0.0, half)
	for i in OUTLINE.size():
		var a := OUTLINE[i]
		var b := OUTLINE[(i + 1) % OUTLINE.size()]
		# Fan from the centre, counter-clockwise seen from +Z: the outline runs clockwise.
		_tri(front, Vector3(0, 0, 1), centre, Vector3(b.x, b.y, half), Vector3(a.x, a.y, half))
		var back_a := Vector3(a.x, a.y, -half)
		var back_b := Vector3(b.x, b.y, -half)
		_tri(wood, Vector3(0, 0, -1), Vector3(0, 0, -half), back_a, back_b)
		var side := Vector3(b.y - a.y, a.x - b.x, 0.0).normalized()
		var a0 := Vector3(a.x, a.y, half)
		var a1 := Vector3(a.x, a.y, -half)
		var b0 := Vector3(b.x, b.y, half)
		var b1 := Vector3(b.x, b.y, -half)
		_tri(wood, side, a0, a1, b1)
		_tri(wood, side, a0, b1, b0)
	front.commit(mesh)
	wood.commit(mesh)
	var instance := MeshInstance3D.new()
	instance.name = "Board"
	instance.mesh = mesh
	return instance


static func _tri(tool: SurfaceTool, normal: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p: Vector3 in [a, b, c]:
		tool.set_normal(normal)
		tool.add_vertex(p)


static func _bar(size: Vector2, colour: Color, at: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, 0.005)
	box.material = _material(colour)
	var instance := MeshInstance3D.new()
	instance.name = "Cross"
	instance.mesh = box
	instance.position = at
	return instance


static func _boss() -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.045
	sphere.material = _material(IRON, 0.8, 0.4)
	var instance := MeshInstance3D.new()
	instance.name = "Boss"
	instance.mesh = sphere
	instance.position = Vector3(0.0, 0.05, THICKNESS * 0.5)
	return instance
