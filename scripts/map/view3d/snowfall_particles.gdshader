shader_type particles;

// ADR 0045 snowfall motion. Each flake's velocity relaxes toward "wind plus fall"
// every frame, so a gust shoves every flake in the air at once (a baked initial
// velocity would only reach flakes spawned after it). Per-flake variation in
// fall speed, wind lag and sway stops the sheet moving in lockstep.

uniform vec3 emit_half = vec3(15.0, 0.5, 15.0);
// World-space horizontal wind in m/s (y unused).
uniform vec3 wind_velocity = vec3(0.0);
uniform float fall_speed = 1.5;
// 1/seconds: how fast a flake follows a change of wind.
uniform float response = 1.8;
uniform float size_min = 0.1;
uniform float size_max = 0.2;
// Sideways flutter in m/s.
uniform float flutter = 0.4;

float hash(float n) {
	return fract(sin(n * 12.9898 + 78.233) * 43758.5453);
}

vec3 target_velocity(float index) {
	float lag = mix(0.7, 1.3, hash(index * 1.7));
	float fall = fall_speed * mix(0.75, 1.25, hash(index * 3.1));
	return vec3(wind_velocity.x * lag, -fall, wind_velocity.z * lag);
}

void start() {
	// RANDOM_SEED is not unique per flake here, so seed from index and spawn time.
	float seed = float(INDEX) * 1.37 + fract(TIME * 0.713) * 9173.0;
	vec3 local = vec3(
		(hash(seed + 1.0) * 2.0 - 1.0) * emit_half.x,
		(hash(seed + 2.0) * 2.0 - 1.0) * emit_half.y,
		(hash(seed + 3.0) * 2.0 - 1.0) * emit_half.z);
	float s = mix(size_min, size_max, hash(seed + 4.0));
	vec3 world = (EMISSION_TRANSFORM * vec4(local, 1.0)).xyz;
	TRANSFORM = mat4(
		vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0),
		vec4(0.0, 0.0, s, 0.0), vec4(world, 1.0));
	VELOCITY = target_velocity(float(INDEX));
	COLOR = vec4(1.0);
}

void process() {
	float index = float(INDEX);
	vec3 target = target_velocity(index);
	float k = clamp(response * DELTA, 0.0, 1.0);
	VELOCITY += (target - VELOCITY) * k;
	float phase = hash(index * 5.3) * 6.2831;
	float rate = mix(1.2, 2.6, hash(index * 7.9));
	vec3 sway = vec3(sin(TIME * rate + phase), 0.0, cos(TIME * rate * 0.83 + phase)) * flutter;
	TRANSFORM[3].xyz += (VELOCITY + sway) * DELTA;
}
