shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Leaded stained glass for church lancets (plausible composite for Reval 1343
// after 13th-14th-century Gotland parish glazing). Each light shows a column
// of painted panels from the plate array (flat Romanesque / early Gothic
// figures and grisaille, generated), joined by dark saddle bars. UV is metres
// across the light (u from its left edge, v up from the sill). Seen from
// inside (back face, the mesh normal points outdoors) it glows with daylight;
// from outside it is dark glass with a faint sky sheen.

#include "res://scripts/city/city_weathering.gdshaderinc"

uniform float daylight = 1.0;
// assets/textures/churches/glass/glass_plates.png, one layer per plate in the
// order of tools/build_church_glass_plates.py (0 Crucifixion, 1 Virgin and
// Child, 2 Annunciation, 3 St Olaf, 4 St Nicholas, 5 St Mary, 6 St Catherine,
// 7 grisaille foliage).
uniform sampler2DArray plates : source_color, filter_linear_mipmap, repeat_disable;

// Plate width / height (512 x 768).
const float PLATE_ASPECT = 0.6667;
// Glazing programme per church, six panels each, cycled across the window
// (index from SiteKit.GLAZING): the patron and Marian panels first, grisaille
// between them as in parish glazing of the period.
const int PROGRAMMES[24] = {
	0, 2, 7, 1, 6, 7, // 0 Holy Spirit (hospital church: Passion and Marian cycle)
	3, 1, 7, 0, 2, 7, // 1 St Olaf
	4, 1, 7, 0, 6, 7, // 2 St Nicholas (and its St Barbara chapel)
	5, 1, 7, 2, 0, 7 // 3 St Mary
};

void fragment() {
	// Vertex colour: r = window width / 4, b = lights / 4, a = height / 8,
	// g = (programme * 16 + seed) / 255 (exact in the 8-bit vertex colour).
	float lights = max(1.0, floor(COLOR.b * 4.0 + 0.5));
	float width = COLOR.r * 4.0 / lights;
	float height = max(COLOR.a * 8.0, 0.5);
	int code = int(COLOR.g * 255.0 + 0.5);
	int programme = clamp(code / 16, 0, 3);
	int seed = code % 16;
	int light = int(floor(UV.x / width));
	vec2 uv = vec2(mod(UV.x, width), UV.y);
	// A tall narrow light gets a column of panels instead of one plate
	// squeezed into a strip: each panel stays within ~1.3x of the plate's
	// own proportions. The pointed head simply clips the top panel.
	float panels = max(1.0, floor(height * PLATE_ASPECT / width / 1.3 + 0.5));
	float panel_h = height / panels;
	float row = min(floor(uv.y / panel_h), panels - 1.0);
	float pv = uv.y - row * panel_h;
	// Neighbouring lights and stacked panels walk the programme, so no two
	// adjacent figure panels repeat.
	int slot = (seed + light + int(row) * int(lights)) % 6;
	float layer = float(PROGRAMMES[programme * 6 + slot]);
	vec2 pu = vec2(clamp(uv.x / width, 0.0, 1.0), 1.0 - clamp(pv / panel_h, 0.0, 1.0));
	vec3 col = texture(plates, vec3(pu, layer)).rgb;
	// Iron saddle bar between stacked panels.
	float joint = clamp(floor(uv.y / panel_h + 0.5), 1.0, max(panels - 1.0, 1.0));
	if (panels > 1.0) {
		col = mix(vec3(0.04), col, smoothstep(0.012, 0.025, abs(uv.y - joint * panel_h)));
	}
	// Pot-metal glass is a little uneven in thickness and colour.
	col *= 0.9 + wnoise(uv * 23.0 + float(seed)) * 0.2;
	if (FRONT_FACING) {
		// Outside: dark glass with a cool sky sheen.
		ALBEDO = col * 0.18 + vec3(0.05, 0.07, 0.09);
	} else {
		ALBEDO = col * 1.25 * daylight;
	}
}
