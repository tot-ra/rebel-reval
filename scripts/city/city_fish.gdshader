shader_type spatial;
render_mode cull_disabled;
global uniform float ocean_time;
// Painted herring / perch for CityFish. Mesh contract (CityFish.build_mesh):
// UV2 = (ring height -1 belly .. 1 back, part id); UV = (along, around) on the
// body and (base-to-edge, along-the-base) on fins. INSTANCE_CUSTOM = (phase, perch).
varying float species;
varying vec3 rest;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	species = INSTANCE_CUSTOM.g;
	rest = VERTEX;
	// Keep in step with test_city_water_realism (fin bounds under full swing).
	float tail = smoothstep(0.15, 0.75, -VERTEX.x);
	VERTEX.z += sin(ocean_time * 11.0 + INSTANCE_CUSTOM.r - VERTEX.x * 5.0) * tail * 0.12;
}

vec3 body_colour(float h, out float metal, out float rough) {
	// Instances are scaled unevenly (herring slim, perch deep): undo it so the
	// eye stays round and scales keep their shape.
	float aspect = mix(0.79, 1.4, species);
	vec3 back = mix(vec3(0.06, 0.16, 0.22), vec3(0.11, 0.16, 0.05), species);
	vec3 flank = mix(vec3(0.70, 0.75, 0.78), vec3(0.56, 0.58, 0.27), species);
	vec3 belly = mix(vec3(0.93, 0.94, 0.93), vec3(0.88, 0.85, 0.70), species);
	vec3 col = mix(belly, flank, smoothstep(-0.75, -0.2, h));
	col = mix(col, back, smoothstep(mix(0.02, 0.05, species), mix(0.4, 0.6, species), h));
	// Herring flanks shimmer violet-gold along the body.
	float shimmer = 0.5 + 0.5 * sin(rest.x * 26.0 + h * 5.0);
	col = mix(col, col * mix(vec3(0.9, 0.86, 1.08), vec3(1.06, 1.0, 0.82), shimmer),
		(1.0 - species) * smoothstep(-0.6, -0.1, h) * (1.0 - smoothstep(0.2, 0.5, h)));
	// Perch: six dark saddle bars fading towards the belly.
	float bars = smoothstep(-0.1, 0.55, sin((rest.x + 0.02) * 62.0))
		* smoothstep(-0.45, 0.15, h) * step(rest.x, 0.26) * step(-0.34, rest.x);
	col *= 1.0 - 0.6 * bars * species;
	// Overlapping scale rows behind the gill cover.
	vec2 g = vec2(rest.x * 64.0, rest.y * aspect * 80.0);
	g.x += mod(floor(g.y), 2.0) * 0.5;
	vec2 f = fract(g) - 0.5;
	float rim = smoothstep(0.18, 0.5, length(f * vec2(1.0, 1.25)));
	float scaled = step(rest.x, 0.29);
	col *= 1.0 - 0.14 * rim * scaled;
	float sparkle = hash(floor(g));
	col *= 1.0 + (sparkle - 0.5) * 0.18 * scaled * (1.0 - species);
	// Lateral line.
	col *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.05, abs(h - 0.32))) * scaled;
	// Gill cover: a dark arc, the cheek ahead of it brassy on herring.
	float gill_x = 0.30 - 0.04 * h * h;
	col *= 1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.007, abs(rest.x - gill_x))) * step(abs(h), 0.85);
	col = mix(col, col * vec3(1.08, 0.98, 0.72),
		step(gill_x, rest.x) * (1.0 - species) * smoothstep(-0.5, 0.0, h) * (1.0 - smoothstep(0.2, 0.45, h)));
	// Mouth slit.
	col *= 1.0 - 0.35 * step(0.465, rest.x)
		* (1.0 - smoothstep(0.0, 0.006, abs(rest.y + 0.012 + (rest.x - 0.5) * 0.25)));
	// Eye: dark pupil in a silver-gold iris, just above the midline.
	vec2 e = vec2(rest.x - 0.42, (rest.y - 0.024) * aspect / mix(0.79, 1.0, species));
	float r = length(e);
	vec3 iris = mix(vec3(0.82, 0.78, 0.6), vec3(0.85, 0.62, 0.22), species);
	col = mix(col, iris, 1.0 - smoothstep(0.021, 0.025, r));
	col = mix(col, vec3(0.02), 1.0 - smoothstep(0.009, 0.013, r));
	float eye = 1.0 - smoothstep(0.021, 0.025, r);
	metal = mix(mix(0.15, 0.55, smoothstep(-0.8, 0.2, h) * (1.0 - smoothstep(0.3, 0.6, h))), 0.1, species);
	rough = mix(mix(0.32, 0.45, species), 0.08, eye);
	return col;
}

vec3 fin_colour(float part, vec2 uv) {
	vec3 col;
	if (species > 0.5) {
		col = vec3(0.44, 0.46, 0.34);
		if (part > 0.5 && part < 1.5) col = vec3(0.58, 0.45, 0.25);
		if (part > 2.5 && part < 3.5) col = vec3(0.78, 0.62, 0.34);
		if (part > 3.5 && part < 5.5) col = vec3(0.9, 0.38, 0.12);
		// The black blotch at the back of the spiny dorsal.
		if (part > 1.5 && part < 2.5) {
			col = mix(col, vec3(0.05, 0.05, 0.04), smoothstep(0.65, 0.85, uv.y) * smoothstep(0.25, 0.5, uv.x));
		}
	} else {
		col = vec3(0.46, 0.51, 0.52);
		if (part > 0.5 && part < 2.5) col = vec3(0.2, 0.28, 0.32);
	}
	// Bony rays from base to edge, membrane paler towards the rim.
	float rays = 0.5 + 0.5 * cos(uv.y * (part > 0.5 && part < 1.5 ? 70.0 : 40.0));
	col *= 0.78 + 0.22 * rays;
	col = mix(col, col * 1.15 + 0.03, smoothstep(0.55, 1.0, uv.x));
	return col;
}

void fragment() {
	float part = UV2.y;
	if (part < 0.5) {
		float metal;
		float rough;
		ALBEDO = body_colour(UV2.x, metal, rough);
		METALLIC = metal;
		ROUGHNESS = rough;
		SPECULAR = 0.6;
	} else {
		vec3 col = fin_colour(part, UV);
		ALBEDO = col;
		// Thin membranes glow when the sun is behind them.
		BACKLIGHT = col * 0.2;
		ROUGHNESS = 0.55;
		METALLIC = 0.0;
	}
}
