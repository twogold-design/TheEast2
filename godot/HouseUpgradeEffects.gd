extends Node3D

## Cosmetic state only. Main supplies real presentation time and whether the
## household can currently build; no timers or resource changes live here.
const Kit = preload("res://godot/OpenClinicAssets.gd")
const DUST_SECONDS := 1.25
var hammer: Node3D
var dust: Node3D
var dust_age := 0.0
var completion_count := 0
var _was_building := false
var _swing_time := 0.0
var _dust_material: StandardMaterial3D

func apply_state(artisan: bool, building: bool) -> void:
	if building and hammer == null:
		_create_hammer()
	if hammer != null:
		hammer.visible = building
	if _was_building and not building and artisan:
		_start_dust()
	_was_building = building

func advance_visual(delta: float, running := true) -> void:
	# Keep a slow, readable hammer cycle even at accelerated simulation speed.
	var step := clampf(delta, 0.0, 0.10)
	if _was_building and running and hammer != null:
		_swing_time += step
		var phase := fposmod(_swing_time, 0.95) / 0.95
		# Lift slowly, strike quickly, then rest briefly at the bottom.
		var lift := smoothstep(0.0, 0.68, phase) if phase < 0.68 else 1.0 - smoothstep(0.68, 0.86, phase)
		hammer.rotation.z = lerpf(-0.90, 0.42, lift)
		hammer.position.y = 2.52 + lift * 0.045
	if dust != null:
		# Finish a short cosmetic puff even if the game is paused after completion.
		dust_age += step
		var progress := clampf(dust_age / DUST_SECONDS, 0.0, 1.0)
		for i in range(dust.get_child_count()):
			var puff := dust.get_child(i) as MeshInstance3D
			var origin: Vector3 = puff.get_meta("origin")
			var drift: Vector3 = puff.get_meta("drift")
			puff.position = origin + drift * progress
			puff.scale = Vector3.ONE * lerpf(0.35, 1.6, progress)
		_dust_material.albedo_color.a = (1.0 - smoothstep(0.12, 1.0, progress)) * 0.65
		if progress >= 1.0:
			dust.free()
			dust = null
			_dust_material = null

func _create_hammer() -> void:
	hammer = Kit.branch(self, "RenovationHammer")
	hammer.position = Vector3(0.18, 2.52, -0.27)
	hammer.rotation = Vector3(0.15, -0.30, -0.90)
	var wood := Kit.material(Color("9e8052"))
	var iron := Kit.material(Color("65716f"))
	iron.metallic = 0.32
	iron.roughness = 0.50
	Kit.cylinder(hammer, "WoodHandle", 0.035, 0.48, Vector3(0, 0.22, 0), wood)
	Kit.box(hammer, "HammerHead", Vector3(0.30, 0.15, 0.15), Vector3(0, 0.48, 0), iron)
	var face := Kit.material(Color("bac0b3"))
	for side in [-1.0, 1.0]:
		Kit.box(hammer, "SteelFace", Vector3(0.025, 0.17, 0.17), Vector3(side * 0.15, 0.48, 0), face)
	for i in range(4):
		Kit.cylinder(hammer, "HandleBinding", 0.039, 0.025, Vector3(0, 0.04 + i * 0.04, 0), Kit.material(Color("d0b376")))

func _start_dust() -> void:
	if dust != null:
		dust.free()
	dust = Kit.branch(self, "CompletionDust")
	dust_age = 0.0
	completion_count += 1
	# Soft radial alpha sprites work with the project's Compatibility renderer.
	# Each household owns its fading material; no shared material is modified.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.40, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.48), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	_dust_material = StandardMaterial3D.new()
	_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_dust_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dust_material.albedo_texture = texture
	_dust_material.albedo_color = Color(0.79, 0.74, 0.62, 0.65)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.90, 0.78)
	mesh.material = _dust_material
	for i in range(24):
		var angle := float(i % 8) * TAU / 8.0 + float(i / 8) * 0.27
		var direction := Vector3(cos(angle), 0, sin(angle))
		var level := float(i / 8)
		var origin := Vector3(direction.x * 0.77, 0.45 + level * 0.82, -0.30 + direction.z * 0.52)
		var puff := MeshInstance3D.new()
		puff.name = "SoftDustPuff%d" % i
		puff.mesh = mesh
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = origin
		puff.scale = Vector3.ONE * 0.35
		puff.set_meta("origin", origin)
		puff.set_meta("drift", direction * (0.28 + (i % 3) * 0.06) + Vector3.UP * (0.20 + level * 0.12))
		dust.add_child(puff)
