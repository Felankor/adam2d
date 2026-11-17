extends Control

const BG_PATH := "res://art/menu_bg.png"

var _main_box: VBoxContainer
var _diff_box: VBoxContainer
var _slot_box: VBoxContainer
var _new_diff: int = 0
const K := 1.0                     # launcher size factor (buttons, text, logo)
const PAGE_W := 860.0               # panel width: about 45% of the screen so the castle painting stays visible
const MAIN_BTN_W := 520.0           # main-menu and Back buttons: narrower than the panel and centred
const WIDE_BTN_W := 780.0           # buttons with long labels (difficulty choice)
const BTN_H := 76.0                 # button height: tall enough for the biggest menu font
var _panel: PanelContainer
var _logo: Control
var _subtitle: Label
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
	margin.add_theme_constant_override("margin_left", 80)
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
	_panel = panel

	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(PAGE_W, 0)      # every page and button lines up on one width
	stack.add_theme_constant_override("separation", 22)
	panel.add_child(stack)

	var logo := PixelLogo.new()
	logo.set_k(0.9)
	_logo = logo
	stack.add_child(logo)

	var subtitle := Label.new()
	subtitle.text = "Grow your village into an Eye of End"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", PixelUI.mfs(int(22 * K)))
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	stack.add_child(subtitle)
	_subtitle = subtitle

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
	_diff_box.add_child(PixelTitle.make("Choose your difficulty", int(30 * K)))
	_diff_box.add_child(_button("Beginner  -  the standard experience", _pick_difficulty.bind(0), WIDE_BTN_W))
	_diff_box.add_child(_button("I Hate Myself  -  denser waves, more rivals, double gold", _pick_difficulty.bind(1), WIDE_BTN_W))
	_diff_box.add_child(_button("Back", _show_main, MAIN_BTN_W))

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

func _button(text: String, handler: Callable, width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", PixelUI.mfs(int(24 * K)))
	if width > 0.0:
		b.custom_minimum_size = Vector2(width, BTN_H)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		b.custom_minimum_size = Vector2(0, BTN_H)
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
		_main_box.add_child(_button(label, _load_slot.bind(newest), MAIN_BTN_W))
		_main_box.add_child(_button("Load Game", _open_slots.bind("load"), MAIN_BTN_W))
	_main_box.add_child(_button("New Game", _on_new_game, MAIN_BTN_W))
	_main_box.add_child(_button("Settings", _on_settings, MAIN_BTN_W))
	_main_box.add_child(_button("Quit", _on_quit, MAIN_BTN_W))

# Shows exactly one page (main, difficulty, slots, settings) and hides all the others.
func _show_page(page: Control) -> void:
	for p: Control in [_main_box, _diff_box, _slot_box, _settings]:
		p.visible = p == page
	# the big logo only shows on the first two pages, so the settings and save lists never run off the screen
	var show_logo := page == _main_box or page == _diff_box
	_logo.visible = show_logo
	_subtitle.visible = show_logo
	_panel.reset_size.call_deferred()        # shrink the panel to the page that is showing now (it never shrank back before)

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
	_slot_box.add_child(PixelTitle.make("Load which save?" if mode == "load" else "Save the new game in which slot?", int(30 * K)))
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
		btn.add_theme_font_size_override("font_size", PixelUI.mfs(int(22 * K)))
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
			del.add_theme_font_size_override("font_size", PixelUI.mfs(int(22 * K)))
			del.custom_minimum_size = Vector2(180 * K, BTN_H)
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
			gap.custom_minimum_size = Vector2(180 * K, BTN_H)
			row.add_child(gap)
	_slot_box.add_child(_button("Back", _show_main if mode == "load" else _on_new_game, MAIN_BTN_W))

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
