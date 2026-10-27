extends Node

## Cosmetic real-clock swimming. It never reads simulation day/speed/resources.
var preview := false
var elapsed := 0.0
var swimmers: Array[Node3D] = []
var phases: Array[float] = []
var water_material: ShaderMaterial

func _ready() -> void:
	set_process(not preview)

func configure(fish: Array[Node3D], water: ShaderMaterial, is_preview: bool) -> void:
	swimmers = fish
	water_material = water
	preview = is_preview
	for i in range(swimmers.size()):
		phases.append(float(i) * 2.39996)
		_update_fish(i)
	set_process(not preview)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if preview:
		return
	elapsed += delta
	water_material.set_shader_parameter("water_clock", elapsed)
	for i in range(swimmers.size()):
		var radius := _radii(i)
		var theta: float = phases[i]
		# Arc-length correction keeps speed steady on elliptical paths.
		var tangent_length := Vector2(radius.x * sin(theta), radius.y * cos(theta)).length()
		phases[i] = fmod(theta + delta * (0.14 + float(i % 3) * 0.018) / tangent_length, TAU)
		_update_fish(i)

func _radii(index: int) -> Vector2:
	return Vector2(0.95 + float(index) * 0.14, 0.30 + float(index) * 0.13)

func _update_fish(index: int) -> void:
	var fish: Node3D = swimmers[index]
	var theta: float = phases[index]
	var radius := _radii(index)
	fish.position = Vector3(cos(theta) * radius.x - 0.20, 0.267, sin(theta) * radius.y - 0.20)
	var tangent := Vector3(-sin(theta) * radius.x, 0, cos(theta) * radius.y)
	# Authored fish points toward local -Z.
	fish.rotation.y = atan2(-tangent.x, -tangent.z)
	var beat := sin(elapsed * 7.0 + float(index) * 1.7)
	(fish.get_node("TailJoint") as Node3D).rotation.y = beat * 0.35
	(fish.get_node("LeftFin") as Node3D).rotation.z = -0.08 + beat * 0.09
	(fish.get_node("RightFin") as Node3D).rotation.z = 0.08 - beat * 0.09
