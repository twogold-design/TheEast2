extends RefCounted

## Continuous world-space water: separate river stretches share the same slow
## ripple field, independent of construction cells or each plane's UVs.
const WATER_SHADER = preload("res://godot/shaders/river_water.gdshader")

static func create_surface(size: Vector2) -> MeshInstance3D:
	var surface := MeshInstance3D.new()
	surface.name = "RiverSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(maxf(size.x, 0.01), maxf(size.y, 0.01))
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	plane.material = material
	surface.mesh = plane
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return surface
