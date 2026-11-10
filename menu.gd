extends Control

var _main_box: VBoxContainer
var _diff_box: VBoxContainer
var _settings: SettingsPanel

func _ready() -> void:
	Settings.load_and_apply()
	Cursors.set_mode(Cursors.Mode.ARROW)

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
	title.add_theme_font_size_override("font_size", 96)
	stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Grow your village into a Death Star"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)

	# ----- main buttons -----
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 12)
	stack.add_child(_main_box)
	var save := GameState.read_save()
	if not save.is_empty():
		var lvl := int(save.get("level", 1))
		var diff := clampi(int(save.get("difficulty", 0)), 0, 1)
		var label := "Continue  (Level %d, %s)" % [lvl, GameState.DIFFICULTY_NAMES[diff]]
		_main_box.add_child(_button(label, _on_continue.bind(save)))
	_main_box.add_child(_button("New Game", _on_new_game))
	_main_box.add_child(_button("Settings", _on_settings))
	_main_box.add_child(_button("Quit", _on_quit))

	# ----- difficulty choice -----
	_diff_box = VBoxContainer.new()
	_diff_box.add_theme_constant_override("separation", 12)
	_diff_box.visible = false
	stack.add_child(_diff_box)
	var diff_title := Label.new()
	diff_title.text = "Choose your difficulty"
	diff_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_title.add_theme_font_size_override("font_size", 28)
	_diff_box.add_child(diff_title)
	_diff_box.add_child(_button("Beginner  -  the standard experience", _on_start.bind(0)))
	_diff_box.add_child(_button("Seasoned  -  denser waves, faster and tougher enemies", _on_start.bind(1)))
	_diff_box.add_child(_button("Back", _show_main))

	# ----- settings -----
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_pressed.connect(_show_main)
	stack.add_child(_settings)

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(560, 64)
	b.pressed.connect(handler)
	return b

func _show_main() -> void:
	_main_box.visible = true
	_diff_box.visible = false
	_settings.visible = false

func _on_new_game() -> void:
	Sfx.play("click")
	_main_box.visible = false
	_diff_box.visible = true

func _on_start(difficulty: int) -> void:
	Sfx.play("click")
	GameState.difficulty = difficulty
	GameState.pending_load = {}
	get_tree().change_scene_to_file("res://main.tscn")

func _on_continue(save: Dictionary) -> void:
	Sfx.play("click")
	GameState.difficulty = clampi(int(save.get("difficulty", 0)), 0, 1)
	GameState.pending_load = save
	get_tree().change_scene_to_file("res://main.tscn")

func _on_settings() -> void:
	Sfx.play("click")
	_main_box.visible = false
	_settings.visible = true

func _on_quit() -> void:
	get_tree().quit()
