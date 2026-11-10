class_name GameOverMenu
extends Control

# Window shown when the base is destroyed: Retry or Quit.
signal retry_requested
signal quit_requested

var _info: Label
var _retry: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.09, 0.97)
	sb.border_color = Color(0.85, 0.2, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Your castle has been destroyed!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	box.add_child(title)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 24)
	box.add_child(_info)

	box.add_child(HSeparator.new())
	_retry = _button("Retry", _on_retry)
	box.add_child(_retry)
	box.add_child(_button("Quit to Main Menu", _on_quit))

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(420, 60)
	b.add_theme_font_size_override("font_size", 26)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(handler)
	return b

func open(info: String, retry_text: String) -> void:
	_info.text = info
	_retry.text = retry_text
	modulate.a = 0.0
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6)

func _on_retry() -> void:
	Sfx.play("click")
	retry_requested.emit()

func _on_quit() -> void:
	Sfx.play("click")
	quit_requested.emit()
