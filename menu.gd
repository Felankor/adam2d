extends Control

var _main_box: VBoxContainer
var _settings_box: VBoxContainer

func _ready() -> void:
	Settings.load_and_apply()

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 28)
	center.add_child(stack)

	var title := Label.new()
	title.text = "ADAM 2D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Grow your village into a Death Star"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 12)
	stack.add_child(_main_box)
	_main_box.add_child(_button("Play", _on_play))
	_main_box.add_child(_button("Settings", _on_settings))
	_main_box.add_child(_button("Quit", _on_quit))

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 12)
	_settings_box.visible = false
	stack.add_child(_settings_box)

	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(_on_fullscreen)
	_settings_box.add_child(fs)

	var vol_label := Label.new()
	vol_label.text = "Volume"
	_settings_box.add_child(vol_label)

	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Settings.volume
	vol.custom_minimum_size = Vector2(260, 24)
	vol.value_changed.connect(_on_volume)
	_settings_box.add_child(vol)

	_settings_box.add_child(_button("Back", _on_back))

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.pressed.connect(handler)
	return b

func _on_play() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_settings() -> void:
	_main_box.visible = false
	_settings_box.visible = true

func _on_back() -> void:
	Settings.save()
	_settings_box.visible = false
	_main_box.visible = true

func _on_quit() -> void:
	get_tree().quit()

func _on_fullscreen(on: bool) -> void:
	Settings.fullscreen = on
	Settings.apply()
	Settings.save()

func _on_volume(v: float) -> void:
	Settings.volume = v
	Settings.apply()
