extends SceneTree

const Expanded = preload("res://godot/ExpandedBuildingAssets.gd")
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var frames := 0
var checked_models := 0
var errors: Array[String] = []

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c7ccb9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1d5")
	env.ambient_light_energy = 0.8
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58,-28,0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16
	world.add_child(camera)
	camera.position = Vector3(9,15,18)
	camera.look_at_from_position(camera.position,Vector3.ZERO)
	var source_scene: PackedScene = load("res://godot/assets/realistic/models/building_warehouse.glb")
	_check(Economy.CATALOG.warehouse.footprint == Vector2i(2,2),"economic footprint is2x2")
	for quarter in 4:
		var model := Expanded.create_building("warehouse",false,source_scene.instantiate())
		world.add_child(model)
		model.position = Vector3((quarter % 2) * 5.3 - 2.65,0,(quarter / 2) * 5.3 - 2.65)
		model.rotation.y = quarter * PI / 2
		var bounds := _bounds(model,Transform3D(Basis(Vector3.UP,quarter * PI / 2),Vector3.ZERO))
		print("WAREHOUSE rotation=",quarter * 90," bounds=",bounds)
		_check(bounds.position.x >= -2.091 and bounds.end.x <= 2.091 and bounds.position.z >= -2.091 and bounds.end.z <= 2.091,"visible geometry stays inside4.18 square at rotation" + str(quarter))
		_check(model.scale == Vector3.ONE,"whole model is not scaled")
		_check(model.get_meta("footprint_cells") == Vector2i(2,2),"asset metadata matches2x2")
		_check(model.get_node("Door").position == Vector3(0,0,2.09),"entrance uses compact court boundary")
		var shape: BoxShape3D = model.get_node("AssetCollision").get_child(0).shape
		_check(shape.size == Vector3(4.18,0.35,4.18),"collision matches compact square")
		_check(model.find_child("OpenLoadingDoor",true,false) != null and model.find_child("WarehouseHandcart",true,false) != null,"open doors and human-scale cart remain")
		var label := Label3D.new()
		label.text = "仓库 2×2 · %d°" % (quarter * 90)
		label.position = model.position + Vector3(0,0.1,2.6)
		label.font_size = 40
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
		checked_models += 1

func _bounds(node: Node3D, transform: Transform3D) -> AABB:
	var bounds := AABB()
	if not node.visible: return bounds
	if node is MeshInstance3D: bounds = transform * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var extra := _bounds(child,transform * child.transform)
			if extra.size.length_squared() > 0: bounds = extra if bounds.size.length_squared() == 0 else bounds.merge(extra)
	return bounds

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 12:
		_check(checked_models == 4,"all four models completed validation")
		if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("res://qa/needs-economy/warehouse-compact-four-angles.png")
		for error in errors: push_error(error)
		if errors.is_empty(): print("PASS compact warehouse: four rotations,4.18m bounds,2x2 footprint,entrance,collision,full-size loading details")
		quit(0 if errors.is_empty() else 1)
	return false
