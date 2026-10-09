// R-1518: physical rainbow shared by the sky dome and the water reflection.
//
// A rainbow is sunlight refracted and internally reflected by falling drops. Every
// drop that sends a given wavelength to the eye sits on a cone around the antisolar
// point (the direction straight away from the sun, through the observer's shadow).
// Descartes' minimum-deviation angle sets the cone radius per wavelength:
//   primary   (1 internal reflection):  ~42.4 deg red  .. ~40.6 deg violet (red OUTSIDE)
//   secondary (2 internal reflections): ~50.4 deg red  .. ~53.6 deg violet (red INSIDE)
// Light is scattered towards smaller angles than the primary (bright sky inside the
// bow) and larger angles than the secondary; nothing reaches the gap between them,
// which is Alexander's dark band. Because the cone is anchored to the eye, the bow
// moves with the camera, never has a place where it "touches" the ground, and needs
// the sun below ~42 deg (primary) / ~54 deg (secondary) to show above the horizon.
//
// Drop size matters: large rain drops give narrow saturated bands; mist and fog
// droplets (<0.05 mm) diffract so strongly that the colours overlap into a broad,
// nearly white fogbow at a slightly smaller radius. Mid-size drops add pale
// supernumerary fringes just inside the primary.
//
// Callers own the uniforms (rainbow_strength, rainbow_droplet, rainbow_curtain) so the
// sky and the water read the same values pushed from SkyWeather3D.

const int RAINBOW_SAMPLES = 9;
const float RAINBOW_DEG = 0.017453293;

// Refractive index of water (Cauchy fit, lambda in nm): 1.3305 at 700 nm, 1.3435 at 400 nm.
float rainbow_water_index(float lambda_nm) {
	return 1.3242 + 3090.0 / (lambda_nm * lambda_nm);
}

// Angular radius from the antisolar point for k internal reflections (k = 1 or 2).
// Minimum deviation: cos^2(i) = (n^2 - 1) / (k^2 + 2k); D = 2(i - r) + k(pi - 2r).
float rainbow_radius(float n, float k) {
	float cos_i = sqrt((n * n - 1.0) / (k * k + 2.0 * k));
	float i = acos(cos_i);
	float r = asin(sin(i) / n);
	float deviation = 2.0 * (i - r) + k * (PI - 2.0 * r);
	return abs(PI - deviation);
}

// CIE 1931 colour matching, Wyman/Sloan/Shirley multi-lobe Gaussian fit, to linear sRGB.
vec3 rainbow_spectral_rgb(float lambda_nm) {
	float t1 = (lambda_nm - 442.0) * ((lambda_nm < 442.0) ? 0.0624 : 0.0374);
	float t2 = (lambda_nm - 599.8) * ((lambda_nm < 599.8) ? 0.0264 : 0.0323);
	float t3 = (lambda_nm - 501.1) * ((lambda_nm < 501.1) ? 0.0490 : 0.0382);
	float x = 0.362 * exp(-0.5 * t1 * t1) + 1.056 * exp(-0.5 * t2 * t2) - 0.065 * exp(-0.5 * t3 * t3);
	float t4 = (lambda_nm - 568.8) * ((lambda_nm < 568.8) ? 0.0213 : 0.0247);
	float t5 = (lambda_nm - 530.9) * ((lambda_nm < 530.9) ? 0.0613 : 0.0322);
	float y = 0.821 * exp(-0.5 * t4 * t4) + 0.286 * exp(-0.5 * t5 * t5);
	float t6 = (lambda_nm - 437.0) * ((lambda_nm < 437.0) ? 0.0845 : 0.0278);
	float t7 = (lambda_nm - 459.0) * ((lambda_nm < 459.0) ? 0.0385 : 0.0725);
	float z = 1.217 * exp(-0.5 * t6 * t6) + 0.681 * exp(-0.5 * t7 * t7);
	return vec3(
		3.2406 * x - 1.5372 * y - 0.4986 * z,
		-0.9689 * x + 1.8758 * y + 0.0415 * z,
		0.0557 * x - 0.2040 * y + 1.0570 * z);
}

// Asymmetric band: sharp on the dark side (outside the primary, inside the secondary),
// softer and with a long tail on the bright side, as the Airy profile is.
float rainbow_band(float offset_to_bright, float width) {
	if (offset_to_bright < 0.0) {
		float d = offset_to_bright / width;
		return exp(-d * d);
	}
	float d = offset_to_bright / (width * 1.7);
	return exp(-d * d);
}

// Linear rainbow radiance for view direction `dir` (unit), relative to sunlight of 1.
// droplet: 0 = fog/mist droplets (white fogbow) .. 1 = large rain drops (vivid bow).
vec3 rainbow_radiance(vec3 dir, vec3 sun_dir, float droplet) {
	vec3 anti_sun = -normalize(sun_dir);
	float theta = acos(clamp(dot(dir, anti_sun), -1.0, 1.0));
	// Early out far from both bows (the secondary's violet edge plus its blur).
	if (theta > 62.0 * RAINBOW_DEG || theta < 22.0 * RAINBOW_DEG) {
		return vec3(0.0);
	}
	float drop = clamp(droplet, 0.0, 1.0);
	// Sun disk (0.53 deg) plus diffraction broadening that grows as drops shrink.
	float width = mix(4.2, 0.55, sqrt(drop)) * RAINBOW_DEG;
	// Small drops pull the bow inwards (fogbows sit near 38-39 deg).
	float shrink = mix(-3.0, 0.0, drop) * RAINBOW_DEG;
	// Supernumeraries need drops of roughly 0.2-0.5 mm: a bump in the mid range.
	float supernumerary = smoothstep(0.25, 0.55, drop) * (1.0 - smoothstep(0.7, 0.95, drop)) * 0.45;
	float fringe_spacing = mix(2.4, 1.1, drop) * RAINBOW_DEG;
	// Tiny droplets smear the faint secondary (and the dark band beside it) away.
	float secondary_presence = smoothstep(0.15, 0.6, drop);
	float secondary_gain = 0.43 * secondary_presence;

	vec3 bow = vec3(0.0);
	vec3 white = vec3(0.0);
	for (int s = 0; s < RAINBOW_SAMPLES; s++) {
		float lambda_nm = mix(400.0, 700.0, (float(s) + 0.5) / float(RAINBOW_SAMPLES));
		vec3 rgb = rainbow_spectral_rgb(lambda_nm);
		white += rgb;
		float n = rainbow_water_index(lambda_nm);
		float r1 = rainbow_radius(n, 1.0) + shrink;
		float r2 = rainbow_radius(n, 2.0) - shrink;
		// Primary: bright side is inside (theta < r1).
		float inside1 = r1 - theta;
		float primary = rainbow_band(inside1, width);
		if (inside1 > 0.0 && supernumerary > 0.0) {
			float spacing = fringe_spacing * lambda_nm / 550.0;
			float fringe = 0.5 + 0.5 * cos(TAU * inside1 / spacing);
			primary += supernumerary * fringe * exp(-inside1 / (spacing * 2.5)) * step(width * 0.8, inside1);
		}
		// Secondary: bright side is outside (theta > r2).
		float secondary = rainbow_band(theta - r2, width * 1.3) * secondary_gain;
		bow += rgb * (primary + secondary);
	}
	// White-balance so the full spectrum sums to neutral: overlapping colours in a
	// fogbow, and the centre of the band, read white rather than tinted.
	bow /= max(white, vec3(1e-4));
	// Scattered white light: brighter sky inside the primary and outside the secondary,
	// nothing in between (Alexander's dark band).
	float r1_mid = rainbow_radius(rainbow_water_index(550.0), 1.0) + shrink;
	float r2_mid = rainbow_radius(rainbow_water_index(550.0), 2.0) - shrink;
	float inner_glow = smoothstep(r1_mid - 18.0 * RAINBOW_DEG, r1_mid - width, theta)
		* (1.0 - smoothstep(r1_mid - width, r1_mid + width, theta)) * 0.05;
	float outer_glow = smoothstep(r2_mid - width, r2_mid + width, theta)
		* (1.0 - smoothstep(r2_mid, r2_mid + 10.0 * RAINBOW_DEG, theta)) * 0.03 * secondary_presence;
	return bow + vec3(inner_glow + outer_glow);
}

// 0..1 visibility inside the Alexander band, used to darken the sky slightly there.
float rainbow_alexander_band(vec3 dir, vec3 sun_dir, float droplet) {
	float theta = acos(clamp(dot(dir, -normalize(sun_dir)), -1.0, 1.0));
	float drop = clamp(droplet, 0.0, 1.0);
	float shrink = mix(-3.0, 0.0, drop) * RAINBOW_DEG;
	return smoothstep(0.15, 0.6, drop) * smoothstep(42.3 * RAINBOW_DEG + shrink, 43.5 * RAINBOW_DEG + shrink, theta)
		* (1.0 - smoothstep(49.5 * RAINBOW_DEG - shrink, 50.6 * RAINBOW_DEG - shrink, theta));
}

// The bow only exists where lit drops hang in the air. After a shower the rain has
// drifted downwind, so `curtain.xz` points (unit, world XZ) at the departed rain and
// `curtain.y` is the cosine of its angular half-width. A zero xz means drops all
// around the observer (mist, fog): no azimuth mask.
float rainbow_curtain_mask(vec3 dir, vec3 curtain) {
	if (dot(curtain.xz, curtain.xz) < 1e-6) {
		return 1.0;
	}
	vec2 flat_dir = dir.xz / max(length(dir.xz), 1e-4);
	float c = dot(flat_dir, normalize(curtain.xz));
	// Wide feather: a shower thins out at its edge, so the bow fades rather than stops.
	return smoothstep(curtain.y - 0.6, curtain.y + 0.15, c);
}

// Applies the rainbow to a sky colour. `light` is the sunlight colour reaching the
// drops (orange at sunset gives the red, short-wavelength-starved evening bow).
vec3 rainbow_apply(vec3 color, vec3 dir, vec3 sun_dir, float strength, float droplet,
		vec3 curtain, vec3 light) {
	if (strength <= 0.0) {
		return color;
	}
	// Drops right at the horizon are far away behind more air; the ground hides the rest.
	float horizon = smoothstep(-0.005, 0.03, dir.y);
	float amount = strength * horizon * rainbow_curtain_mask(dir, curtain);
	if (amount <= 0.0) {
		return color;
	}
	color *= 1.0 - 0.12 * amount * rainbow_alexander_band(dir, sun_dir, droplet);
	vec3 bow = rainbow_radiance(dir, sun_dir, droplet) * light;
	return max(color + bow * amount, vec3(0.0));
}
