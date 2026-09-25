// WS-09 atmosphere parameterisation shared by the physical sky (WS-10) and sky-driven water/fog
// (WS-11). No runtime user yet; nothing includes this file until WS-10.
//
// Sebastien Hillaire, "A Scalable and Production Ready Sky and Atmosphere Rendering Technique"
// (EGSR 2020), with the Bruneton and Neyret 2008 transmittance mapping.
// Ported from Tidewater (MIT), see notice.code.tidewater (src/sky/Atmosphere.js).
//
// This is the GLSL side of tools/bake_atmosphere_luts.py; every constant and mapping below must
// match that file and assets/sky/atmosphere/atmosphere_profile.json (test_atmosphere_luts.gd
// checks the constants). Units are km. Bind both LUTs with `filter_linear, repeat_disable`:
//   uniform sampler2D atmosphere_transmittance_lut : filter_linear, repeat_disable;  // 256x64
//   uniform sampler2D atmosphere_multiscatter_lut : filter_linear, repeat_disable;   // 32x32

// Hillaire 2020 section 4: Earth atmosphere constants (Tidewater defaults).
const float ATMO_RG = 6360.0;
const float ATMO_RT = 6460.0;
const vec3 ATMO_RAYLEIGH_SCATTERING = vec3(5.802e-3, 13.558e-3, 33.1e-3);
const float ATMO_RAYLEIGH_SCALE_HEIGHT = 8.0;
const float ATMO_MIE_SCATTERING = 3.996e-3;
const float ATMO_MIE_EXTINCTION = 4.440e-3;
const float ATMO_MIE_SCALE_HEIGHT = 1.2;
const float ATMO_MIE_G = 0.8;
const vec3 ATMO_OZONE_ABSORPTION = vec3(0.650e-3, 1.881e-3, 0.085e-3);
const float ATMO_OZONE_CENTER = 25.0;
const float ATMO_OZONE_HALF_WIDTH = 15.0;
const vec3 ATMO_GROUND_ALBEDO = vec3(0.06, 0.08, 0.10);
const vec2 ATMO_TRANSMITTANCE_SIZE = vec2(256.0, 64.0);
const float ATMO_MULTISCATTER_SIZE = 32.0;
const float ATMO_PI = 3.14159265358979;

struct AtmosphereMedium {
	vec3 rayleigh_scattering;
	float mie_scattering;
	vec3 extinction;
	vec3 scattering;
};

// Hillaire 2020 section 4: participating media at altitude h_km above the ground. The baked LUTs
// use scale 1 for all three; WS-10 must pass the profile's scales if it ever re-bakes with others.
AtmosphereMedium atmosphere_medium(float h_km) {
	float rayleigh_density = exp(-h_km / ATMO_RAYLEIGH_SCALE_HEIGHT);
	float mie_density = exp(-h_km / ATMO_MIE_SCALE_HEIGHT);
	float ozone_density = max(0.0, 1.0 - abs(h_km - ATMO_OZONE_CENTER) / ATMO_OZONE_HALF_WIDTH);
	AtmosphereMedium m;
	m.rayleigh_scattering = ATMO_RAYLEIGH_SCATTERING * rayleigh_density;
	m.mie_scattering = ATMO_MIE_SCATTERING * mie_density;
	m.extinction = m.rayleigh_scattering + ATMO_MIE_EXTINCTION * mie_density + ATMO_OZONE_ABSORPTION * ozone_density;
	m.scattering = m.rayleigh_scattering + m.mie_scattering;
	return m;
}

// Nearest positive intersection of a planet-centred sphere, -1 on a miss (Tidewater semantics).
float ray_sphere(vec3 ro, vec3 rd, float radius) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - radius * radius;
	float disc = b * b - c;
	if (disc < 0.0) {
		return -1.0;
	}
	float sq = sqrt(disc);
	float t0 = -b - sq;
	float t1 = -b + sq;
	return t0 > 0.0 ? t0 : (t1 > 0.0 ? t1 : -1.0);
}

// Maps [0, 1] onto first..last texel centres (Bruneton). Tidewater's forward mapping scales by
// N/(N+1) and disagrees with its own bake; this pair is the one the WS-09 bake inverts.
float atmosphere_unit_to_sub_uv(float x, float size) {
	return 0.5 / size + x * (size - 1.0) / size;
}

float atmosphere_sub_uv_to_unit(float u, float size) {
	return (u - 0.5 / size) * size / (size - 1.0);
}

// Hillaire 2020 section 5.1 / Bruneton 2008 section 4: (r, mu) -> transmittance LUT uv. Row 0
// (uv.y = 0) is the ground; column 0 is straight up; mu below the ground horizon clamps.
vec2 transmittance_uv(float r, float mu) {
	float h = sqrt(ATMO_RT * ATMO_RT - ATMO_RG * ATMO_RG);
	float rho = sqrt(max(r * r - ATMO_RG * ATMO_RG, 0.0));
	float disc = r * r * (mu * mu - 1.0) + ATMO_RT * ATMO_RT;
	float d = max(0.0, -r * mu + sqrt(max(disc, 0.0)));
	float d_min = ATMO_RT - r;
	float d_max = rho + h;
	float x_mu = (d - d_min) / (d_max - d_min);
	float x_r = rho / h;
	return vec2(
		atmosphere_unit_to_sub_uv(x_mu, ATMO_TRANSMITTANCE_SIZE.x),
		atmosphere_unit_to_sub_uv(x_r, ATMO_TRANSMITTANCE_SIZE.y));
}

// Inverse of transmittance_uv: returns vec2(r_km, mu).
vec2 transmittance_r_mu(vec2 uv) {
	float x_mu = atmosphere_sub_uv_to_unit(uv.x, ATMO_TRANSMITTANCE_SIZE.x);
	float x_r = atmosphere_sub_uv_to_unit(uv.y, ATMO_TRANSMITTANCE_SIZE.y);
	float h = sqrt(ATMO_RT * ATMO_RT - ATMO_RG * ATMO_RG);
	float rho = x_r * h;
	float r = sqrt(rho * rho + ATMO_RG * ATMO_RG);
	float d_min = ATMO_RT - r;
	float d_max = rho + h;
	float d = d_min + x_mu * (d_max - d_min);
	float mu = d == 0.0 ? 1.0 : (h * h - rho * rho - d * d) / (2.0 * r * d);
	return vec2(r, clamp(mu, -1.0, 1.0));
}

// Hillaire 2020 section 5.5: (r, cos sun zenith) -> multi-scattering LUT uv. Row 0 is the ground.
vec2 multiscatter_uv(float r, float mu_sun) {
	return vec2(
		atmosphere_unit_to_sub_uv(mu_sun * 0.5 + 0.5, ATMO_MULTISCATTER_SIZE),
		atmosphere_unit_to_sub_uv(clamp((r - ATMO_RG) / (ATMO_RT - ATMO_RG), 0.0, 1.0), ATMO_MULTISCATTER_SIZE));
}

// Hillaire 2020 section 4, equation 2.
float rayleigh_phase(float cos_theta) {
	return 3.0 / (16.0 * ATMO_PI) * (1.0 + cos_theta * cos_theta);
}

// Hillaire 2020 section 4, equation 4 (Cornette-Shanks), as in Tidewater's sky-view kernel.
float mie_phase_cornette_shanks(float cos_theta, float g) {
	float g2 = g * g;
	return 3.0 / (8.0 * ATMO_PI) * ((1.0 - g2) * (1.0 + cos_theta * cos_theta))
		/ ((2.0 + g2) * pow(max(1.0 + g2 - 2.0 * g * cos_theta, 1e-4), 1.5));
}
