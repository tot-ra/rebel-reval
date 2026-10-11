shader_type canvas_item;
render_mode unshaded;

// WR-4 CPU/GPU parity probe (tools/water_sandbox/shore_parity.gd). Each column
// evaluates the shared shore_state() at one probe point; rows carry the camera
// height lift, the surging share and the validity, packed into 24 bits.

global uniform float ocean_time;

#include "res://scripts/map/view3d/shore_swash.gdshaderinc"

uniform sampler2D probe_points : filter_nearest;
uniform float probe_time = 0.0;
uniform float probe_geometry_scale = 1.0;
uniform int probe_count = 1;

const float PROBE_RANGE = 16.0;

void fragment() {
	int column = min(int(UV.x * float(probe_count)), probe_count - 1);
	int row = min(int(UV.y * 3.0), 2);
	vec2 xz = texelFetch(probe_points, ivec2(column, 0), 0).rg;
	ShoreState s = shore_state(xz, probe_time, shore_sea());
	float value = s.valid;
	if (row == 0) {
		value = (s.height + max(s.slosh, 0.0)) * probe_geometry_scale * s.valid;
	} else if (row == 1) {
		value = s.surging;
	}
	float v = floor(clamp(value / PROBE_RANGE + 0.5, 0.0, 1.0) * 16777215.0);
	float r = floor(v / 65536.0);
	float g = floor((v - r * 65536.0) / 256.0);
	float b = v - r * 65536.0 - g * 256.0;
	COLOR = vec4(r, g, b, 255.0) / 255.0;
}
