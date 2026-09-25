shader_type canvas_item;
render_mode blend_disabled, unshaded;

// WS-10 sky-view LUT (Hillaire EGSR 2020 section 5.3). One texel per (view zenith, azimuth
// relative to the sun) holds the single + multiple scattered sky radiance seen from the ground.
// Rendered by SkyAtmosphereLut into an HDR SubViewport (float render target, no RGBM) and
// sampled by sky_weather_3d.gdshader with the inverse of the mapping below.
// Ported from Tidewater (MIT), see notice.code.tidewater (skyViewKernel, skyViewRadiance).

#include "res://scripts/map/view3d/atmosphere_common.gdshaderinc"

uniform sampler2D atmosphere_transmittance_lut : filter_linear, repeat_disable;
uniform sampler2D atmosphere_multiscatter_lut : filter_linear, repeat_disable;
// Cosine of the sun zenith angle. The LUT is azimuth-relative, so this is its only input.
uniform float sun_zenith_cos = 1.0;
// Tidewater SkyParams default; the sky shader applies art exposure on top.
uniform float sun_illuminance = 11.0;
// Texel grid of the target so the sub-UV mapping hits texel centres at every tier.
uniform vec2 lut_size = vec2(192.0, 108.0);
// GL Compatibility applies an sRGB-to-linear decode when a 3D (sky) shader samples this
// ViewportTexture, even with use_hdr_2d; Metal/Vulkan do not. Pre-encoding with the exact
// inverse curve restores the stored radiance there. Float storage keeps the round trip exact.
uniform bool encode_srgb = false;

// Tidewater viewHeight 6360.002: the camera stands on the ground.
const float VIEW_HEIGHT_OFFSET_KM = 0.002;
// Hillaire PLANET_RADIUS_OFFSET: lifts the Earth-shadow test off the sample's own sphere.
const float PLANET_RADIUS_OFFSET_KM = 0.01;
const int MARCH_STEPS = 30;
const float MARCH_SAMPLE_OFFSET = 0.3;


vec3 sample_transmittance(float r, float mu) {
	return texture(atmosphere_transmittance_lut, transmittance_uv(r, mu)).rgb;
}


vec3 sample_multiscatter(float r, float mu_sun) {
	return texture(atmosphere_multiscatter_lut, multiscatter_uv(r, mu_sun)).rgb;
}


void fragment() {
	// FRAGCOORD, not UV: it indexes the render target in memory order on every backend, which
	// is also the order texture() reads. UV follows Godot's top-down 2D convention, and on GL
	// Compatibility that flips the LUT vertically when the sky shader samples it.
	vec2 lut_uv = FRAGCOORD.xy / lut_size;
	vec2 unit = vec2(
		atmosphere_sub_uv_to_unit(lut_uv.x, lut_size.x),
		atmosphere_sub_uv_to_unit(lut_uv.y, lut_size.y));
	unit = clamp(unit, 0.0, 1.0);
	float r = ATMO_RG + VIEW_HEIGHT_OFFSET_KM;

	// Non-linear latitude (Hillaire UvToSkyViewLutParams): half of the rows cover the sky
	// above the horizon, squared towards it; the other half cover the ground below it.
	float v_horizon = sqrt(r * r - ATMO_RG * ATMO_RG);
	float beta = acos(v_horizon / r);
	float zh = ATMO_PI - beta;
	float cos_view_zenith;
	if (unit.y < 0.5) {
		float c = 1.0 - 2.0 * unit.y;
		c = 1.0 - c * c;
		cos_view_zenith = cos(zh * c);
	} else {
		float c = 2.0 * unit.y - 1.0;
		c = c * c;
		cos_view_zenith = cos(zh + beta * c);
	}
	float cos_light_view = -(unit.x * unit.x * 2.0 - 1.0);

	// Local frame: +y up, the sun in the x-y plane, azimuth measured from the sun.
	float sin_view_zenith = sqrt(max(1.0 - cos_view_zenith * cos_view_zenith, 0.0));
	vec3 view_dir = vec3(
		sin_view_zenith * cos_light_view,
		cos_view_zenith,
		sin_view_zenith * sqrt(max(1.0 - cos_light_view * cos_light_view, 0.0)));
	float mu_s = clamp(sun_zenith_cos, -1.0, 1.0);
	vec3 sun_dir = vec3(sqrt(max(1.0 - mu_s * mu_s, 0.0)), mu_s, 0.0);
	vec3 origin = vec3(0.0, r, 0.0);

	// March to the ground if the ray hits it, otherwise to the top of the atmosphere.
	float t_ground = ray_sphere(origin, view_dir, ATMO_RG);
	float t_top = ray_sphere(origin, view_dir, ATMO_RT);
	float t_max = t_ground > 0.0 ? t_ground : max(t_top, 0.0);
	float dt = t_max / float(MARCH_STEPS);

	float cos_theta = dot(view_dir, sun_dir);
	float phase_r = rayleigh_phase(cos_theta);
	float phase_m = mie_phase_cornette_shanks(cos_theta, ATMO_MIE_G);

	vec3 radiance = vec3(0.0);
	vec3 throughput = vec3(1.0);
	for (int i = 0; i < MARCH_STEPS; i++) {
		float t = (float(i) + MARCH_SAMPLE_OFFSET) * dt;
		vec3 p = origin + view_dir * t;
		float p_height = length(p);
		vec3 up = p / p_height;
		AtmosphereMedium medium = atmosphere_medium(max(p_height - ATMO_RG, 0.0));
		vec3 sample_transmittance_step = exp(-medium.extinction * dt);
		float sun_cos = dot(sun_dir, up);
		vec3 sun_transmittance = sample_transmittance(p_height, sun_cos);
		// Earth shadow: the sun is below this sample's local horizon.
		float t_earth = ray_sphere(p + up * PLANET_RADIUS_OFFSET_KM, sun_dir, ATMO_RG);
		float earth_shadow = t_earth >= 0.0 ? 0.0 : 1.0;
		vec3 phase_scattering = medium.rayleigh_scattering * phase_r + vec3(medium.mie_scattering * phase_m);
		vec3 multi_scattered = sample_multiscatter(p_height, sun_cos);
		vec3 s = earth_shadow * sun_transmittance * phase_scattering + multi_scattered * medium.scattering;
		// Energy-conserving analytic integration over the step (Hillaire 2020 section 5.3).
		vec3 s_int = (s - s * sample_transmittance_step) / max(medium.extinction, vec3(1e-7));
		radiance += throughput * s_int;
		throughput *= sample_transmittance_step;
	}
	vec3 result = max(radiance * sun_illuminance, vec3(0.0));
	if (encode_srgb) {
		// Inverse of Godot's srgb_to_linear, valid above 1.0 for HDR values.
		result = mix(
			1.055 * pow(result, vec3(1.0 / 2.4)) - 0.055,
			result * 12.92,
			lessThan(result, vec3(0.0031308)));
	}
	COLOR = vec4(result, 1.0);
}
