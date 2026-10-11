class_name CityObstacleMask
extends RefCounted

## WR-5 (R-1510, docs/SYSTEMS/CITY_SEA.md "Waves around rocks"): the obstacle mask the
## local wave sim (WaterRippleSim in obstacle mode) reads. One float per sim texel: the
## still-water depth in world units, from the bathymetry (the ground heightfield) and
## from every rock instance on top of it. Depth <= SOLID_DEPTH is a wall the waves
## reflect from; shallow water slows them down and breaks them (the sim's damping).
##
## WHY rocks separately: the city and sandbox heightfields are 2-3 m cells, so a
## boulder of 0.3-2 m is invisible to them (the sandbox stamps only rocks >= 1.6 m).
## Each rock is a dome (x, z, radius, top y) stamped into the raster at sim resolution.
##
## WHY coarse bathymetry: a 256 x 256 window is 65 k texels; sampling the ground per
## texel in GDScript takes ~100 ms. The heightfield has nothing finer than its cells,
## so it is sampled every BATHYMETRY_STEP world units on a world-aligned grid and
## upscaled bilinearly by Image.resize (native), then the rocks are stamped per texel.
##
## The raster is aligned with the sim's texel grid (origin given in texels), so the
## step shader reads it with texelFetch and no filtering decides where a wall is.

## Still-water depth at or below which a texel is solid (rock or quay above the water).
const SOLID_DEPTH := 0.0
## Ground sampling pitch of the bathymetry pass (world units).
const BATHYMETRY_STEP := 1.0
## Spatial hash cell for the rock index (world units).
const ROCK_BUCKET := 16.0
## Rocks smaller than this radius are pebbles: they do not stop a wave.
const MIN_ROCK_RADIUS := 0.12
## Shore debris kinds that are solid rocks (CityShore / water sandbox placements).
const ROCK_KIND_PREFIXES := ["boulder", "stone_cluster", "erratic"]

## Returns the ground height (world y) at a world XZ.
var ground: Callable
## Still-water level (world y). The city sea rests at 0.
var sea_level := 0.0
## Rock domes: x, z, radius (world units), top y.
var rocks := PackedVector4Array()
## Last raster's cost, for the sim's timing report.
var last_build_usec := 0

var _buckets: Dictionary = {}


func _init(ground_height: Callable = Callable(), still_level: float = 0.0) -> void:
	ground = ground_height
	sea_level = still_level


## Replaces the rock list and rebuilds the spatial index.
func set_rocks(rock_domes: PackedVector4Array) -> void:
	rocks = PackedVector4Array()
	_buckets.clear()
	for rock in rock_domes:
		if rock.z < MIN_ROCK_RADIUS:
			continue
		var index := rocks.size()
		rocks.append(rock)
		var lo := _bucket_of(Vector2(rock.x - rock.z, rock.y - rock.z))
		var hi := _bucket_of(Vector2(rock.x + rock.z, rock.y + rock.z))
		for bj in range(lo.y, hi.y + 1):
			for bi in range(lo.x, hi.x + 1):
				var key := Vector2i(bi, bj)
				if not _buckets.has(key):
					_buckets[key] = PackedInt32Array()
				var list: PackedInt32Array = _buckets[key]
				list.append(index)
				_buckets[key] = list


static func _bucket_of(xz: Vector2) -> Vector2i:
	return Vector2i(floori(xz.x / ROCK_BUCKET), floori(xz.y / ROCK_BUCKET))


## A rock dome from a mesh instance: radius from the scaled horizontal footprint, top
## from the scaled AABB top. Works for any rock mesh (CityShore, sandbox, prefabs).
static func rock_from_instance(mesh_aabb: AABB, xform: Transform3D) -> Vector4:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for corner in 8:
		var p := xform * mesh_aabb.get_endpoint(corner)
		lo = lo.min(p)
		hi = hi.max(p)
	var centre := (lo + hi) * 0.5
	var radius := maxf(hi.x - lo.x, hi.z - lo.z) * 0.5
	return Vector4(centre.x, centre.z, radius, hi.y)


## Rock domes from shore-debris placements ({kind, transform}); `mesh_for` maps a kind to
## its Mesh (ShoreDebris.shore_debris_mesh). Wrack, weed and pebble patches are skipped.
static func rocks_from_placements(placements: Array, mesh_for: Callable) -> PackedVector4Array:
	var out := PackedVector4Array()
	var aabbs: Dictionary = {}
	for placement: Dictionary in placements:
		var kind := String(placement.get("kind", ""))
		if not is_rock_kind(kind):
			continue
		if not aabbs.has(kind):
			var mesh: Mesh = mesh_for.call(StringName(kind))
			aabbs[kind] = mesh.get_aabb() if mesh != null else AABB()
		var box: AABB = aabbs[kind]
		if box.size == Vector3.ZERO:
			continue
		out.append(rock_from_instance(box, placement["transform"]))
	return out


## Rock domes from built shore-debris MultiMeshes under `root` (CityShore names them
## "Shore_<kind>_<chunk x>_<chunk z>"). WHY not placements_for(): it walks the whole
## plan again (~1.2 s for Reval); the built instances already hold every transform.
static func rocks_from_multimeshes(root: Node, prefix: String = "Shore_") -> PackedVector4Array:
	var out := PackedVector4Array()
	if root == null:
		return out
	for node in root.find_children(prefix + "*", "MultiMeshInstance3D", true, false):
		var inst := node as MultiMeshInstance3D
		if not is_rock_kind(String(inst.name).trim_prefix(prefix)) or inst.multimesh == null:
			continue
		var multi := inst.multimesh
		if multi.mesh == null:
			continue
		var box := multi.mesh.get_aabb()
		var placed := _transform_under(inst, root)
		for i in multi.instance_count:
			out.append(rock_from_instance(box, placed * multi.get_instance_transform(i)))
	return out


## Transform of `node` relative to `root` (root's own transform included). Built from
## local transforms, because the city is assembled before it enters the tree and
## global_transform is not available there.
static func _transform_under(node: Node, root: Node) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var cursor := node
	while cursor != null:
		if cursor is Node3D:
			xform = (cursor as Node3D).transform * xform
		if cursor == root:
			break
		cursor = cursor.get_parent()
	return xform


static func is_rock_kind(kind: String) -> bool:
	for prefix: String in ROCK_KIND_PREFIXES:
		if kind.begins_with(prefix):
			return true
	return false


## Height of the rock surface at `xz` (world y), or -INF off every rock. A dome: the top
## at the centre, dropping by one radius at the rim.
func rock_height_at(xz: Vector2) -> float:
	var best := -INF
	var key := _bucket_of(xz)
	if not _buckets.has(key):
		return best
	for index in _buckets[key]:
		var rock := rocks[index]
		var q2 := (Vector2(rock.x, rock.y) - xz).length_squared() / (rock.z * rock.z)
		if q2 < 1.0:
			best = maxf(best, rock.w - rock.z * (1.0 - sqrt(1.0 - q2)))
	return best


## Still-water depth at `xz` (world units, negative above the water).
func depth_at(xz: Vector2) -> float:
	var bed: float = ground.call(xz) if ground.is_valid() else -INF
	return sea_level - maxf(bed, rock_height_at(xz))


## One-channel float raster (FORMAT_RF) of the still-water depth over `size` x `size`
## texels of `texel` world units whose texel (0, 0) is world texel `origin_texel`
## (texel (i, j) covers world [origin + i, origin + i + 1) * texel, like the sim).
func rasterise(origin_texel: Vector2i, size: int, texel: float) -> Image:
	var t0 := Time.get_ticks_usec()
	var origin := Vector2(origin_texel) * texel
	var span := float(size) * texel
	# Bathymetry on a world-aligned grid every BATHYMETRY_STEP, upscaled natively. WHY
	# world-aligned: sampled from the window corner, the 2 m quay ramp landed on
	# different sample phases as the window moved, so the depth beside a wall (and with
	# it the breaking damping and the reflection) changed with the camera.
	var ratio := maxi(roundi(BATHYMETRY_STEP / texel), 1)
	var step := texel * float(ratio)
	var lo := Vector2i(floori(origin.x / step) - 1, floori(origin.y / step) - 1)
	var hi := Vector2i(ceili((origin.x + span) / step) + 1, ceili((origin.y + span) / step) + 1)
	var coarse_size := hi - lo + Vector2i.ONE
	var coarse := Image.create_empty(coarse_size.x, coarse_size.y, false, Image.FORMAT_RF)
	for j in coarse_size.y:
		for i in coarse_size.x:
			var at := Vector2(lo + Vector2i(i, j)) * step
			var bed: float = ground.call(at) if ground.is_valid() else sea_level - 100.0
			coarse.set_pixel(i, j, Color(sea_level - bed, 0.0, 0.0))
	coarse.resize(coarse_size.x * ratio, coarse_size.y * ratio, Image.INTERPOLATE_BILINEAR)
	# The crop offset is a whole number of texels, so every window cuts the same
	# world-aligned raster (resize's own sub-texel phase is the same everywhere).
	var crop := Vector2i(origin_texel.x - lo.x * ratio, origin_texel.y - lo.y * ratio)
	var image := Image.create_empty(size, size, false, Image.FORMAT_RF)
	image.blit_rect(coarse, Rect2i(crop, Vector2i(size, size)), Vector2i.ZERO)
	_stamp_rocks(image, origin, size, texel)
	last_build_usec = Time.get_ticks_usec() - t0
	return image


func _stamp_rocks(image: Image, origin: Vector2, size: int, texel: float) -> void:
	var span := float(size) * texel
	var window := Rect2(origin, Vector2(span, span))
	var seen: Dictionary = {}
	var lo := _bucket_of(origin)
	var hi := _bucket_of(origin + Vector2(span, span))
	for bj in range(lo.y, hi.y + 1):
		for bi in range(lo.x, hi.x + 1):
			var key := Vector2i(bi, bj)
			if not _buckets.has(key):
				continue
			for index in _buckets[key]:
				if seen.has(index):
					continue
				seen[index] = true
				var rock := rocks[index]
				var centre := Vector2(rock.x, rock.y)
				if not window.grow(rock.z).has_point(centre):
					continue
				# Texels whose centres fall inside the dome footprint.
				var i0 := maxi(floori((centre.x - rock.z - origin.x) / texel), 0)
				var i1 := mini(ceili((centre.x + rock.z - origin.x) / texel), size - 1)
				var j0 := maxi(floori((centre.y - rock.z - origin.y) / texel), 0)
				var j1 := mini(ceili((centre.y + rock.z - origin.y) / texel), size - 1)
				var inv_r2 := 1.0 / (rock.z * rock.z)
				for j in range(j0, j1 + 1):
					for i in range(i0, i1 + 1):
						var at := origin + (Vector2(i, j) + Vector2(0.5, 0.5)) * texel
						var q2 := (at - centre).length_squared() * inv_r2
						if q2 >= 1.0:
							continue
						var top := rock.w - rock.z * (1.0 - sqrt(1.0 - q2))
						var depth := sea_level - top
						if depth < image.get_pixel(i, j).r:
							image.set_pixel(i, j, Color(depth, 0.0, 0.0))


## Solid texels of a raster (tests and captures).
static func solid_count(image: Image) -> int:
	var count := 0
	for j in image.get_height():
		for i in image.get_width():
			if image.get_pixel(i, j).r <= SOLID_DEPTH:
				count += 1
	return count
