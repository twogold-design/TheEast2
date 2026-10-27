extends RefCounted

## Thin worn earth, with world-space grain and fading outer edges.
const EARTH_SHADER = preload("res://godot/CountryRoad.gdshader")

static func create(origin: Vector2, rectangles: Array[Rect2], openings: Array[Dictionary]) -> Node3D:
	var root := Node3D.new()
	var surface := SurfaceTool.new()
	var shoulders := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	shoulders.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := ShaderMaterial.new()
	material.shader = EARTH_SHADER
	var axes := Vector2.ZERO
	for opening in openings:
		axes.x = maxf(axes.x, absf(opening.direction.x))
		axes.y = maxf(axes.y, absf(opening.direction.y))
	if axes == Vector2.ZERO: axes.x = 1.0
	material.set_shader_parameter("road_axes", axes)
	var edge_count := 0
	for rect in rectangles:
		var a := rect.position
		var b := Vector2(rect.end.x, rect.position.y)
		var c := rect.end
		var d := Vector2(rect.position.x, rect.end.y)
		_triangle(surface, a, b, c, 0, 0, 0)
		_triangle(surface, a, c, d, 0, 0, 0)
		var edges := [[a,b,Vector2(0,-1)], [d,c,Vector2(0,1)], [a,d,Vector2(-1,0)], [b,c,Vector2(1,0)]]
		for edge in edges:
			var from: Vector2 = edge[0]
			var to: Vector2 = edge[1]
			var normal: Vector2 = edge[2]
			var steps := maxi(1, ceili(from.distance_to(to) / 0.12))
			for part in steps:
				var inner_a := from.lerp(to, float(part) / steps)
				var inner_b := from.lerp(to, float(part + 1) / steps)
				var middle := (inner_a + inner_b) * 0.5
				if _inside(middle + normal * 0.003, rectangles) or _open(middle, normal, openings): continue
				var outer_a := inner_a + normal * _edge_width(inner_a + origin)
				var outer_b := inner_b + normal * _edge_width(inner_b + origin)
				_triangle(shoulders, inner_a, inner_b, outer_b, 0, 0, 1)
				_triangle(shoulders, inner_a, outer_b, outer_a, 0, 1, 1)
				edge_count += 1
	_finish(root, surface, "WornPath", material)
	_finish(root, shoulders, "SoftGroundEdges", material)
	root.set_meta("exposed_edge_count", edge_count)
	root.set_meta("surface_rectangles", rectangles)
	root.set_meta("openings", openings)
	return root

static func _edge_width(point: Vector2) -> float:
	return 0.13 + sin(point.x * 5.3 + point.y * 3.7) * 0.025 + sin(point.y * 9.1 - point.x * 2.4) * 0.015

static func _inside(point: Vector2, rectangles: Array[Rect2]) -> bool:
	for rect in rectangles:
		if rect.has_point(point): return true
	return false

static func _open(point: Vector2, normal: Vector2, openings: Array[Dictionary]) -> bool:
	for opening in openings:
		var direction: Vector2 = opening.direction
		var tangent := Vector2(-direction.y, direction.x)
		if normal.dot(direction) > 0.99 and absf(point.dot(direction) - float(opening.distance)) < 0.005 and absf(point.dot(tangent)) <= float(opening.half_width) + 0.01:
			return true
	return false

static func _triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, fade_a: float, fade_b: float, fade_c: float) -> void:
	# Flat faces blend onto the ground; there are no slab walls or curb shadows.
	var points := [[a,fade_a], [b,fade_b], [c,fade_c]]
	if (b-a).cross(c-a) < 0:
		points = [[a,fade_a], [c,fade_c], [b,fade_b]]
	for item in points:
		var point: Vector2 = item[0]
		surface.set_normal(Vector3.UP)
		surface.set_color(Color(float(item[1]),0,0))
		surface.add_vertex(Vector3(point.x,-0.020,point.y))

static func _finish(root: Node3D, surface: SurfaceTool, label: String, material: Material) -> void:
	surface.set_material(material)
	surface.index()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
