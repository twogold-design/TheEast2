extends RefCounted

## Closed, smoothly shaded terrain mounds. Every footprint vertex samples the
## rendered ground, so mountain skirts remain buried on sloping map borders.
const SIDES := 80
const RINGS := 28
const FOOT_BURIAL := 0.24
static var _material: ShaderMaterial

static func create_mountain(center: Vector3, radius: Vector2, height: float, variant: int, ground_height: Callable) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var phase := variant * 0.731
	var rotation := variant * 0.417
	var center_profile := _ridge_profile(Vector2.ZERO, variant)
	vertices.append(Vector3(0, float(ground_height.call(center.x, center.z)) - center.y + height * center_profile - FOOT_BURIAL, 0))
	colors.append(_surface_color(center_profile, Vector2.ZERO, phase))
	for ring in range(1, RINGS + 1):
		var distance := float(ring) / RINGS
		for side in range(SIDES):
			var angle := float(side) / SIDES * TAU
			var contour := 1.0 + 0.085 * sin(angle * 3.0 + phase) + 0.055 * cos(angle * 5.0 - phase)
			var horizontal := Vector2(cos(angle) * radius.x * 1.20, sin(angle) * radius.y * 1.10) * distance * contour
			horizontal = horizontal.rotated(rotation)
			# Offset summit, a lower shoulder and an extended side ridge form a
			# small landscape, rather than a radial cone with decorative ripples.
			var normalized_point := Vector2(cos(angle), sin(angle)) * distance
			var profile := _ridge_profile(normalized_point, variant)
			var weathered := pow(sin(distance * PI), 2.0) * (0.045 * sin(horizontal.x * 3.1 + phase + sin(horizontal.y * 2.0)) * cos(horizontal.y * 3.7 - phase) + 0.028 * sin(horizontal.x * 6.3 + horizontal.y * 4.9 + phase))
			var elevation := height * profile + weathered
			var ground := float(ground_height.call(center.x + horizontal.x, center.z + horizontal.y))
			vertices.append(Vector3(horizontal.x, ground - center.y + elevation - FOOT_BURIAL, horizontal.y))
			colors.append(_surface_color(profile, normalized_point, phase))
	for side in range(SIDES):
		indices.append_array(PackedInt32Array([0, 1 + side, 1 + (side + 1) % SIDES]))
	for ring in range(RINGS - 1):
		for side in range(SIDES):
			var a := 1 + ring * SIDES + side
			var b := 1 + ring * SIDES + (side + 1) % SIDES
			var c := a + SIDES
			var d := b + SIDES
			indices.append_array(PackedInt32Array([a, c, d, a, d, b]))
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for triangle in range(0, indices.size(), 3):
		var a := indices[triangle]
		var b := indices[triangle + 1]
		var c := indices[triangle + 2]
		# Godot front faces use clockwise winding.
		var face := -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		normals[a] += face
		normals[b] += face
		normals[c] += face
	for index in range(normals.size()):
		normals[index] = normals[index].normalized()
	# A buried underside closes the volume without changing the smooth visible
	# skirt normals. There are no open cards or upside-down cylinder bottoms.
	var rim_start := vertices.size()
	var lower_y := 0.0
	for side in range(SIDES):
		var point := vertices[1 + (RINGS - 1) * SIDES + side]
		lower_y = minf(lower_y, point.y - 0.2)
		vertices.append(point)
		normals.append(Vector3.DOWN)
		colors.append(Color("59704f"))
	var bottom := vertices.size()
	vertices.append(Vector3(0, lower_y, 0))
	normals.append(Vector3.DOWN)
	colors.append(Color("59704f"))
	for side in range(SIDES):
		indices.append_array(PackedInt32Array([bottom, rim_start + (side + 1) % SIDES, rim_start + side]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _mountain_material())
	var mountain := MeshInstance3D.new()
	mountain.mesh = mesh
	mountain.position = center
	mountain.set_meta("mountain_detail", "smooth_terrain_conforming_ridges")
	mountain.set_meta("foot_ring_start", 1 + (RINGS - 1) * SIDES)
	mountain.set_meta("foot_ring_count", SIDES)
	mountain.set_meta("foot_burial", FOOT_BURIAL)
	mountain.set_meta("triangle_count", indices.size() / 3)
	mountain.set_meta("shape_family", variant % 3)
	return mountain

static func _ridge_profile(point: Vector2, variant: int) -> float:
	var phase := variant * 0.731
	var summit := Vector2(-0.31 - 0.035 * sin(phase), -0.16 + 0.06 * cos(phase))
	var shoulder := Vector2(0.33, 0.15 + 0.09 * sin(phase))
	var main_width := Vector2(0.115, 0.19)
	var shoulder_width := Vector2(0.19, 0.16)
	var shoulder_height := 0.59
	if variant % 3 == 1:
		# Unequal twin peaks and a visible saddle.
		summit = Vector2(-0.34, 0.13)
		shoulder = Vector2(0.36, -0.18)
		main_width = Vector2(0.13, 0.14)
		shoulder_width = Vector2(0.10, 0.15)
		shoulder_height = 0.74
	elif variant % 3 == 2:
		# One dominant peak with a long low spur running away from it.
		summit = Vector2(-0.30, -0.22)
		shoulder = Vector2(0.24, 0.26)
		main_width = Vector2(0.13, 0.17)
		shoulder_width = Vector2(0.28, 0.12)
		shoulder_height = 0.43
	var main_delta := point - summit
	var shoulder_delta := point - shoulder
	var main_peak := 0.90 * exp(-main_delta.x * main_delta.x / main_width.x - main_delta.y * main_delta.y / main_width.y)
	var side_peak := shoulder_height * exp(-shoulder_delta.x * shoulder_delta.x / shoulder_width.x - shoulder_delta.y * shoulder_delta.y / shoulder_width.y)
	var spur_delta := point - Vector2(0.02, 0.42)
	var spur := 0.20 * exp(-spur_delta.x * spur_delta.x / 0.40 - spur_delta.y * spur_delta.y / 0.105)
	# A broad low apron flattens smoothly into the existing terrain. Neither
	# the highest point nor the silhouette is tied to the footprint center.
	var apron := 0.10 * maxf(0.0, 1.0 - point.length_squared())
	return (main_peak + side_peak + spur + apron) * (1.0 - smoothstep(0.67, 1.0, point.length()))

static func _surface_color(profile: float, point: Vector2, phase: float) -> Color:
	var stone := smoothstep(0.28, 0.91, profile) * (0.64 + 0.11 * sin(point.x * 7.0 + point.y * 3.0 + phase))
	return Color("59704f").lerp(Color("838578"), stone)

static func _mountain_material() -> ShaderMaterial:
	if _material != null:
		return _material
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode diffuse_burley, specular_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec3 p = world_position;
    float weathering = sin(p.x * 4.7 + sin(p.z * 2.9)) * sin(p.z * 5.3 + p.y * 2.1);
    float strata = sin(p.y * 7.0 + sin(p.x * 1.7) + cos(p.z * 2.1));
    ALBEDO = COLOR.rgb * (0.98 + weathering * 0.045 + strata * 0.022);
    ROUGHNESS = 1.0;
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	return _material
