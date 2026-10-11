shader_type spatial;
render_mode cull_disabled;

// Falling leaf (leaf_atlas.gd): a species leaf cut out of the atlas and tinted
// by the particle colour, which carries the species' seasonal hue. The atlas
// cell is fixed per material, or read from COLOR.a (CityLeafFall packs it there).

uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int fixed_cell = -1;
uniform vec3 backlight_tint = vec3(0.35, 0.3, 0.15);

varying flat float v_cell;

void vertex() {
	v_cell = fixed_cell >= 0 ? float(fixed_cell) : floor(clamp(COLOR.a, 0.0, 0.999) * 16.0);
}

void fragment() {
	vec2 cell = vec2(mod(v_cell, 4.0), floor(v_cell / 4.0));
	vec4 leaf = texture(leaf_atlas, (cell + clamp(UV, vec2(0.002), vec2(0.998))) * 0.25);
	ALBEDO = COLOR.rgb * leaf.rgb;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.8;
	BACKLIGHT = backlight_tint;
}
