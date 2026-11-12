class_name GameOverMenu
extends Control

# Window shown when the base is destroyed: Retry or Quit.
signal retry_requested
signal quit_requested

var _info: Label
var _retry: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PixelUI.theme()
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
	var sb := PixelUI.box(Color(0.1, 0.05, 0.04, 0.97), Color(0.7, 0.32, 0.18))
	sb.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	PixelUI.fit(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	box.add_child(PixelTitle.make("Your castle has been destroyed!", 40, PixelUI.BAD))

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", PixelUI.mfs(24))
	box.add_child(_info)

	box.add_child(HSeparator.new())
	_retry = _button("Retry", _on_retry)
	box.add_child(_retry)
	box.add_child(_button("Quit to Main Menu", _on_quit))

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(480, 68)
	b.add_theme_font_size_override("font_size", PixelUI.mfs(30))
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
