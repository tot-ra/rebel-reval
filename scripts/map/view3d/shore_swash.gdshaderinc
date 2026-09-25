// WS-08 shore swash, shared by the water shader and the blended-ground terrain.
//
// Ported from Tidewater (MIT), see notice.code.tidewater: ShoreParams (period 9,
// amplitude 0.34, variation 0.55, gamma 0.78, breakSpan 0.13, curl 1, runup 1,
// turbidity 0.16), ShoreSimParams (dryTime 28, foamLife 4.5, surfFoamLife 2.6,
// residueLife 5) and the shore fragment's foam bead, trailing foam and meniscus.
//
// WHY analytic: Tidewater carries wetness and foam between frames in compute
// buffers, which GL Compatibility cannot do. Here every value is a pure, periodic
// function of (shore distance, along-shore coordinate, ocean_time, sea state), so
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
const float SHORE_NEVER_WET = 10000.0;

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
	return max(x, 0.02) * SHORE_METERS_PER_UNIT * SHORE_BEACH_SLOPE;
}

float _swash_set_envelope(float wave_index) {
	return 0.62 + 0.38 * (0.5 + 0.5 * sin(6.2831853 * wave_index / SHORE_SET_WAVES + 1.3));
}

// Sheet front (world units inland) during one cycle: ease-out uprush, then an
// ease-in backwash that starts slowly and drains back over the longer remainder.
float _swash_front(float u, float reach) {
	if (u < SHORE_UPRUSH) {
		float a = 1.0 - u / SHORE_UPRUSH;
		return reach * (1.0 - a * a);
	}
	float b = (u - SHORE_UPRUSH) / (1.0 - SHORE_UPRUSH);
	return reach * (1.0 - b * b);
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
	if (shore_field_valid < 0.5 || sea.y <= 0.0) {
		return s;
	}
	vec2 uv = (world_xz - shore_field_origin) / shore_field_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return s;
	}
	vec4 field = textureLod(shore_field, uv, 0.0);
	vec2 dir = field.gb * 2.0 - 1.0;
	float dir_length = length(dir);
	if (dir_length < 0.2) {
		// No shoreline within the field clamp (or two shores cancel in the filter).
		return s;
	}
	dir /= dir_length;
	float x = field.r + sea.z;
	s.valid = 1.0 - smoothstep(SHORE_OFFSHORE - 1.0, SHORE_OFFSHORE, abs(field.r));
	s.distance = x;
	s.to_land = dir;
	s.beach = smoothstep(0.35, 0.65, field.a);

	float sea_state = clamp(sea.x, 0.0, 1.0);
	// Calm Baltic days still lap at the sand; family strength scales everything.
	float energy = mix(0.35, 1.0, sea_state) * sea.y;
	float period = SHORE_PERIOD;
	// Projecting onto the shore tangent gives an along-shore coordinate, so crest
	// phase and reach vary along the beach instead of arriving as ruled lines.
	float along = dot(world_xz, vec2(-dir.y, dir.x));
	float cycle = t / period + SHORE_VARIATION * _swash_noise(vec2(along * 0.05, 3.7));
	float wave_index = floor(cycle);
	float u = cycle - wave_index;

	// Shoaling H = A (d0 / d)^0.25 breaks where H > gamma d. Solving for d gives
	// the break depth; the break point is clamped inside the field.
	float d0 = _swash_depth(SHORE_OFFSHORE);
	float h_deep = SHORE_AMPLITUDE * energy;
	float break_depth = pow(h_deep * pow(d0, 0.25) / SHORE_GAMMA, 0.8);
	float break_x = min(
		break_depth / (SHORE_METERS_PER_UNIT * SHORE_BEACH_SLOPE), SHORE_OFFSHORE - 0.5
	);
	float breaker_height = SHORE_GAMMA * _swash_depth(break_x);
	s.surf_zone = (1.0 - smoothstep(break_x * 0.85, break_x * 1.1, x)) * step(0.0, x) * s.beach;

	if (x >= 0.0) {
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
		float width = mix(2.4, 1.4, steep);
		float face = rel < 0.0 ? width * mix(1.0, 0.4, steep) : width;
		float phase = clamp(rel / face, -1.0, 1.0) * 3.14159265;
		float profile = pow(0.5 + 0.5 * cos(phase), 1.0 + 2.0 * steep);
		float incoming = step(1.0 - SHORE_APPROACH, u)
			* (1.0 - smoothstep(SHORE_OFFSHORE - 1.5, SHORE_OFFSHORE, crest_x));
		s.height = crest_h / SHORE_METERS_PER_UNIT * profile * incoming * s.beach;
		s.curl = SHORE_CURL * s.height * profile * smoothstep(0.6, 1.0, steep);
		// Bore: shoreward of the break point, foam trails the crest for
		// surfFoamLife seconds after it passes, brightest just behind the front.
		float u_pass = 1.0 - SHORE_APPROACH * pow(clamp(x / SHORE_OFFSHORE, 0.0, 1.0), 1.25);
		float since_pass = fract(u - u_pass) * period;
		float broken = 1.0 - smoothstep(break_x, break_x * (1.0 + SHORE_BREAK_SPAN) + 0.3, x);
		float bore = exp(-since_pass / SHORE_SURF_FOAM_LIFE) * mix(0.55, 1.0, exp(-since_pass / 0.6));
		// Older foam lingers faintly over the whole surf zone (foamLife).
		bore = max(bore, exp(-since_pass / SHORE_FOAM_LIFE) * 0.25 * s.surf_zone);
		s.bore_foam = broken * bore * s.beach * mix(0.7, 1.0, sea_state);
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
	float reach_variation = 0.8 + 0.4 * _swash_noise(vec2(along * 0.11, 17.3));
	float base_reach = (
		SHORE_RUNUP * breaker_height * 1.8 / SHORE_METERS_PER_UNIT * sea.w * reach_variation
	);
	float reach_now = min(base_reach * _swash_set_envelope(wave_index), SHORE_MAX_RUNUP);
	float front = _swash_front(u, reach_now);
	float uprush = 1.0 - step(SHORE_UPRUSH, u);
	s.front_distance = front - land;
	s.wet = step(0.0, land) * step(land, front) * step(0.001, front);
	s.sheet_thickness = 0.045 * energy
		* sqrt(clamp(s.front_distance / max(front, 0.05), 0.0, 1.0))
		* mix(0.45, 1.0, uprush);
	// A narrow bright bead sits just behind the front, a thinner trail behind it.
	float bead = exp(-pow((s.front_distance - 0.08) / 0.06, 2.0));
	float trail = smoothstep(0.0, 0.1, s.front_distance)
		* exp(-max(s.front_distance, 0.0) / 0.45) * 0.55;
	s.front_foam = (bead + trail) * mix(0.3, 1.0, _swash_patch(world_xz, t))
		* mix(0.5, 1.0, uprush) * step(0.02, front) * s.beach;

	if (land >= 0.0) {
		// Periodic model => analytic wetting history. Walk back over the last set:
		// the newest wave whose reach covers this point decides the wet time, and
		// every wave's highest reach leaves a residue line that fades in 5 s.
		bool found = false;
		for (int k = 0; k < SHORE_LOOKBACK; k++) {
			float m = wave_index - float(k);
			float reach = min(base_reach * _swash_set_envelope(m), SHORE_MAX_RUNUP);
			float elapsed = cycle - m;
			float since_peak = (elapsed - SHORE_UPRUSH) * period;
			if (since_peak >= 0.0) {
				float line = 1.0 - smoothstep(0.0, 0.07, abs(land - reach));
				s.residue = max(s.residue, line * exp(-since_peak / SHORE_RESIDUE_LIFE));
			}
			if (!found && land <= reach) {
				float r = sqrt(max(1.0 - land / max(reach, 0.001), 0.0));
				float u_up = SHORE_UPRUSH * (1.0 - r);
				float u_down = SHORE_UPRUSH + (1.0 - SHORE_UPRUSH) * r;
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
