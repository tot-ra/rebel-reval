shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float phase : hint_range(0.0, 1.0) = 0.0;
uniform bool reduced_motion = false;
uniform vec2 origin = vec2(0.5, 0.6);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 delta = uv - origin;
	delta.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float radius = length(delta);
	float pulse = sin(phase * 3.14159265);
	// Reduced motion removes displacement and the travelling ring, not just its speed.
	float ring = reduced_motion ? 0.0 : exp(-pow((radius - phase * 1.6) * 25.0, 2.0));
	vec2 offset = normalize(delta + vec2(0.00001)) * ring * pulse * 0.008 * amount;
	vec3 color = textureLod(screen_texture, clamp(uv + offset, vec2(0.0), vec2(1.0)), 0.0).rgb;
	color *= mix(vec3(1.0), vec3(0.78, 0.82, 1.03), amount);
	float vignette = smoothstep(0.28, 0.76, length(uv - vec2(0.5)));
	color *= 1.0 - vignette * 0.24 * amount;
	COLOR = vec4(color, 1.0);
}
