extends PanelContainer
signal trade_requested(good: String, side: String, quantity: int)
signal cancel_trade_requested(good: String)
signal close_requested
signal immigration_requested(enabled: bool)
signal route_requested(source: String, destination: String, good: String, reserve: int, batch: int, enabled: bool)
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
const NAMES := {"food":"粮食", "wood":"木材", "hemp":"麻料", "tools":"木器", "cloth":"布衣", "tea":"茶叶", "clay":"黏土", "pottery":"陶器", "bamboo":"竹材", "paper":"纸张"}
const REGIONS := ["河湾故地", "北坡梯田", "东麓林场", "云岫高台", "沧波东原", "朔岭关田", "天际新都"]
const UNLOCK := {"food":0, "wood":0, "tools":0, "hemp":1, "cloth":1, "bamboo":2, "tea":3, "paper":4, "clay":5, "pottery":5}
var selected_good := "food"
var selected_region := "0"
var summary: Label
var detail: Label
var quantity: SpinBox
var buy_button: Button
var sell_button: Button
var order_status: Label
var cancel_trade_button: Button
var immigration: CheckButton
var immigration_label: Label
var region_select: OptionButton
var logistics_button: Button
var buttons := {}
var current_snapshot := {}
var region_level := 0
var logistics_visible := false
var trade_controls: VBoxContainer
var route_controls: VBoxContainer
var route_destination: OptionButton
var route_reserve: SpinBox
var route_batch: SpinBox
var route_apply: Button
var route_stop: Button
var route_status: Label

func _ready() -> void:
	name = "EconomyPanel"
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -310
	offset_right = 310
	offset_top = -285
	offset_bottom = 285
	z_index = 25
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f1e5cb")
	style.set_content_margin_all(15)
	style.set_corner_radius_all(10)
	style.border_color = Color("9a8865")
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	var skin := Theme.new()
	for kind in ["Label", "CheckButton", "Button", "OptionButton", "LineEdit", "SpinBox"]:
		for state in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color", "font_selected_color"]:
			skin.set_color(state, kind, Color("343b31"))
		skin.set_color("font_disabled_color", kind, Color("79715f"))
		if kind == "Label":
			continue
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var button_style := StyleBoxFlat.new()
			button_style.bg_color = Color("d8c7a3") if state == "pressed" else Color("e9ddc2")
			button_style.set_corner_radius_all(4)
			button_style.set_content_margin_all(5)
			skin.set_stylebox(state, kind, button_style)
	theme = skin
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _label("货物与经营", 21)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)
	var regions_row := HBoxContainer.new()
	box.add_child(regions_row)
	region_select = OptionButton.new()
	region_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_select.item_selected.connect(func(index: int) -> void:
		selected_region = str(region_select.get_item_id(index))
		select_good(selected_good)
	)
	regions_row.add_child(region_select)
	logistics_button = Button.new()
	logistics_button.text = "查看运输"
	logistics_button.toggle_mode = true
	logistics_button.toggled.connect(func(value: bool) -> void:
		logistics_visible = value
		refresh(current_snapshot, region_level)
	)
	regions_row.add_child(logistics_button)
	var tabs := GridContainer.new()
	tabs.columns = 5
	box.add_child(tabs)
	for good in NAMES:
		var button := Button.new()
		button.text = NAMES[good]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_good.bind(good))
		tabs.add_child(button)
		buttons[good] = button
	summary = _label("")
	box.add_child(summary)
	detail = _label("")
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(detail)
	trade_controls = VBoxContainer.new()
	trade_controls.add_theme_constant_override("separation", 8)
	box.add_child(trade_controls)
	var order_row := HBoxContainer.new()
	order_row.custom_minimum_size.y = 50
	trade_controls.add_child(order_row)
	order_status = _label("暂无买卖订单")
	order_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_status.max_lines_visible = 2
	order_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	order_row.add_child(order_status)
	cancel_trade_button = Button.new()
	cancel_trade_button.text = "取消订单"
	cancel_trade_button.custom_minimum_size.x = 90
	cancel_trade_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel_trade_button.tooltip_text = "只取消尚未成交的数量，已完成的买卖不受影响。"
	cancel_trade_button.pressed.connect(func() -> void: cancel_trade_requested.emit(selected_good))
	order_row.add_child(cancel_trade_button)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	trade_controls.add_child(controls)
	controls.add_child(_field_label("数量"))
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 2000
	quantity.step = 1
	quantity.rounded = true
	quantity.value = 10
	quantity.custom_minimum_size.x = 100
	quantity.tooltip_text = "输入本次买卖数量；订单按商路速度逐步完成。"
	quantity.value_changed.connect(func(_value: float) -> void: refresh(current_snapshot, region_level))
	controls.add_child(quantity)
	buy_button = Button.new()
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.tooltip_text = "买入指定数量，按商路速度分批付款收货；新订单替换本区该货物尚未完成的订单。"
	buy_button.pressed.connect(func() -> void: trade_requested.emit(selected_good, "buy", int(quantity.value)))
	controls.add_child(buy_button)
	sell_button = Button.new()
	sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_button.tooltip_text = "卖出指定数量，按商路速度分批收钱；新订单替换本区该货物尚未完成的订单。"
	sell_button.pressed.connect(func() -> void: trade_requested.emit(selected_good, "sell", int(quantity.value)))
	controls.add_child(sell_button)
	route_controls = VBoxContainer.new()
	route_controls.hide()
	box.add_child(route_controls)
	route_status = _label("自动调拨已启用，可额外指定专线。")
	route_controls.add_child(route_status)
	var route_row := HBoxContainer.new()
	route_controls.add_child(route_row)
	route_row.add_child(_field_label("运往"))
	route_destination = OptionButton.new()
	route_destination.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_destination.item_selected.connect(func(_index: int) -> void: select_route())
	route_row.add_child(route_destination)
	var quantity_row := HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation", 10)
	route_controls.add_child(quantity_row)
	quantity_row.add_child(_field_label("本区留存"))
	route_reserve = SpinBox.new()
	route_reserve.max_value = 2000
	route_reserve.step = 1
	route_reserve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_row.add_child(route_reserve)
	quantity_row.add_child(_field_label("每批"))
	route_batch = SpinBox.new()
	route_batch.min_value = 1
	route_batch.max_value = 16
	route_batch.step = 1
	route_batch.value = 4
	route_batch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_row.add_child(route_batch)
	var route_actions := HBoxContainer.new()
	route_controls.add_child(route_actions)
	route_apply = Button.new()
	route_apply.text = "开通 / 更新专线"
	route_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_apply.pressed.connect(func() -> void: emit_route(true))
	route_actions.add_child(route_apply)
	route_stop = Button.new()
	route_stop.text = "停用专线"
	route_stop.pressed.connect(func() -> void: emit_route(false))
	route_actions.add_child(route_stop)
	immigration = CheckButton.new()
	immigration.text = "允许居民迁入"
	immigration.toggled.connect(func(enabled: bool) -> void: immigration_requested.emit(enabled))
	box.add_child(immigration)
	immigration_label = _label("")
	box.add_child(immigration_label)
	select_good(selected_good)

func _label(text: String, size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("343b31"))
	return label

func _field_label(text: String) -> Label:
	var label := _label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

func select_good(good: String) -> void:
	if not NAMES.has(good):
		return
	selected_good = good
	if not is_instance_valid(quantity):
		return
	refresh(current_snapshot, region_level)
	select_route()

func selected_route() -> Dictionary:
	if not is_instance_valid(route_destination) or route_destination.selected < 0:
		return {}
	var destination := str(route_destination.get_selected_id())
	for route in current_snapshot.get("routes", []):
		if str(route.source) == selected_region and str(route.destination) == destination and str(route.good) == selected_good:
			return route
	return {}

func select_route() -> void:
	if not is_instance_valid(route_reserve):
		return
	var route := selected_route()
	route_reserve.set_value_no_signal(float(route.get("reserve", 30)))
	route_batch.set_value_no_signal(float(route.get("batch", 4)))
	refresh(current_snapshot, region_level)

func emit_route(enabled: bool) -> void:
	if route_destination.selected >= 0:
		route_requested.emit(selected_region, str(route_destination.get_selected_id()), selected_good, int(route_reserve.value), int(route_batch.value), enabled)

static func integer_text(value: float) -> String:
	return "不足1" if value > 0 and value < 1 else str(floori(value + 0.000001))

static func rate_text(value: float) -> String:
	if absf(value) < 0.001:
		return "0"
	return ("+" if value > 0 else "−") + ("不足1" if absf(value) < 1 else str(roundi(absf(value))))

func refresh(data: Dictionary, level: int) -> void:
	current_snapshot = data
	region_level = level
	if not is_instance_valid(summary):
		return
	if region_select.item_count != level + 1:
		region_select.clear()
		for i in range(level + 1):
			region_select.add_item(REGIONS[i], i)
		if int(selected_region) > level:
			selected_region = "0"
		region_select.select(int(selected_region))
	var destinations: Array[int] = []
	for i in range(level + 1):
		if str(i) != selected_region:
			destinations.append(i)
	if str(route_destination.get_meta("source", "")) != selected_region or route_destination.item_count != destinations.size():
		route_destination.clear()
		for i in destinations:
			route_destination.add_item(REGIONS[i], i)
		route_destination.set_meta("source", selected_region)
	trade_controls.visible = not logistics_visible
	route_controls.visible = logistics_visible
	logistics_button.text = "查看贸易" if logistics_visible else "查看运输"
	immigration.set_pressed_no_signal(bool(data.get("immigration_enabled", true)))
	immigration_label.text = str(data.get("immigration_status", "满足条件后，每30秒迁入2人"))
	var area: Dictionary = data.get("regions", {}).get(selected_region, {})
	var goods: Dictionary = area.get("goods", data.get("goods", {}) if selected_region == "0" else {})
	var rates: Dictionary = data.get("rates", {})
	for good in buttons:
		buttons[good].button_pressed = good == selected_good
		buttons[good].disabled = level < int(UNLOCK[good])
	var cap := int(area.get("food_capacity", 200) if selected_good == "food" else area.get("capacity", 200))
	summary.text = "%s · 本区 %s/%d · 全镇可用 %s\n全镇净变化 %s/日" % [NAMES[selected_good], integer_text(float(goods.get(selected_good, 0))), cap, integer_text(float(data.get("goods", {}).get(selected_good, 0))), rate_text(float(rates.get(selected_good, 0)))]
	var locked := level < int(UNLOCK[selected_good])
	buy_button.disabled = locked or bool(data.get("failed", false))
	sell_button.disabled = buy_button.disabled
	buy_button.text = "买入 · %d铜钱" % (int(quantity.value) * int(Economy.BUY[selected_good]))
	sell_button.text = "卖出 · %d铜钱" % (int(quantity.value) * int(Economy.SELL[selected_good]))
	var order: Dictionary = data.get("trade_orders", {}).get(selected_region, {}).get(selected_good, {})
	var remaining := float(order.get("remaining", 0))
	cancel_trade_button.disabled = order.is_empty() or remaining <= 0 or bool(data.get("failed", false))
	order_status.text = "暂无买卖订单"
	if not order.is_empty():
		var side := "买入" if str(order.get("side", "buy")) == "buy" else "卖出"
		order_status.text = "%s已完成" % side if remaining <= 0 else "%s还剩%d\n%s" % [side, ceili(remaining), str(order.get("status", "交易中"))]
	order_status.tooltip_text = order_status.text
	route_apply.disabled = locked or level < 1 or bool(data.get("failed", false))
	var route := selected_route()
	route_stop.disabled = route.is_empty() or not bool(route.get("enabled", false)) or bool(data.get("failed", false))
	route_status.text = "%s专线：%s" % [NAMES[selected_good], "运行中；口粮与生产优先保留" if bool(route.get("enabled", false)) else "未开通；缺货仍会自动调拨"]
	var notes := {"food":"居民口粮。缺粮可停外销、增建农田或进口。", "wood":"用于建设与加工；小工坊加工木材直接赚铜钱。", "hemp":"麻田产麻，织坊加工成布衣。", "tools":"商路货物，可出售库存木器。", "cloth":"匠户自动使用布衣；可以自产或进口。", "tea":"茶园产茶，茶馆用茶提供休闲服务。", "clay":"采泥场原料，由陶窑加工。", "pottery":"陶窑烧制，改善生活或外销。", "bamboo":"竹林场产竹，造纸坊加工。", "paper":"书院使用纸张，也可出口。"}
	detail.text = "%s\n单价：买%d · 卖%d铜钱（含运费）\n商路%d单位/日%s\n铜钱 %s · 净变化 %s/日" % [notes[selected_good], int(Economy.BUY[selected_good]), int(Economy.SELL[selected_good]), int(area.get("trade_capacity", 4 if selected_region == "0" else 0)), " · 货物尚未解锁" if locked else "", integer_text(float(data.get("coins", 0))), rate_text(float(rates.get("coins", 0)))]
	if logistics_visible:
		var lines: Array[String] = ["各区沿连通道路自动补货，跨区货物按路程到达。"]
		summary.tooltip_text = "仓库增加库存容量；接路且配齐工人的货运站使本区发出的道路货物运送时间减半。"
		var shown := 0
		for shipment in data.get("shipments", []):
			if str(shipment.get("source", "")) != selected_region and str(shipment.get("destination", "")) != selected_region:
				continue
			var source := clampi(int(shipment.get("source", 0)), 0, 6)
			var dest := clampi(int(shipment.get("destination", 0)), 0, 6)
			var status := str(shipment.get("status", "运输中"))
			var arrival := "%d秒" % ceili(float(shipment.get("remaining", 0))) if status == "运输中" else status
			lines.append("%s→%s · %s %s · %s · %s" % [REGIONS[source], REGIONS[dest], NAMES.get(str(shipment.get("good", "")), "货物"), integer_text(float(shipment.get("quantity", 0))), "水运" if shipment.get("mode", "road") == "water" else "陆运", arrival])
			shown += 1
			if shown >= 2:
				break
		if shown == 0:
			lines.append("当前无在途货物。各区缺货时自动申请调拨。")
		detail.text = "\n".join(lines)
