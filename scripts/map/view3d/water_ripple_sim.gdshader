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

// Safety bound only; a stable run stays far inside it (see docs/reports/ws15_ripple_sim.md).
const float HEIGHT_LIMIT = 0.95;

// ---- WR-5 obstacle mode (R-1510, docs/SYSTEMS/CITY_SEA.md "Waves around rocks") -------
// A second WaterRippleSim instance runs this branch: R = scattered height s (world units),
// G = its vertical velocity (units/s), B = impact foam (0..1). The sea already draws the
// incident swell (FFT + WR-4 shore waves); the sim carries only what rocks and walls add:
// the reflected, diffracted and shadowing field. Total = incident + s, and a wall imposes
// no flow through it (Neumann: dT/dn = 0), so the ghost value behind a wall is
// s_c + inc(c - d) - inc(c) (the incident's own slope, mirrored). The incident is the same
// function the sea's vertex() draws, so reflections are phase-locked to the visible crests.
// Wave speed follows the local depth (linear dispersion of the dominant wave), capped
// by the CFL bound; shallow water breaks (damps) the field, so beaches absorb and only
// steep faces (rocks, quays, the stack) reflect.
uniform bool obstacle_mode = false;
// Still-water depth per sim texel (CityObstacleMask), texel-aligned with the sim window.
uniform sampler2D obstacle_mask : filter_nearest, repeat_disable;
// Mask texel of this window's texel (0, 0).
uniform ivec2 mask_offset = ivec2(0);
uniform ivec2 mask_size = ivec2(1);
// World XZ of this window's min corner, texel size (world units).
uniform vec2 obstacle_origin = vec2(0.0);
uniform float obstacle_texel = 0.5;
// Seconds of ocean time this step covers (0 = paused clock: the state only scrolls).
uniform float obstacle_dt = 0.0;
uniform float obstacle_gravity = 11.276;
// Wavenumber of the dominant incident wave (rad per world unit) for the dispersion relation.
uniform float obstacle_k = 0.52;
uniform float obstacle_max_courant = 0.5;
uniform float obstacle_smoothing = 0.05;
uniform float obstacle_viscosity = 0.05;
uniform float obstacle_break_depth = 0.6;
uniform float obstacle_break_rate = 6.0;
// Bed slope (rise per run) over which breaking hands over to reflection.
uniform vec2 obstacle_steep_slope = vec2(0.15, 0.5);
uniform float obstacle_edge_rate = 8.0;
// Impact foam: born where the total surface at a wall stands above foam_height, carried
// by the drift (deflected along the rock), dissolving over a few seconds.
uniform float foam_birth_rate = 2.5;
uniform float foam_height = 0.12;
uniform float foam_decay = 0.35;
uniform float foam_diffusion = 0.04;
uniform vec2 foam_drift = vec2(0.0);
// Fraction of FFT geometry that reaches the near-shore mesh (sea material's shallow preset).
uniform float incident_fft_scale = 1.0;

// Sea uniforms the incident needs; WaterRippleSim copies them from the sea material each
// step (every uniform both shaders declare), so the two always draw the same swell.
uniform float choppiness = 0.85;
uniform float standing_wave_ratio = 0.12;
uniform vec2 wind_direction = vec2(0.9578, 0.2873);
uniform float shore_geometry_scale = 0.12;
global uniform float ocean_time;
#include "res://scripts/map/view3d/shore_swash.gdshaderinc"
// OUTPUT_IS_SRGB is a spatial built-in; the FFT include reads it only in its foam path,
// which this kernel never calls.
#define OUTPUT_IS_SRGB false
#include "res://scripts/map/view3d/ocean_fft_common.gdshaderinc"

const float OBSTACLE_HEIGHT_LIMIT = 3.0;
const float OBSTACLE_VELOCITY_LIMIT = 20.0;
// Depth is clamped to this before the wall normal is taken, so a tall rock top does not
// dominate the gradient.
const vec2 OBSTACLE_NORMAL_DEPTH = vec2(-0.5, 2.0);

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

vec4 _ripple_step(vec2 frag) {
	// FRAGCOORD indexes texels in memory order on every backend (see WaterRippleSim).
	vec2 cell = frag;
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
	h_next += forced;

	// Sponge border: damp both time levels together so the band absorbs outgoing rings
	// instead of reflecting them back into the window (a hard zero edge would reflect).
	vec2 edge = min(cell, sim_size - cell);
	float sponge = mix(0.82, 1.0, smoothstep(0.0, edge_absorb_texels, min(edge.x, edge.y)));
	h_next = clamp(h_next * sponge, -HEIGHT_LIMIT, HEIGHT_LIMIT);
	float h_keep = h * sponge;

	// Churned white water comes from hull forcing only (bow and stern). It decays over a few seconds and
	// stays where the hull passed, which leaves a white trail behind the stern.
	float aer = max(c.b * exp(-aer_decay * step_dt), min(abs(forced) * aer_gain, 1.0));
	aer *= sponge;

	if (reset_state) {
		return vec4(0.0, 0.0, 0.0, 1.0);
	}
	return vec4(h_next, h_keep, aer, 1.0);
}

// Still-water depth at a window texel (new window coordinates).
float _obstacle_depth(ivec2 cell) {
	ivec2 m = cell + mask_offset;
	if (m.x < 0 || m.y < 0 || m.x >= mask_size.x || m.y >= mask_size.y) {
		return 100.0;
	}
	return texelFetch(obstacle_mask, m, 0).r;
}

bool _obstacle_solid(float depth) {
	return depth <= 0.0;
}

// The incident wave field that scatters: the FFT wind sea, cascade C1 (4-16 m), as the
// fine LOD rings near the camera displace it. WHY only C1: the window is 64 m, so it
// holds four or more C1 wavelengths, while C0 (16-128 m) is mostly longer than the window
// and a 1-13 m rock barely scatters it (ka << 1); scattering C0 and the WR-4 shore swell
// (longer still, with a set-up towards land) drew a standing dip around every rock
// instead of waves. Hard edges keep sloshing those long waves analytically (WR-4).
float _incident(vec2 xz) {
	if (!use_fft) {
		return 0.0;
	}
	vec2 p = _fft_to_wind(xz, _fft_wind_axis());
	vec4 c1 = fft_cascade[1];
	float h = _fft_signed(_fft_sample(fft_c1_disp, p / c1.x, c1, 0.0), fft_disp_scale[1]).y * c1.w;
	return h * ocean_amplitude * incident_fft_scale / FFT_METERS_PER_WORLD_UNIT;
}

// The whole sea surface at a rock face, shore breakers included: what foams on impact.
float _incident_surface(vec2 xz, float waves) {
	if (shore_field_valid > 0.5 && shore_strength > 0.0) {
		ShoreState shore = shore_state(xz, ocean_time, shore_sea());
		waves += shore.height * shore_geometry_scale * shore.valid;
	}
	return waves;
}

vec2 _obstacle_world(ivec2 cell) {
	return obstacle_origin + (vec2(cell) + vec2(0.5)) * obstacle_texel;
}

// Previous state at a new-window texel (scrolled by window_shift; outside = calm).
vec3 _obstacle_prev(ivec2 cell) {
	return state_at(cell + window_shift);
}

// Bilinear foam of the previous state at a fractional new-window texel position.
float _obstacle_foam_at(vec2 pos) {
	vec2 q = pos - vec2(0.5);
	ivec2 b = ivec2(floor(q));
	vec2 f = q - vec2(b);
	float f00 = _obstacle_prev(b).b;
	float f10 = _obstacle_prev(b + ivec2(1, 0)).b;
	float f01 = _obstacle_prev(b + ivec2(0, 1)).b;
	float f11 = _obstacle_prev(b + ivec2(1, 1)).b;
	return mix(mix(f00, f10, f.x), mix(f01, f11, f.x), f.y);
}

vec4 _obstacle_step(vec2 frag) {
	ivec2 cell = ivec2(floor(frag));
	float depth = _obstacle_depth(cell);
	if (reset_state || _obstacle_solid(depth)) {
		return vec4(0.0, 0.0, 0.0, 1.0);
	}
	vec3 c = _obstacle_prev(cell);
	float dt = obstacle_dt;
	if (dt <= 0.0) {
		return vec4(c, 1.0);
	}
	ivec2 DIRS[4] = ivec2[4](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
	float lap = 0.0;
	float lap_v = 0.0;
	float walls = 0.0;
	float inc_c = 0.0;
	bool inc_ready = false;
	for (int i = 0; i < 4; i++) {
		ivec2 n = cell + DIRS[i];
		if (_obstacle_solid(_obstacle_depth(n))) {
			// Neumann wall: the total surface is level across the face. The incident's
			// slope comes from the water side (c - d), never from inside the rock.
			if (!inc_ready) {
				inc_c = _incident(_obstacle_world(cell));
				inc_ready = true;
			}
			ivec2 back = cell - DIRS[i];
			float slope = _obstacle_solid(_obstacle_depth(back))
				? 0.0 : _incident(_obstacle_world(back)) - inc_c;
			lap += slope;
			walls += 1.0;
		} else {
			vec3 nb = _obstacle_prev(n);
			lap += nb.r - c.r;
			lap_v += nb.g - c.g;
		}
	}
	// Bed gradient over a 4-texel baseline (depth clamped, so a tall rock top does not
	// dominate): the wall normal for the foam drift and the bed slope for breaking.
	float dxp = clamp(_obstacle_depth(cell + ivec2(2, 0)), OBSTACLE_NORMAL_DEPTH.x, OBSTACLE_NORMAL_DEPTH.y);
	float dxm = clamp(_obstacle_depth(cell - ivec2(2, 0)), OBSTACLE_NORMAL_DEPTH.x, OBSTACLE_NORMAL_DEPTH.y);
	float dzp = clamp(_obstacle_depth(cell + ivec2(0, 2)), OBSTACLE_NORMAL_DEPTH.x, OBSTACLE_NORMAL_DEPTH.y);
	float dzm = clamp(_obstacle_depth(cell - ivec2(0, 2)), OBSTACLE_NORMAL_DEPTH.x, OBSTACLE_NORMAL_DEPTH.y);
	vec2 grad = vec2(dxp - dxm, dzp - dzm);
	float bed_slope = length(grad) / (4.0 * obstacle_texel);
	// Waves break (and lose their energy) only over a gentle bed. A steep face, a quay
	// ramped over one 2 m height cell, a rock dome, reflects them (WR-4's surging class,
	// Iribarren number above ~2): breaking there killed the quay's reflection.
	float breaking = (1.0 - smoothstep(0.0, obstacle_break_depth, depth))
		* (1.0 - smoothstep(obstacle_steep_slope.x, obstacle_steep_slope.y, bed_slope));
	// Linear dispersion of the dominant wave at this depth, capped by the CFL bound.
	float k = max(obstacle_k, 0.01);
	float speed = sqrt(obstacle_gravity / k * tanh(k * max(depth, 0.02)));
	float courant = min(speed * dt / obstacle_texel, obstacle_max_courant);
	float v = c.g + courant * courant / dt * lap + obstacle_smoothing * lap_v;
	// Breaking in the shallows, viscosity, and the sponge band at the window edge.
	vec2 edge = min(frag, sim_size - frag);
	float rate = obstacle_viscosity
		+ obstacle_break_rate * breaking
		+ obstacle_edge_rate * (1.0 - smoothstep(0.0, edge_absorb_texels, min(edge.x, edge.y)));
	v *= exp(-rate * dt);
	float s = c.r + v * dt;
	s *= exp(-(rate * 0.5 + 0.05) * dt);
	s = clamp(s, -OBSTACLE_HEIGHT_LIMIT, OBSTACLE_HEIGHT_LIMIT);
	v = clamp(v, -OBSTACLE_VELOCITY_LIMIT, OBSTACLE_VELOCITY_LIMIT);

	// Foam drift slides along a rock instead of into it: the component towards the
	// wall is removed, so foam born on the weather side wraps around to the lee.
	// A wall within two texels: the impact band where foam is born.
	float near_wall = max(max(step(dxp, 0.0), step(dxm, 0.0)), max(step(dzp, 0.0), step(dzm, 0.0)));
	vec2 drift = foam_drift;
	if (dot(grad, grad) > 1e-4) {
		vec2 away = normalize(grad);
		drift -= away * min(dot(drift, away), 0.0);
	}
	float foam = _obstacle_foam_at(frag - drift * dt / obstacle_texel);
	float around = (_obstacle_prev(cell + ivec2(1, 0)).b + _obstacle_prev(cell - ivec2(1, 0)).b
		+ _obstacle_prev(cell + ivec2(0, 1)).b + _obstacle_prev(cell - ivec2(0, 1)).b) * 0.25;
	foam = mix(foam, around, foam_diffusion) * exp(-foam_decay * dt);
	if (walls > 0.0 || near_wall > 0.0) {
		if (!inc_ready) {
			inc_c = _incident(_obstacle_world(cell));
		}
		float total = s + _incident_surface(_obstacle_world(cell), inc_c);
		float band = walls > 0.0 ? min(walls, 2.0) : 0.5;
		// Only a steep face throws impact foam: beside a rock or quay the depth jumps
		// (a boulder in 0.3 m of water still has 0.3 m beside it), while a beach meets
		// its waterline at a few centimetres per texel. The beach is WR-2/WR-4 swash; a
		// foam line along it read as a ruled edge.
		float steep = smoothstep(0.08, 0.25, depth);
		foam += foam_birth_rate * dt * smoothstep(0.0, foam_height, total) * band * steep;
	}
	foam = clamp(foam, 0.0, 1.0);
	if (isnan(s) || isnan(v) || isnan(foam)) {
		return vec4(0.0, 0.0, 0.0, 1.0);
	}
	return vec4(s, v, foam, 1.0);
}

void fragment() {
	if (obstacle_mode) {
		COLOR = _obstacle_step(FRAGCOORD.xy);
	} else {
		COLOR = _ripple_step(FRAGCOORD.xy);
	}
}
