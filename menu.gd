extends Control

const BG_PATH := "res://art/menu_bg.png"

var _main_box: VBoxContainer
var _diff_box: VBoxContainer
var _settings: SettingsPanel

func _ready() -> void:
	PixelUI.setup(get_tree())
	Settings.load_and_apply()
	Cursors.set_mode(Cursors.Mode.ARROW)

	# Background: the floating castle painting (falls back to a dark gradient).
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.10, 0.20)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if ResourceLoader.exists(BG_PATH):
		var pic := TextureRect.new()
		pic.texture = load(BG_PATH) as Texture2D
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(pic)

	# The menu sits in a column on the left so the castle stays visible.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_right", 60)
	add_child(margin)

	var left := CenterContainer.new()
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(left)

	var panel := PanelContainer.new()
	var sb := PixelUI.box(Color(0.04, 0.06, 0.12, 0.72), Color(0.45, 0.55, 0.8))
	sb.set_content_margin_all(34)
	panel.add_theme_stylebox_override("panel", sb)
	left.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 22)
	panel.add_child(stack)

	stack.add_child(PixelLogo.new())

	var subtitle := Label.new()
	subtitle.text = "Grow your village into a Death Star"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", PixelUI.fs(22))
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	stack.add_child(subtitle)

	# ----- main buttons -----
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 12)
	stack.add_child(_main_box)
	var save := GameState.read_save()
	if not save.is_empty():
		var lvl := int(save.get("level", 1))
		var diff := clampi(int(save.get("difficulty", 0)), 0, 1)
		var label := Loc.t("Continue  (Wave %d, %s)") % [lvl, Loc.t(GameState.DIFFICULTY_NAMES[diff])]
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
	diff_title.add_theme_font_size_override("font_size", PixelUI.fs(28))
	_diff_box.add_child(diff_title)
	_diff_box.add_child(_button("Beginner  -  the standard experience", _on_start.bind(0)))
	_diff_box.add_child(_button("Seasoned  -  denser waves, tougher foes", _on_start.bind(1)))
	_diff_box.add_child(_button("Back", _show_main))

	# ----- settings -----
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_pressed.connect(_show_main)
	stack.add_child(_settings)

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", PixelUI.fs(24))
	b.custom_minimum_size = Vector2(600, 64)
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
