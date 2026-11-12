class_name SettingsPanel
extends VBoxContainer

# Reusable settings screen (main menu + in-game pause menu).
# Three sections: Game, Sounds, Controls.
signal back_pressed

var _key_buttons: Dictionary = {}
var _waiting: String = ""
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(620, 0)
	add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", PixelUI.fs(40))
	add_child(title)

	# Section tabs
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	var names := ["Game", "Sounds", "Controls"]
	for i in names.size():
		var tb := Button.new()
		tb.text = names[i]
		tb.toggle_mode = true
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(190, 46)
		tb.add_theme_font_size_override("font_size", PixelUI.fs(22))
		tb.pressed.connect(_show_page.bind(i))
		tabs.add_child(tb)
		_tab_buttons.append(tb)

	_pages.append(_build_game_page())
	_pages.append(_build_sound_page())
	_pages.append(_build_controls_page())
	for p in _pages:
		add_child(p)

	add_child(_button("Back", _on_back))
	_show_page(0)
	_refresh()

func _show_page(index: int) -> void:
	_waiting = ""
	for i in _pages.size():
		_pages[i].visible = (i == index)
		_tab_buttons[i].button_pressed = (i == index)
	_refresh()

# ---------- pages ----------

func _build_game_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.custom_minimum_size = Vector2(0, 360)
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.focus_mode = Control.FOCUS_NONE
	fs.add_theme_font_size_override("font_size", PixelUI.fs(22))
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(_on_fullscreen)
	page.add_child(fs)
	var auto := CheckButton.new()
	auto.text = "Autosave at the start of each wave"
	auto.focus_mode = Control.FOCUS_NONE
	auto.add_theme_font_size_override("font_size", PixelUI.fs(22))
	auto.button_pressed = Settings.autosave
	auto.toggled.connect(func(on: bool) -> void:
		Settings.autosave = on
		Settings.save())
	page.add_child(auto)
	page.add_child(_slider_row("HUD size", Settings.hud_scale, _on_hud_scale, 0.6, 1.6, true))
	page.add_child(_slider_row("Screen shake", Settings.shake_scale, _on_shake))
	page.add_child(_slider_row("Screen flashes", Settings.flash_scale, _on_flash))
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 14)
	var lang_label := Label.new()
	lang_label.text = "Language"
	lang_label.custom_minimum_size = Vector2(220, 0)
	lang_label.add_theme_font_size_override("font_size", PixelUI.fs(22))
	lang_row.add_child(lang_label)
	var lang_opt := OptionButton.new()
	lang_opt.focus_mode = Control.FOCUS_NONE
	lang_opt.custom_minimum_size = Vector2(220, 40)
	lang_opt.add_theme_font_size_override("font_size", PixelUI.fs(20))
	for n: String in Loc.LANG_NAMES:
		lang_opt.add_item(n)
	lang_opt.selected = maxi(Loc.LANGS.find(Settings.language), 0)
	lang_opt.item_selected.connect(_on_language)
	lang_row.add_child(lang_opt)
	page.add_child(lang_row)
	return page

func _build_sound_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.custom_minimum_size = Vector2(0, 300)

	var mute := CheckButton.new()
	mute.text = "Mute all sounds"
	mute.focus_mode = Control.FOCUS_NONE
	mute.add_theme_font_size_override("font_size", PixelUI.fs(22))
	mute.button_pressed = Settings.muted
	mute.toggled.connect(_on_mute)
	page.add_child(mute)

	page.add_child(_slider_row("Master volume", Settings.volume, _on_volume))
	page.add_child(_slider_row("Effects volume", Settings.sfx_volume, _on_sfx_volume))
	page.add_child(_slider_row("Music volume", Settings.music_volume, _on_music_volume))
	return page

func _build_controls_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	page.custom_minimum_size = Vector2(0, 300)
	var hint := Label.new()
	hint.text = "Click a key, then press the new key (Esc cancels)"
	hint.add_theme_font_size_override("font_size", PixelUI.fs(18))
	page.add_child(hint)

	for action in Keybinds.ORDER:
		var a: String = action
		var row := HBoxContainer.new()
		page.add_child(row)
		var name_label := Label.new()
		name_label.text = Keybinds.label_of(a)
		name_label.custom_minimum_size = Vector2(220, 0)
		name_label.add_theme_font_size_override("font_size", PixelUI.fs(22))
		row.add_child(name_label)
		var kb := Button.new()
		kb.focus_mode = Control.FOCUS_NONE
		kb.custom_minimum_size = Vector2(220, 40)
		kb.add_theme_font_size_override("font_size", PixelUI.fs(20))
		kb.pressed.connect(_on_rebind.bind(a))
		row.add_child(kb)
		_key_buttons[a] = kb

	page.add_child(_button("Reset controls to default", _on_reset))
	return page

func _slider_row(label_text: String, value: float, handler: Callable, lo: float = 0.0, hi: float = 1.0, show_pct: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(220, 0)
	label.add_theme_font_size_override("font_size", PixelUI.fs(22))
	row.add_child(label)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.05
	sl.value = value
	sl.focus_mode = Control.FOCUS_NONE
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(300, 28)
	sl.value_changed.connect(handler)
	sl.drag_ended.connect(_on_slider_done)
	row.add_child(sl)
	if show_pct:
		var pct := Label.new()
		pct.text = "%d%%" % roundi(value * 100.0)
		pct.custom_minimum_size = Vector2(70, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.add_theme_font_size_override("font_size", PixelUI.fs(20))
		row.add_child(pct)
		sl.value_changed.connect(func(v: float) -> void: pct.text = "%d%%" % roundi(v * 100.0))
	return row

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(380, 52)
	b.add_theme_font_size_override("font_size", PixelUI.fs(22))
	b.pressed.connect(handler)
	return b

# ---------- handlers ----------

func _refresh() -> void:
	for a in _key_buttons:
		var kb: Button = _key_buttons[a]
		kb.text = "Press a key..." if a == _waiting else Keybinds.key_text(a)

func _on_rebind(action: String) -> void:
	_waiting = action
	_refresh()

func _input(event: InputEvent) -> void:
	if _waiting == "" or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.keycode != KEY_ESCAPE:
		Keybinds.set_key(_waiting, key.keycode)
		Settings.save()
	_waiting = ""
	_refresh()

func _on_reset() -> void:
	_waiting = ""
	Keybinds.reset_defaults()
	Settings.save()
	_refresh()

func _on_language(index: int) -> void:
	Settings.language = str(Loc.LANGS[index])
	Loc.set_language(Settings.language)
	Settings.save()

func _on_fullscreen(on: bool) -> void:
	Settings.fullscreen = on
	Settings.apply()
	Settings.save()

func _on_mute(on: bool) -> void:
	Settings.muted = on
	Settings.apply()
	Settings.save()

func _on_volume(v: float) -> void:
	Settings.volume = v
	Settings.apply()

func _on_sfx_volume(v: float) -> void:
	Settings.sfx_volume = v

func _on_music_volume(v: float) -> void:
	Settings.music_volume = v
	Music.refresh_volume()

func _on_hud_scale(v: float) -> void:
	Settings.hud_scale = v

func _on_shake(v: float) -> void:
	Settings.shake_scale = v

func _on_flash(v: float) -> void:
	Settings.flash_scale = v

func _on_slider_done(_changed: bool) -> void:
	Settings.save()
	Sfx.play("hit")

func _on_back() -> void:
	_waiting = ""
	Settings.save()
	back_pressed.emit()
