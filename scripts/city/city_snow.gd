class_name CitySnow
extends RefCounted

## Where snow lies on the city ground. A GDScript port of the patch rule in
## city_ground.gdshader (snow_patch / the fragment's snow_noise), so what the eye
## sees under the foot, the footprint it leaves and the crunch it makes agree.
## Pure function of position and the 0..1 settled-snow cover; no state.

## Same constants as the shader: snow settles where the noise field is high first.
const COVER_GAIN := 1.18
const EDGE_SHARPNESS := 5.0
## Above this patch value a foot is in snow rather than on the ground under it.
const LYING := 0.45


static func _fract(x: float) -> float:
	return x - floorf(x)


static func hash12(p: Vector2) -> float:
	var a := _fract(p.x * 0.1031)
	var b := _fract(p.y * 0.1031)
	var c := _fract(p.x * 0.1031)
	var dot_value := a * (b + 33.33) + b * (c + 33.33) + c * (a + 33.33)
	a += dot_value
	b += dot_value
	c += dot_value
	return _fract((a + b) * c)


static func value_noise(p: Vector2) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := Vector2(p.x - i.x, p.y - i.y)
	var u := Vector2(f.x * f.x * (3.0 - 2.0 * f.x), f.y * f.y * (3.0 - 2.0 * f.y))
	var bottom := lerpf(hash12(i), hash12(i + Vector2(1.0, 0.0)), u.x)
	var top := lerpf(hash12(i + Vector2(0.0, 1.0)), hash12(i + Vector2(1.0, 1.0)), u.x)
	return lerpf(bottom, top, u.y)


## Snow at `world_xz` (0 bare .. 1 covered) for a settled `cover` of 0..1.
static func patch(world_xz: Vector2, cover: float) -> float:
	if cover <= 0.001:
		return 0.0
	var noise := value_noise(world_xz * 0.035) * 0.55 + value_noise(world_xz * 0.6) * 0.45
	return clampf((cover * COVER_GAIN - (1.0 - noise)) * EDGE_SHARPNESS, 0.0, 1.0)
