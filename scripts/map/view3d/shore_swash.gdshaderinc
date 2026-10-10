// WS-08 shore swash, shared by the water shader and the blended-ground terrain.
//
// Ported from Tidewater (MIT), see notice.code.tidewater: ShoreParams (period 9,
// amplitude 0.34, variation 0.55, gamma 0.78, breakSpan 0.13, curl 1, runup 1,
// turbidity 0.16), ShoreSimParams (dryTime 28, foamLife 4.5, surfFoamLife 2.6,
// residueLife 5) and the shore fragment's foam bead, trailing foam and meniscus.
//
// WHY analytic: Tidewater carries wetness and foam between frames in compute
// buffers, which GL Compatibility cannot do. Here every value is a pure, periodic
// function of (shore distance, world position, ocean_time, sea state), so
// the water surface, the swash sheet and the wet sand evaluate the same wave and
// always agree, with no simulation texture and no per-frame CPU work.
//
// Hosts must declare `global uniform float ocean_time;` before including.

// Per-map signed distance field baked by MapViewMeshBuilderTerrainWater:
// R = distance in world units (+ water, - land, clamped to +-8), GB = unit
// direction towards land (0..1 encoded), A = 1 beach / 0 hard edge.
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 shore_field_origin = vec2(0.0);
uniform vec2 shore_field_size = vec2(1.0);
// 0 on maps without a sea shoreline: every swash path is skipped.
uniform float shore_field_valid = 0.0;
// Scalar sea state 0..1 (MapViewWaterMaterials.fft_sea_state_scalar, clamped).
uniform float shore_sea_state = 0.35;
// Per water family: 1 open sea, 0.3 ponds (slosh only), 0 rivers (off).
uniform float shore_strength = 1.0;
// World units the waterline has moved at the current tide: 0 at high water,
// negative (seaward) during the ebb.
uniform float shore_tide_offset = 0.0;
// Art-direction lever (ADR 0018). The physical run-up of a 0.2 m Baltic breaker
// is about 0.4 m, which does not read from the gameplay camera; this gain keeps a
// visible uprush that still stays inside the 3-unit sheet in a storm.
uniform float shore_runup_gain = 3.2;
// Scale of the breaker height (shore_state h_deep). 1 keeps the district maps; the
// seamless city (1 m per unit, open Baltic) raises it so a gale throws a tall surf
// where a calm day only laps.
uniform float shore_wave_gain = 1.0;
// Multiplies the idealised beach depth (_swash_depth). 1 keeps the district maps. The
// city bakes its field with distances divided by this factor (CityShoreField), so one
// field unit spans that many world units and its breakers can be metres wide and
// about a metre tall instead of the district's 0.25 m ripple.
uniform float shore_depth_scale = 1.0;
// Scales the breaker foam (bore_foam). 1 keeps the district maps; the city lifts it so
// a metre-tall surf reads as white water, not a thin line.
uniform float shore_foam_gain = 1.0;
// WR-1 crest shape. 0 keeps the district profile; 1 (city) rounds the crest of
// a spilling breaker: a milder skew, a broader top and only a hint of the curl
// that pushed the crest over its own face into a sharp lip.
uniform float shore_crest_shape = 0.0;
// WR-4 bathymetry, baked by CityShoreField.bake on the shore_field grid (same
// origin and size): R still-water depth (m), G crest travel time from the offshore
// source line (s, -1 where no wave arrives; land copies its waterline's time),
// B beach-face slope tan(beta) of the nearest shore, A controlling depth (the
// shallowest depth the wave crossed). shore_bed_valid 0 (district maps) keeps the
// idealised beach below; 1 (the city) lets the waves feel this bed. Then the bound
// shore_field is a side-by-side atlas: distance field left, bathymetry right. WHY
// one sampler: the water shader already sits at GL Compatibility's limit of 16
// fragment samplers.
uniform float shore_bed_valid = 0.0;

// shore_field uv of one atlas half (0 field, 1 bed); plain uv without the atlas.
// The clamp keeps each half clamp-to-edge, so the seam never blends field and bed.
vec2 shore_atlas_uv(vec2 uv, float half_index) {
	if (shore_bed_valid < 0.5) {
		return uv;
	}
	float edge = 0.5 / float(textureSize(shore_field, 0).x);
	return vec2(clamp(uv.x * 0.5, edge, 0.5 - edge) + 0.5 * half_index, uv.y);
}

// Deviation from Tidewater's sea-state-scaled period (9 s * mix(1.2, 0.8, sea)):
// ocean_time is an absolute clock, so a period that follows the weather would
// scroll the phase by t * dP / P^2 during every weather transition. The period is
// fixed at ~9 s and quantised so the wrap of ocean_time (25.6 * 64 s, see
// MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS) holds a whole number of
// 7-wave sets: 182 waves = 26 sets, so the wrap is seamless. Sea state still
// drives height, break point, run-up and foam.
const float SHORE_OCEAN_TIME_WRAP = 1638.4;
const float SHORE_WAVES_PER_WRAP = 182.0;
const float SHORE_PERIOD = SHORE_OCEAN_TIME_WRAP / SHORE_WAVES_PER_WRAP;
const float SHORE_AMPLITUDE = 0.34;
const float SHORE_VARIATION = 0.55;
const float SHORE_GAMMA = 0.78;
const float SHORE_BREAK_SPAN = 0.13;
const float SHORE_CURL = 1.0;
const float SHORE_RUNUP = 1.0;
const float SHORE_TURBIDITY = 0.16;
const float SHORE_DRY_TIME = 28.0;
const float SHORE_FOAM_LIFE = 4.5;
const float SHORE_SURF_FOAM_LIFE = 2.6;
const float SHORE_RESIDUE_LIFE = 5.0;
// Last stretch of the sheet (world units) that bends down to the sand.
const float SHORE_MENISCUS = 0.14;
const float SHORE_BEACH_SLOPE = 0.05;
const float SHORE_METERS_PER_UNIT = 0.87;
// Field clamp: the crest enters the field here (world units offshore).
const float SHORE_OFFSHORE = 8.0;
// Cycle fraction the incoming crest spends crossing the field; it reaches the
// waterline exactly when the next cycle (and its run-up) starts.
const float SHORE_APPROACH = 0.45;
// Cycle fraction of the uprush; the slower backwash takes the rest.
const float SHORE_UPRUSH = 0.35;
// Waves per set. The envelope is strictly periodic in the wave index so the
// wet-time lookback below always contains the largest wave of the last set.
const float SHORE_SET_WAVES = 7.0;
const int SHORE_LOOKBACK = 8;
// Run-up clamp, just inside MapViewMeshBuilderTerrainWater.SHORE_SHEET_REACH.
const float SHORE_MAX_RUNUP = 2.9;
// City rundown: share of the run-up reach the backwash draws the edge below the
// still-water line before the next bore (CityWaterSurface.RUNDOWN mirrors it).
const float SHORE_RUNDOWN = 0.3;
const float SHORE_NEVER_WET = 10000.0;
// WR-4 bed-aware surf (shore_bed_valid), mirrored by CityWaterSurface.
// Deep-water wavelength of the fixed shore period, L0 = g T^2 / (2 pi).
const float BED_L0 = 9.81 * SHORE_PERIOD * SHORE_PERIOD / 6.2831853;
// Depth (m) at which shore_wave_gain x SHORE_AMPLITUDE x energy is the wave height;
// Green's law H ~ h^-1/4 shoals it from there.
const float BED_REF_DEPTH = 4.0;
const float BED_MIN_DEPTH = 0.05;
// Seconds of travel from the source line over which the train grows in.
const float BED_ONSET = 3.0;
// Slow alongshore phase scatter (cycles): the travel time already varies the
// arrival along the coast, so far less than the district's 0.55.
const float BED_PHASE_VARIATION = 0.15;
// Cap on the local seaward-facing bed slope in the Iribarren number. WHY: the
// breaker sees the slope over about a quarter wavelength; a 3 m boulder dome
// differenced over one 2 m texel is not a 1:1 beach.
const float BED_LOCAL_SLOPE_MAX = 0.1;
// Breaker class blends on xi_b (Battjes 1974: spilling < 0.4, plunging 0.4-2,
// collapsing / surging > 2). The plunging blend sits a little above 0.4 so a
// 1:25-1:30 sand beach stays spilling at the fixed 9 s period (a long L0 that
// already overstates xi for the Baltic wind sea); the surging blend is centred on 2.
const vec2 BED_PLUNGE_XI = vec2(0.45, 0.8);
const vec2 BED_SURGE_XI = vec2(1.6, 2.4);
// Crest half-width as a share of the local wavelength.
const float BED_CREST_WIDTH = 0.24;

struct ShoreState {
	float valid;            // 0..1, fades out at the field clamp
	float distance;         // signed world units after the tide shift (+ water)
	vec2 to_land;           // unit direction towards land
	float beach;            // 1 beach, 0 hard edge
	float height;           // shore wave height, world units (water side)
	float curl;             // crest-top push towards land, world units
	float bore_foam;        // broken-wave foam in the surf zone
	float surf_zone;        // 0..1 mask shoreward of the break point (beaches)
	float wet;              // 1 while the swash sheet covers this point
	float sheet_thickness;  // metres of water in the sheet
	float front_distance;   // world units behind the moving front (+ = covered)
	float front_foam;       // bead at the front plus the trail behind it
	float time_since_wet;   // seconds, SHORE_NEVER_WET if the swash never reaches
	float residue;          // foam line left at the highest reach
	float slosh;            // hard-edge vertical slosh, world units
	float wall_foam;        // foam at the foot of a quay or rock edge
	float surge;            // WR-2 landward water excursion in the surf zone, world units
	float foam_age;         // WR-2 seconds since the bore passed this point (surf zone)
	float plunge;           // WR-4 0 spilling .. 1 plunging (Iribarren number)
	float surging;          // WR-4 0 breaking .. 1 collapsing / surging (steep shore)
	float backwash;         // WR-9 0 during the uprush, 0..1 progress of the backwash
	float edge_feather;     // world units over which the film thins out behind its front
	float rundown;          // city: world units the backwash has drawn below the still-water line
};


float _swash_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float _swash_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(_swash_hash(cell), _swash_hash(cell + vec2(1.0, 0.0)), local.x),
		mix(_swash_hash(cell + vec2(0.0, 1.0)), _swash_hash(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

vec4 shore_sea() {
	return vec4(shore_sea_state, shore_strength, shore_tide_offset, shore_runup_gain);
}

// Water depth (metres) of the idealised beach profile at a water-side distance.
float _swash_depth(float x) {
	return max(x, 0.02) * SHORE_METERS_PER_UNIT * SHORE_BEACH_SLOPE * shore_depth_scale;
}

float _swash_set_envelope(float wave_index) {
	return 0.62 + 0.38 * (0.5 + 0.5 * sin(6.2831853 * wave_index / SHORE_SET_WAVES + 1.3));
}

// Per-wave noise offset. The wave index is taken modulo the 182-wave wrap so the
// pattern repeats exactly when ocean_time wraps (seamless, like the set envelope).
vec2 _swash_wave_seed(float wave_index) {
	float m = mod(wave_index, SHORE_WAVES_PER_WRAP);
	return vec2(fract(m * 0.6180340), fract(m * 0.7548777)) * 61.0;
}

// Run-up reach multiplier (mean 1, 0.6..1.4). WHY: one smooth noise shared by every
// wave drew the front as a clean contour that came back to the same line each
// time. Real uprush breaks into tongues and lobes (metres) with ragged fingers,
// and each wave lays them down somewhere else. Mirrored by
// CityWaterSurface.reach_variation. `steady` is _swash_noise(world_xz * 0.11 +
// (0, 17.3)), passed in so the wetting-history loop evaluates it once.
float _swash_reach_variation(vec2 world_xz, float wave_index, float steady) {
	vec2 seed = _swash_wave_seed(wave_index);
	float lobes = _swash_noise(world_xz * 0.23 + seed);
	float fingers = _swash_noise(world_xz * 0.9 + seed.yx * 1.7);
	return 0.6 + 0.25 * steady + 0.4 * lobes + 0.15 * fingers;
}

// Width (world units) of the thinning film tip, 0.12..0.67. A swash tip is a
// broken, sand-studded film, so the water fades out over a ragged band instead
// of ending in one sharp line. It morphs into the next wave's pattern over the
// cycle (u), so a part-covered tip pixel never pops at the wave boundary.
// Mirrored by CityWaterSurface.edge_feather.
float _swash_edge_feather(vec2 world_xz, float wave_index, float u) {
	float now = _swash_noise(world_xz * 2.7 + _swash_wave_seed(wave_index) * 0.37);
	float next = _swash_noise(world_xz * 2.7 + _swash_wave_seed(wave_index + 1.0) * 0.37);
	return 0.12 + 0.55 * mix(now, next, u);
}

// Sheet front (world units inland) during one cycle: ease-out uprush, then an
// ease-in backwash that starts slowly and drains back over the longer remainder.
// WR-4 `drain` (0 district, surging share in the city) pulls the backwash in
// earlier and harder, the strong return flow of a reflective shore.
float _swash_front(float u, float reach, float drain) {
	if (u < SHORE_UPRUSH) {
		float a = 1.0 - u / SHORE_UPRUSH;
		return reach * (1.0 - a * a);
	}
	float b = (u - SHORE_UPRUSH) / (1.0 - SHORE_UPRUSH);
	return reach * (1.0 - (drain > 0.0 ? pow(b, mix(2.0, 1.2, drain)) : b * b));
}

// WR-4 depth (m) at which this sea state breaks: Green's law H = H_ref (h_ref / h)^1/4
// from BED_REF_DEPTH meets H = gamma h.
float _shore_bed_break_depth(float h_deep) {
	return pow(h_deep * pow(BED_REF_DEPTH, 0.25) / SHORE_GAMMA, 0.8);
}

// WR-4 crest profile over one local wavelength. rel is metres from the crest
// (+ seaward, behind it); the shoreward face shortens as the wave steepens,
// more for plunging, barely for surging.
float _shore_bed_profile(float rel, float wavelength, float steep, float plunge, float surging) {
	float width = max(BED_CREST_WIDTH * wavelength, 1.5);
	float face_k = mix(mix(0.65, 0.42, plunge), 0.9, surging);
	float face = rel < 0.0 ? width * mix(1.0, face_k, steep) : width;
	float phase = clamp(rel / face, -1.0, 1.0) * 3.14159265;
	// Same GLES guard as the district profile: never a negative pow() base.
	float base = max(0.5 + 0.5 * cos(phase), 0.000001);
	return pow(base, 1.0 + mix(mix(0.8, 1.8, plunge), 0.5, surging) * steep);
}

// WR-4 water side of the bed-aware surf. bed, bed_dx, bed_dz are the shore_bed
// texel here and one texel along +x / +z; cell is world units per texel.
ShoreState _shore_bed_water(
	ShoreState s, vec4 bed, vec4 bed_dx, vec4 bed_dz, vec2 cell, float u, float h_deep,
	float sea_state, float strength, float field_distance
) {
	float h = max(bed.r, BED_MIN_DEPTH);
	float h_ctrl = clamp(bed.a, BED_MIN_DEPTH, h);
	vec2 grad_h = vec2(bed_dx.r - bed.r, bed_dz.r - bed.r) / cell;
	vec2 travel = s.to_land;
	// Bed slope met by the wave (depth falling along its travel).
	float up = clamp(-dot(grad_h, travel), 0.0, BED_LOCAL_SLOPE_MAX);
	float tan_beta = max(bed.b, up);
	// Iribarren number with the breaker height of this sea state. Re-formed
	// waves behind a bar keep it: their own, lower re-break is spilling anyway.
	float breaker = SHORE_GAMMA * _shore_bed_break_depth(h_deep);
	float xi = tan_beta / sqrt(max(breaker, 0.02) / BED_L0);
	s.plunge = smoothstep(BED_PLUNGE_XI.x, BED_PLUNGE_XI.y, xi);
	s.surging = smoothstep(BED_SURGE_XI.x, BED_SURGE_XI.y, xi);
	if (s.distance < 0.0) {
		return s;
	}
	// Shoaling from the reference depth, capped by the shallowest depth crossed:
	// a wave that broke on a bar or reef travels on at gamma x that depth and
	// only breaks again where the bed rises above the bar.
	float shoal = h_deep * pow(BED_REF_DEPTH / h, 0.25);
	float height = min(shoal, SHORE_GAMMA * h_ctrl);
	float steep = clamp(height / (SHORE_GAMMA * h), 0.0, 1.0);
	float breaking = smoothstep(0.9, 1.0, steep);
	float broke_before = smoothstep(
		0.92, 1.0, h_deep * pow(BED_REF_DEPTH / h_ctrl, 0.25) / (SHORE_GAMMA * h_ctrl)
	);
	float reformed = broke_before * (1.0 - breaking);
	// Eckart (1952): L = L0 sqrt(tanh(2 pi h / L0)), so trains shorten as they slow.
	float wavelength = BED_L0 * sqrt(tanh(6.2831853 * h / BED_L0));
	float onset = smoothstep(0.0, BED_ONSET, bed.g);
	float rel = (u < 0.5 ? u : u - 1.0) * wavelength;
	float incident = height * onset
		* _shore_bed_profile(rel, wavelength, steep, s.plunge, s.surging);
	// Reflection off the shore, Battjes R = 0.1 xi^2 on the beach face: a crest
	// leaves the waterline as the incident one arrives and dies off within about
	// half a wavelength. Quays (xi >> 3) reflect fully and stand. The reflected
	// crest adds R x H / 2: this lift-only profile already draws the incident crest
	// at the full height H (troughs are not drawn), so a second full H would make a
	// standing crest four times its physical elevation and overtop the quays.
	float xi_face = bed.b / sqrt(max(breaker, 0.02) / BED_L0);
	float reflect_k = clamp(0.1 * xi_face * xi_face, 0.0, 1.0);
	float to_shore = max(field_distance, 0.0) * shore_depth_scale;
	float u_back = fract(u - 2.0 * to_shore / wavelength);
	float reflected = reflect_k * 0.5 * height * onset * exp(-to_shore / (0.5 * wavelength))
		* _shore_bed_profile((u_back < 0.5 ? u_back : u_back - 1.0) * wavelength, wavelength,
			steep, 0.0, 1.0);
	s.height = incident + reflected;
	s.curl = SHORE_CURL * mix(0.3, 0.7, s.plunge * (1.0 - s.surging)) * incident
		* smoothstep(0.6, 1.0, steep);
	float since_pass = u * SHORE_PERIOD;
	s.surf_zone = max(breaking, 0.5 * reformed) * (1.0 - 0.7 * s.surging);
	float bore = exp(-since_pass / SHORE_SURF_FOAM_LIFE) * mix(0.55, 1.0, exp(-since_pass / 0.6));
	bore = max(bore, exp(-since_pass / SHORE_FOAM_LIFE) * 0.25 * s.surf_zone);
	bore *= smoothstep(0.0, 0.18, since_pass);
	// Plunging: the jet hits the trough, a burst of foam just after the crest.
	bore *= 1.0 + 0.8 * s.plunge * (1.0 - s.surging) * exp(-since_pass / 0.9);
	// Surging: the wave slides up the face without breaking; little foam.
	float broken = max(breaking, 0.35 * reformed) * (1.0 - 0.8 * s.surging) * onset;
	s.bore_foam = broken * bore * mix(0.7, 1.0, sea_state) * shore_foam_gain;
	// WR-2 contract: landward excursion under the bore and seconds since it passed.
	float excursion = 0.5 * height * sqrt(9.81 / h) * SHORE_PERIOD / 6.2831853;
	s.surge = min(excursion, 4.0) * (smoothstep(0.0, 0.12, u) - u) * broken;
	s.foam_age = mix(SHORE_NEVER_WET, since_pass, broken);
	// The reflected crest replaces the district wall slosh; the wall foam stays.
	s.slosh = 0.0;
	float slosh_phase = sin(6.2831853 * u);
	s.wall_foam = exp(-s.distance / 0.45) * (0.45 + 0.55 * max(slosh_phase, 0.0))
		* mix(0.5, 1.0, sea_state) * strength * (1.0 - s.beach);
	return s;
}

// Two octaves of patch noise so foam lines never read as an even white rope
// (Tidewater edgePatch).
float _swash_patch(vec2 world_xz, float t) {
	float coarse = _swash_noise(world_xz * 3.1 + vec2(t * 0.35, -t * 0.21));
	float fine = _swash_noise(world_xz * 7.3 - vec2(t * 0.52, t * 0.13));
	return smoothstep(0.30, 0.72, coarse * 0.65 + fine * 0.35);
}

// sea = (sea state 0..1, family strength, tide offset, run-up gain); see shore_sea().
ShoreState shore_state(vec2 world_xz, float t, vec4 sea) {
	ShoreState s;
	s.valid = 0.0;
	s.distance = SHORE_OFFSHORE;
	s.to_land = vec2(0.0);
	s.beach = 0.0;
	s.height = 0.0;
	s.curl = 0.0;
	s.bore_foam = 0.0;
	s.surf_zone = 0.0;
	s.wet = 0.0;
	s.sheet_thickness = 0.0;
	s.front_distance = -1.0;
	s.front_foam = 0.0;
	s.time_since_wet = SHORE_NEVER_WET;
	s.residue = 0.0;
	s.slosh = 0.0;
	s.wall_foam = 0.0;
	s.surge = 0.0;
	s.foam_age = SHORE_NEVER_WET;
	s.backwash = 0.0;
	s.edge_feather = 0.12;
	s.rundown = 0.0;
	s.plunge = 0.0;
	s.surging = 0.0;
	if (shore_field_valid < 0.5 || sea.y <= 0.0) {
		return s;
	}
	vec2 uv = (world_xz - shore_field_origin) / shore_field_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return s;
	}
	vec4 field = textureLod(shore_field, shore_atlas_uv(uv, 0.0), 0.0);
	vec2 dir = field.gb * 2.0 - 1.0;
	float dir_length = length(dir);
	// WR-4: the bed-aware surf reaches past the shore field (bars, reefs), so it
	// keeps going where no shoreline is within the field clamp.
	bool bed_mode = shore_bed_valid > 0.5;
	vec4 bed = vec4(0.0, -1.0, 0.0, 0.0);
	vec4 bed_dx = bed;
	vec4 bed_dz = bed;
	vec2 bed_cell = vec2(1.0);
	if (bed_mode) {
		// One bed texel in the field's uv (the atlas is two fields wide).
		vec2 texel = vec2(2.0, 1.0) / vec2(textureSize(shore_field, 0));
		bed_cell = shore_field_size * texel;
		bed = textureLod(shore_field, shore_atlas_uv(uv, 1.0), 0.0);
		bed_dx = textureLod(shore_field, shore_atlas_uv(uv + vec2(texel.x, 0.0), 1.0), 0.0);
		bed_dz = textureLod(shore_field, shore_atlas_uv(uv + vec2(0.0, texel.y), 1.0), 0.0);
	}
	if (dir_length < 0.2 && !bed_mode) {
		// No shoreline within the field clamp (or two shores cancel in the filter).
		return s;
	}
	dir = dir_length > 0.0001 ? dir / dir_length : vec2(0.0);
	float x = field.r + sea.z;
	s.valid = 1.0 - smoothstep(SHORE_OFFSHORE - 1.0, SHORE_OFFSHORE, abs(field.r));
	s.distance = x;
	s.to_land = dir;
	s.beach = smoothstep(0.35, 0.65, field.a);
	if (bed_mode) {
		// Inside the wave zone (travel time >= 0) on the water side; the land side
		// still fades at the field clamp.
		s.valid = smoothstep(-0.9, -0.1, bed.g) * smoothstep(-0.9, -0.1, min(bed_dx.g, bed_dz.g))
			* (1.0 - smoothstep(SHORE_OFFSHORE - 1.0, SHORE_OFFSHORE, max(-field.r, 0.0)));
		// Waves travel along the travel-time gradient (refracted rays); land
		// copies its waterline's time, so there the shore normal takes over.
		vec2 grad_tau = vec2(bed_dx.g - bed.g, bed_dz.g - bed.g) / bed_cell;
		float ray = smoothstep(0.02, 0.06, length(grad_tau)) * step(0.2, s.valid);
		vec2 travel = mix(dir, grad_tau / max(length(grad_tau), 0.0001), ray);
		s.to_land = length(travel) > 0.0001 ? normalize(travel) : vec2(0.0);
	}

	float sea_state = clamp(sea.x, 0.0, 1.0);
	// Calm Baltic days still lap at the sand; family strength scales everything.
	float energy = mix(0.35, 1.0, sea_state) * sea.y;
	float period = SHORE_PERIOD;
	// Use a continuous world-space field for phase and reach. Projecting absolute
	// coordinates onto the changing nearest-shore tangent makes phase islands at
	// bends/quays: centimetres of travel can jump the crest and its foam by seconds.
	float cycle = t / period + SHORE_VARIATION * _swash_noise(world_xz * 0.05 + vec2(0.0, 3.7));
	if (bed_mode) {
		// WR-4: the crest passes here travel-time seconds after it left the source
		// line, so crests are lines of equal travel time: refracted and shoaled by
		// the bake. A static offset keeps the 182-wave ocean_time wrap seamless.
		cycle = (t - max(bed.g, 0.0)) / period
			+ BED_PHASE_VARIATION * _swash_noise(world_xz * 0.02 + vec2(0.0, 3.7));
	}
	float wave_index = floor(cycle);
	float u = cycle - wave_index;

	// Shoaling H = A (d0 / d)^0.25 breaks where H > gamma d. Solving for d gives
	// the break depth; the break point is clamped inside the field.
	float d0 = _swash_depth(SHORE_OFFSHORE);
	float h_deep = SHORE_AMPLITUDE * energy * shore_wave_gain;
	float break_depth = pow(h_deep * pow(d0, 0.25) / SHORE_GAMMA, 0.8);
	float break_x = min(
		break_depth / (SHORE_METERS_PER_UNIT * SHORE_BEACH_SLOPE * shore_depth_scale), SHORE_OFFSHORE - 0.5
	);
	float breaker_height = SHORE_GAMMA * _swash_depth(break_x);
	s.surf_zone = (1.0 - smoothstep(break_x * 0.85, break_x * 1.1, x)) * step(0.0, x) * s.beach;

	float drain = 0.0;
	if (bed_mode) {
		// breaker_height stays the district value: the run-up gains were calibrated
		// on it, and the bed's taller breaker (Green's law from 4 m) pinned every
		// storm run-up at SHORE_MAX_RUNUP, a film across the city paving.
		s = _shore_bed_water(s, bed, bed_dx, bed_dz, bed_cell, u, h_deep, sea_state, sea.y, x);
		drain = s.surging;
	}
	if (x >= 0.0 && !bed_mode) {
		// Incoming crest: enters the field at u = 1 - SHORE_APPROACH, slows as the
		// water shallows (celerity ~ sqrt(g d)) and reaches the waterline at u = 1.
		float approach = clamp((1.0 - u) / SHORE_APPROACH, 0.0, 1.0);
		float crest_x = SHORE_OFFSHORE * pow(approach, 0.8);
		float crest_depth = _swash_depth(crest_x);
		float crest_h = h_deep * pow(d0 / crest_depth, 0.25);
		float steep = clamp(crest_h / (SHORE_GAMMA * crest_depth), 0.0, 1.0);
		crest_h = min(crest_h, SHORE_GAMMA * crest_depth);
		// Skewed profile pow(0.5 + 0.5 cos phi, 1 + 2 steep): the shoreward face
		// shortens and the crest sharpens as the wave approaches breaking.
		float rel = x - crest_x;
		float round_crest = clamp(shore_crest_shape, 0.0, 1.0);
		float width = mix(2.4, 1.4, steep) * mix(1.0, 1.3, round_crest);
		float face = rel < 0.0 ? width * mix(1.0, mix(0.4, 0.65, round_crest), steep) : width;
		float phase = clamp(rel / face, -1.0, 1.0) * 3.14159265;
		// GLES cos(PI) can undershoot -1 by one ulp. A negative base raised
		// to the fractional steepness exponent poisons height/normal with NaN,
		// producing flat dark polygons everywhere outside the crest.
		float profile_base = max(0.5 + 0.5 * cos(phase), 0.000001);
		float profile = pow(profile_base, 1.0 + mix(2.0, 0.8, round_crest) * steep);
		float incoming = step(1.0 - SHORE_APPROACH, u)
			* (1.0 - smoothstep(SHORE_OFFSHORE - 1.5, SHORE_OFFSHORE, crest_x));
		s.height = crest_h / SHORE_METERS_PER_UNIT * profile * incoming * s.beach;
		s.curl = SHORE_CURL * mix(1.0, 0.3, round_crest)
			* s.height * profile * smoothstep(0.6, 1.0, steep);
		// Bore: shoreward of the break point, foam trails the crest for
		// surfFoamLife seconds after it passes, brightest just behind the front.
		float u_pass = 1.0 - SHORE_APPROACH * pow(clamp(x / SHORE_OFFSHORE, 0.0, 1.0), 1.25);
		float since_pass = fract(u - u_pass) * period;
		float broken = 1.0 - smoothstep(break_x, break_x * (1.0 + SHORE_BREAK_SPAN) + 0.3, x);
		float bore = exp(-since_pass / SHORE_SURF_FOAM_LIFE) * mix(0.55, 1.0, exp(-since_pass / 0.6));
		// Older foam lingers faintly over the whole surf zone (foamLife).
		bore = max(bore, exp(-since_pass / SHORE_FOAM_LIFE) * 0.25 * s.surf_zone);
		// Air entrains over a short interval instead of the fract() wrap painting
		// a fully white front in one frame. Decay still trails the advancing bore.
		bore *= smoothstep(0.0, 0.18, since_pass);
		s.bore_foam = broken * bore * s.beach * mix(0.7, 1.0, sea_state) * shore_foam_gain;
		// WR-2: water under a broken wave lunges landward as the bore passes
		// (fast, first ~12% of the cycle) and drifts back over the rest, so it is
		// back at rest when the next bore arrives (the cycle mean is ~0.44 of the
		// excursion landward; only foam reads it). Shallow-water excursion ~ H/2 sqrt(g/h) T / (2 pi):
		// metres for a metre-high breaker, so foam visibly surges in and out.
		float pass_phase = fract(u - u_pass);
		float local_depth = max(_swash_depth(x), 0.05);
		float excursion = 0.5 * breaker_height * sqrt(9.81 / local_depth) * period / 6.2831853
			/ SHORE_METERS_PER_UNIT;
		s.surge = min(excursion, 4.0) * (smoothstep(0.0, 0.12, pass_phase) - pass_phase)
			* broken * s.beach;
		s.foam_age = mix(SHORE_NEVER_WET, since_pass, broken * s.beach);
		// Hard edges: no run-up, the water column sloshes against the wall.
		float wall = 1.0 - s.beach;
		float slosh_phase = sin(6.2831853 * u);
		s.slosh = h_deep * 0.5 * slosh_phase / SHORE_METERS_PER_UNIT * exp(-x / 1.5) * wall;
		s.wall_foam = exp(-x / 0.45) * (0.45 + 0.55 * max(slosh_phase, 0.0))
			* mix(0.5, 1.0, sea_state) * sea.y * wall;
	}

	if (s.beach <= 0.0) {
		return s;
	}
	float land = -x;
	float steady_reach = _swash_noise(world_xz * 0.11 + vec2(0.0, 17.3));
	float base_reach = SHORE_RUNUP * breaker_height * 1.8 / SHORE_METERS_PER_UNIT * sea.w;
	float reach_now = min(
		base_reach * _swash_reach_variation(world_xz, wave_index, steady_reach)
			* _swash_set_envelope(wave_index),
		SHORE_MAX_RUNUP
	);
	s.edge_feather = _swash_edge_feather(world_xz, wave_index, u);
	float front = _swash_front(u, reach_now, drain);
	float uprush = 1.0 - step(SHORE_UPRUSH, u);
	s.backwash = clamp((u - SHORE_UPRUSH) / (1.0 - SHORE_UPRUSH), 0.0, 1.0);
	// City (bed mode): late in the backwash the water drains below the still-water
	// line and the next bore floods it again. WHY: without it the sea always
	// covered every bed below the mean level, so that contour stood as a fixed,
	// sharp line (straight on planar beach faces) while only the run-up moved.
	// Static reach terms only, so it is continuous across the wave wrap.
	float rundown = 0.0;
	if (bed_mode) {
		float drained = max(smoothstep(0.6, 1.0, u), 1.0 - smoothstep(0.0, 0.12, u));
		rundown = SHORE_RUNDOWN * base_reach * (0.6 + 0.8 * steady_reach) * drained;
	}
	s.rundown = rundown;
	s.front_distance = front - rundown - land;
	s.wet = step(0.0, land) * step(land, front) * step(0.001, front);
	s.sheet_thickness = 0.045 * energy
		* sqrt(clamp(s.front_distance / max(front, 0.05), 0.0, 1.0))
		* mix(mix(0.45, 0.9, drain), 1.0, uprush);
	// A narrow bright bead sits just behind the front, a thinner trail behind it.
	float bead_coordinate = (s.front_distance - 0.08) / 0.06;
	float bead = exp(-bead_coordinate * bead_coordinate);
	// Not named `trail`: city_ground.gdshader declares a `trail` uniform.
	float front_trail = smoothstep(0.0, 0.1, s.front_distance)
		* exp(-max(s.front_distance, 0.0) / 0.45) * 0.55;
	s.front_foam = (bead + front_trail) * mix(0.3, 1.0, _swash_patch(world_xz, t))
		* mix(0.5, 1.0, uprush) * step(0.02, front) * s.beach * (1.0 - 0.6 * drain);

	if (land >= 0.0) {
		// Periodic model => analytic wetting history. Walk back over the last set:
		// the newest wave whose reach covers this point decides the wet time, and
		// every wave's highest reach leaves a residue line that fades in 5 s.
		bool found = false;
		for (int k = 0; k < SHORE_LOOKBACK; k++) {
			float m = wave_index - float(k);
			float reach = min(
				base_reach * _swash_reach_variation(world_xz, m, steady_reach)
					* _swash_set_envelope(m),
				SHORE_MAX_RUNUP
			);
			float elapsed = cycle - m;
			float since_peak = (elapsed - SHORE_UPRUSH) * period;
			if (since_peak >= 0.0) {
				float line = 1.0 - smoothstep(0.0, 0.07, abs(land - reach));
				s.residue = max(s.residue, line * exp(-since_peak / SHORE_RESIDUE_LIFE));
			}
			if (!found && land <= reach) {
				float r = sqrt(max(1.0 - land / max(reach, 0.001), 0.0));
				float u_up = SHORE_UPRUSH * (1.0 - r);
				// Backwash inverse of _swash_front (b^p = 1 - land / reach).
				float drained = drain > 0.0
					? pow(max(1.0 - land / max(reach, 0.001), 0.0), 1.0 / mix(2.0, 1.2, drain))
					: r;
				float u_down = SHORE_UPRUSH + (1.0 - SHORE_UPRUSH) * drained;
				if (elapsed >= u_up) {
					s.time_since_wet = max(elapsed - u_down, 0.0) * period;
					found = true;
				}
			}
		}
		s.residue *= s.beach * _swash_patch(world_xz * 0.6, 0.0);
	}
	return s;
}

// WR-9 beach response. The bed reads porosity from its own slope: backwash that
// percolates into shingle cannot carry the stones back down, so pebble beaches
// stand at 1:8..1:4 while fine sand stays at 1:20..1:50. The same slope test
// works in the city and the sandbox without a land-use texture.
const float SHORE_SHINGLE_DRY_TIME = 9.0;  // seconds, wet pebbles drain and dull
const float SHORE_GLISTEN_TIME = 4.0;      // seconds a standing film mirrors on sand
const float SHORE_SHINGLE_GLISTEN_TIME = 0.8;
// Nominal pebble diameter (metres) of the shingle the film runs over; tops
// within this of the film surface break through it.
const float SHORE_PEBBLE_SIZE = 0.05;

struct ShoreBeach {
	float wet;        // 0..1 bed darkening: 1 under water, dries over the dry time
	float glisten;    // 0..1 standing water film just after the backwash left
	float film_keep;  // 0..1 share of the swash film still above the bed
	float foam_keep;  // 0..1 share of the swash foam not drained into the gaps
};

// tan(beta) of the local bed -> 0 sand .. 1 shingle.
float shore_porosity(float tan_beta) {
	return smoothstep(0.07, 0.11, tan_beta);
}

// Bed and film response to the analytic swash history. `porosity` 0 sand .. 1 shingle.
ShoreBeach shore_beach(ShoreState s, float porosity) {
	ShoreBeach b;
	float p = clamp(porosity, 0.0, 1.0);
	float since = s.time_since_wet;
	// Sea side of the waterline and under the sheet: fully wet, film standing.
	float covered = max(step(0.0, s.distance), s.wet);
	b.wet = max(covered, exp(-since / mix(SHORE_DRY_TIME, SHORE_SHINGLE_DRY_TIME, p))) * s.valid;
	b.glisten = max(s.wet, exp(-since / mix(SHORE_GLISTEN_TIME, SHORE_SHINGLE_GLISTEN_TIME, p)))
		* s.beach * s.valid * step(s.distance, 0.0);
	// Backwash over shingle sinks into the bed: the film thins far faster than
	// the front retreats (the front itself stays analytic, so wet time agrees).
	float drain = smoothstep(0.0, 0.55, s.backwash);
	b.film_keep = 1.0 - p * drain * 0.85;
	// Bubbles pop into the gaps: foam dies within the first part of the backwash
	// over pebbles, and even the uprush bead is thinner than on sand.
	b.foam_keep = mix(1.0, mix(0.6, 0.0, smoothstep(0.0, 0.3, s.backwash)), p);
	return b;
}

// 0..1 share of a thin film over shingle that still hides the stones: crowns of
// SHORE_PEBBLE_SIZE pebbles break through once the film is thinner than they are
// tall. A mean cover, not a per-pebble pattern: on GL the bed under the film is
// the ground texture, and holes in the film showed it as a lattice of sand dots.
// Real stones (shore debris meshes) poke through the film by their own geometry.
float shore_pebble_cover(float film_metres, float porosity) {
	float cover = smoothstep(0.1 * SHORE_PEBBLE_SIZE, 0.7 * SHORE_PEBBLE_SIZE, film_metres);
	return mix(1.0, cover, clamp(porosity, 0.0, 1.0));
}
