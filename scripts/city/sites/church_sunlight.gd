class_name ChurchSunlight
extends RefCounted

## Sunlight through a church's stained glass (R-1451). Three parts:
## - the Upper walls, the upper Glass and the Roof (vaults included) cast
##   their shadows through always-present proxies, so the cutaway that hides
##   them while Kalev is inside no longer floods the nave with sun from above;
##   the glass blocks the white sun like a wall;
## - an overlay (city_window_sunlight.gdshader) on the interior meshes adds
##   the light each window lets through, in the colours of its panels;
## - a shaft mesh (city_window_shaft.gdshader) draws a faint dusty beam from
##   every window, pushed along the light in the vertex shader.
## All three follow the global `window_sun` (push_light), so the patches and
## beams move with the sun without rebuilding anything.

const SUNLIGHT := preload("res://scripts/city/city_window_sunlight.gdshader")
const SHAFT := preload("res://scripts/city/city_window_shaft.gdshader")
const PLATES := "res://assets/textures/churches/glass/glass_plates.png"
const MAX_WINDOWS := 32
const GLOBAL := &"window_sun"
## Glass plane inset from the outer face, as SiteKit._glass.
const INSET := 0.3
const SHADOW_SUFFIX := "Shadow"
## Glazing programmes, the same table as city_stained_glass.gdshaderinc.
const PROGRAMMES := [0, 2, 7, 1, 6, 7, 3, 1, 7, 0, 2, 7, 4, 1, 7, 0, 6, 7, 5, 1, 7, 2, 0, 7]

static var _plate_means: Array[Color] = []


## Sets the global light the church glass reacts to from the scene's sun:
## its direction towards the light and its direct strength (energy against
## the clear-day sun, times the shadow opacity overcast lowers).
static func push_light(sun: DirectionalLight3D) -> void:
	var basis := sun.global_basis if sun.is_inside_tree() else sun.basis
	var toward := basis.z.normalized()
	var direct := 0.0
	if sun.visible:
		direct = (
			clampf(sun.light_energy / MapViewLighting.SUN_DAY_ENERGY, 0.0, 1.0)
			* clampf(sun.shadow_opacity, 0.0, 1.0)
		)
	RenderingServer.global_shader_parameter_set(
		GLOBAL, Vector4(toward.x, toward.y, toward.z, direct)
	)


## Wires one church building: `lower`, `upper` and `roof` are its Kit.mesh
## nodes (Upper holds "Glass", Lower "GlassLow"), `fabric` the manifest walls.
static func apply(
	building: Node3D, lower: Node3D, upper: Node3D, roof: Node3D, fabric: Array, glazing: int
) -> void:
	var wins := windows(fabric, glazing)
	# The upper glass hides with the Upper walls, so it needs a proxy too:
	# without it the cutaway would let white sun through the empty holes.
	for node: Variant in [upper, roof, upper.get_node_or_null("Glass")]:
		var inst := node as MeshInstance3D
		if inst == null or inst.mesh == null:
			continue
		var proxy := MeshInstance3D.new()
		proxy.name = String(inst.name) + SHADOW_SUFFIX
		proxy.mesh = inst.mesh
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		building.add_child(proxy)
	if wins.is_empty():
		return
	var mat := sunlight_material(wins)
	for node: Node3D in [lower, upper]:
		_overlay(node, mat)
	# The site transform is set before the site enters the tree; read it then.
	building.ready.connect(
		func() -> void:
			mat.set_shader_parameter(
				"site_from_world", Projection(building.global_transform.affine_inverse())
			)
	)
	building.add_child(shafts(wins))


## Glazed windows of a fabric list in site-local space, in fabric order
## (first MAX_WINDOWS only). Mirrors SiteKit.wall / _glass placement and the
## vertex-colour quantisation of the glass, so the panels line up exactly.
static func windows(fabric: Array, glazing: int) -> Array[Dictionary]:
	var out_list: Array[Dictionary] = []
	for w: Dictionary in fabric:
		var a := Vector2(w["a"][0], w["a"][1])
		var b := Vector2(w["b"][0], w["b"][1])
		var inside := Vector2(w["inside"][0], w["inside"][1])
		var thick := float(w["thick"])
		var dir := (b - a).normalized()
		var out := Vector2(-dir.y, dir.x)
		if out.dot(inside - (a + b) * 0.5) > 0.0:
			out = -out
		for op: Dictionary in w.get("openings", []):
			var kind := String(op.get("kind", "window"))
			if kind == "niche" or kind == "recess" or not bool(op.get("glass", false)):
				continue
			if out_list.size() >= MAX_WINDOWS:
				return out_list
			var o := CitySiteKit._opening(op, false)
			var s0 := float(o["s"])
			var sill := float(o["sill"])
			var width := float(o["w"])
			var apex := float(o["apex"])
			var top := apex if apex > 0.0 else float(o["spring"])
			var origin := a + dir * s0 - out * thick * INSET
			var centre := origin + dir * width * 0.5
			(
				out_list
				. append(
					{
						"origin": Vector3(origin.x, sill, origin.y),
						"dir": dir,
						"out": out,
						# Quantised like the 8-bit glass vertex colour.
						"w": roundf(width / 4.0 * 255.0) / 255.0 * 4.0,
						"width": width,
						"lights": int(op.get("lights", 1)),
						"spring": float(o["spring"]) - sill,
						"apex": apex - sill if apex > 0.0 else 0.0,
						"height":
						roundf(clampf((top - sill) / 8.0, 0.05, 1.0) * 255.0) / 255.0 * 8.0,
						"code": glazing * 16 + posmod(int(roundf(float(o["seed"]) * 3.0)), 16),
						"floor": float(w.get("floor", 0.12)),
						"outer": thick * INSET,
						"thick": thick,
						"inner": _inner_face(op, thick),
						"depth": _depth(fabric, centre, -out, thick),
						"outline": CitySiteKit.outline(o),
					}
				)
			)
	return out_list


static func sunlight_material(wins: Array[Dictionary]) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SUNLIGHT
	mat.set_shader_parameter("plates", load(PLATES))
	var wa := PackedVector4Array()
	var wb := PackedVector4Array()
	var wc := PackedVector4Array()
	var wd := PackedVector4Array()
	var we := PackedVector4Array()
	for k in MAX_WINDOWS:
		if k >= wins.size():
			wa.append(Vector4.ZERO)
			wb.append(Vector4.ZERO)
			wc.append(Vector4.ZERO)
			wd.append(Vector4.ZERO)
			we.append(Vector4.ZERO)
			continue
		var win: Dictionary = wins[k]
		var o: Vector3 = win["origin"]
		var dir: Vector2 = win["dir"]
		var out: Vector2 = win["out"]
		wa.append(Vector4(o.x, o.y, o.z, float(win["lights"])))
		wb.append(Vector4(dir.x, dir.y, out.x, out.y))
		wc.append(Vector4(win["w"], win["spring"], win["apex"], win["height"]))
		wd.append(Vector4(float(win["code"]), float(win["outer"]), 0.0, 0.0))
		we.append(win["inner"])
	mat.set_shader_parameter("window_count", wins.size())
	mat.set_shader_parameter("win_a", wa)
	mat.set_shader_parameter("win_b", wb)
	mat.set_shader_parameter("win_c", wc)
	mat.set_shader_parameter("win_d", wd)
	mat.set_shader_parameter("win_e", we)
	return mat


## Beam prisms, one per window, in site-local space (see the shader for the
## vertex layout). Shadows off; the AABB is grown by the longest throw so
## the moving far ends are not culled.
static func shafts(wins: Array[Dictionary]) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var reach := 0.0
	for win: Dictionary in wins:
		var o: Vector3 = win["origin"]
		var dir: Vector2 = win["dir"]
		var out: Vector2 = win["out"]
		var n := Vector3(out.x, 0.0, out.y)
		var d3 := Vector3(dir.x, 0.0, dir.y)
		# Just inside the glass so the beam starts at the pane, not in it.
		var base := o - n * 0.03
		var tint := window_tint(win)
		# Alpha carries the opening's width for the shader's reveal cut-off.
		tint.a = clampf(float(win["width"]) / 4.0, 0.0, 1.0)
		var depth := float(win["depth"])
		var floor_y := float(win["floor"])
		reach = maxf(reach, maxf(depth, o.y - floor_y + float(win["height"])) * 3.0)
		var s0 := float((win["outline"] as PackedVector2Array)[0].x) - float(win["width"])
		var pts: PackedVector2Array = win["outline"]
		for k in pts.size():
			var p := pts[k]
			var q := pts[(k + 1) % pts.size()]
			var p3 := base + d3 * (p.x - s0) + Vector3(0, p.y - o.y, 0)
			var q3 := base + d3 * (q.x - s0) + Vector3(0, q.y - o.y, 0)
			if p3.is_equal_approx(q3):
				continue
			for v: Array in [[p3, 0.0], [q3, 0.0], [q3, 1.0], [p3, 0.0], [q3, 1.0], [p3, 1.0]]:
				verts.append(v[0])
				normals.append(n)
				colors.append(tint)
				uvs.append(Vector2(v[1], depth))
				uv2s.append(Vector2(floor_y, float(win["thick"])))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = SHAFT
	mesh.surface_set_material(0, mat)
	var inst := MeshInstance3D.new()
	inst.name = "SunShafts"
	inst.mesh = mesh
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.custom_aabb = mesh.get_aabb().grow(reach)
	return inst


## Mean light colour of a window: the plates its panels show (same walk as
## glass_panel), linear, normalised to a brightest channel of 1 and
## halfway to warm white.
static func window_tint(win: Dictionary) -> Color:
	var means := plate_means()
	var lights := maxi(int(win["lights"]), 1)
	var width := float(win["w"]) / lights
	var height := float(win["height"])
	var panels := maxi(1, int(floorf(height * 0.6667 / maxf(width, 0.01) / 1.3 + 0.5)))
	var code := int(win["code"])
	var programme := clampi(code / 16, 0, 3)
	var seed := code % 16
	var sum := Color(0, 0, 0)
	for light in lights:
		for row in panels:
			var slot := (seed + light + row * lights) % 6
			sum += means[PROGRAMMES[programme * 6 + slot]]
	var c := sum / float(lights * panels)
	var peak := maxf(maxf(c.r, c.g), maxf(c.b, 0.001))
	# Half sunlight: dust in the air scatters the mixed colours towards white.
	return Color(c.r / peak, c.g / peak, c.b / peak).lerp(Color(1.0, 0.95, 0.85), 0.5)


## Linear mean colour of each glass plate layer (cached).
static func plate_means() -> Array[Color]:
	if not _plate_means.is_empty():
		return _plate_means
	var tex := load(PLATES) as TextureLayered
	for k in tex.get_layers():
		var img := tex.get_layer_data(k)
		if img == null:
			# Headless (dummy renderer) keeps no texture data: neutral shafts.
			_plate_means.append(Color(0.5, 0.5, 0.5))
			continue
		if img.is_compressed():
			img.decompress()
		img = img.duplicate() as Image
		img.convert(Image.FORMAT_RGB8)
		img.resize(16, 24, Image.INTERPOLATE_BILINEAR)
		var sum := Color(0, 0, 0)
		for y in img.get_height():
			for x in img.get_width():
				sum += img.get_pixel(x, y).srgb_to_linear()
		_plate_means.append(sum / float(img.get_width() * img.get_height()))
	return _plate_means


## Splayed inner face of an opening for the sunlight shader: splay, the
## distance in from the glass, and its spring and apex above its own sill
## (SiteKit._opening lowers the inner sill by 0.6 x splay).
static func _inner_face(op: Dictionary, thick: float) -> Vector4:
	var outer := CitySiteKit._opening(op, false)
	var inner := CitySiteKit._opening(op, true)
	var splay := (float(inner["w"]) - float(outer["w"])) * 0.5
	var sill := float(inner["sill"])
	var apex := float(inner["apex"])
	return Vector4(
		splay,
		thick * (1.0 - INSET),
		float(inner["spring"]) - sill,
		apex - sill if apex > 0.0 else 0.0
	)


## Distance from `from` along `dir` (inward) to the nearest other wall face of
## the fabric, the room depth a beam may cross. 30 m when nothing is hit.
static func _depth(fabric: Array, from: Vector2, dir: Vector2, thick: float) -> float:
	var best := 30.0
	for w: Dictionary in fabric:
		var a := Vector2(w["a"][0], w["a"][1])
		var b := Vector2(w["b"][0], w["b"][1])
		var hit: Variant = Geometry2D.segment_intersects_segment(from, from + dir * 60.0, a, b)
		if hit == null:
			continue
		var t := from.distance_to(hit as Vector2)
		if t > thick + 0.1:
			best = minf(best, t)
	return best


## Lays `mat` as the overlay of every mesh under `node` (itself included)
## except the glass.
static func _overlay(node: Node, mat: Material) -> void:
	if node is MeshInstance3D and not String(node.name).begins_with("Glass"):
		(node as MeshInstance3D).material_overlay = mat
	for child in node.get_children():
		_overlay(child, mat)
