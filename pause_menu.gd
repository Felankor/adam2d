class_name PauseMenu
extends Control

# Opened with Esc while playing: Resume, Save, Settings, Quit to Main Menu.
signal resume_requested
signal save_requested
signal quit_requested

var _main_box: VBoxContainer
var _status: Label
var _quit_btn: Button
var _settings: SettingsPanel
var _quit_armed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.14, 0.97)
	sb.border_color = Color(0.85, 0.65, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var holder := VBoxContainer.new()
	panel.add_child(holder)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 14)
	holder.add_child(_main_box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	_main_box.add_child(title)

	_main_box.add_child(_button("Resume", _on_resume))
	_main_box.add_child(_button("Save", _on_save))
	_main_box.add_child(_button("Settings", _on_settings))
	_quit_btn = _button("Quit to Main Menu", _on_quit)
	_main_box.add_child(_quit_btn)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_status.custom_minimum_size = Vector2(440, 48)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_box.add_child(_status)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_pressed.connect(_show_main)
	holder.add_child(_settings)

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(440, 62)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(handler)
	return b

func open() -> void:
	visible = true
	_status.text = ""
	_show_main()

func close() -> void:
	visible = false
	_show_main()

# Returns true if it handled "back" itself (closing the settings page).
func go_back() -> bool:
	if _settings.visible:
		_show_main()
		return true
	return false

func set_status(text: String) -> void:
	_status.text = text

func _show_main() -> void:
	_settings.visible = false
	_main_box.visible = true
	_reset_quit()

func _reset_quit() -> void:
	_quit_armed = false
	_quit_btn.text = "Quit to Main Menu"

func _on_resume() -> void:
	Sfx.play("click")
	resume_requested.emit()

func _on_save() -> void:
	_reset_quit()
	save_requested.emit()

func _on_settings() -> void:
	Sfx.play("click")
	_reset_quit()
	_main_box.visible = false
	_settings.visible = true

func _on_quit() -> void:
	Sfx.play("click")
	if not _quit_armed:
		_quit_armed = true
		_quit_btn.text = "Click again to confirm (unsaved progress is lost)"
		return
	quit_requested.emit()
