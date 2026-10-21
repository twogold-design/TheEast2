shader_type spatial;
render_mode specular_disabled;

uniform float playable_half_extent = 52.8;
varying vec2 ground_world;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float meadow_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 w = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), w.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), w.x), w.y);
}

void vertex() {
	ground_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float outside = max(abs(ground_world.x), abs(ground_world.y)) - playable_half_extent;
	float meadow_weight = smoothstep(0.0, 2.0, outside);
	vec2 p = mat2(vec2(0.91, 0.415), vec2(-0.415, 0.91)) * ground_world;
	// Continuous world-space layers: no logical tile indices, cell colors or
	// repeating tile UVs. Large patches blend into fine, softened grass grain.
	float broad = meadow_noise(p * 0.065 + vec2(3.2, 8.1));
	float tufts = meadow_noise(p * 0.63 + vec2(17.8, -3.7));
	float blades = meadow_noise(p * vec2(11.0, 3.1));
	float fine_visibility = 1.0 - smoothstep(0.20, 0.85, length(fwidth(p * 11.0)));
	vec3 meadow = mix(vec3(0.31, 0.40, 0.265), vec3(0.395, 0.485, 0.33), broad);
	meadow += (tufts - 0.5) * vec3(0.035, 0.040, 0.021);
	meadow += (blades - 0.5) * vec3(0.028, 0.035, 0.018) * fine_visibility;
	ALBEDO = mix(COLOR.rgb, meadow, meadow_weight);
	ROUGHNESS = 0.98;
}
