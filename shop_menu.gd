class_name ShopMenu
extends Control

signal buy_requested(index: int)

var _coins_label: Label
var _hint: Label
var _buttons: Array[Button] = []
var _level_labels: Array[Label] = []
var _icons: Array[IconRect] = []
var _names: Array[Label] = []
var _descs: Array[Label] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func setup(count: int) -> void:
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
	var coin_icon := TextureRect.new()
	coin_icon.texture = CoinTex.get_texture()
	coin_icon.custom_minimum_size = Vector2(36, 36)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(coin_icon)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 30)
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	head.add_child(_coins_label)

	box.add_child(HSeparator.new())

	for i in count:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		box.add_child(row)

		var icon := IconRect.new()
		row.add_child(icon)
		_icons.append(icon)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(text)
		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 24)
		text.add_child(name_label)
		_names.append(name_label)
		var desc_label := Label.new()
		desc_label.add_theme_font_size_override("font_size", 16)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		text.add_child(desc_label)
		_descs.append(desc_label)

		var lvl := Label.new()
		lvl.custom_minimum_size = Vector2(90, 0)
		lvl.add_theme_font_size_override("font_size", 20)
		lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lvl)
		_level_labels.append(lvl)

		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 56)
		b.add_theme_font_size_override("font_size", 22)
		b.icon = CoinTex.get_texture()
		b.add_theme_constant_override("icon_max_width", 28)
		b.pressed.connect(_on_buy.bind(i))
		row.add_child(b)
		_buttons.append(b)

	box.add_child(HSeparator.new())
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	box.add_child(_hint)

# rows: one Dictionary per item: name, desc, icon, cost, level, can_buy, maxed
func refresh(coins: int, rows: Array) -> void:
	_coins_label.text = "x %d" % coins
	_hint.text = "Click Buy or press 1-%d   |   %s or Esc to close" % [rows.size(), Keybinds.key_text("open_shop")]
	for i in mini(rows.size(), _buttons.size()):
		var r: Dictionary = rows[i]
		_icons[i].set_kind(str(r["icon"]))
		_names[i].text = "[%d]  %s" % [i + 1, str(r["name"])]
		_descs[i].text = str(r["desc"])
		_level_labels[i].text = str(r["level"])
		var cost: int = int(r["cost"])
		if bool(r["maxed"]):
			_buttons[i].icon = null
			_buttons[i].text = "MAX"
			_buttons[i].disabled = true
		else:
			_buttons[i].icon = CoinTex.get_texture()
			_buttons[i].text = " %d" % cost
			_buttons[i].disabled = coins < cost

func _on_buy(index: int) -> void:
	buy_requested.emit(index)
