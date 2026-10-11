shader_type canvas_item;
// Top-down map of the cloud shade over the ground, drawn into a SubViewport by
// cloud_shadow_map.gd and read by god_ray_pass.gdshader (see air_shadow() there). One texel is
// the shade a ground point receives: deck plus discrete cells, along `light_dir`.
uniform vec3 light_dir = vec3(0.0, 1.0, 0.0);
// World XZ of the map's corner and its world size.
uniform vec2 window_origin = vec2(0.0);
uniform float window_size = 3000.0;
global uniform sampler2D cloud_noise_tex : filter_linear_mipmap, repeat_enable;
global uniform sampler2D cloud_shape_tex : filter_linear_mipmap, repeat_enable;
global uniform vec2 cloud_offset_g;
global uniform vec2 cloud_detail_offset_g;
global uniform float cloud_coverage_g;
global uniform float cloud_chaos_g;
#include "res://scripts/map/view3d/sky_clouds.gdshaderinc"
#include "res://scripts/map/view3d/cloud_cells.gdshaderinc"
#include "res://scripts/map/view3d/cloud_air_shadow.gdshaderinc"

void fragment() {
	vec2 xz = window_origin + UV * window_size;
	float shade = cloud_shadow(vec3(xz.x, 0.0, xz.y), 2.0);
	COLOR = vec4(shade, shade, shade, 1.0);
}
