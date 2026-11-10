class_name ShopMenu
extends Control

signal buy_requested(index: int)

var _coins_label: Label
var _buttons: Array[Button] = []
var _level_labels: Array[Label] = []
var _leveled: Array[bool] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func setup(items: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.14, 0.97)
	sb.border_color = Color(0.85, 0.65, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "SHOP"
	title.add_theme_font_size_override("font_size", 38)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 30)
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	head.add_child(_coins_label)

	box.add_child(HSeparator.new())

	for i in items.size():
		var item: Dictionary = items[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		box.add_child(row)

		var icon := IconRect.new()
		icon.kind = item["id"]
		row.add_child(icon)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(text)
		var name_label := Label.new()
		name_label.text = "[%d]  %s" % [i + 1, item["name"]]
		name_label.add_theme_font_size_override("font_size", 24)
		text.add_child(name_label)
		var desc_label := Label.new()
		desc_label.text = item["desc"]
		desc_label.add_theme_font_size_override("font_size", 16)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		text.add_child(desc_label)

		var lvl := Label.new()
		lvl.custom_minimum_size = Vector2(80, 0)
		lvl.add_theme_font_size_override("font_size", 20)
		lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lvl)
		_level_labels.append(lvl)
		_leveled.append(item.get("leveled", true))

		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 56)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_on_buy.bind(i))
		row.add_child(b)
		_buttons.append(b)

	box.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = "Click Buy or press 1-6   |   Tab or Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	box.add_child(hint)

func refresh(coins: int, costs: Array, levels: Array) -> void:
	_coins_label.text = "Coins: %d" % coins
	for i in _buttons.size():
		_buttons[i].text = "Buy  -  %d" % costs[i]
		_buttons[i].disabled = coins < costs[i]
		_level_labels[i].text = ("Lv %d" % levels[i]) if _leveled[i] else ""

func _on_buy(index: int) -> void:
	buy_requested.emit(index)
