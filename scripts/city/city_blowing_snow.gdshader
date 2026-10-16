shader_type particles;

// Drifting and blowing snow (CityBlowingSnow). Wind lifts dry, loose snow off the
// ground and the frozen moat: most grains skim the surface in low streams (drifting
// snow, ankle to knee high), and in a gale a share is thrown up to a few metres
// (blowing snow) before it settles again. Grains are born only where snow lies
// (CitySnow depth map, the snowed ice over the moat) and in gust puffs that travel
// downwind, so the streams come in waves instead of an even sheet.
// Particle kinds (kind_of(CUSTOM)): 0 grain skimming the surface, 1 faint veil sheet (the
// haze of fine grains, metres wide), 2 grain lofted high.

const float GRAIN_ALPHA = 0.85;
const float LOFT_ALPHA = 0.6;
const float VEIL_ALPHA = 0.3;

uniform vec3 emit_half = vec3(26.0, 0.0, 26.0);
// World-space horizontal wind at 10 m in m/s (y unused).
uniform vec3 wind_velocity = vec3(0.0);
// 0..1 drifting (low streams) and blowing (lofted) share, from CityBlowingSnow.strength().
uniform float drift = 0.0;
uniform float blowing = 0.0;
// Terrain heights (CityPlan.height_texture) over rect (origin x, z, size x, z).
uniform sampler2D ground_height : filter_linear, repeat_disable;
uniform vec4 ground_rect = vec4(0.0, 0.0, 1.0, 1.0);
// CitySnow depth map: R = drift factor / 2, G = 0 over water. snow_rect as above.
uniform sampler2D snow_map : filter_linear, repeat_disable;
uniform vec4 snow_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float snow_cover = 0.0;
// Snow on load-bearing ice (0 when the water is open), and the ice top near the
// player (CityWorld3D.ice_deck_at); grains over water texels ride at this height.
uniform float ice_snow = 0.0;
uniform float ice_level = -1000.0;
// CitySnow roof shelter mask (R = 1 under a roof): grains blown into a house fade
// out instead of crossing its rooms.
uniform sampler2D shelter_map : filter_linear, repeat_disable;
uniform vec4 shelter_rect = vec4(0.0, 0.0, 1.0, 1.0);

float hash(float n) {
	return fract(sin(n * 12.9898 + 78.233) * 43758.5453);
}

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Walking surface under xz: the ground, or the ice top over water texels.
float surface_y(vec2 xz, out float land) {
	float bed = textureLod(ground_height, (xz - ground_rect.xy) / ground_rect.zw, 0.0).r;
	vec4 s = textureLod(snow_map, (xz - snow_rect.xy) / snow_rect.zw, 0.0);
	land = s.g;
	float lying = snow_cover * 0.5 * s.r * 2.0;
	float y = bed + lying * land;
	return land < 0.5 ? max(y, ice_level) : y;
}

// 0..1 loose snow that can be picked up at xz.
float snow_source(vec2 xz) {
	vec4 s = textureLod(snow_map, (xz - snow_rect.xy) / snow_rect.zw, 0.0);
	// Same depth rule as CitySnow.depth_at (MAX_DEPTH_M 0.5, EDGE 0.04).
	float depth = snow_cover * 0.5 * s.r * 2.0 - 0.04;
	float land_src = smoothstep(0.0, 0.06, depth);
	return mix(ice_snow, land_src, step(0.5, s.g));
}

float kind_of(vec4 custom) {
	return floor(custom.w / 10.0);
}

// Gust puffs: a noise field carried downwind at the wind speed.
float puff(vec2 xz, float t) {
	vec2 p = xz - wind_velocity.xz * t * 0.85;
	return vnoise(p * 0.055 + vec2(3.7, 1.9)) * 0.7 + vnoise(p * 0.17) * 0.3;
}

void start() {
	float seed = float(INDEX) * 1.37 + fract(TIME * 0.713) * 9173.0;
	vec3 local = vec3((hash(seed + 1.0) * 2.0 - 1.0) * emit_half.x, 0.0,
		(hash(seed + 3.0) * 2.0 - 1.0) * emit_half.z);
	vec3 origin = EMISSION_TRANSFORM[3].xyz;
	vec2 xz = origin.xz + local.xz;
	float r_kind = hash(seed + 5.0);
	// Lofted grains only in a real blow; veils about a third of the rest.
	float kind = r_kind < blowing * 0.35 ? 2.0 : (r_kind > 0.62 ? 1.0 : 0.0);
	float gate = snow_source(xz) * smoothstep(0.38, 0.72, puff(xz, TIME) + blowing * 0.25);
	gate *= kind > 1.5 ? 1.0 : drift;
	gate *= 1.0 - textureLod(shelter_map, (xz - shelter_rect.xy) / shelter_rect.zw, 0.0).r;
	if (hash(seed + 7.0) > gate) {
		ACTIVE = false;
	}
	float land;
	float y = surface_y(xz, land);
	float h = kind > 1.5 ? mix(0.3, 2.5, pow(hash(seed + 9.0), 1.5)) : mix(0.02, 0.18, hash(seed + 9.0));
	// Grains are drawn as short streaks (the eye sees their motion blur, not
	// the 1 mm grain); veils as low, wide sheets of haze hugging the surface.
	// BILLBOARD_PARTICLES keeps the x/y scale in screen space.
	bool veil = kind > 0.5 && kind < 1.5;
	float s = veil ? mix(0.8, 2.4, hash(seed + 4.0)) : mix(0.06, 0.14, hash(seed + 4.0));
	vec2 stretch = veil ? vec2(2.2, 0.45) : vec2(1.0 + length(wind_velocity.xz) * 0.25, 0.5);
	if (veil) {
		// Haze hugs the surface in a breeze; in a gale it rises past the knees.
		h = h * 0.5 + blowing * 1.4 * hash(seed + 11.0);
	}
	TRANSFORM = mat4(vec4(s * stretch.x, 0.0, 0.0, 0.0), vec4(0.0, s * stretch.y, 0.0, 0.0),
		vec4(0.0, 0.0, s, 0.0), vec4(xz.x, y + h, xz.y, 1.0));
	// Near the surface the wind is slower (log profile): skimming grains run at
	// about half the 10 m wind, lofted ones nearly with it.
	float lag = kind > 1.5 ? mix(0.7, 0.95, hash(seed + 6.0)) : mix(0.4, 0.65, hash(seed + 6.0));
	VELOCITY = vec3(wind_velocity.x * lag, 0.0, wind_velocity.z * lag);
	// x stays 0: BILLBOARD_PARTICLES rolls the quad by CUSTOM.x (radians), which
	// stood the streaks on end. y height above the surface, z age, w kind * 10 + lag.
	CUSTOM = vec4(0.0, h, 0.0, kind * 10.0 + lag);
	float a = veil ? VEIL_ALPHA : (kind > 1.5 ? LOFT_ALPHA : GRAIN_ALPHA);
	COLOR = vec4(1.0, 1.0, 1.0, a);
}

void process() {
	float index = float(INDEX);
	float kind = kind_of(CUSTOM);
	CUSTOM.z += DELTA;
	float t = CUSTOM.z / max(LIFETIME, 0.01);
	vec3 target = vec3(wind_velocity.x, 0.0, wind_velocity.z) * (CUSTOM.w - kind * 10.0);
	// Turbulence: sideways meander so streams braid instead of running in rails.
	float phase = hash(index * 5.3) * 6.2831;
	float rate = mix(1.5, 3.5, hash(index * 7.9));
	vec2 side = normalize(vec2(-wind_velocity.z, wind_velocity.x) + vec2(0.0001));
	float wander = sin(TIME * rate + phase) * length(wind_velocity.xz) * 0.08;
	target.xz += side * wander;
	VELOCITY.xz += (target.xz - VELOCITY.xz) * clamp(2.5 * DELTA, 0.0, 1.0);
	TRANSFORM[3].xz += VELOCITY.xz * DELTA;
	float land;
	float ground = surface_y(TRANSFORM[3].xz, land);
	float h = CUSTOM.y;
	if (kind > 1.5) {
		// Lofted: rises and sinks on eddies, slowly settling back.
		h += (vnoise(vec2(index * 0.37, TIME * 0.6)) - 0.55) * 1.6 * DELTA;
		h = max(h - 0.15 * DELTA, 0.05);
	} else if (kind < 0.5) {
		// Saltation: short hops along the surface.
		h = CUSTOM.y * (0.5 + abs(sin(TIME * rate * 2.0 + phase)));
	}
	CUSTOM.y = kind < 0.5 ? CUSTOM.y : h;
	// Ride over the ground (and walls of drifts): never below the surface.
	TRANSFORM[3].y = ground + h;
	float fade = smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.65, 1.0, t));
	float base = kind > 0.5 && kind < 1.5 ? VEIL_ALPHA : (kind > 1.5 ? LOFT_ALPHA : GRAIN_ALPHA);
	float roof = textureLod(shelter_map, (TRANSFORM[3].xz - shelter_rect.xy) / shelter_rect.zw, 0.0).r;
	COLOR.a = base * fade * (1.0 - roof);
}
