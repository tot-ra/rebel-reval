// Painted-iso roof cutaway (R-1744). While the high telephoto camera is active,
// CityBuildingBuilder.set_roof_cutaway() feeds the player's chest and the lens
// position; roof fragments near that sight line, between Kalev and the lens,
// are screen-door dithered away so he stays visible under the eaves.
// Shadow passes render from the light, whose eye differs from the lens, so the
// roof keeps casting its shadow and no sunlight leaks onto the street.

uniform bool cutaway_on = false;
uniform vec3 cutaway_player = vec3(0.0);
uniform vec3 cutaway_camera = vec3(0.0);
uniform float cutaway_radius = 3.2;

void roof_cutaway(vec3 world_pos, vec3 eye_world, vec2 frag_coord) {
	if (!cutaway_on || distance(eye_world, cutaway_camera) > 1.0) {
		return;
	}
	vec3 axis = cutaway_camera - cutaway_player;
	float len = length(axis);
	if (len < 0.01) {
		return;
	}
	axis /= len;
	float t = dot(world_pos - cutaway_player, axis);
	// Only geometry in front of Kalev (toward the lens) hides him.
	if (t < 0.4 || t > len) {
		return;
	}
	float r = length(world_pos - cutaway_player - axis * t);
	float cut = 1.0 - smoothstep(cutaway_radius * 0.55, cutaway_radius, r);
	// Interleaved gradient noise: a stable screen-door pattern for the soft rim.
	float dither = fract(52.9829189 * fract(dot(frag_coord, vec2(0.06711056, 0.00583715))));
	if (cut > dither) {
		discard;
	}
}
