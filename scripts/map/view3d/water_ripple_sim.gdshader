shader_type canvas_item;
render_mode blend_disabled, unshaded;

// WS-15 ripple step: damped discrete wave equation on a camera-following window.
// Owned by WaterRippleSim, which renders this kernel into one of two HDR SubViewports and
// feeds it the partner viewport's output as prev_state (R = h_t, G = h_{t-1}, B = aeration).
// Ported from Tidewater (MIT), see notice.code.tidewater (WakeKernel: visc, foam/aeration).

uniform sampler2D prev_state : filter_nearest, repeat_disable;
uniform vec2 sim_size = vec2(256.0);
// Texel offset of this window relative to the previous one (the window scrolls with the
// camera in whole texels). Texels that enter from outside start flat.
uniform ivec2 window_shift = ivec2(0);
// c^2 of the five-point Laplacian; 2D stability needs <= 0.5.
uniform float wave_c2 = 0.25;
uniform float viscosity = 0.006;
// Velocity-Laplacian damping; explicit stability needs wave_c2 + 2 * wave_smoothing <= 0.5.
uniform float wave_smoothing = 0.1;
uniform float aer_gain = 7.0;
uniform float aer_decay = 0.45;
uniform float step_dt = 0.016667;
uniform float edge_absorb_texels = 8.0;
// Writes a flat state; covers the first steps before the partner target was ever rendered.
uniform bool reset_state = false;
// vec4(texel x, texel y, radius texels, strength) in this window's texel space.
uniform int impulse_count = 0;
uniform vec4 impulses[32];
uniform int rain_count = 0;
uniform vec4 rain_drops[40];

// Safety bound only; a stable run stays far inside it (see docs/reports/ws15_ripple_sim.md).
const float HEIGHT_LIMIT = 0.95;

vec3 state_at(ivec2 p) {
	ivec2 size = ivec2(sim_size);
	if (p.x < 0 || p.y < 0 || p.x >= size.x || p.y >= size.y) {
		return vec3(0.0);
	}
	return texelFetch(prev_state, p, 0).rgb;
}

// Every impulse displaces no net water: a Laplacian-of-Gaussian ("Mexican hat") profile with
// a crater and a rim integrates to zero over the plane. Plain Gaussians piled up a standing
// offset under rain (|h| crept to 0.55 in 600 steps) and a quasi-static ridge under a hull
// that hid its wake. A hull re-emitting these rings every step while it outruns the ring
// speed draws the V envelope (Huygens), and a raindrop or splash reads as a clean ring.
float drop(vec4 impulse, vec2 p) {
	vec2 d = p - impulse.xy;
	float r = max(impulse.z, 0.5);
	float q = dot(d, d) / (r * r);
	// Beyond 3 radii the profile is < 1e-3 of its peak; skip the exp.
	return q > 9.0 ? 0.0 : -impulse.w * (1.0 - q) * exp(-q);
}

void fragment() {
	// FRAGCOORD indexes texels in memory order on every backend (see WaterRippleSim).
	vec2 cell = FRAGCOORD.xy;
	ivec2 p = ivec2(floor(cell)) + window_shift;
	vec3 c = state_at(p);
	float h = c.r;
	float h_prev = c.g;
	vec3 east = state_at(p + ivec2(1, 0));
	vec3 west = state_at(p - ivec2(1, 0));
	vec3 north = state_at(p + ivec2(0, 1));
	vec3 south = state_at(p - ivec2(0, 1));
	float lap = east.r + west.r + north.r + south.r - 4.0 * h;
	// Laplacian of the vertical velocity (h - h_prev): Kelvin-Voigt damping that grows with
	// the square of the wavenumber, so grid-scale chatter from 1-2 texel raindrops dies in a
	// few steps while metre-scale rings and wakes keep travelling. Uniform viscosity alone
	// damps every wavelength equally and left the rain as grid noise.
	float lap_prev = east.g + west.g + north.g + south.g - 4.0 * h_prev;
	float h_next = (2.0 * h - h_prev + wave_c2 * lap + wave_smoothing * (lap - lap_prev))
		* (1.0 - viscosity);

	float forced = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= impulse_count) {
			break;
		}
		forced += drop(impulses[i], cell);
	}
	float rain = 0.0;
	for (int i = 0; i < 40; i++) {
		if (i >= rain_count) {
			break;
		}
		rain += drop(rain_drops[i], cell);
	}
	h_next += forced + rain;

	// Sponge border: damp both time levels together so the band absorbs outgoing rings
	// instead of reflecting them back into the window (a hard zero edge would reflect).
	vec2 edge = min(cell, sim_size - cell);
	float sponge = mix(0.82, 1.0, smoothstep(0.0, edge_absorb_texels, min(edge.x, edge.y)));
	h_next = clamp(h_next * sponge, -HEIGHT_LIMIT, HEIGHT_LIMIT);
	float h_keep = h * sponge;

	// Churned white water comes from hull forcing only (bow and stern), not from rain, so
	// a rain shower rings the surface without whitening it. It decays over a few seconds and
	// stays where the hull passed, which leaves a white trail behind the stern.
	float aer = max(c.b * exp(-aer_decay * step_dt), min(abs(forced) * aer_gain, 1.0));
	aer *= sponge;

	if (reset_state) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = vec4(h_next, h_keep, aer, 1.0);
	}
}
