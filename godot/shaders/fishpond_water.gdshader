shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// Water stays transparent so opaque fish below it survive compatibility rendering.
uniform float water_clock = 0.0;
uniform vec3 shallow_color : source_color = vec3(0.24, 0.47, 0.40);
varying vec3 local_point;

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec2 p = local_point.xz;
	float a = p.x * 13.0 + p.y * 9.0 + water_clock * 1.15;
	float b = p.x * -8.0 + p.y * 16.0 - water_clock * 0.86;
	float c = sin(a) * 0.5 + sin(b) * 0.5;
	float glint = pow(max(0.0, sin(a * 0.63 + sin(b) * 0.75)), 18.0) * smoothstep(-0.3, 0.9, sin(b * 0.72));
	ALBEDO = shallow_color + vec3(c * 0.022) + vec3(0.25, 0.28, 0.21) * glint * 0.18;
	NORMAL_MAP = vec3(0.5 + cos(a) * 0.075, 0.5 + cos(b) * 0.075, 1.0);
	NORMAL_MAP_DEPTH = 0.38;
	ROUGHNESS = 0.25;
	SPECULAR = 0.72;
	METALLIC = 0.08;
	ALPHA = 0.36;
}
