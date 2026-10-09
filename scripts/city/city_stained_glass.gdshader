shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Leaded stained glass for church lancets (plausible composite for Reval 1343
// after 13th-14th-century Gotland parish glazing). Each light shows a column
// of painted panels from the plate array (flat Romanesque / early Gothic
// figures and grisaille, generated), joined by dark saddle bars. UV is metres
// across the light (u from its left edge, v up from the sill). Seen from
// inside (back face, the mesh normal points outdoors) it glows with daylight;
// from outside it is dark glass with a faint sky sheen. The panel layout is
// shared with the sunlight the window throws inside (city_window_sunlight).

#include "res://scripts/city/city_weathering.gdshaderinc"
#include "res://scripts/city/city_stained_glass.gdshaderinc"

uniform float daylight = 1.0;
// assets/textures/churches/glass/glass_plates.png, one layer per plate in the
// order of tools/build_church_glass_plates.py (0 Crucifixion, 1 Virgin and
// Child, 2 Annunciation, 3 St Olaf, 4 St Nicholas, 5 St Mary, 6 St Catherine,
// 7 grisaille foliage).
uniform sampler2DArray plates : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	// Vertex colour: r = window width / 4, b = lights / 4, a = height / 8,
	// g = (programme * 16 + seed) / 255 (exact in the 8-bit vertex colour).
	float lights = max(1.0, floor(COLOR.b * 4.0 + 0.5));
	float height = max(COLOR.a * 8.0, 0.5);
	int code = int(COLOR.g * 255.0 + 0.5);
	vec4 panel = glass_panel(UV, COLOR.r * 4.0, lights, height, code);
	vec3 col = texture(plates, panel.xyz).rgb;
	col = mix(vec3(0.04), col, panel.w);
	// Pot-metal glass is a little uneven in thickness and colour.
	col *= 0.9 + wnoise(UV * 23.0 + float(code % 16)) * 0.2;
	if (FRONT_FACING) {
		// Outside: dark glass with a cool sky sheen.
		ALBEDO = col * 0.18 + vec3(0.05, 0.07, 0.09);
	} else {
		ALBEDO = col * 1.25 * daylight;
	}
}
