shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// A painted mural plate laid over the lime wash (ChurchMurals decal quads): the
// plate's alpha lets the wash show through. Lit and toned like the indoor wash
// in city_limewash.gdshader (same indoor darkening, candle smoke towards the
// vault), so the paint reads as pigment on the wall, not a sticker.

uniform sampler2D plate : source_color, filter_linear_mipmap, repeat_enable;
uniform float indoor_ao = 0.82;
uniform float floor_y = 0.0;

varying float height;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - floor_y;
}

void fragment() {
	vec4 paint = texture(plate, UV);
	vec3 col = paint.rgb * mix(1.0, 0.82, smoothstep(2.6, 4.8, height));
	ALBEDO = col * indoor_ao * vec3(1.06, 0.98, 0.86);
	ALPHA = paint.a * COLOR.a;
	AO = indoor_ao;
	AO_LIGHT_AFFECT = 0.0;
	FOG = vec4(0.0);
	ROUGHNESS = 0.94;
	SPECULAR = 0.2;
}
