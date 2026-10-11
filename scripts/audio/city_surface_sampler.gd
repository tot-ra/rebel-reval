class_name CitySurfaceSampler
extends RefCounted

## Footstep surface under a foot in the seamless city (ADR 0031, R-1641). The
## city has no MapTerrainGrid: its ground is painted by city_ground.gdshader from
## the plan's land-use rasters, so this reads the same rasters the shader reads
## and answers with a SurfaceResolver surface. Nothing here touches game state.
##
## Priority, first match wins: water the foot stands in (splash or wade by
## depth, R-1648), a bridge deck, an
## interior site floor, a building floor, the painted ground, and a rain puddle
## on that ground.

## Site floors that are not stone (churches, the hospital and the market hall
## are). Kalev's forge has a beaten earth floor: no timber near the hearth.
const SITE_FLOOR_SURFACES := {
	&"site.kalev_smithy": SurfaceResolver.SURFACE_DIRT,
}
## Building kinds whose floor is flagstone; every other shell has boards.
const STONE_FLOOR_KINDS := ["church", "chapel"]
## Ground this close above the sea (world y, sea at 0) is beach sand, as the
## shader's shore band paints it.
const SHORE_SAND_HEIGHT := 1.0
## A painted layer must cover at least this share to be heard; below it the
## ground reads as turf, the shader's base layer.
const LAYER_MIN_SHARE := 0.5
## Standing water deeper than this (shader units) is a puddle; the shader shows
## a film from 0 and standing water from 0.04.
const PUDDLE_MIN_DEPTH := 0.04

var plan: CityPlan
## Callable(world_xz: Vector2) -> float: water column over the walking surface.
var water_depth: Callable


func _init(city_plan: CityPlan, water_depth_at: Callable = Callable()) -> void:
	plan = city_plan
	water_depth = water_depth_at


## `puddles` and `ground_dryness` are SkyWeather3D.puddle_wetness() and
## ground_dryness(), the values city_world_3d.gd hands the ground shader;
## `snow_cover` is the settled-snow cover (0..1) it hands the same shader.
func surface_at(
	foot: Vector3, puddles: float = 0.0, ground_dryness: float = 0.0, snow_cover: float = 0.0
) -> StringName:
	if plan == null:
		return &""
	var xz := Vector2(foot.x, foot.z)
	var depth := float(water_depth.call(xz)) if water_depth.is_valid() else 0.0
	if depth > 0.0:
		return SurfaceResolver.water_surface_for_depth(depth)
	if not is_nan(plan.bridge_deck_height(xz)):
		return SurfaceResolver.SURFACE_WOOD
	var site := plan.site_at(xz)
	if site != null and not site.floor_at(xz).is_empty():
		return SITE_FLOOR_SURFACES.get(site.id, SurfaceResolver.SURFACE_STONE)
	var building := plan.building_at(xz)
	if building >= 0:
		var kind := String(plan.buildings[building].get("kind", ""))
		return (
			SurfaceResolver.SURFACE_STONE
			if kind in STONE_FLOOR_KINDS
			else SurfaceResolver.SURFACE_WOOD
		)
	var surface := ground_surface(xz)
	# Settled snow buries soft ground (the same patches the shader paints).
	if snow_cover > 0.0 and CitySnow.patch(xz, snow_cover) > CitySnow.LYING:
		var snowy := SurfaceResolver.with_snow(surface, true)
		if snowy != surface:
			return snowy
	var in_puddle := puddle_depth(xz, puddles, ground_dryness) > PUDDLE_MIN_DEPTH
	return SurfaceResolver.with_puddle(surface, in_puddle)


## Surface the ground shader paints at `xz`: splat R paving, G packed earth,
## B sand, A mud (with the field band carved out of A), plus the cart-road
## raster. The layer weights use the shader's own smoothstep ramps.
func ground_surface(xz: Vector2) -> StringName:
	if plan.has_coast() and plan.ground_height(xz) < SHORE_SAND_HEIGHT:
		return SurfaceResolver.SURFACE_GRAVEL
	var w := _layer_weights(xz)
	var best := SurfaceResolver.SURFACE_GRASS
	var best_share := LAYER_MIN_SHARE
	for surface: StringName in w:
		if float(w[surface]) > best_share:
			best_share = float(w[surface])
			best = surface
	return best


## Standing water over `xz`, a CPU port of the `hollow * soft` basins in
## city_ground.gdshader (ruts and footprints, which only fill near the camera,
## are left out). Positive where the shader draws water.
func puddle_depth(xz: Vector2, puddles: float, ground_dryness: float) -> float:
	if puddles <= 0.0:
		return -1.0
	# Baked ground drinks the first rain (R-1516): no standing water yet.
	var soaked := 1.0 - smoothstep(0.05, 0.3, ground_dryness)
	if soaked < 0.5:
		return -1.0
	var s := CityShore.land_use_at(plan, xz)
	var road := CityShore.road_raster_at(plan, xz).r
	var paving := smoothstep(0.25, 0.7, s.r)
	var field := CityGrass.field_share(s)
	var earth := smoothstep(0.15, 0.65, s.g) * (1.0 - field)
	var mud := smoothstep(0.2, 0.7, s.a) * (1.0 - field)
	var soft := clampf(earth + mud + field + road * (1.0 - paving), 0.0, 1.0) * (1.0 - paving)
	var h0 := mud_height(xz)
	var hollow := 1.0 - smoothstep(0.32, 0.5, h0 + value_noise(xz * 0.23) * 0.45)
	# The shader's slope_len is 1 - normal.y; slope_at answers the angle.
	var flat_ground := 1.0 - smoothstep(0.04, 0.12, 1.0 - cos(plan.slope_at(xz)))
	var pool := hollow * soft * flat_ground
	return (pool - (1.05 - puddles * 0.75)) * (1.0 - paving)


func _layer_weights(xz: Vector2) -> Dictionary:
	var s := CityShore.land_use_at(plan, xz)
	var road := CityShore.road_raster_at(plan, xz).r
	var paving := smoothstep(0.25, 0.7, s.r)
	var field := CityGrass.field_share(s)
	return {
		SurfaceResolver.SURFACE_STONE: paving,
		SurfaceResolver.SURFACE_DIRT:
		maxf(maxf(smoothstep(0.15, 0.65, s.g) * (1.0 - field), field), road * (1.0 - paving)),
		SurfaceResolver.SURFACE_GRAVEL: smoothstep(0.2, 0.7, s.b),
		SurfaceResolver.SURFACE_MUD: smoothstep(0.2, 0.7, s.a) * (1.0 - field),
	}


## city_ground.gdshader hash12 / value_noise / mud_height, ported so the CPU
## puddle basins fall where the shader draws them.
static func hash12(p: Vector2) -> float:
	var p3 := Vector3(p.x, p.y, p.x) * 0.1031
	p3 = Vector3(p3.x - floorf(p3.x), p3.y - floorf(p3.y), p3.z - floorf(p3.z))
	p3 += Vector3.ONE * p3.dot(Vector3(p3.y, p3.z, p3.x) + Vector3.ONE * 33.33)
	var v := (p3.x + p3.y) * p3.z
	return v - floorf(v)


static func value_noise(p: Vector2) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	return lerpf(
		lerpf(hash12(i), hash12(i + Vector2(1.0, 0.0)), u.x),
		lerpf(hash12(i + Vector2(0.0, 1.0)), hash12(i + Vector2(1.0, 1.0)), u.x),
		u.y
	)


static func mud_height(p: Vector2) -> float:
	var lumps := value_noise(p * 0.9)
	var ruts := (
		value_noise(Vector2(p.x * 0.35, p.y * 3.1)) * value_noise(Vector2(p.x * 3.1, p.y * 0.35))
	)
	var pocks := value_noise(p * 4.7)
	return lumps * 0.55 + ruts * 0.3 + pocks * 0.15
