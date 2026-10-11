shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Dusty shafts of sunlight from a church's stained-glass windows (R-1451).
// Each window is a prism of side quads: the window-end vertices (UV.x = 0)
// sit on the glass plane, the far ones (UV.x = 1) are pushed along the light
// until they reach the floor (UV2.x, site-local) or the opposite wall (UV.y,
// the inward depth of the room). The shaft fades with throw and towards its
// silhouette, and dims as the wall's thickness (UV2.y) closes the opening
// (width COLOR.a * 4) to a slanting sun. It follows the sun every frame
// without rebuilding the mesh.
//
// Colour: every point of a side face traces back along the light to a point
// on the window's outline (CUSTOM1.xy, metres on the glass), so the shaft
// takes the colours of the actual panels: a few taps of the glass from that
// edge point in towards the window's middle, the panels a view ray crossing
// the beam there passes through. A single mean colour per window (COLOR.rgb,
// still the fallback when the plates are missing) mixed red, blue and
// grisaille into a pale grey that read as white sun.

#include "res://scripts/city/city_stained_glass.gdshaderinc"

// xyz direction towards the light, w the direct light strength 0..1.
global uniform vec4 window_sun;
uniform float intensity = 0.22;
uniform sampler2DArray plates : source_color, filter_linear_mipmap, repeat_disable;
// Share of warm white the dust in the air scatters into the coloured light.
uniform float dust_white = 0.1;
// Exponent on the normalised panel colour (1 = as the glass, higher = deeper).
uniform float saturation = 1.8;
const int TAPS = 6;

varying float along;
varying float aperture;
// Glass layout: width, lights, height, glazing code (CUSTOM0).
varying flat vec4 glass;
varying vec2 glass_uv;

void vertex() {
	// Mesh space is site-local (the shaft mesh sits at the site root).
	vec3 l = normalize(transpose(mat3(MODEL_MATRIX)) * window_sun.xyz);
	vec3 n = normalize(NORMAL);
	float facing = dot(l, n);
	float t = 0.0;
	if (UV.x > 0.5 && l.y > 0.02 && facing > 0.02 && window_sun.w > 0.01) {
		t = min((VERTEX.y - UV2.x) / l.y, UV.y / facing);
		t = max(t, 0.0);
	}
	VERTEX -= l * t;
	along = UV.x;
	glass = CUSTOM0;
	glass_uv = CUSTOM1.xy;
	// Sideways drift of the light across the wall thickness against the
	// opening's width: a grazing sun gets only a sliver through the reveal.
	vec3 d = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	float drift = UV2.y * abs(dot(l, d)) / max(facing, 0.02);
	aperture = clamp(1.0 - drift / max(COLOR.a * 4.0, 0.1), 0.0, 1.0);
}

void fragment() {
	// Soft silhouette: a side seen edge-on adds little, so the shaft has no
	// hard outline; brightest near the window, thinning towards the floor.
	vec3 nrm = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float face = smoothstep(0.0, 0.6, abs(dot(nrm, VIEW)));
	float fade = (1.0 - along * 0.75) * smoothstep(0.0, 0.08, along);
	vec3 tint = COLOR.rgb;
	if (glass.x > 0.01) {
		// Nudged just inside the outline so the edge taps land on glass, not
		// on the frame; the middle sits a little low, below the pointed head.
		vec2 mid = vec2(glass.x * 0.5, glass.z * 0.4);
		vec2 edge = mix(glass_uv, mid, 0.04);
		vec3 sum = vec3(0.0);
		for (int k = 0; k < TAPS; k++) {
			vec2 uv = mix(edge, mid, (float(k) + 0.5) / float(TAPS));
			vec4 panel = glass_panel(uv, glass.x, glass.y, glass.z, int(glass.w + 0.5));
			// High lod: the dust blurs the panel image to its colour fields.
			sum += textureLod(plates, panel.xyz, 5.0).rgb;
		}
		// Hue at full strength like the floor patch: the plates are painted
		// dark (albedo).
		tint = sum / max(max(sum.r, max(sum.g, sum.b)), 0.001);
		// Deepen the weaker channels: the overlapping faces of a beam add up,
		// and a mixed hue added twice clips towards white on screen.
		tint = pow(tint, vec3(saturation));
		tint = mix(tint, vec3(1.0, 0.95, 0.85), dust_white);
	}
	ALBEDO = tint * intensity * window_sun.w * face * fade * aperture;
}
