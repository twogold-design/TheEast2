shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform vec2 road_axes = vec2(1.0, 0.0);
varying vec2 world_xz;
varying vec2 local_xz;

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash22(cell).x, hash22(cell + vec2(1.0, 0.0)).x, f.x),
		mix(hash22(cell + vec2(0.0, 1.0)).x, hash22(cell + vec2(1.0)).x, f.x), f.y);
}

// Nearest and second-nearest irregular soil clumps. No repeating texture tile.
vec2 clumps(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 distances = vec2(10.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 delta = offset + 0.12 + hash22(cell + offset) * 0.76 - f;
			float d = dot(delta, delta);
			if (d < distances.x) {
				distances.y = distances.x;
				distances.x = d;
			} else {
				distances.y = min(distances.y, d);
			}
		}
	}
	return sqrt(distances);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	local_xz = VERTEX.xz;
}

void fragment() {
	// Different scales and a warped, rotated domain avoid square cloudy patches.
	vec2 p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * world_xz;
	vec2 warp = vec2(noise2(p * 0.72), noise2(p * 0.69 + vec2(21.7, -8.3))) - 0.5;
	vec2 soil_uv = p + warp * 0.24;
	float broad = noise2(p * 0.33 + vec2(8.1, 13.9));
	float medium = noise2(soil_uv * 7.7);
	float fine = noise2(soil_uv * 34.7);
	float pixel_size = max(length(dFdx(world_xz)), length(dFdy(world_xz)));
	float fine_visibility = 1.0 - smoothstep(0.015, 0.065, pixel_size);
	float grain_relief = (noise2(soil_uv * 18.9 + vec2(7.3, -11.2)) - 0.5) * (0.4 + fine_visibility * 0.6);

	// Shallow broken dry cracks appear only in a few patches, not a tiled web.
	vec2 fissures = clumps(soil_uv * 5.1 + vec2(31.2, 7.4));
	float gap = fissures.y - fissures.x;
	float aa = max(fwidth(gap), 0.009);
	float crack = 1.0 - smoothstep(0.008, 0.008 + aa, gap);
	float dry_patch = smoothstep(0.48, 0.72, noise2(p * 1.13 + vec2(-16.3, 8.7)));
	crack *= dry_patch * (0.35 + 0.65 * fine_visibility);

	float wobble = (noise2(p * 1.8) - 0.5) * 0.07;
	float horizontal = (1.0 - smoothstep(0.025, 0.10, abs(abs(local_xz.y + wobble) - 0.25))) * road_axes.x;
	float vertical = (1.0 - smoothstep(0.025, 0.10, abs(abs(local_xz.x + wobble) - 0.25))) * road_axes.y;
	float worn = max(horizontal, vertical) * smoothstep(0.26, 0.7, noise2(p * 0.87));

	vec3 earth = mix(vec3(0.37, 0.265, 0.155), vec3(0.47, 0.355, 0.225), broad);
	earth += vec3(0.075, 0.061, 0.043) * (medium - 0.5);
	earth += vec3(0.10, 0.085, 0.063) * grain_relief;
	earth += vec3(0.045, 0.038, 0.026) * (fine - 0.5) * fine_visibility;
	earth -= vec3(0.065, 0.052, 0.035) * crack;
	earth = mix(earth, vec3(0.49, 0.375, 0.245), worn * 0.20);

	// Small surface relief catches light without adding raised road geometry.
	float height = medium * 0.0015 + grain_relief * 0.003 + fine * 0.002 * fine_visibility - crack * 0.0004;
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 rx = cross(dy, NORMAL);
	vec3 ry = cross(NORMAL, dx);
	float determinant = dot(dx, rx);
	if (abs(determinant) > 0.0000001) {
		vec3 gradient = (rx * dFdx(height) + ry * dFdy(height)) / determinant;
		NORMAL = normalize(NORMAL - gradient);
	}
	ALBEDO = earth;
	// Keep ground blending narrow and slightly irregular, instead of blurry.
	float edge = clamp(COLOR.r + (medium - 0.5) * 0.16 * COLOR.r, 0.0, 1.0);
	ALPHA = 1.0 - smoothstep(0.25, 0.93, edge);
	SPECULAR = 0.0;
	ROUGHNESS = 0.97;
}
