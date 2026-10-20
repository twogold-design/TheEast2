extends RefCounted

## Ink-wash presentation layer. The original realistic assets remain untouched;
## this layer gives their silhouettes a hand-painted Jiangnan palette and paper grain.

const RealisticKit = preload("res://godot/RealisticAssets.gd")
const JiangnanKit = preload("res://godot/JiangnanStyleAssets.gd")
const TINTS := {
	"house": Color("c08d69"),
	"lumber": Color("806a53"),
	"farm": Color("a7ad78"),
	"warehouse": Color("91816a"),
	"workshop": Color("73858a"),
	"tree": Color("718b6b"),
	"rock": Color("7d8179"),
	"lantern": Color("b06d52"),
	"bridge": Color("98785b"),
	"citizen_0": Color("a97862"),
	"citizen_1": Color("718d96"),
	"citizen_2": Color("b58d53"),
	"citizen_3": Color("78916e"),
}

static var _styled_meshes: Dictionary = {}

static func create_building(type: String, preview := false) -> Node3D:
	# Prefer the open-front Jiangnan tier for the game camera.  If an asset is
	# missing, preserve the tested realistic pack and its low-poly fallback.
	var root := JiangnanKit.create_building(type, preview)
	if root == null:
		root = RealisticKit.create_building(type, preview)
	if root:
		apply_ink_style(root, type)
		if preview:
			RealisticKit.apply_preview_tint(root, true)
	return root

static func create_tree(variant := 0) -> Node3D:
	var root := RealisticKit.create_tree(variant)
	if root:
		apply_ink_style(root, "tree")
	return root

static func create_rock(variant := 0) -> Node3D:
	var root := RealisticKit.create_rock(variant)
	if root:
		apply_ink_style(root, "rock")
	return root

static func create_lantern() -> Node3D:
	var root := RealisticKit.create_lantern()
	if root:
		apply_ink_style(root, "lantern")
	return root

static func create_bridge() -> Node3D:
	var root := RealisticKit.create_bridge()
	if root:
		apply_ink_style(root, "bridge")
	return root

static func create_crops(preview := false) -> Node3D:
	var root := RealisticKit.create_crops(preview)
	if root:
		apply_ink_style(root, "farm")
	return root

static func create_citizen(index := 0) -> Node3D:
	var root := RealisticKit.create_citizen(index)
	if root:
		apply_ink_style(root, "citizen_%d" % posmod(index, 4))
	return root

static func apply_preview_tint(root: Node3D, valid: bool) -> void:
	RealisticKit.apply_preview_tint(root, valid)

static func apply_ink_style(root: Node3D, kind: String) -> void:
	if root == null:
		return
	var surface_count := _apply_material_recursive(root, kind)
	root.set_meta("art_style", "ink_wash")
	root.set_meta("art_style_version", 3)
	root.set_meta("ink_surface_count", surface_count)

static func _apply_material_recursive(node: Node, kind: String) -> int:
	var surface_count := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			# Per-surface instance overrides are unsafe to tear down in Godot 4.7.2:
			# the renderer briefly queries a cleared material RID while a preview or
			# building is freed. Put the ink materials on a copied mesh resource and
			# reuse it by source mesh and tint kind, keeping the imported GLB untouched.
			var source_mesh := mesh_instance.mesh
			var cache_key := "%d:%s" % [source_mesh.get_instance_id(), kind]
			var styled_mesh := _styled_meshes.get(cache_key) as Mesh
			if styled_mesh == null:
				styled_mesh = source_mesh.duplicate(false) as Mesh
				if styled_mesh == null:
					push_error("InkWashAssets: failed to copy mesh %s" % mesh_instance.name)
					return surface_count
				for surface in range(source_mesh.get_surface_count()):
					var original := source_mesh.surface_get_material(surface)
					styled_mesh.surface_set_material(surface, _make_surface_material(original, kind))
				_styled_meshes[cache_key] = styled_mesh
			surface_count += styled_mesh.get_surface_count()
			mesh_instance.mesh = styled_mesh
	for child in node.get_children():
		surface_count += _apply_material_recursive(child, kind)
	return surface_count

static func _make_surface_material(original: Material, kind: String) -> StandardMaterial3D:
	# Duplicate a native imported material so every authored texture channel and
	# UV transform survives the style pass. A fresh material is only a fallback
	# for unusual material types or an empty source slot.
	var material := StandardMaterial3D.new()
	if original is StandardMaterial3D:
		material = (original as StandardMaterial3D).duplicate(true) as StandardMaterial3D
	var base_color := Color(0.72, 0.70, 0.62)
	if original is BaseMaterial3D:
		var source := original as BaseMaterial3D
		base_color = source.albedo_color
		if not original is StandardMaterial3D:
			material.albedo_texture = source.albedo_texture
			material.metallic = source.metallic
			material.metallic_specular = source.metallic_specular
			material.transparency = source.transparency
			material.cull_mode = source.cull_mode
	var tint: Color = TINTS.get(kind, Color("9b927c"))
	var strength := 0.26 if kind in ["tree", "rock"] else 0.16
	material.albedo_color = base_color.lerp(tint, strength)
	# The atlas is a full-map painting rather than a tileable detail texture.
	# Repeating it on every mesh surface breaks the model's original UV layout,
	# so imported assets keep their own texture and receive the ink style through
	# palette, roughness and toon lighting only.
	material.roughness = maxf(material.roughness, 0.82)
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return material
