extends Label

## Preserve the existing two-line Label and native text layout. Native glyph
## bounds account for font fallback, spacing, alignment and changing integers.
var cloth_tooltip: String = ""
var resource_tooltips: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _get_tooltip(at_position: Vector2) -> String:
	if not cloth_tooltip.is_empty() and cloth_text_bounds().has_point(at_position):
		return cloth_tooltip
	for resource in resource_tooltips:
		if resource_text_bounds(str(resource)).has_point(at_position):
			return str(resource_tooltips[resource])
	return tooltip_text

func cloth_text_bounds() -> Rect2:
	return resource_text_bounds("衣物")

func resource_text_bounds(resource: String) -> Rect2:
	# Shortage notices on the date line can also contain words such as 水.
	var start := text.find(resource + " ", text.find("\n") + 1)
	if start < 0:
		return Rect2()
	var end := text.find(" · ", start)
	var newline := text.find("\n", start)
	if end < 0:
		end = text.length()
	if newline >= 0:
		end = mini(end, newline)
	while end > start and text.substr(end - 1, 1).strip_edges().is_empty():
		end -= 1
	var bounds := Rect2()
	for index in range(start, end):
		var glyph := get_character_bounds(index)
		if not glyph.has_area():
			continue
		bounds = glyph if not bounds.has_area() else bounds.merge(glyph)
	return bounds.intersection(Rect2(Vector2.ZERO, size))
