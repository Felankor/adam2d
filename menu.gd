extends Control

const BG_PATH := "res://art/menu_bg.png"

var _main_box: VBoxContainer
var _diff_box: VBoxContainer
var _slot_box: VBoxContainer
var _new_diff: int = 0
const PAGE_W := 1000.0
var _settings: SettingsPanel

func _ready() -> void:
	PixelUI.setup(get_tree())
	MobArt.prewarm()
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
	var sb := PixelUI.box(Color(0.07, 0.05, 0.04, 0.82), Color(0.85, 0.65, 0.2))
	sb.set_content_margin_all(34)
	panel.add_theme_stylebox_override("panel", sb)
	left.add_child(panel)

	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(PAGE_W, 0)      # every page and button lines up on one width
	stack.add_theme_constant_override("separation", 22)
	panel.add_child(stack)

	stack.add_child(PixelLogo.new())

	var subtitle := Label.new()
	subtitle.text = "Grow your village into an Eye of End"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", PixelUI.fs(22))
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	stack.add_child(subtitle)

	# ----- main buttons -----
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 12)
	stack.add_child(_main_box)
	GameState.init_saves()
	_build_main()

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
	_diff_box.add_child(_button("Beginner  -  the standard experience", _pick_difficulty.bind(0)))
	_diff_box.add_child(_button("I Hate Myself  -  denser waves, more rivals, double gold", _pick_difficulty.bind(1)))
	_diff_box.add_child(_button("Back", _show_main))

	# ----- save slots (load or choose where a new game is saved) -----
	_slot_box = VBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 12)
	_slot_box.visible = false
	stack.add_child(_slot_box)

	# ----- settings -----
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_pressed.connect(_show_main)
	stack.add_child(_settings)
	if GameState.reopen_slots:
		GameState.reopen_slots = false
		_open_slots.call_deferred("load")

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", PixelUI.fs(24))
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not handler.is_null():
		b.pressed.connect(handler)
	return b

func _build_main() -> void:
	for c in _main_box.get_children():
		_main_box.remove_child(c)
		c.queue_free()
	var newest := GameState.newest_slot()
	if newest >= 0:
		var info := GameState.slot_info(newest)
		var label := Loc.t("Continue  (Slot %d, Wave %d, %s)") % [newest + 1, int(info["level"]), Loc.t(GameState.DIFFICULTY_NAMES[int(info["difficulty"])])]
		_main_box.add_child(_button(label, _load_slot.bind(newest)))
		_main_box.add_child(_button("Load Game", _open_slots.bind("load")))
	_main_box.add_child(_button("New Game", _on_new_game))
	_main_box.add_child(_button("Settings", _on_settings))
	_main_box.add_child(_button("Quit", _on_quit))

# Shows exactly one page (main, difficulty, slots, settings) and hides all the others.
func _show_page(page: Control) -> void:
	for p: Control in [_main_box, _diff_box, _slot_box, _settings]:
		p.visible = p == page

func _show_main() -> void:
	_show_page(_main_box)

func _on_new_game() -> void:
	Sfx.play("click")
	_show_page(_diff_box)

func _pick_difficulty(difficulty: int) -> void:
	Sfx.play("click")
	_new_diff = difficulty
	_open_slots("new")

# Lists the save slots. mode "load": pick one to load (or delete it). mode "new": pick where the new game is saved.
func _open_slots(mode: String) -> void:
	_show_page(_slot_box)
	for c in _slot_box.get_children():
		_slot_box.remove_child(c)        # take them out at once so old rows never overlap the new list
		c.queue_free()
	var title := Label.new()
	title.text = "Load which save?" if mode == "load" else "Save the new game in which slot?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", PixelUI.fs(28))
	_slot_box.add_child(title)
	for i in GameState.SLOT_COUNT:
		var info := GameState.slot_info(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_slot_box.add_child(row)
		var text := ""
		if info.is_empty():
			text = Loc.t("Slot %d  -  Empty") % (i + 1)
		else:
			text = Loc.t("Slot %d  -  Wave %d, %s   %s") % [i + 1, int(info["level"]), Loc.t(GameState.DIFFICULTY_NAMES[int(info["difficulty"])]), GameState.time_text(int(info["time"]))]
		var btn := _button(text, Callable())
		btn.add_theme_font_size_override("font_size", PixelUI.fs(22))
		row.add_child(btn)
		if mode == "load":
			btn.disabled = info.is_empty()
			btn.pressed.connect(_load_slot.bind(i))
		else:
			var armed := [false]
			btn.pressed.connect(func() -> void:
				if not info.is_empty() and not armed[0]:
					armed[0] = true
					Sfx.play("click")
					btn.text = Loc.t("Click again to overwrite Slot %d") % (i + 1)
					return
				_start_new(i))
		if not info.is_empty():
			var del := Button.new()
			del.text = "Delete"
			del.add_theme_font_size_override("font_size", PixelUI.fs(22))
			del.custom_minimum_size = Vector2(180, 64)
			var confirm := [false]
			del.pressed.connect(func() -> void:
				if not confirm[0]:
					confirm[0] = true
					del.text = "Sure?"
					Sfx.play("click")
					return
				GameState.delete_slot(i)
				Sfx.play("click")
				_build_main()
				_open_slots.call_deferred(mode))
			row.add_child(del)
		else:
			var gap := Control.new()                 # keeps empty rows the same width as the others
			gap.custom_minimum_size = Vector2(180, 64)
			row.add_child(gap)
	_slot_box.add_child(_button("Back", _show_main if mode == "load" else _on_new_game))

func _start_new(slot: int) -> void:
	Sfx.play("click")
	GameState.difficulty = _new_diff
	GameState.current_slot = slot
	GameState.pending_load = {}
	get_tree().change_scene_to_file("res://main.tscn")

func _load_slot(slot: int) -> void:
	Sfx.play("click")
	var save := GameState.read_slot(slot)
	if save.is_empty():
		return
	GameState.difficulty = clampi(int(save.get("difficulty", 0)), 0, 1)
	GameState.current_slot = slot
	GameState.pending_load = save
	get_tree().change_scene_to_file("res://main.tscn")

func _on_settings() -> void:
	Sfx.play("click")
	_show_page(_settings)

func _on_quit() -> void:
	get_tree().quit()
