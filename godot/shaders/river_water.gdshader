shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// Opaque water avoids depth/screen sampling and transparent sorting seams.
// World coordinates keep the ripples continuous across separate river planes.
uniform vec4 water_color : source_color = vec4(0.247, 0.490, 0.545, 1.0);
uniform vec4 soft_reflection : source_color = vec4(0.48, 0.65, 0.64, 1.0);
uniform float ripple_speed : hint_range(0.0, 1.0) = 0.18;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.48;

varying vec3 water_world_position;

float water_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float water_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	return mix(mix(water_hash(cell), water_hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(water_hash(cell + vec2(0.0, 1.0)), water_hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void vertex() {
	water_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = water_world_position.xz;
	float t = TIME * ripple_speed;
	// Slow continuous domain warping breaks the diagonal lattice produced by
	// intersecting sine waves. Nothing is tiled to the construction grid.
	float drift = water_noise(p * 0.43 + vec2(0.0, -t * 0.10));
	float eddies = water_noise(p * 0.62 + vec2(19.7, 8.4) + t * 0.04);
	vec2 wave_position = p + (vec2(drift, eddies) - 0.5) * 1.45;
	// Several oblique wavelengths soften the regularity without textures or
	// high-frequency noise. The long component suggests a gentle river flow.
	vec2 d1 = vec2(0.91, 0.42);
	vec2 d2 = vec2(-0.38, 0.93);
	vec2 d3 = vec2(0.22, 0.98);
	float a = dot(wave_position, d1) * 5.2 - t * 2.4;
	float b = dot(wave_position, d2) * 8.3 + t * 1.3;
	float c = dot(p, d3) * 2.1 - t;
	float waves = sin(a) * 0.52 + sin(b) * 0.22 + sin(c) * 0.26;
	vec2 slope = (d1 * cos(a) * 0.17 + d2 * cos(b) * 0.085
		+ d3 * cos(c) * 0.075) * ripple_strength;
	vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize(mat3(VIEW_MATRIX) * world_normal);

	// Small broken glints, tinted like the sky instead of solid white bands.
	float glint_mask = water_noise(p * vec2(1.12, 0.87) + vec2(7.4, -t * 0.16));
	float broken_crest = pow(max(sin(a + sin(c) * 0.55), 0.0), mix(8.0, 24.0, eddies))
		* smoothstep(0.39, 0.74, glint_mask) * smoothstep(-0.15, 0.8, sin(b * 0.47 + c + drift * 4.0));
	// The scene's muted exposure needs enough local contrast to keep these
	// fine, interrupted ripples readable from the normal management camera.
	float reflection = 0.065 + waves * 0.058 + broken_crest * 0.32;
	ALBEDO = mix(water_color.rgb, soft_reflection.rgb, reflection);
	ROUGHNESS = 0.46 - broken_crest * 0.08;
	SPECULAR = 0.32;
	METALLIC = 0.0;
}
