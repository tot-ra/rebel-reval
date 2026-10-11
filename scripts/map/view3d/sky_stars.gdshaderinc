// R-1443: naked-eye stars and the Milky Way for the sky dome over Reval.
// Included by sky_weather_3d.gdshader after star_map, cloud_noise, cloud_shape,
// sun_direction, moon_direction and moon_phase are declared.
//
// WHY: sampling the nearest-filtered star map directly blew every catalog
// texel up into a 3-4 pixel square, and the old 5-texel '+' kernel for bright
// stars read as little crosses. Stars are point sources, so each catalog texel
// near the ray is now drawn as a round, pixel-sized point-spread disk.

// Seconds of real (presentation) time for scintillation. Pushed by SkyWeather3D;
// visual only, never stored in game state.
uniform float star_twinkle_time = 0.0;
// Overall star brightness relative to the old one-texel sample.
uniform float star_gain : hint_range(0.0, 8.0) = 2.4;
// Galactic north pole and galactic centre as unit vectors in the star map's
// equatorial frame. SkyWeather3D pushes them precessed to 1343; the defaults
// are the J2000 values.
uniform vec3 galactic_pole = vec3(-0.86766, -0.19808, 0.45598);
uniform vec3 galactic_center = vec3(-0.05487, -0.87342, -0.48384);
uniform float milky_way_strength : hint_range(0.0, 4.0) = 1.0;

// Must match SkyWeatherResources.STAR_MAP_WIDTH / STAR_MAP_HEIGHT.
const float STAR_TEXELS_X = 2048.0;
const float STAR_TEXELS_Y = 1024.0;
// Wider PSFs would need more than the +-1 declination texels searched below.
const float STAR_PSF_MAX = 0.0011;
const int STAR_SEARCH_MAX_X = 12;

vec3 equatorial_vector(float right_ascension, float declination) {
	float c = cos(declination);
	return vec3(c * cos(right_ascension), c * sin(right_ascension), sin(declination));
}

float star_hash(vec2 texel) {
	return fract(sin(dot(texel, vec2(12.9898, 78.233))) * 43758.5453);
}

// Sum of three incommensurate sines: a cheap, smooth stand-in for the
// turbulent intensity flicker of a star seen through moving air. Range ~[-1, 1].
float star_flicker(float seed, float phase) {
	float t = star_twinkle_time;
	return sin(t * (6.1 + seed * 5.3) + seed * 41.0 + phase) * 0.5
		+ sin(t * (11.7 + seed * 4.1) + seed * 93.0 + phase * 1.7) * 0.3
		+ sin(t * (2.3 + seed * 1.9) + seed * 17.0 + phase * 0.6) * 0.2;
}

// `uv` is equatorial_uv(dir); `height` is dir.y; `pixel_angle` the angular size
// of one screen pixel in radians.
vec3 star_field(vec2 uv, float height, float pixel_angle) {
	float ray_ra = uv.x * TAU;
	float ray_dec = (0.5 - uv.y) * PI;
	vec3 ray = equatorial_vector(ray_ra, ray_dec);
	// About one screen pixel wide at any resolution or FOV.
	float sigma = clamp(pixel_angle * 0.6, 0.00025, STAR_PSF_MAX);
	// Bright stars may spread up to 2x sigma (see below), so search 3 * 2 sigma.
	float reach = sigma * 6.0;
	// Texel centres follow SkyWeatherResources.bake_stars exactly:
	// x = round(ra / TAU * W), y = round((90 - dec) / 180 * (H - 1)).
	float fx = uv.x * STAR_TEXELS_X;
	float fy = (0.5 - ray_dec / PI) * (STAR_TEXELS_Y - 1.0);
	int x0 = int(round(fx));
	int y0 = int(round(fy));
	// Right-ascension texels shrink toward the poles (Polaris sits at 85.7 deg in
	// 1343), so widen the search there instead of clipping the disk.
	float texel_ra = TAU / STAR_TEXELS_X * max(cos(ray_dec), 1e-3);
	int nx = clamp(int(ceil(reach / texel_ra)), 1, STAR_SEARCH_MAX_X);
	// Scintillation grows with air mass: barely visible at the zenith, strong low down.
	float amplitude = mix(0.55, 0.10, smoothstep(0.0, 0.7, height));
	vec3 light = vec3(0.0);
	for (int dy = -1; dy <= 1; dy++) {
		int y = clamp(y0 + dy, 0, int(STAR_TEXELS_Y) - 1);
		float dec = PI * 0.5 - float(y) * PI / (STAR_TEXELS_Y - 1.0);
		for (int dx = -STAR_SEARCH_MAX_X; dx <= STAR_SEARCH_MAX_X; dx++) {
			if (abs(dx) > nx) {
				continue;
			}
			int x = (x0 + dx) % int(STAR_TEXELS_X);
			x = x < 0 ? x + int(STAR_TEXELS_X) : x;
			vec3 c = texelFetch(star_map, ivec2(x, y), 0).rgb;
			float luminance = max(c.r, max(c.g, c.b));
			if (luminance <= 0.0) {
				continue;
			}
			vec3 s = equatorial_vector(float(x) / STAR_TEXELS_X * TAU, dec);
			float d = length(ray - s);
			// Brighter stars look slightly larger to the eye (and to a camera).
			float spread = sigma * (1.0 + 0.19 * log(max(luminance, 1.0)));
			float psf = exp(-0.5 * d * d / (spread * spread));
			if (psf < 1e-3) {
				continue;
			}
			float seed = star_hash(vec2(float(x), float(y)));
			float mono = star_flicker(seed, 0.0);
			// Chromatic scintillation: low bright stars (Sirius, Capella on the
			// horizon) flash red and blue because dispersion splits the colours.
			float chroma = amplitude * smoothstep(3.0, 40.0, luminance) * smoothstep(0.45, 0.05, height);
			vec3 twinkle = vec3(
				star_flicker(seed, 1.9),
				mono,
				star_flicker(seed, 4.2)
			);
			vec3 gain = max(vec3(1.0) + amplitude * mix(vec3(mono), twinkle, chroma), vec3(0.0));
			light += c * psf * gain;
		}
	}
	return light * star_gain;
}

// Diffuse glow of the Galaxy. Galactic latitude/longitude come from the
// precessed pole and centre, so the band lies where it does over Tallinn: low
// along the northern horizon on spring nights, overhead through Cygnus and
// Cassiopeia in late summer and autumn, and the bright southern bulge in
// Sagittarius never clears the horizon at 59.4 N.
vec3 milky_way(vec2 uv) {
	vec3 ray = equatorial_vector(uv.x * TAU, (0.5 - uv.y) * PI);
	float b = asin(clamp(dot(ray, galactic_pole), -1.0, 1.0));
	vec3 l90 = cross(galactic_pole, galactic_center);
	// 0 at the galactic centre, +PI/2 in Cygnus, +-PI at the anticentre (Auriga).
	float l = atan(dot(ray, l90), dot(ray, galactic_center));
	float bulge = exp(-pow(l / 0.55, 2.0));
	float cygnus = exp(-pow((l - 1.38) / 0.38, 2.0));
	float cassiopeia = exp(-pow((l - 2.0) / 0.35, 2.0));
	float anticentre = smoothstep(1.6, PI, abs(l));
	float width = mix(0.085, 0.17, bulge) + 0.035 * cygnus;
	float disk = exp(-0.5 * pow(b / width, 2.0));
	// Faint thick halo so the band edge is soft rather than a ribbon.
	disk += 0.25 * exp(-0.5 * pow(b / (width * 2.6), 2.0));
	float level = (0.42 + 1.1 * bulge + 0.45 * cygnus + 0.18 * cassiopeia) * mix(1.0, 0.55, anticentre);
	// Lumpy star clouds from the cellular cloud texture. The longitude factor is
	// an integer so the pattern wraps seamlessly at the anticentre.
	vec2 g = vec2(l, b) / TAU;
	// Large star clouds stay low-contrast (high contrast reads as weather
	// clouds); most of the texture is fine unresolved-star grain.
	float clumps = textureLod(cloud_shape, g * 23.0 + vec2(0.37, 0.11), 0.0).r;
	float grain = textureLod(cloud_noise, g * 97.0 + vec2(0.71, 0.29), 0.0).r;
	float speckle = textureLod(cloud_shape, g * 211.0 + vec2(0.13, 0.57), 0.0).r;
	float mottle = mix(0.7, 1.2, clumps) * mix(0.55, 1.35, grain) * mix(0.7, 1.25, speckle);
	// Great Rift: dust lanes splitting the band from Cygnus to Aquila/Sagittarius,
	// slightly north of the galactic plane, plus the Coalsack-like ragged edges.
	float rift_span = smoothstep(-0.45, -0.1, l) * (1.0 - smoothstep(1.45, 1.75, l));
	float lane_noise = textureLod(cloud_noise, g * vec2(13.0, 29.0) + vec2(0.5, 0.2), 0.0).r;
	float rift_b = 0.03 + 0.015 * sin(l * 4.0) + (lane_noise - 0.5) * 0.05;
	float rift = exp(-0.5 * pow((b - rift_b) / 0.04, 2.0)) * rift_span;
	rift *= smoothstep(0.25, 0.75, textureLod(cloud_noise, g * vec2(37.0, 61.0), 0.0).r);
	float glow = disk * level * mottle * (1.0 - 0.8 * rift);
	vec3 tint = mix(vec3(0.80, 0.86, 1.0), vec3(1.0, 0.91, 0.78), bulge);
	return tint * glow * milky_way_strength;
}

// 0..1 how much of the faint galactic glow survives the sky brightness. The
// Milky Way needs nearly astronomical darkness (sun below about -16 degrees)
// and a moonless sky, which is why it fades out of Reval's white summer nights.
float milky_way_visibility(float height) {
	float darkness = smoothstep(-0.10, -0.28, sun_direction.y);
	float moon_up = smoothstep(-0.05, 0.15, moon_direction.y);
	float moon_lit = 0.5 - 0.5 * cos(moon_phase * TAU);
	float moon_wash = 1.0 - 0.85 * moon_up * moon_lit;
	// Extinction and horizon haze hide the band in the lowest few degrees.
	float extinction = smoothstep(0.0, 0.35, height);
	return darkness * moon_wash * extinction;
}
