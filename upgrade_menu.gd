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
		b.text = "[%d]\n%s\n\n%s" % [n, opt["name"], opt["desc"]]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(320, 200)
		b.pressed.connect(_on_pick.bind(opt["id"]))
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
