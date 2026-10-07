shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Leaded stained glass for church lancets (plausible composite for Reval 1343
// after 13th-14th-century Gotland parish glazing): a border of ruby and cobalt
// pieces, a column of round medallions in saturated pot-metal colours, and
// grisaille quarries between them, all held in dark lead cames. UV is metres
// across the light (u from its left edge, v up from the sill), so every
// window keeps the same piece size. Seen from inside (back face, the mesh
// normal points outdoors) it glows with daylight; from outside it is dark
// glass with a faint sky sheen.

#include "res://scripts/city/city_weathering.gdshaderinc"

uniform float daylight = 1.0;

vec3 pot_metal(float k) {
	if (k < 0.3) return vec3(0.62, 0.04, 0.05); // ruby
	if (k < 0.55) return vec3(0.07, 0.16, 0.58); // cobalt
	if (k < 0.72) return vec3(0.85, 0.62, 0.1); // silver-stain yellow
	if (k < 0.86) return vec3(0.12, 0.42, 0.2); // green
	return vec3(0.42, 0.13, 0.36); // murrey
}

void fragment() {
	// Vertex colour: r = window width / 4, g = seed, b = lights / 4. Each
	// light of a multi-light window gets its own border and medallions.
	float lights = max(1.0, floor(COLOR.b * 4.0 + 0.5));
	float width = COLOR.r * 4.0 / lights;
	float seed = COLOR.g * 10.0 + floor(UV.x / width);
	vec2 uv = vec2(mod(UV.x, width), UV.y);
	float border = 0.07;
	vec3 col;
	float lead = 0.0;
	if (uv.x < border || uv.x > width - border) {
		// Border: alternating short pieces.
		float k = floor(uv.y / 0.16);
		col = mod(k, 2.0) < 1.0 ? vec3(0.62, 0.04, 0.05) : vec3(0.07, 0.16, 0.58);
		lead = 1.0 - smoothstep(0.0, 0.012, min(fract(uv.y / 0.16), 1.0 - fract(uv.y / 0.16)) * 0.16);
		lead = max(lead, 1.0 - smoothstep(0.0, 0.015, min(abs(uv.x - border), abs(uv.x - (width - border)))));
	} else {
		float cx = width * 0.5;
		float cell = floor(uv.y / 0.95);
		vec2 c = vec2(cx, cell * 0.95 + 0.5);
		float r = length(uv - c);
		float radius = (width - 2.0 * border) * 0.42;
		if (r < radius) {
			// Medallion: rings and quarters of colour around a figure ground.
			float ang = atan(uv.y - c.y, uv.x - c.x);
			float ring = step(radius * 0.82, r);
			float sector = floor((ang + 3.1416) / 1.5708);
			float k = wh(vec2(cell + seed * 7.0, sector + ring * 5.0));
			col = ring > 0.5 ? vec3(0.62, 0.04, 0.05) : pot_metal(k);
			lead = 1.0 - smoothstep(0.0, 0.02, abs(r - radius * 0.82));
			// Lead between the quarters of the inner field.
			float spoke = min(abs(uv.x - c.x), abs(uv.y - c.y));
			lead = max(lead, (1.0 - ring) * (1.0 - smoothstep(0.0, 0.012, spoke)));
			lead = max(lead, 1.0 - smoothstep(0.0, 0.02, abs(r - radius)));
		} else {
			// Grisaille quarries: diamond lattice of greenish white glass.
			vec2 q = vec2((uv.x + uv.y) / 0.22, (uv.x - uv.y) / 0.22);
			vec2 fq = abs(fract(q) - 0.5);
			lead = 1.0 - smoothstep(0.0, 0.06, min(0.5 - fq.x, 0.5 - fq.y));
			float k = wh(floor(q) + seed);
			col = vec3(0.68, 0.72, 0.6) * (0.85 + k * 0.2);
		}
	}
	// Each piece is a little uneven in thickness and colour.
	col *= 0.85 + wnoise(uv * 23.0 + seed) * 0.3;
	col = mix(col, vec3(0.05, 0.05, 0.05), clamp(lead, 0.0, 1.0));
	if (FRONT_FACING) {
		// Outside: dark glass with a cool sky sheen.
		ALBEDO = col * 0.18 + vec3(0.05, 0.07, 0.09);
	} else {
		ALBEDO = col * 1.25 * daylight;
	}
}
