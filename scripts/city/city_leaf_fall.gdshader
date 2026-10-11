shader_type particles;

// ADR 0045 autumn leaf fall for the seamless city. Leaves are born inside the
// crowns of real trees near the player (CityLeafFall uploads up to 16 of them),
// ride the shared wind and tumble down; they vanish when they reach the ground
// they were shed over, so nothing piles up. Which tree sheds is weighted by how
// many leaves it still carries and how hard the wind blows.

uniform vec4 tree_pos[16];   // xyz crown centre, w crown radius
uniform vec4 tree_col[16];   // rgb leaf colour, w ground height under the tree
uniform float tree_cum[16];  // cumulative share of the shedding, last = 1
uniform int tree_count = 0;
// World horizontal wind in m/s (y unused).
uniform vec3 wind_velocity = vec3(0.0);
uniform float fall_speed = 1.0;
// 1/seconds: how fast a leaf follows a change of wind.
uniform float response = 1.4;
uniform float leaf_size = 0.32;
uniform float flutter = 1.1;

float hash(float n) {
	return fract(sin(n * 12.9898 + 78.233) * 43758.5453);
}

mat3 rotation(vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	float t = 1.0 - c;
	vec3 a = axis;
	return mat3(
		vec3(t * a.x * a.x + c, t * a.x * a.y + s * a.z, t * a.x * a.z - s * a.y),
		vec3(t * a.x * a.y - s * a.z, t * a.y * a.y + c, t * a.y * a.z + s * a.x),
		vec3(t * a.x * a.z + s * a.y, t * a.y * a.z - s * a.x, t * a.z * a.z + c));
}

vec3 target_velocity(float index) {
	float lag = mix(0.6, 1.2, hash(index * 1.7));
	float fall = fall_speed * mix(0.6, 1.4, hash(index * 3.1));
	return vec3(wind_velocity.x * lag, -fall, wind_velocity.z * lag);
}

// Which tree a particle slot sheds from is fixed per slot (statistically in
// proportion to tree_cum), so process() can recompute its ground height: CUSTOM is
// not preserved between frames.
int pick_tree(float index) {
	float roll = hash(index * 0.731 + 0.19);
	int pick = max(tree_count - 1, 0);
	for (int i = 15; i >= 0; i--) {
		if (i < tree_count && tree_cum[i] >= roll) {
			pick = i;
		}
	}
	return pick;
}

float leaf_scale(float index) {
	return leaf_size * mix(0.7, 1.4, hash(index * 6.1 + 2.3));
}

void start() {
	float index = float(INDEX);
	float seed = index * 1.37 + fract(TIME * 0.713) * 9173.0;
	vec4 crown = tree_pos[pick_tree(index)];
	vec3 pos = crown.xyz + vec3(
		(hash(seed + 2.0) * 2.0 - 1.0) * crown.w,
		(hash(seed + 3.0) * 2.0 - 1.0) * crown.w * 0.6,
		(hash(seed + 4.0) * 2.0 - 1.0) * crown.w);
	float s = leaf_scale(index);
	TRANSFORM = mat4(
		vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0),
		vec4(0.0, 0.0, s, 0.0), vec4(pos, 1.0));
	VELOCITY = target_velocity(index);
	COLOR = vec4(tree_col[pick_tree(index)].rgb * mix(0.82, 1.16, hash(seed + 6.0)), 1.0);
	if (tree_count <= 0) {
		ACTIVE = false;
	}
}

void process() {
	float index = float(INDEX);
	vec3 target = target_velocity(index);
	float k = clamp(response * DELTA, 0.0, 1.0);
	VELOCITY += (target - VELOCITY) * k;
	float phase = hash(index * 5.3) * 6.2831;
	float rate = mix(1.4, 3.2, hash(index * 7.9));
	vec3 sway = vec3(sin(TIME * rate + phase), sin(TIME * rate * 1.7 + phase) * 0.35,
		cos(TIME * rate * 0.83 + phase)) * flutter;
	vec3 position = TRANSFORM[3].xyz + (VELOCITY + sway) * DELTA;
	vec3 axis = normalize(vec3(hash(index * 2.1) - 0.5, 1.0, hash(index * 4.3) - 0.5));
	float spin = mix(1.5, 4.5, hash(index * 9.7));
	mat3 basis = rotation(axis, TIME * spin + phase) * leaf_scale(index);
	TRANSFORM = mat4(
		vec4(basis[0], 0.0), vec4(basis[1], 0.0), vec4(basis[2], 0.0), vec4(position, 1.0));
	if (position.y < tree_col[pick_tree(index)].w + 0.03) {
		ACTIVE = false;
	}
}
