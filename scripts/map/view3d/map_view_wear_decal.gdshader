shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// P0-157 wear/grime/blood projected decals. Soft radial falloff times an authored
// alpha mask keeps GL Compatibility free of Decal3D while avoiding hard quad edges.
uniform vec4 tint_color : source_color = vec4(0.2, 0.2, 0.2, 0.4);
uniform sampler2D mask_texture : source_color, filter_linear_mipmap;
uniform float soft_edge = 0.35;

void fragment() {
	vec4 mask = texture(mask_texture, UV);
	vec2 centered = UV * 2.0 - 1.0;
	float radial = 1.0 - clamp(length(centered), 0.0, 1.0);
	float edge = clamp(soft_edge, 0.05, 0.95);
	float falloff = smoothstep(0.0, edge, radial);
	float alpha = mask.a * tint_color.a * falloff;
	ALBEDO = tint_color.rgb;
	ALPHA = alpha;
}
