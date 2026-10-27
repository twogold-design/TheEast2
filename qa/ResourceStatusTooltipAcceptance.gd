extends SceneTree

## UI-only test: no Main instance and no save access.
const StatusLabel = preload("res://godot/ResourceStatusLabel.gd")
const MainScript = preload("res://godot/Main.gd")
var failures: Array[String] = []

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var label = StatusLabel.new()
 root.add_child(label)
 label.size = Vector2(1250, 90)
 label.add_theme_font_size_override("font_size", 15)
 label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 label.tooltip_text = "原有资源说明"
 label.cloth_tooltip = "相关物料：麻 100\n麻田产麻 → 织坊制衣"
 check(label.mouse_filter == Control.MOUSE_FILTER_PASS, "label receives tooltip hit tests")
 var previous_x := 0.0
 for sample in [["木材 8/200 · 水 4/200 · 粮食 9/200", "12/200"], ["木材 12345/50000 · 水 6789/50000 · 粮食 9876/50000", "9876/50000"]]:
  label.text = "第 1 日 · 正常\n" + sample[0] + " · 衣物 " + sample[1] + " · 铜钱 34 · 人口 8/16 · 幸福度 60"
  await process_frame
  var cloth: Rect2 = label.cloth_text_bounds()
  check(cloth.has_area(), "clothing has a nonempty text rectangle")
  check(label.get_tooltip(cloth.get_center()) == "相关物料：麻 100\n麻田产麻 → 织坊制衣", "clothing center shows hemp stock")
  check(label.get_tooltip(cloth.position + Vector2(1, cloth.size.y / 2)) == "相关物料：麻 100\n麻田产麻 → 织坊制衣", "clothing name shows hemp stock")
  check(label.get_tooltip(cloth.end - Vector2(1, cloth.size.y / 2)) == "相关物料：麻 100\n麻田产麻 → 织坊制衣", "clothing capacity shows hemp stock")
  check(label.get_tooltip(Vector2(cloth.end.x + 8, cloth.get_center().y)) == label.tooltip_text, "following separator does not show hemp")
  check(label.get_tooltip(Vector2(cloth.position.x - 8, cloth.get_center().y)) == label.tooltip_text, "preceding resource does not show hemp")
  var first_line: Rect2 = label.get_character_bounds(0)
  check(label.get_tooltip(first_line.get_center()) == label.tooltip_text, "date line keeps original explanation")
  check(label.get_tooltip(Vector2(cloth.get_center().x, first_line.get_center().y)) == label.tooltip_text, "same x on date line does not show hemp")
  check(label.get_tooltip(Vector2(0, 0)) == label.tooltip_text, "blank vertical margin keeps original explanation")
  check(cloth.position.x > previous_x, "longer stock values shift hit rectangle")
  previous_x = cloth.position.x
 label.cloth_tooltip = "相关物料：麻 7\n麻田产麻 → 织坊制衣"
 check(label.get_tooltip(label.cloth_text_bounds().get_center()) == "相关物料：麻 7\n麻田产麻 → 织坊制衣", "hemp amount updates without rebuilding label")
 label.add_theme_font_size_override("font_size", 22)
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 label.size = Vector2(1800, 110)
 await process_frame
 check(label.get_tooltip(label.cloth_text_bounds().get_center()) == "相关物料：麻 7\n麻田产麻 → 织坊制衣", "font and alignment changes use native glyph bounds")
 var game = MainScript.new()
 game.economy_snapshot = {"population_pressure":"缺衣 · 居民将逐步离开"}
 label.resource_tooltips = game.top_resource_tooltips()
 for resource in label.resource_tooltips:
  var tip: String = label.resource_tooltips[resource]
  check(tip.split("\n").size() <= 2, resource + " tooltip is at most two lines")
  check(not tip.contains("每1日") and not tip.contains("每2日") and not tip.contains("离开1人") and not tip.contains("归零"), "top tooltips do not contain departure manuals")
  var bounds: Rect2 = label.resource_text_bounds(resource)
  check(bounds.has_area() and label.get_tooltip(bounds.get_center()) == tip, resource + " shows only its own tooltip")
 check(label.get_tooltip(label.resource_text_bounds("幸福度").get_center()).contains("缺衣"), "happiness tooltip identifies current shortage briefly")
 check(label.get_tooltip(label.cloth_text_bounds().get_center()).begins_with("相关物料"), "clothes keep the concise hemp chain tooltip")
 game.free()
 label.text = "第 2 日 · 缺水 · 居民将逐步离开\n木材 20/100 · 水 0/50 · 衣物 0/60"
 await process_frame
 var notice: Rect2 = label.get_character_bounds(label.text.find("缺水") + 1)
 check(label.get_tooltip(notice.get_center()) == label.tooltip_text, "shortage notice is not mistaken for the water counter")
 check(label.get_tooltip(label.resource_text_bounds("水").get_center()) == label.resource_tooltips["水"], "water tooltip still targets the second-line resource")
 label.text = "第 2 日 · 正常\n木材 20/200 · 水 40/200"
 await process_frame
 check(not label.cloth_text_bounds().has_area(), "missing clothing has no hit rectangle")
 check(label.get_tooltip(Vector2(10, 70)) == label.tooltip_text, "other labels retain original tooltip")
 label.queue_free()
 await process_frame
 for failure in failures: push_error(failure)
 print("RESOURCE_STATUS_TOOLTIP_OK" if failures.is_empty() else "RESOURCE_STATUS_TOOLTIP_FAILED")
 quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
