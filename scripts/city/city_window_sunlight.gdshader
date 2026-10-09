shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

// Coloured sunlight of a church's stained glass on its floor, walls and
// furnishings (R-1451). Laid as material_overlay over the interior meshes.
// The glass blocks the engine's white sun like any wall (its shadow proxy
// stays while the cutaway hides the upper walls), and this pass adds the
// light the glass lets through instead: from each fragment it follows the
// ray to the sun, finds the window it passes through (inside the glass
// outline, and clear of the outer face and the splayed inner face of the
// opening, so the reveal trims the patch) and adds that window's panel
// colour, blurred with throw like the real sun disc does. Where no window is
// hit the fragment is discarded (no change). The overlay has no shadow map,
// so shade inside a patch is analytic too: the tracery mullions of a
// multi-light window, and the ray tested against the church's occluder boxes
// (piers, benches, solid wall blocks; ChurchSunlight.occluder_boxes).
//
// Why additive: the Compatibility renderer gives a blended overlay no usable
// shadow map, and a multiply over the engine's own soft sun patch turned into
// dark blades in the game's lighting. (Scaling by the shaded surface through
// the screen texture read black in the city render, so the level is fixed.)

#include "res://scripts/city/city_stained_glass.gdshaderinc"

const int MAX_WINDOWS = 32;

// xyz direction towards the light (sun, or the moon at night), w the direct
// light strength 0..1 (set by CityWorld3D.apply_time).
global uniform vec4 window_sun;
uniform sampler2DArray plates : source_color, filter_linear_mipmap, repeat_disable;
// World to site-local (set by ChurchSunlight once the site is placed).
uniform mat4 site_from_world = mat4(1.0);
uniform int window_count = 0;
// Per window, site-local: a = glass plane origin at the left sill corner
// (xyz) and lights (w); b = along-wall direction (xz) and outward normal (zw);
// c = width, spring and apex above the sill (apex 0 = flat head), shader
// height; d.x = glazing code (programme * 16 + seed), d.y = distance from
// the glass out to the outer face of the wall.
uniform vec4 win_a[MAX_WINDOWS];
uniform vec4 win_b[MAX_WINDOWS];
uniform vec4 win_c[MAX_WINDOWS];
uniform vec4 win_d[MAX_WINDOWS];
// Inner (splayed) face of the opening: x = splay, y = distance from the glass
// in to the inner face, z / w = its spring and apex above its own sill
// (0.6 x splay below the glass sill).
uniform vec4 win_e[MAX_WINDOWS];
// Added light = panel colour (brightest channel 1) x level x direct
// strength x cos(incidence).
uniform float level = 0.55;
// Oriented boxes, two texels each: (centre xyz, along-wall dir x) and
// (half extents along / up / across, along-wall dir z).
uniform sampler2D occluders : filter_nearest, repeat_disable;
uniform int occluder_count = 0;
// Mullion half-width and half-depth about the glass plane (SiteKit._tracery).
const float MULLION_HALF = 0.045;
const float MULLION_DEPTH = 0.07;

varying vec3 s_pos;
varying vec3 s_nrm;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	s_pos = (site_from_world * vec4(world, 1.0)).xyz;
	s_nrm = mat3(site_from_world) * (mat3(MODEL_MATRIX) * NORMAL);
}

// Inside the window outline: rectangle to the springing, then the two-centred
// pointed head of SiteKit.arch (each half an arc of radius r centred on the
// springing line at the opposite side).
bool in_window(vec2 uv, vec4 c) {
	float w = c.x;
	if (uv.x < 0.0 || uv.x > w || uv.y < 0.0) {
		return false;
	}
	if (c.z <= 0.0) {
		return uv.y <= c.y;
	}
	if (uv.y <= c.y) {
		return true;
	}
	if (uv.y > c.z) {
		return false;
	}
	float h = c.z - c.y;
	float r = (w * w * 0.25 + h * h) / max(w, 0.01);
	float cx = uv.x <= w * 0.5 ? r : w - r;
	vec2 d = vec2(uv.x - cx, uv.y - c.y);
	return dot(d, d) <= r * r;
}

// On a stone mullion between lights: from the sill to the lights' heads
// (spring + 0.85 x light width), at each joint between lights.
bool on_mullion(vec2 uv, vec4 c, float lights) {
	if (lights < 1.5) {
		return false;
	}
	float lw = c.x / lights;
	if (uv.y > c.y + lw * 0.85) {
		return false;
	}
	float k = floor(uv.x / lw + 0.5);
	return k >= 1.0 && k <= lights - 1.0 && abs(uv.x - k * lw) < MULLION_HALF;
}

// Does the ray p + l t, 0 < t < t_end, pass through an occluder box? A
// fragment on a box's own face leaves it at once (exit at t ~ 0), so the
// boxes need no gap to the meshes they stand for.
bool occluded(vec3 p, vec3 l, float t_end) {
	for (int i = 0; i < occluder_count; i++) {
		vec4 a = texelFetch(occluders, ivec2(i * 2, 0), 0);
		vec4 b = texelFetch(occluders, ivec2(i * 2 + 1, 0), 0);
		vec2 d = vec2(a.w, b.w);
		vec2 n = vec2(-d.y, d.x);
		vec3 q = p - a.xyz;
		vec3 o = vec3(dot(q.xz, d), q.y, dot(q.xz, n));
		vec3 r = vec3(dot(l.xz, d), l.y, dot(l.xz, n));
		vec3 sgn = vec3(greaterThanEqual(r, vec3(0.0))) * 2.0 - 1.0;
		vec3 inv = sgn / max(abs(r), vec3(1e-5));
		vec3 t0 = (-b.xyz - o) * inv;
		vec3 t1 = (b.xyz - o) * inv;
		vec3 tn = min(t0, t1);
		vec3 tf = max(t0, t1);
		float t_in = max(max(tn.x, tn.y), tn.z);
		float t_out = min(min(tf.x, tf.y), tf.z);
		if (t_in < t_out && t_out > 0.03 && t_in < t_end) {
			return true;
		}
	}
	return false;
}

void fragment() {
	vec3 l = normalize(mat3(site_from_world) * window_sun.xyz);
	float strength = window_sun.w;
	float incidence = dot(normalize(s_nrm), l);
	if (strength <= 0.01 || l.y <= 0.02 || incidence <= 0.0) {
		discard;
	}
	vec3 tint = vec3(0.0);
	bool hit = false;
	for (int i = 0; i < MAX_WINDOWS; i++) {
		if (i >= window_count) {
			break;
		}
		vec3 o = win_a[i].xyz;
		vec3 n = vec3(win_b[i].z, 0.0, win_b[i].w);
		float side = dot(s_pos - o, n);
		float facing = dot(l, n);
		// Only light that came in through this window: the fragment is inside
		// its plane and the ray to the sun leaves through it.
		if (side >= 0.0 || facing <= 0.0) {
			continue;
		}
		float t = -side / facing;
		vec3 h = s_pos + l * t;
		vec2 uv = vec2(dot(h - o, vec3(win_b[i].x, 0.0, win_b[i].y)), h.y - o.y);
		if (!in_window(uv, win_c[i])) {
			continue;
		}
		// The opening has the glass's outline at the outer face too.
		vec3 h2 = h + l * (win_d[i].y / facing);
		vec2 uv2 = vec2(dot(h2 - o, vec3(win_b[i].x, 0.0, win_b[i].y)), h2.y - o.y);
		if (!in_window(uv2, win_c[i])) {
			continue;
		}
		vec4 e = win_e[i];
		vec3 h3 = h - l * (e.y / facing);
		vec2 uv3 = vec2(dot(h3 - o, vec3(win_b[i].x, 0.0, win_b[i].y)), h3.y - o.y);
		uv3 += vec2(e.x, e.x * 0.6);
		if (!in_window(uv3, vec4(win_c[i].x + e.x * 2.0, e.z, e.w, 0.0))) {
			continue;
		}
		// The stone mullions between the lights, at the glass and at both of
		// their faces, so a slanting sun widens their shade as it should.
		vec3 dm = l * (MULLION_DEPTH / facing);
		vec3 hm0 = h - dm;
		vec3 hm1 = h + dm;
		vec2 ub = vec2(win_b[i].x, win_b[i].y);
		if (on_mullion(uv, win_c[i], win_a[i].w)
				|| on_mullion(vec2(dot(hm0.xz - o.xz, ub), hm0.y - o.y), win_c[i], win_a[i].w)
				|| on_mullion(vec2(dot(hm1.xz - o.xz, ub), hm1.y - o.y), win_c[i], win_a[i].w)) {
			break;
		}
		// Piers, benches and other walls between the fragment and the inner
		// face of this window's wall (the reveal itself is tested above).
		if (occluder_count > 0 && occluded(s_pos, l, t - e.y / facing - 0.03)) {
			break;
		}
		vec4 panel = glass_panel(uv, win_c[i].x, win_a[i].w, win_c[i].w, int(win_d[i].x + 0.5));
		// The sun disc (0.53 deg) blurs the glass image by ~0.9 cm per metre
		// of throw; a plate texel is ~1.2 mm, so lod = log2(7.5 * t).
		vec3 col = textureLod(plates, panel.xyz, log2(max(7.5 * t, 1.0))).rgb;
		col = mix(vec3(0.08), col, mix(panel.w, 1.0, clamp(t * 0.15, 0.0, 1.0)));
		// Keep the hue at full strength: the plates are painted dark
		// (albedo); the leading (near black) stays dark.
		tint = col / max(max(col.r, max(col.g, col.b)), 0.12);
		hit = true;
		break;
	}
	if (!hit) {
		discard;
	}
	ALBEDO = tint * level * strength * incidence;
}
