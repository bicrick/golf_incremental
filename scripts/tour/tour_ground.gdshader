shader_type spatial;
render_mode unshaded, cull_disabled;
// v8 ground: one plane, painted per range. World: 1 unit = 1 yard, -Z down
// range. Greens, hazards, light pools and ground mist are all drawn here so
// the whole range reads as one piece of pixel art.

uniform int style = 0; // 0 meadow, 1 cliffs, 2 mesa, 3 frost, 4 edge
uniform vec3 fairway_a : source_color = vec3(0.36, 0.62, 0.24);
uniform vec3 fairway_b : source_color = vec3(0.31, 0.56, 0.21);
uniform vec3 rough_a : source_color = vec3(0.24, 0.47, 0.18);
uniform vec3 rough_b : source_color = vec3(0.20, 0.41, 0.16);
uniform vec3 outer_a : source_color = vec3(0.18, 0.38, 0.17);
uniform vec3 outer_b : source_color = vec3(0.14, 0.31, 0.15);
uniform vec3 green_a : source_color = vec3(0.42, 0.72, 0.30);
uniform vec3 green_b : source_color = vec3(0.37, 0.66, 0.27);
uniform vec3 fringe : source_color = vec3(0.30, 0.55, 0.22);
uniform vec3 hazard_a : source_color = vec3(0.16, 0.42, 0.62);
uniform vec3 hazard_b : source_color = vec3(0.26, 0.56, 0.74);
uniform vec3 accent : source_color = vec3(1.0, 0.95, 0.7); // flowers / foam / snow sparkle
uniform vec3 haze : source_color = vec3(0.75, 0.80, 0.86);
uniform vec3 mist_color : source_color = vec3(0.92, 0.93, 0.95);
uniform float haze_start = 120.0;
uniform float haze_end = 600.0;
uniform float haze_max = 0.75;
uniform float half_width = 24.0;
uniform float stripe_len = 12.0;
uniform vec4 hazards[2]; // z0, z1, kind (1 water, 2 canyon), 0
uniform vec3 island = vec3(0.0, -9999.0, 0.0); // x, d, r
uniform vec4 greens[6]; // x, d, r, state (0 open, 1 starred, 2 lantern dark, 3 lantern lit, 4 hidden, -1 unused)
uniform float darkness = 0.0; // 0 day .. 1 night
uniform vec3 night_tint : source_color = vec3(0.10, 0.14, 0.28);
uniform vec3 lamp_color : source_color = vec3(1.0, 0.78, 0.42);
uniform float mist_amount = 0.0;
uniform float mist_far = 1.0; // mist thickens with distance
uniform float reach = 150.0;
uniform float time_s = 0.0;
uniform float sea_side = 0.0; // cliffs: sea past this x (0 = none)

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int idx = q.x + q.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}

void fragment() {
	vec2 p = vec2(world_pos.x, -world_pos.z); // x right, d down range
	float d = p.y;
	vec2 sp = floor(SCREEN_UV * VIEWPORT_SIZE);
	float dither = bayer4(sp);
	// Fairway edge wobbles a little so it never looks ruled.
	float wobble = (fbm(vec2(d * 0.03, 3.0)) - 0.5) * 6.0;
	float hw = half_width + wobble;
	float ax = abs(p.x);
	vec3 col;
	float n = fbm(p * 0.35);
	float grain = hash(floor(p * 2.0));

	if (ax < hw && d > -30.0) {
		float stripe = mod(floor(d / stripe_len), 2.0);
		col = mix(fairway_a, fairway_b, stripe);
		col *= 0.96 + 0.08 * step(0.55, n);
	} else if (ax < hw + 10.0) {
		col = mix(rough_a, rough_b, step(0.5, n));
	} else {
		float m = fbm(p * 0.08);
		col = mix(outer_a, outer_b, step(0.52, m));
		if (grain > 0.985 && style != 4 && d < 160.0) {
			col = accent; // flowers, pebbles, snow glints
		}
	}
	col *= 0.97 + 0.06 * grain;

	// Cliffs: the sea along the right, with a foam line.
	if (sea_side > 0.0) {
		float edge = sea_side + (fbm(vec2(d * 0.05, 1.0)) - 0.5) * 14.0;
		if (p.x > edge) {
			float w = fbm(p * vec2(0.05, 0.2) + vec2(time_s * 0.05, 0.0));
			col = mix(hazard_a, hazard_b, step(0.55, w));
			if (p.x < edge + 3.0 + 1.5 * sin(time_s * 1.3 + d * 0.2)) {
				col = accent;
			}
		} else if (p.x > edge - 6.0) {
			col = mix(outer_b, vec3(0.62, 0.56, 0.46), 0.6); // cliff lip
		}
	}

	// Hazard bands across the range.
	for (int i = 0; i < 2; i++) {
		vec4 h = hazards[i];
		if (h.z < 0.5) continue;
		float z0 = h.x + (fbm(vec2(p.x * 0.06, float(i) * 7.0)) - 0.5) * 6.0;
		float z1 = h.y + (fbm(vec2(p.x * 0.06, float(i) * 7.0 + 3.0)) - 0.5) * 6.0;
		if (d > z0 && d < z1) {
			bool dry = distance(p, island.xy) < island.z;
			if (!dry) {
				if (h.z < 1.5) {
					float w = fbm(p * vec2(0.08, 0.25) + vec2(time_s * 0.04, time_s * 0.02));
					col = mix(hazard_a, hazard_b, step(0.58, w));
					if (hash(floor(p * 1.5 + floor(time_s * 3.0))) > 0.992) col = accent;
					if (d < z0 + 1.6 || d > z1 - 1.6) col = mix(col, accent, 0.7);
				} else {
					float depth = min(d - z0, z1 - d) / max((z1 - z0) * 0.5, 1.0);
					float strata = step(0.5, fract((d - z0) * 0.28 + fbm(p * 0.1) * 0.8));
					col = mix(hazard_a, hazard_b, strata) * (1.0 - 0.55 * clamp(depth * 1.6, 0.0, 1.0));
					if (d < z0 + 1.2) col = hazard_b * 1.15;
				}
			} else if (distance(p, island.xy) > island.z - 2.0) {
				col = vec3(0.86, 0.80, 0.62); // sandy island rim
			}
		}
	}

	// Greens: fringe, putting surface, a tiny cup.
	float light = 0.0;
	for (int i = 0; i < 6; i++) {
		vec4 g = greens[i];
		if (g.w < -0.5) continue;
		float gd = distance(p, g.xy);
		if (g.w > 3.5) continue;
		if (gd < g.z + 2.0) {
			float rings = step(0.5, fract(gd * 0.25));
			col = gd < g.z ? mix(green_a, green_b, rings) : fringe;
			if (g.w > 0.5 && g.w < 1.5 && gd < g.z && gd > g.z - 0.9) {
				col = mix(col, vec3(1.0, 0.93, 0.55), 0.45); // starred rim glows
			}
			if (gd < 0.6) col = vec3(0.08, 0.10, 0.08);
		}
		if (g.w > 2.5 && g.w < 3.5) {
			light = max(light, 1.0 - smoothstep(4.0, g.z * 3.2, gd));
		} else if (g.w > 1.5 && g.w < 2.5) {
			// Unlit lanterns still show a cold ring of moonlight so you can aim.
			light = max(light, 0.35 * (1.0 - smoothstep(g.z * 0.8, g.z * 1.6, gd)));
		}
	}

	// Reach arc: a faint dotted line at the Perfect carry.
	float rd = length(p);
	if (abs(rd - reach) < 0.9 && mod(atan(p.x, p.y) * reach * 0.25, 2.0) < 1.0 && ax < hw + 10.0) {
		col = mix(col, vec3(1.0, 0.97, 0.85), 0.55);
	}

	// Night: everything sinks into blue except the lantern pools and the tee.
	if (darkness > 0.0) {
		float tee = 1.0 - smoothstep(6.0, 34.0, rd);
		float lit = max(light, tee * 0.9);
		float lq = floor(lit * 4.0 + dither) / 4.0;
		vec3 night = col * night_tint * 2.2;
		vec3 warm = col * lamp_color * 1.1;
		col = mix(col, mix(night, warm, lq), darkness);
		if (grain > 0.992 && lit < 0.2) col += vec3(0.25) * darkness; // snow glints
	}

	// Ground mist: flat, drifting shapes with a bright lip on their far
	// edge — cartoon fog, no stipple. Two tones, thicker with distance.
	if (mist_amount > 0.0) {
		vec2 mp = p * vec2(0.03, 0.012) + vec2(time_s * 0.02, time_s * 0.006);
		float m = fbm(mp);
		float m_ahead = fbm(mp + vec2(0.0, 0.035));
		float far = mix(1.0, smoothstep(20.0, 260.0, d), mist_far);
		float t1 = 0.66 - 0.16 * far * mist_amount;
		float t2 = t1 + 0.09;
		if (m > t2) {
			col = mix(col, mist_color, 0.62 * mist_amount);
		} else if (m > t1) {
			col = mix(col, mist_color, 0.34 * mist_amount);
			if (m_ahead < t1) col = mix(col, vec3(1.0), 0.35 * mist_amount);
		}
	}

	// Distance haze toward the sky, dithered in steps.
	float hz = clamp((d - haze_start) / max(haze_end - haze_start, 1.0), 0.0, 1.0) * haze_max;
	hz = floor(hz * 5.0 + dither) / 5.0;
	col = mix(col, haze, hz);

	ALBEDO = col;
}
