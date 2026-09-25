// Shared WS-04 FFT ocean sampling (WS-13): the water surface shader and the
// UnderwaterPass screen pass include this file so the per-pixel waterline seen
// from below matches the displaced surface exactly. Moved unchanged from
// map_view_water.gdshader; keep it free of behaviour changes.
//
// The includer must declare, before this include:
//   uniform float choppiness;
//   uniform float standing_wave_ratio;
//   uniform vec2 wind_direction;
//   global uniform float ocean_time;

uniform bool use_fft = false;
// Every atlas shares one filter/repeat hint because Godot rejects a sampler
// argument (_fft_sample) fed textures with differing hints. The disp atlases
// always sample LOD 0, so the mipmap filter changes nothing for them.
uniform sampler2DArray fft_c0_disp : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray fft_c0_deriv : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray fft_c1_disp : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray fft_c1_deriv : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray fft_c2_deriv : filter_linear_mipmap, repeat_enable;
// Per cascade: x = patch size in world units (patch_m / 0.87), y = loop period s,
// z = frames, w = weather weight.
uniform vec4 fft_cascade[3];
// Dx, Dy, Dz decode scale in metres; w unused.
uniform vec4 fft_disp_scale[2];
// dDy/dx, dDy/dz, dDx/dx, dDz/dz decode scale.
uniform vec4 fft_deriv_scale[3];
// 1 = the baked physical reference sea state (Hs 1.26 m).
uniform float ocean_amplitude = 1.0;
// Quality tier: 3 recommended, 2 minimum (C2 slopes off, detail normal only).
uniform int fft_cascade_count = 3;
// WHY: the view mesh keeps water only WATER_RECESS - WATER_SURFACE_LIFT (0.074
// units) above a flat bed, so a physical 1.26 m sea (troughs near -0.72 units)
// would expose the bed everywhere. Geometry is compressed to the per-terrain
// Gerstner height budget; slopes, Jacobian and foam stay physical, so shading
// still reads the baked sea state. 1.0 would be the physical geometric sea.
uniform float fft_geometry_scale = 1.0;
// Horizontal bake axis is metres, world units are 0.87 m (profile key
// meters_per_world_unit). Vertical offsets convert with the same factor.
const float FFT_METERS_PER_WORLD_UNIT = 0.87;
// Deepest geometric trough. WATER_SURFACE_LIFT (0.006) minus the lowest tide
// offset (tide_height 0.004) leaves 0.002 units above the recessed bed.
const float FFT_TROUGH_FLOOR = 0.0015;
// Horizontal mesh chop relative to the vertical geometry. Separate view meshes
// (in-map cells vs surroundings planes) displace their borders differently, so
// full-size chop opens hairline cracks; crest sharpness still comes from the
// Jacobian in the shading normal.
const float FFT_HORIZONTAL_GEOMETRY = 0.5;

// ---- WS-04 FFT path ---------------------------------------------------------
// The bake blows the wind along +X. Rotating the lookup, not the bake, lets the
// live SkyWeather heading steer the wave trains without a second atlas.
vec2 _fft_wind_axis() {
	return wind_direction / max(length(wind_direction), 0.001);
}

// R(-angle(wind)) * p: world XZ into the bake frame.
vec2 _fft_to_wind(vec2 p, vec2 axis) {
	return vec2(p.x * axis.x + p.y * axis.y, -p.x * axis.y + p.y * axis.x);
}

// R(+angle(wind)) * v: bake-frame vectors back to world XZ.
vec2 _fft_from_wind(vec2 v, vec2 axis) {
	return vec2(v.x * axis.x - v.y * axis.y, v.x * axis.y + v.y * axis.x);
}

// Linear blend between the two bracketing baked frames. i1 wraps to frame 0,
// and the bake is periodic, so the 25.6 s / 12.8 s / 6.4 s loops never pop.
vec4 _fft_sample(sampler2DArray tex, vec2 uv, vec4 c, float lod) {
	float f = fract(ocean_time / c.y) * c.z;
	float i0 = floor(f);
	float i1 = mod(i0 + 1.0, c.z);
	vec4 a = textureLod(tex, vec3(uv, i0), lod);
	vec4 b = textureLod(tex, vec3(uv, i1), lod);
	return mix(a, b, f - i0);
}

vec4 _fft_signed(vec4 encoded, vec4 scale) {
	return (encoded - vec4(0.5)) * 2.0 * scale;
}

// Weighted C0 + C1 displacement in metres, bake frame. p is already in the bake
// frame. WS-06 foam terms read the disp alpha raw (linear 0..1, never signed-
// decoded, WS-03 amendment 1): x = weather-weighted mask w0*a0 + w1*a1,
// y = freshness max(a0, a1) (the bake decays foam, so high = just broken),
// z = the C0 share alone, a 1 m/texel coarse mask that connects wind streaks.
vec3 _fft_displacement_at(vec2 p, out vec3 foam) {
	vec4 c0 = fft_cascade[0];
	vec4 c1 = fft_cascade[1];
	vec4 s0 = _fft_sample(fft_c0_disp, p / c0.x, c0, 0.0);
	vec4 s1 = _fft_sample(fft_c1_disp, p / c1.x, c1, 0.0);
	vec3 d = _fft_signed(s0, fft_disp_scale[0]).xyz * c0.w
		+ _fft_signed(s1, fft_disp_scale[1]).xyz * c1.w;
	foam = vec3(s0.a * c0.w + s1.a * c1.w, max(s0.a, s1.a), s0.a * c0.w);
	return d;
}

// World-unit displacement (before shore fade) plus the WS-06 foam terms of
// _fft_displacement_at. The surface point is x' = x + lambda * D (WS-03
// amendment 1: crests compress).
vec3 _fft_displacement_foam(vec2 world_xz, out vec3 foam) {
	vec2 axis = _fft_wind_axis();
	vec2 p = _fft_to_wind(world_xz, axis);
	vec3 d = _fft_displacement_at(p, foam);
	float standing = clamp(standing_wave_ratio, 0.0, 1.0);
	// Two equal trains in opposite directions sum to a standing wave. The mirror
	// train is F(-p) with horizontal displacement negated back; height and foam
	// keep their sign. Branch on the uniform so open sea pays nothing.
	if (standing > 0.01) {
		vec3 mirror_foam;
		vec3 o = _fft_displacement_at(-p, mirror_foam);
		o.xz = -o.xz;
		d = mix(d, 0.5 * (d + o), standing);
		foam = mix(foam, 0.5 * (foam + mirror_foam), standing);
	}
	float chop = max(choppiness, 0.0) * (1.0 - standing * 0.65);
	vec3 world_d = vec3(0.0);
	world_d.xz = _fft_from_wind(d.xz * chop * FFT_HORIZONTAL_GEOMETRY, axis);
	world_d.y = d.y;
	return world_d * (ocean_amplitude * fft_geometry_scale / FFT_METERS_PER_WORLD_UNIT);
}

// Displacement only (xyz) with the foam mask in w, for callers that need no
// WS-06 styling terms (UnderwaterPass waterline).
vec4 _fft_displacement(vec2 world_xz) {
	vec3 foam;
	vec3 d = _fft_displacement_foam(world_xz, foam);
	return vec4(d, foam.x);
}

// Explicit layer indices stop some GL drivers from choosing mips, so the LOD is
// derived from the world-space pixel footprint (texels per pixel, log2).
float _fft_lod(float footprint, vec4 c, float texels) {
	return max(log2(max(footprint / c.x * texels, 1e-4)), 0.0);
}

// Slopes (xy) and Jacobian diagonal (zw) of one cascade, weighted, bake frame.
vec4 _fft_derivatives_cascade(sampler2DArray tex, vec2 p, vec4 c, vec4 scale, float lod) {
	return _fft_signed(_fft_sample(tex, p / c.x, c, lod), scale) * c.w;
}

// The gameplay camera is orthographic at a fixed 90-unit distance, so camera
// distance never changes texel density; the Tidewater oceanLOD distance fade is
// driven by the pixel footprint instead. Weight fades to zero while a cascade's
// shortest wave (2 texels) shrinks towards one pixel, before it can alias.
float _fft_cascade_fade(float footprint, vec4 c, float texels) {
	float texels_per_pixel = footprint / c.x * texels;
	return 1.0 - smoothstep(0.55, 1.6, texels_per_pixel);
}

// c2_gain scales the ripple cascade per pixel: WS-06 gust/slick patches.
vec4 _fft_derivatives_at(vec2 p, float footprint, float c2_gain) {
	vec4 c0 = fft_cascade[0];
	vec4 c1 = fft_cascade[1];
	vec4 c2 = fft_cascade[2];
	float n0 = float(textureSize(fft_c0_deriv, 0).x);
	float n1 = float(textureSize(fft_c1_deriv, 0).x);
	float n2 = float(textureSize(fft_c2_deriv, 0).x);
	vec4 sum = _fft_derivatives_cascade(fft_c0_deriv, p, c0, fft_deriv_scale[0], _fft_lod(footprint, c0, n0));
	float fade1 = _fft_cascade_fade(footprint, c1, n1);
	if (fade1 > 0.001) {
		sum += _fft_derivatives_cascade(fft_c1_deriv, p, c1, fft_deriv_scale[1], _fft_lod(footprint, c1, n1)) * fade1;
	}
	float fade2 = _fft_cascade_fade(footprint, c2, n2);
	if (fft_cascade_count > 2 && fade2 > 0.001) {
		sum += _fft_derivatives_cascade(fft_c2_deriv, p, c2, fft_deriv_scale[2], _fft_lod(footprint, c2, n2)) * fade2 * c2_gain;
	}
	return sum;
}

// World-space normal and crest fold from the summed slopes. Evaluated at the
// undisplaced XZ like the Gerstner path. Derivative channels are decoded with
// no sign flip (WS-03 amendment 2), so 1 + J drops below 1 on compressed crests.
vec3 _fft_normal_gust(vec2 world_xz, float footprint, float c2_gain, out float crest) {
	vec2 axis = _fft_wind_axis();
	vec2 p = _fft_to_wind(world_xz, axis);
	vec4 d = _fft_derivatives_at(p, footprint, c2_gain);
	float standing = clamp(standing_wave_ratio, 0.0, 1.0);
	if (standing > 0.01) {
		// Mirror train: slopes of F(-p) negate, the Jacobian of -D(-p) does not.
		vec4 o = _fft_derivatives_at(-p, footprint, c2_gain);
		o.xy = -o.xy;
		d = mix(d, 0.5 * (d + o), standing);
	}
	float chop = max(choppiness, 0.0) * (1.0 - standing * 0.65);
	vec2 slope = d.xy * ocean_amplitude;
	vec2 jacobian = d.zw * chop * ocean_amplitude;
	vec2 fold = max(vec2(1.0) + jacobian, vec2(0.15));
	crest = clamp(1.0 - fold.x * fold.y, 0.0, 1.0);
	vec3 n_wind = vec3(-slope.x / fold.x, 1.0, -slope.y / fold.y);
	vec2 n_xz = _fft_from_wind(n_wind.xz, axis);
	return normalize(vec3(n_xz.x, 1.0, n_xz.y));
}

vec3 _fft_normal(vec2 world_xz, float footprint, out float crest) {
	return _fft_normal_gust(world_xz, footprint, 1.0, crest);
}

// ---- Shared water medium constants ------------------------------------------
// Refractive index of sea water. WS-01 (refracted column) and WS-13 (Snell's
// window, refracted sun for shafts) must use the same value.
const float WATER_IOR = 1.333;
// Per-channel extinction sigma_t in 1/m for Baltic coastal water: red dies
// within a few metres, green and blue carry ~10 m, so distance fades to
// turquoise. WS-01 adopts these for the surface column when it lands.
const vec3 WATER_SIGMA_T_PER_M = vec3(0.36, 0.075, 0.062);

// Same soft trough floor as the water vertex stage, so a CPU or screen-pass
// waterline sits exactly on the rendered surface.
float _fft_trough_floor(float y) {
	return y < 0.0 ? -FFT_TROUGH_FLOOR * (1.0 - exp(y / FFT_TROUGH_FLOOR)) : y;
}

// ---- Shared underwater lighting (WS-13) -------------------------------------
// Used by the UnderwaterPass medium and by the water back face (the mirror
// outside Snell's window) so both show the same water colour.

// Henyey-Greenstein phase; g 0.75 is the strong forward lobe of sea water.
float _uw_hg(float cos_theta, float g) {
	float g2 = g * g;
	return (1.0 - g2) / (4.0 * PI * pow(max(1.0 + g2 - 2.0 * g * cos_theta, 1e-4), 1.5));
}

// Sun direction after refraction into the water, pointing back towards the
// light. A sun below the horizon falls back to straight up (its light is off).
vec3 _uw_sun_refracted(vec3 sun_dir) {
	vec3 s = normalize(sun_dir);
	if (s.y <= 0.0) {
		return vec3(0.0, 1.0, 0.0);
	}
	return -refract(-s, vec3(0.0, 1.0, 0.0), 1.0 / WATER_IOR);
}

// Storms stir the water: extinction rises with the cloud cover.
vec3 _uw_sigma_t(float cloud_cover) {
	return WATER_SIGMA_T_PER_M * (1.0 + 1.4 * clamp(cloud_cover, 0.0, 1.0));
}

// Ambient and direct sun light that reaches the top of the water column.
// Art direction (ADR 0018) keeps a cobalt night instead of black: the floor is
// a quarter of the day tint (AgX crushes anything darker to black).
void _uw_lighting(
	vec3 water_tint, vec3 sun_color, vec3 sun_dir, float daylight, float cloud_cover,
	out vec3 ambient, out vec3 sun
) {
	float clouds = clamp(cloud_cover, 0.0, 1.0);
	float day = clamp(daylight, 0.0, 1.0);
	ambient = water_tint * mix(0.25, 1.0, day) * (1.0 - 0.55 * clouds);
	float sun_up = smoothstep(-0.02, 0.18, normalize(sun_dir).y);
	// Only the tint of the reflection colour is used: SkyWeather3D currently feeds
	// sun_reflection_color on a 0..255 scale, which would blow the medium out.
	vec3 tint = sun_color / max(max(max(sun_color.r, sun_color.g), sun_color.b), 1.0);
	sun = tint * sun_up * day * (1.0 - 0.85 * clouds);
}

// In-scattered radiance for an eye ray `view_dir` (camera -> scene) at
// depth_m metres under the surface. T_down is the light lost on the way down.
vec3 _uw_inscatter(
	vec3 view_dir, float depth_m, vec3 ambient, vec3 sun, vec3 sun_dir, vec3 sigma_t
) {
	vec3 t_down = exp(-sigma_t * max(depth_m, 0.0));
	float phase = _uw_hg(dot(normalize(view_dir), _uw_sun_refracted(sun_dir)), 0.75);
	return ambient * t_down + sun * t_down * phase * 0.15;
}

// The surface seen from below along `ray_up` (camera -> surface, travelling
// up). Inside Snell's window (critical angle ~48.6 deg for WATER_IOR) the air
// scene behind is refracted in with Fresnel transmission, a brightened rim and
// a small dispersion fringe; outside it total internal reflection mirrors the
// lit water as a silver-green sheet.
//
// Split in two because a hint_screen_texture sampler passed as a function
// argument binds a default texture instead of the screen copy (Godot 4.7): the
// caller samples the screen at the UVs from _uw_window() and hands the colour
// to _uw_below_color().
struct UwWindow {
	vec2 uv;
	vec2 fringe;
	float window;
	float rim;
	float transmit;
};

UwWindow _uw_window(vec2 screen_uv, mat4 view_matrix, vec3 ray_up, vec3 surface_up) {
	UwWindow w;
	// GLSL refract wants the normal against the incident ray; eta = n_water / n_air.
	float cos_in = dot(ray_up, surface_up);
	float k = 1.0 - WATER_IOR * WATER_IOR * (1.0 - cos_in * cos_in);
	// k > 0 inside the window, k < 0 is total internal reflection. The soft band
	// keeps the rim from aliasing on the moving normal.
	w.window = smoothstep(-0.03, 0.05, k);
	vec3 exit_ray = refract(ray_up, -surface_up, WATER_IOR);
	vec2 bend = (view_matrix * vec4(exit_ray - ray_up, 0.0)).xy;
	w.uv = clamp(screen_uv + bend * 0.06 * step(0.0, k), vec2(0.001), vec2(0.999));
	w.rim = w.window * exp(-max(k, 0.0) * 16.0);
	w.fringe = bend * 0.018 * w.rim;
	// Schlick on the air side (cosine of the transmitted ray) stays valid across
	// the water-to-air interface.
	float cos_air = clamp(dot(exit_ray, surface_up), 0.0, 1.0);
	w.transmit = 1.0 - (0.02 + 0.98 * pow(1.0 - cos_air, 5.0));
	return w;
}

// `air_scene` is the screen sampled at w.uv (+/- w.fringe for red/blue).
vec3 _uw_below_color(
	UwWindow w, vec3 air_scene, vec3 ray_up, vec3 ambient, vec3 sun, vec3 sun_dir,
	vec3 sigma_t, vec3 bed_tint
) {
	// The totally reflected ray heads back down into the lit water.
	vec3 mirror = _uw_inscatter(ray_up * vec3(1.0, -1.0, 1.0), 0.0, ambient, sun, sun_dir, sigma_t);
	mirror = mirror * 1.15 + bed_tint * 0.12;
	vec3 window_color = air_scene * w.transmit + sun * w.rim * 0.35;
	return mix(mirror, window_color, w.window);
}
