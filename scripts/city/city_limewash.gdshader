shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Lime-washed interior plaster: an even warm white with soft brush mottling,
// coats that thin over the stone joints, grime at the foot of the wall and
// smoke towards the ceiling. World-space, so walls of any size share a scale.
//
// Optional painted decoration (`paint` > 0), as 14th-century Hanseatic halls
// were finished (plausible composite for Reval 1343: no hall painting of that
// date survives): red-ochre false-ashlar joint lines over the wash, an earthy
// dado painted as a hanging curtain (`dado_plate`), and a frieze band between
// ochre rules. The frieze is the foliage band plate (`frieze_plate`), or a
// green-and-red vine scroll beyond `rich_from` along `site_axis` (measured
// from `site_origin`), so one material can paint two rooms. The plates come
// from tools/build_church_mural_plates.py (R-1396) and are also laid on plain
// lime-washed church walls by ChurchMurals.

#include "res://scripts/city/city_weathering.gdshaderinc"

uniform vec3 wash : source_color = vec3(0.74, 0.69, 0.6);
uniform float indoor_ao = 0.62;
uniform bool outdoor = false; // exterior whitewash: daylight, fog, rain streaks
uniform float floor_y = 0.0; // world height of the floor the grime band sits on
uniform float paint = 0.0;
uniform float frieze_y0 = 1.95; // above the floor
uniform float frieze_y1 = 2.25;
uniform float dado_h = 0.85;
uniform vec2 site_origin = vec2(0.0);
uniform vec2 site_axis = vec2(1.0, 0.0);
uniform float rich_from = 1e9;
uniform vec3 ochre : source_color = vec3(0.6, 0.24, 0.15);
uniform vec3 verdigris : source_color = vec3(0.27, 0.4, 0.3);
// Unset plates read as transparent: the plain ochre dado and an empty band.
uniform sampler2D dado_plate : source_color, filter_linear_mipmap, repeat_enable, hint_default_transparent;
uniform sampler2D frieze_plate : source_color, filter_linear_mipmap, repeat_enable, hint_default_transparent;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 t = normalize(vec2(-w_nrm.z, w_nrm.x) + vec2(1e-4));
	float s = dot(w_pos.xz, t);
	vec2 p = vec2(s, w_pos.y);
	float h = w_pos.y - floor_y;
	float mottle = wfbm(p * 1.3) - 0.5;
	float brush = wnoise(vec2(p.x * 6.0, p.y * 0.8)) - 0.5;
	// Coursed rubble shows faintly through thin wash.
	float rubble = smoothstep(0.42, 0.5, abs(fract(h * 3.2 + wnoise(p * 1.7) * 0.4) - 0.5));
	vec3 col = wash * (1.0 + mottle * 0.16 + brush * 0.05 - rubble * 0.03) * COLOR.rgb;
	if (paint > 0.0) {
		float worn = smoothstep(0.2, 0.6, wfbm(p * 3.0));
		// False ashlar: courses 0.31 m, blocks 0.62 m, alternate courses offset.
		float course = floor(h / 0.31);
		float bx = s / 0.62 + mod(course, 2.0) * 0.5;
		float jy = abs(fract(h / 0.31) - 0.5);
		float jx = abs(fract(bx) - 0.5);
		float joint = max(smoothstep(0.465, 0.485, jy), smoothstep(0.48, 0.492, jx));
		float field = step(dado_h, h) * (1.0 - step(frieze_y0, h));
		col = mix(col, ochre * 1.05, joint * 0.7 * worn * field);
		// Dado: an earthy band at the foot of the wall, with an ochre rule.
		col = mix(col, mix(ochre, wash, 0.55) * 0.9, step(h, dado_h) * 0.85);
		// The curtain plate is 2:1, its top edge on the dado rule.
		vec4 cloth = texture(dado_plate, vec2(s / (dado_h * 2.0), 1.0 - h / dado_h));
		col = mix(col, cloth.rgb, cloth.a * step(h, dado_h));
		float dado_rule = smoothstep(dado_h - 0.035, dado_h, h) * (1.0 - smoothstep(dado_h, dado_h + 0.035, h));
		col = mix(col, ochre * 0.8, dado_rule);
		// Frieze band between two ochre rules.
		if (h > frieze_y0 && h < frieze_y1) {
			float v = (h - frieze_y0) / (frieze_y1 - frieze_y0);
			vec3 band = wash * 0.95;
			bool rich = dot(w_pos.xz - site_origin, site_axis) > rich_from;
			if (!rich) {
				// The foliage plate is 8:1 and carries its own rules.
				vec4 leaf = texture(frieze_plate, vec2(s / ((frieze_y1 - frieze_y0) * 8.0), 1.0 - v));
				band = mix(band, leaf.rgb, leaf.a);
			} else {
				float stem = 0.5 + 0.26 * sin(s * 5.0);
				float st = smoothstep(0.06, 0.0, abs(v - stem));
				vec2 lp = vec2(fract(s * 1.6) - 0.5, (v - stem) * 1.4 - 0.2 * sign(sin(s * 5.0)));
				float leaf = smoothstep(0.17, 0.09, length(lp));
				band = mix(band, verdigris, max(st, leaf * 0.9));
				float berry = smoothstep(0.09, 0.0, length(vec2(fract(s * 1.6 + 0.5) - 0.5, v - 0.5)));
				band = mix(band, ochre, berry * 0.9);
			}
			float rule = max(smoothstep(0.12, 0.0, v), smoothstep(0.88, 1.0, v));
			band = mix(band, ochre * 0.85, rule);
			col = mix(col, band, 0.9 * (0.7 + worn * 0.3));
		}
	}
	// Smoke from candles darkens the wash towards the ceiling.
	if (!outdoor) {
		col *= mix(1.0, 0.82, smoothstep(2.6, 4.8, h));
		float grime = (1.0 - smoothstep(0.0, 0.55, h)) * (0.55 + wfbm(p * 2.4) * 0.45);
		col = mix(col, vec3(0.42, 0.38, 0.32), grime * 0.45);
	}
	// Indoors only the windows let the sky in: the GL Compatibility renderer has
	// no ambient occlusion, so the wash is darkened and warmed directly.
	if (outdoor) {
		// Whitewash outside: rain streaks under the eaves, splash dirt at the foot.
		float streak = smoothstep(0.55, 0.9, wnoise(vec2(s * 3.0, w_pos.y * 0.15)));
		col = mix(col, col * vec3(0.8, 0.78, 0.72), streak * 0.35);
		ALBEDO = col;
	} else {
		ALBEDO = col * indoor_ao * vec3(1.06, 0.98, 0.86);
		AO = indoor_ao;
		AO_LIGHT_AFFECT = 0.0;
		// No sky haze indoors: the distance fog is for streets and the skyline.
		FOG = vec4(0.0);
	}
	ROUGHNESS = 0.94;
	SPECULAR = 0.2;
	NORMAL_MAP = normalize(vec3(mottle * 0.3, brush * 0.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.4;
}
