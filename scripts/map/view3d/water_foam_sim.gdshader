shader_type canvas_item;
render_mode blend_disabled, unshaded;

// WR-7 persistent foam step (WaterFoamSim, docs/SYSTEMS/CITY_SEA.md "Foam memory").
// One kernel per step renders into one of two HDR SubViewports and reads the partner's
// output as prev_state. State channels, all in _foam_dissolve coverage units (0..1):
//   R = foam density (what the sea dissolves its WR-2 structure by)
//   G = fresh foam (decays in about a second: bright, just broken)
//   B = windrow density (long-lived foam smeared along the wind into streaks)
// A is unused (Metal forces alpha to 1 in an opaque target, see WaterRippleSim).
//
// Frame: the buffer stores foam at the sea's REST (Lagrangian) coordinate, the
// wave_sample_xz the water shader feeds _city_foam_cells. The FFT vertex displacement
// therefore carries the stored foam with the orbital motion exactly, and the vertex
// stage shifts its lookup by the surf surge like WR-2, so the oscillating orbital and
// swash motion needs no resampling here. Only the net transport (wind drift plus
// Stokes drift) moves the buffer, and WaterFoamSim folds that drift into the window
// origin as whole-texel shifts plus a sub-texel offset: no bilinear resampling, so
// foam does not blur away as it travels.

// The FFT include expects these sea uniforms; WaterFoamSim mirrors them (and the
// fft_*, shore_* and foam weather uniforms) from the city sea material every step.
uniform float choppiness = 0.85;
uniform float standing_wave_ratio = 0.12;
uniform vec2 wind_direction = vec2(0.9578, 0.2873);
global uniform float ocean_time;
// Canvas shaders have no OUTPUT_IS_SRGB; the FFT include uses it to undo the
// Compatibility sRGB decode of the baked foam alpha. WaterFoamSim sets this flag
// from the rendering method, so the seed reads the same mask as the sea.
uniform bool compat_srgb_alpha = true;
#define OUTPUT_IS_SRGB compat_srgb_alpha
#include "res://scripts/map/view3d/ocean_fft_common.gdshaderinc"
#include "res://scripts/map/view3d/shore_swash.gdshaderinc"

// Sea weather (MapViewWaterMaterials.apply_sea_weather), mirrored from the sea.
uniform float foam_coverage = 1.0;
uniform float storm_foam_coverage = 0.8;
uniform float storm_streaks = 0.0;
uniform float whitecap_onset = 1.0;

uniform sampler2D prev_state : filter_nearest, repeat_disable;
uniform vec2 sim_size = vec2(256.0);
// World XZ of texel (0, 0)'s min corner including the sub-texel drift offset, and
// world units per texel. Texel (i, j) covers origin + (i + 0.5, j + 0.5) * texel.
uniform vec2 window_origin = vec2(0.0);
uniform float texel_world = 0.5;
// Texel offset of the previous state: new texel i holds what old texel i + shift held
// (camera follow and whole-texel drift). Texels arriving from outside are seeded.
uniform ivec2 window_shift = ivec2(0);
uniform float step_dt = 0.033333;
// Seed the whole window from the analytic WR-2 foam (first steps, clock jumps).
uniform bool reset_state = true;
// Calibration view: R = birth, G = crest (1 - J), B = analytic seed density.
uniform bool debug_birth = false;

// Mirrors map_view_water.gdshader (CITY_WHITECAP_*, CITY_SURF_FOAM_LIFE): the seed is
// the analytic WR-2 coverage, so a fresh window starts where the fallback is.
const float CITY_WHITECAP_THRESHOLD = 0.5;
const float CITY_WHITECAP_GAIN = 0.6;
const float CITY_SURF_FOAM_LIFE = 4.0;
// Whitecap birth on the displacement Jacobian J = (1 + Jxx)(1 + Jzz): crest = 1 - J.
// Foam is born where the surface compresses towards a fold (Tessendorf 2001).
// Calibrated so the fresh-breeze and gale windows hold about the WR-2 cover (a few %
// to about a fifth of the sea, Monahan-like) and the window edge does not show.
// Linear ramp from FOLD_BIRTH.x (no foam) to FOLD_BIRTH.y (full): the crest share of
// a fresh breeze peaks near 0.2, a gale's near 0.6 (sandbox calibration view).
const vec2 FOLD_BIRTH = vec2(0.06, 0.61);
const float FOLD_GAIN = 1.0;
// Seconds: whitecap foam (stage B) thins over several seconds, the bright fresh
// patch (stage A) within about one; surf foam uses the WR-2 surf life.
const float WHITECAP_LIFE = 8.0;
const float FRESH_LIFE = 0.9;
// Windrows: a share of the foam per second feeds the long-lived channel, which
// decays slowly and is smeared along the wind (Langmuir lines align with it).
const float WINDROW_FEED = 0.12;
const float WINDROW_LIFE = 30.0;
// Texels per second the windrow channel spreads along the wind axis.
const float WINDROW_SMEAR = 0.6;
// Foam at the foot of a quay or rock edge (WR-2 wall slosh band).
const float WALL_FOAM = 0.8;
// R-1734: below this longshore drift per step (texels) the state is read unfiltered.
const float CURRENT_MIN_TEXELS = 0.001;

struct FoamTerms {
	float density;
	float fresh;
	float windrow;
};

// Analytic WR-2 foam at a rest coordinate: the seed and the source of the surf.
// birth (out) is what breaks right now (Jacobian fold, surf roller, wall slosh).
// current (out) is the R-1734 longshore current, world units per second.
FoamTerms _foam_sources(
	vec2 xz, bool seed, out float birth, out float surf_zone, out float crest, out vec2 current
) {
	FoamTerms seeded = FoamTerms(0.0, 0.0, 0.0);
	birth = 0.0;
	surf_zone = 0.0;
	crest = 0.0;
	current = vec2(0.0);
	if (use_fft) {
		vec2 axis = _fft_wind_axis();
		vec2 p = _fft_to_wind(xz, axis);
		// Jacobian diagonal of C0 + C1 at the sim texel (C2 ripples cannot fold
		// metre-scale foam), with the sea's chop, like _fft_normal_gust.
		// The mip follows the texel footprint so finer waves average, not alias.
		float n0 = float(textureSize(fft_c0_deriv, 0).x);
		float n1 = float(textureSize(fft_c1_deriv, 0).x);
		vec4 d = _fft_derivatives_cascade(fft_c0_deriv, p, fft_cascade[0], fft_deriv_scale[0],
				_fft_lod(texel_world, fft_cascade[0], n0))
			+ _fft_derivatives_cascade(fft_c1_deriv, p, fft_cascade[1], fft_deriv_scale[1],
				_fft_lod(texel_world, fft_cascade[1], n1));
		float standing = clamp(standing_wave_ratio, 0.0, 1.0);
		float chop = max(choppiness, 0.0) * (1.0 - standing * 0.65);
		vec2 jacobian = d.zw * chop * ocean_amplitude;
		vec2 fold = max(vec2(1.0) + jacobian, vec2(0.0));
		crest = 1.0 - fold.x * fold.y;
		birth = clamp((crest - FOLD_BIRTH.x) / (FOLD_BIRTH.y - FOLD_BIRTH.x), 0.0, 1.0)
			* FOLD_GAIN * min(storm_foam_coverage * foam_coverage, 1.0) * whitecap_onset;
		if (seed) {
			vec3 mask = _fft_foam_terms(xz);
			float foam_mask = min(mask.x * storm_foam_coverage * foam_coverage, 1.0);
			float breaking = clamp((foam_mask - CITY_WHITECAP_THRESHOLD)
				/ (1.0 - CITY_WHITECAP_THRESHOLD), 0.0, 1.0);
			seeded.density = breaking * CITY_WHITECAP_GAIN * whitecap_onset;
			seeded.fresh = seeded.density * smoothstep(0.35, 0.8, mask.y * storm_foam_coverage);
			seeded.windrow = smoothstep(0.02, 0.3, mask.z * storm_foam_coverage);
		}
	}
	if (shore_field_valid > 0.5 && shore_strength > 0.0) {
		ShoreState s = shore_state(xz, ocean_time, shore_sea());
		current = shore_longshore_current(s);
		if (s.valid > 0.001 && s.distance >= 0.0) {
			// WR-2 surf coverage split into its fresh roller (born here) and the
			// trail (exp(-age / life)), which this buffer now carries as memory.
			float energy = mix(0.55, 1.0, clamp(shore_sea_state, 0.0, 1.0));
			float roller_x = (s.foam_age - 0.35) / mix(0.5, 0.8, s.plunge);
			float roller = exp(-roller_x * roller_x);
			float zone = clamp(s.bore_foam / max(shore_foam_gain, 0.001), 0.0, 1.0);
			float gate = smoothstep(0.0, 0.25, zone) * energy * (1.0 - 0.7 * s.surging) * s.valid;
			float wall = clamp(s.wall_foam, 0.0, 1.0) * WALL_FOAM * s.valid;
			birth = max(birth, max(roller * 0.95 * gate, wall));
			surf_zone = s.surf_zone * s.valid;
			if (seed) {
				float trail = exp(-s.foam_age / CITY_SURF_FOAM_LIFE);
				float coverage = max(max(roller * 0.95, trail * mix(0.6, 0.72, s.plunge)) * gate, wall);
				seeded.density = max(seeded.density, coverage);
				seeded.fresh = max(seeded.fresh, roller * 0.95 * gate);
			}
		}
	}
	return seeded;
}

vec3 _state_at(ivec2 p) {
	return texelFetch(prev_state, p, 0).rgb;
}

// Previous state at a fractional texel position (bilinear by hand: prev_state is
// nearest), for the longshore advection.
vec3 _state_bilinear(vec2 cell) {
	vec2 q = cell - 0.5;
	ivec2 i = ivec2(floor(q));
	vec2 f = fract(q);
	ivec2 hi = ivec2(sim_size) - 1;
	vec3 a = _state_at(clamp(i, ivec2(0), hi));
	vec3 b = _state_at(clamp(i + ivec2(1, 0), ivec2(0), hi));
	vec3 c = _state_at(clamp(i + ivec2(0, 1), ivec2(0), hi));
	vec3 e = _state_at(clamp(i + ivec2(1, 1), ivec2(0), hi));
	return mix(mix(a, b, f.x), mix(c, e, f.x), f.y);
}

bool _inside(ivec2 p) {
	ivec2 size = ivec2(sim_size);
	return p.x >= 0 && p.y >= 0 && p.x < size.x && p.y < size.y;
}

// Windrow channel one texel up/downwind (bilinear by hand: prev_state is nearest).
float _windrow_at(vec2 cell) {
	vec2 q = cell - 0.5;
	ivec2 i = ivec2(floor(q));
	vec2 f = fract(q);
	ivec2 hi = ivec2(sim_size) - 1;
	float a = _state_at(clamp(i, ivec2(0), hi)).b;
	float b = _state_at(clamp(i + ivec2(1, 0), ivec2(0), hi)).b;
	float c = _state_at(clamp(i + ivec2(0, 1), ivec2(0), hi)).b;
	float e = _state_at(clamp(i + ivec2(1, 1), ivec2(0), hi)).b;
	return mix(mix(a, b, f.x), mix(c, e, f.x), f.y);
}

void fragment() {
	// FRAGCOORD indexes texels in memory order on every backend (see WaterRippleSim).
	vec2 cell = FRAGCOORD.xy;
	vec2 xz = window_origin + cell * texel_world;
	ivec2 p = ivec2(floor(cell)) + window_shift;
	bool arrived = !_inside(p);
	float birth;
	float surf_zone;
	float crest;
	vec2 current;
	FoamTerms seed = _foam_sources(
		xz, reset_state || arrived || debug_birth, birth, surf_zone, crest, current
	);
	vec3 next;
	if (debug_birth) {
		next = vec3(birth, crest, seed.density);
	} else if (reset_state || arrived) {
		next = vec3(seed.density, seed.fresh, seed.windrow);
	} else {
		vec3 c = _state_at(p);
		// R-1734: in the surf zone of an oblique sea the longshore current carries the
		// foam along the beach. The window drift above moves the whole buffer; this
		// varies per texel, so it is a semi-Lagrangian step (read upstream, filtered).
		// Bilinear reads blur a little, which the short surf foam life hides.
		vec2 upstream = current * step_dt / texel_world;
		if (dot(upstream, upstream) > CURRENT_MIN_TEXELS * CURRENT_MIN_TEXELS) {
			c = _state_bilinear(vec2(p) + 0.5 - upstream);
		}
		float life = mix(WHITECAP_LIFE, CITY_SURF_FOAM_LIFE, surf_zone);
		float density = max(c.r * exp(-step_dt / life), birth);
		float fresh = max(c.g * exp(-step_dt / FRESH_LIFE), birth);
		// Windrows: smear along the wind axis (a 1D diffusion in the wind frame),
		// then feed from the foam and decay. Surf foam does not form windrows.
		vec2 along = _fft_wind_axis();
		vec2 from = vec2(p) + 0.5;
		float smeared = 0.5 * (_windrow_at(from + along) + _windrow_at(from - along));
		float windrow = mix(c.b, smeared, clamp(WINDROW_SMEAR * step_dt, 0.0, 0.5));
		windrow = windrow * exp(-step_dt / WINDROW_LIFE)
			+ density * WINDROW_FEED * step_dt * (1.0 - surf_zone);
		next = vec3(density, fresh, min(windrow, 1.0));
	}
	COLOR = vec4(clamp(next, vec3(0.0), vec3(1.0)), 1.0);
}
