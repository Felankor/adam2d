class_name UpgradeMenu
extends Control

signal chosen(id: String)

var _title: Label
var _row: HBoxContainer
var _ids: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	box.add_child(_title)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 20)
	box.add_child(_row)

	var hint := Label.new()
	hint.text = "Click a card or press 1, 2 or 3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	box.add_child(hint)

func open(title: String, options: Array) -> void:
	_title.text = title
	_ids.clear()
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	var n := 1
	for opt in options:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(320, 300)
		b.pressed.connect(_on_pick.bind(opt["id"]))
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 10)
		b.add_child(col)
		var num := Label.new()
		num.text = "[%d]" % n
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.add_theme_font_size_override("font_size", 20)
		num.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(num)
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(holder)
		var icon := IconRect.new()
		icon.custom_minimum_size = Vector2(88, 88)
		icon.kind = str(opt.get("icon", ""))
		holder.add_child(icon)
		var card_title := Label.new()
		card_title.text = str(opt["name"])
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_title.add_theme_font_size_override("font_size", 26)
		card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(card_title)
		var desc := Label.new()
		desc.text = str(opt["desc"])
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.add_theme_font_size_override("font_size", 18)
		desc.add_theme_color_override("font_color", Color(0.78, 0.8, 0.88))
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(desc)
		_row.add_child(b)
		_ids.append(opt["id"])
		n += 1
	visible = true

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var idx := int(key.keycode) - int(KEY_1)
		if idx >= 0 and idx < _ids.size():
			get_viewport().set_input_as_handled()
			_on_pick(_ids[idx])

func _on_pick(id: String) -> void:
	if not visible:
		return
	visible = false
	chosen.emit(id)
