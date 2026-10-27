extends SceneTree
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
func _initialize() -> void:
	# This is an immutable pre-V4 audit snapshot, never a live-value export target.
	if FileAccess.file_exists("res://tools/balance_v4_baseline.json"):
		push_error("Refusing to overwrite the existing pre-V4 balance baseline.")
		quit(1)
		return
	var catalog: Dictionary = Economy.CATALOG.duplicate(true)
	for entry in catalog.values(): entry.footprint = [entry.footprint.x,entry.footprint.y]
	var data := {"specs":Economy.SPECS,"catalog":catalog}
	var file := FileAccess.open("res://tools/balance_v4_baseline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	file.close()
	quit()
