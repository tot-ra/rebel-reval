shader_type spatial;
render_mode cull_disabled;
global uniform float ocean_time;
varying float species;
void vertex() {
	species = INSTANCE_CUSTOM.g;
	float tail = smoothstep(0.15, 0.75, -VERTEX.x);
	VERTEX.z += sin(ocean_time * 11.0 + INSTANCE_CUSTOM.r - VERTEX.x * 5.0) * tail * 0.12;
}
void fragment() {
	vec3 tint = mix(vec3(0.85, 0.96, 1.0), vec3(0.60, 0.70, 0.37), species);
	ALBEDO = COLOR.rgb * tint;
	ROUGHNESS = 0.28;
	METALLIC = 0.25;
}
