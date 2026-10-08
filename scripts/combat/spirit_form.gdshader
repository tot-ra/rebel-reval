shader_type canvas_item;
// Opponent spirit form for the spirit arena (ADR 0033, R-1335). Fully procedural (asset
// freeze P0-040): the opponent's spirit image looms over his body as a glowing
// signed-distance shape, optionally over a dark body silhouette (when no staged actor
// stands behind the arena). `presence` (pressure left) scales the image, `crack` opens
// glowing fissures and finally scatters it into shards, `swell` grows it while a blow is
// telegraphed, `flash` / `recoil` answer each blow.
// Frame units are metres around the opponent's chest: `focus` is the chest in screen UV and
// `frame_height` is one metre as a share of the screen height.

// 0 = generic wisp, 1 = rusted key, 2 = rod.
uniform int image_kind = 0;
uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float crack : hint_range(0.0, 1.0) = 0.0;
uniform float swell : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float recoil : hint_range(-1.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 focus = vec2(0.5, 0.55);
uniform float frame_height = 0.28;
uniform float show_body : hint_range(0.0, 1.0) = 1.0;
uniform vec4 spirit_color : source_color = vec4(0.62, 0.78, 0.95, 1.0);
uniform vec4 body_color : source_color = vec4(0.03, 0.03, 0.05, 1.0);

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Cellular noise: x = distance to the nearest cell border (F2 - F1), yz = nearest cell id.
vec3 cells(vec2 x) {
	vec2 base = floor(x);
	vec2 f = fract(x);
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 nearest = base;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			float d = length(g + hash2(base + g) - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				nearest = base + g;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec3(f2 - f1, nearest);
}

mat2 rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

float sd_box(vec2 p, vec2 half_size) {
	vec2 d = abs(p) - half_size;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sd_segment(vec2 p, vec2 a, vec2 b, float r0, float r1) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - mix(r0, r1, h);
}

float sd_key(vec2 q) {
	q = rot(-0.35) * q;
	float bow = abs(length(q - vec2(0.0, -0.24)) - 0.095) - 0.03;
	float shaft = sd_box(q - vec2(0.0, 0.06), vec2(0.024, 0.22));
	float bit_a = sd_box(q - vec2(0.055, 0.25), vec2(0.05, 0.026));
	float bit_b = sd_box(q - vec2(0.045, 0.17), vec2(0.038, 0.02));
	return min(min(bow, shaft), min(bit_a, bit_b));
}

float sd_rod(vec2 q) {
	q = rot(0.45) * q;
	float rod = sd_segment(q, vec2(0.0, -0.34), vec2(0.0, 0.34), 0.034, 0.016);
	// Leather bindings near the grip.
	float binding = min(
		sd_box(q - vec2(0.0, 0.22), vec2(0.046, 0.012)),
		sd_box(q - vec2(0.0, 0.27), vec2(0.044, 0.012))
	);
	return min(rod, binding);
}

float sd_image(vec2 q) {
	if (image_kind == 1) {
		return sd_key(q);
	}
	if (image_kind == 2) {
		return sd_rod(q);
	}
	return length(q * vec2(1.0, 0.7)) - 0.18;
}

// A heavy man from the head to the hips, in metres around the chest (y down).
float sd_body(vec2 p) {
	float head = length(p - vec2(0.0, -0.42)) - 0.12;
	float neck = sd_box(p - vec2(0.0, -0.28), vec2(0.06, 0.06));
	float shoulders = sd_segment(p, vec2(-0.2, -0.18), vec2(0.2, -0.18), 0.1, 0.1);
	float torso = sd_box(p - vec2(0.0, 0.22), vec2(0.22, 0.4)) - 0.06;
	return min(min(head, neck), min(shoulders, torso));
}

void fragment() {
	float aspect = rect_size.x / max(rect_size.y, 1.0);
	vec2 p = (UV - focus) * vec2(aspect, 1.0) / max(frame_height, 0.01);
	p.x -= recoil * 0.08;

	// Spirit image: about a metre tall, centred a metre over the chest; shrinks with
	// pressure, swells as a blow winds up, flinches back on a hit.
	float scale = 1.4 * mix(0.42, 1.0, presence) * (1.0 + 0.22 * swell) * (1.0 - 0.06 * abs(recoil));
	vec2 q = (p - vec2(0.0, -1.0)) / scale;
	q += 0.008 * vec2(sin(q.y * 28.0 + TIME * 3.1), cos(q.x * 23.0 + TIME * 2.4));
	// Shattering: past half cracked, each cell drifts outward from the centre.
	vec3 cell = cells(q * 7.0);
	float shatter = smoothstep(0.55, 1.0, crack);
	vec2 drift = (hash2(cell.yz) - 0.5) * 0.18 + normalize(cell.yz / 7.0 + 0.001) * 0.05;
	vec2 qs = q - drift * shatter;
	vec3 shard = cells(qs * 7.0);
	float d = sd_image(qs);

	float fill = smoothstep(0.008, -0.008, d);
	float glow = exp(-max(d, 0.0) * 14.0) * 0.55;
	float fissure = (1.0 - smoothstep(0.0, 0.02 + 0.06 * crack, shard.x)) * step(0.02, crack);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.2);
	float spirit_alpha = (fill * mix(0.35, 0.92, presence) + glow * pulse) * (1.0 - 0.75 * shatter);
	vec3 spirit = spirit_color.rgb * (0.65 + 0.35 * fill);
	spirit = mix(spirit, vec3(1.0, 0.86, 0.6), fissure * fill * crack);
	spirit = mix(spirit, vec3(1.0), flash * 0.8);
	spirit_alpha = clamp(spirit_alpha + fissure * fill * crack * 0.5 + flash * glow, 0.0, 1.0);

	// The body: a dark silhouette lit only by a thin spirit-coloured rim.
	vec2 bp = p - vec2(recoil * 0.02, 0.0);
	float bd = sd_body(bp);
	float body = smoothstep(0.01, -0.01, bd) * show_body;
	float rim = exp(-abs(bd) * 60.0) * 0.6 * (0.6 + 0.4 * presence) * show_body;
	vec3 body_rgb = mix(body_color.rgb, spirit_color.rgb, rim + flash * 0.25 * body);

	// The image looms behind the body: body occludes it, the rim stays on top.
	vec3 rgb = mix(spirit, body_rgb, body);
	float alpha = max(spirit_alpha * (1.0 - body), max(body * 0.92, rim));
	COLOR = vec4(rgb, clamp(alpha, 0.0, 1.0));
}
