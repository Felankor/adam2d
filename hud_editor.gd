class_name HudEditor
extends Control

# In-game HUD editor. Opened from Pause > Settings > Edit HUD layout.
# Drag an element to move it, drag its corner handle to resize it, use the side panel for the details
# (visibility, opacity, bar length, text, ...), presets and your own two saved layouts.
signal closed

const PANEL_W := 430.0
const DISPLAY := {
	"layer": "In tube", "own": "Own tube", "fps": "FPS only", "row": "Row", "column": "Column",
	"game": "Classic", "pixelify": "Pixelify", "silkscreen": "Silk",
}

var hud: Hud
var _snapshot: Dictionary = {}
var _sel: String = "bars"
var _hover: String = ""
var _mode: String = ""             # "", "move" or "scale"
var _m0 := Vector2.ZERO
var _off0 := Vector2.ZERO
var _sc0: float = 1.0
var _snap_on: bool = false
var _grid_on: bool = false
var _dock_right: bool = true
var _guide_x: bool = false
var _panel: PanelContainer
var _chips: Dictionary = {}
var _props: VBoxContainer
var _info: Label
var _slot_load: Dictionary = {}
var _built: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PixelUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

# ---------- open / close ----------

func open(h: Hud) -> void:
	hud = h
	if not _built:
		_built = true
		_build_panel()
	_snapshot = HudLayout.snapshot()
	visible = true
	_mode = ""
	hud.set_edit_mode(true)
	_place_panel()
	_select(_sel)
	_refresh_slots()
	queue_redraw()

# Saves (or throws the changes away) and closes the editor.
func finish(save: bool) -> void:
	if not visible:
		return
	if save:
		Settings.save()
	else:
		HudLayout.restore(_snapshot)
	visible = false
	hud.set_edit_mode(false)
	closed.emit()

# ---------- side panel ----------

func _btn(text: String, handler: Callable, w: float, h: float, font: int, toggle: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", PixelUI.mfs(font))
	b.pressed.connect(handler)
	return b

func _label(text: String, font: int = 20, col: Color = PixelUI.CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", PixelUI.mfs(font))
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART      # long hints wrap instead of widening the panel
	l.custom_minimum_size = Vector2(1, 0)
	return l

func _check(text: String, on: bool, handler: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", PixelUI.mfs(20))
	c.button_pressed = on
	c.toggled.connect(handler)
	return c

func _build_panel() -> void:
	_panel = PanelContainer.new()
	var sb := PixelUI.box(PixelUI.WIN_BG, PixelUI.BRONZE)
	sb.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	_panel.minimum_size_changed.connect(_place_panel)

	var head := HBoxContainer.new()
	var title := _label("HUD EDITOR", 30, PixelUI.GOLD)
	PixelUI.style_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_btn("Move panel", _on_dock, 130, 38, 18))
	v.add_child(head)

	v.add_child(_label("Presets", 20, PixelUI.DIM))
	var pr := HFlowContainer.new()
	pr.add_theme_constant_override("h_separation", 6)
	pr.add_theme_constant_override("v_separation", 6)
	for n: String in HudLayout.PRESETS:
		pr.add_child(_btn(n, _on_preset.bind(n), 90, 38, 18))
	v.add_child(pr)
	for n in [1, 2]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lab := _label("Mine %d" % n, 20)
		lab.custom_minimum_size = Vector2(110, 0)
		row.add_child(lab)
		var lb := _btn("Load", _on_slot_load.bind(n), 110, 38, 18)
		row.add_child(lb)
		_slot_load[n] = lb
		row.add_child(_btn("Save here", _on_slot_save.bind(n), 150, 38, 18))
		v.add_child(row)

	v.add_child(HSeparator.new())
	v.add_child(_label("Elements", 20, PixelUI.DIM))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for id: String in HudLayout.IDS:
		var b := _btn(HudLayout.NAMES[id], _select.bind(id), 0, 36, 16, true)
		_chips[id] = b
		chips.add_child(b)
	v.add_child(chips)
	v.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_props = VBoxContainer.new()
	_props.add_theme_constant_override("separation", 8)
	_props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_props)

	v.add_child(HSeparator.new())
	var all_row := HBoxContainer.new()
	all_row.add_theme_constant_override("separation", 6)
	var all_lab := _label("Font for all", 20)
	all_lab.custom_minimum_size = Vector2(130, 0)
	all_row.add_child(all_lab)
	for fid: String in HudFonts.IDS:
		var ab := _btn(_opt_name(fid), _on_all_font.bind(fid), 0, 36, 16)
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all_row.add_child(ab)
	v.add_child(all_row)
	v.add_child(_check("Snap to grid (10 px)", _snap_on, func(on: bool) -> void: _snap_on = on))
	v.add_child(_check("Show grid", _grid_on, func(on: bool) -> void:
		_grid_on = on
		queue_redraw()))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	bottom.add_child(_btn("Reset all", _on_reset_all, 110, 46, 18))
	bottom.add_child(_btn("Cancel", _on_cancel, 110, 46, 18))
	var done := _btn("Save & close", _on_done, 150, 46, 18)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(done)
	v.add_child(bottom)

func _place_panel() -> void:
	var w := Settings.WORLD_SIZE
	var pw := maxf(PANEL_W, _panel.get_combined_minimum_size().x)    # never narrower than its content, so nothing hangs off the screen
	_panel.size = Vector2(pw, w.y)
	_panel.position = Vector2(w.x - pw if _dock_right else 0.0, 0.0)

func _on_dock() -> void:
	Sfx.play("click")
	_dock_right = not _dock_right
	_place_panel()

# ---------- properties of the selected element ----------

func _movable(id: String) -> bool:
	return not (id == "shield" and HudLayout.text("shield", "style") != "own")

func _select(id: String) -> void:
	_sel = id
	for k in _chips:
		(_chips[k] as Button).set_pressed_no_signal(k == id)
	_build_props()
	queue_redraw()

func _build_props() -> void:
	for c in _props.get_children():
		_props.remove_child(c)
		c.queue_free()
	_props.add_child(_label(HudLayout.NAMES[_sel], 26, PixelUI.GOLD))
	var list: Array = []
	if _sel == "shield":
		list.append_array(HudLayout.EXTRA["shield"] as Array)
		for r: Array in HudLayout.COMMON:
			if r[0] == "vis" or HudLayout.text("shield", "style") == "own":
				list.append(r)
	else:
		list.append_array(HudLayout.COMMON)
		list.append_array(HudLayout.EXTRA[_sel] as Array)
	if HudLayout.TEXT.has(_sel):
		list.append_array(HudLayout.TEXT_ROWS)
	for r: Array in list:
		_props.add_child(_row(r))
	if _movable(_sel):
		_info = _label("", 18, PixelUI.DIM)
		_props.add_child(_info)
		_props.add_child(_btn("Reset position", _on_reset_pos, 200, 40, 18))
	else:
		_info = null
		_props.add_child(_label("Inside the health tube. Choose \"Own tube\" to place it freely.", 18, PixelUI.DIM))
	_props.add_child(_btn("Reset this element", _on_reset_element, 240, 40, 18))
	_refresh_info()

func _opt_name(opt: Variant) -> String:
	var k := str(opt)
	return DISPLAY[k] if DISPLAY.has(k) else k.capitalize()

func _fmt(key: String, v: float) -> String:
	if key == "scale" or key == "alpha" or key == "tsize":
		return "%d%%" % roundi(v * 100.0)
	if key == "len":
		return "%+d" % roundi(v)
	return "%d" % roundi(v)

func _row(r: Array) -> Control:
	var key: String = r[0]
	var text: String = r[1]
	var type: String = r[2]
	var cur: Variant = HudLayout.get_v(_sel, key)
	if type == "bool":
		return _check(text, bool(cur), func(on: bool) -> void: _put(key, on))
	if type == "float":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lab := _label(text, 20)
		lab.custom_minimum_size = Vector2(150, 0)
		row.add_child(lab)
		var sl := HSlider.new()
		sl.min_value = float(r[3])
		sl.max_value = float(r[4])
		sl.step = float(r[5])
		sl.value = float(cur)
		sl.focus_mode = Control.FOCUS_NONE
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size = Vector2(120, 28)
		row.add_child(sl)
		var vl := _label(_fmt(key, float(cur)), 18, PixelUI.GOLD)
		vl.custom_minimum_size = Vector2(62, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(vl)
		sl.value_changed.connect(func(val: float) -> void:
			_put(key, val)
			vl.text = _fmt(key, val))
		return row
	# enum: the name on top, one toggle button per option below it
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label(text, 20))
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 6)
	for o: Variant in r[3]:
		var pick := func() -> void:
			_put(key, o)
			_build_props.call_deferred()
		var b := _btn(_opt_name(o), pick, 0, 36, 16, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(str(o) == str(cur))
		opts.add_child(b)
	box.add_child(opts)
	return box

func _put(key: String, v: Variant) -> void:
	HudLayout.set_v(_sel, key, v)
	if key == "style":
		_build_props.call_deferred()
	_apply()

func _apply() -> void:
	hud.apply_layout()
	_refresh_info()
	queue_redraw()

func _refresh_info() -> void:
	if _info != null and is_instance_valid(_info):
		_info.text = "%s   X %+d   Y %+d" % [Loc.t("Offset"), roundi(HudLayout.num(_sel, "ox")), roundi(HudLayout.num(_sel, "oy"))]

# ---------- buttons ----------

func _on_preset(n: String) -> void:
	Sfx.play("click")
	HudLayout.apply_preset(n)
	_apply()
	_build_props()

func _refresh_slots() -> void:
	for n in _slot_load:
		(_slot_load[n] as Button).disabled = not HudLayout.slot_has(n)

func _on_slot_save(n: int) -> void:
	Sfx.play("click")
	HudLayout.slot_save(n)
	_refresh_slots()

func _on_slot_load(n: int) -> void:
	Sfx.play("click")
	if HudLayout.slot_load(n):
		_apply()
		_build_props()

func _on_all_font(fid: String) -> void:
	Sfx.play("click")
	for id: String in HudLayout.TEXT:
		HudLayout.set_v(id, "font", fid)
	_apply()
	_build_props()

func _on_reset_pos() -> void:
	Sfx.play("click")
	HudLayout.set_v(_sel, "ox", 0.0)
	HudLayout.set_v(_sel, "oy", 0.0)
	_apply()

func _on_reset_element() -> void:
	Sfx.play("click")
	HudLayout.reset_element(_sel)
	_apply()
	_build_props()

func _on_reset_all() -> void:
	Sfx.play("click")
	HudLayout.reset_all()
	_apply()
	_build_props()

func _on_cancel() -> void:
	Sfx.play("click")
	finish(false)

func _on_done() -> void:
	Sfx.play("click")
	finish(true)

# ---------- mouse and keys on the HUD itself ----------

# An element's box on the real screen (the HUD canvas is scaled by the HUD size setting).
func _screen_rect(id: String) -> Rect2:
	var r := hud.placed_rect(id)
	var k := hud.space_scale(id)
	return Rect2(r.position * k, r.size * k)

func _pick(pos: Vector2) -> String:
	var best := ""
	var best_area := INF
	for id: String in HudLayout.IDS:
		if not _movable(id):
			continue
		var r := _screen_rect(id).grow(6.0)
		if r.has_point(pos):
			var a := r.size.x * r.size.y
			if a < best_area:
				best_area = a
				best = id
	return best

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb.position)
			else:
				_release()
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		if _mode != "":
			_drag(mm.position)
		else:
			var h := _pick(mm.position)
			if h != _hover:
				_hover = h
				queue_redraw()
		accept_event()

func _press(pos: Vector2) -> void:
	if _movable(_sel):
		var r := _screen_rect(_sel)
		if Rect2(r.end - Vector2(14.0, 14.0), Vector2(26.0, 26.0)).has_point(pos):
			_mode = "scale"
			_m0 = pos
			_sc0 = HudLayout.num(_sel, "scale")
			_panel.modulate.a = 0.35
			return
	var id := _pick(pos)
	if id == "":
		return
	if id != _sel:
		_select(id)
	_mode = "move"
	_m0 = pos
	_off0 = Vector2(HudLayout.num(id, "ox"), HudLayout.num(id, "oy"))
	_panel.modulate.a = 0.35

func _release() -> void:
	if _mode == "scale":
		_build_props.call_deferred()      # the size slider follows the handle
	_mode = ""
	_guide_x = false
	_panel.modulate.a = 1.0
	queue_redraw()

func _drag(pos: Vector2) -> void:
	if _mode == "move":
		var k := hud.space_scale(_sel)
		var s := Settings.WORLD_SIZE / k
		var o := _off0 + (pos - _m0) / k
		if _snap_on:
			o = Vector2(roundf(o.x / 10.0) * 10.0, roundf(o.y / 10.0) * 10.0)
		var base_c := hud.pivot_of(_sel)
		_guide_x = false
		if absf(base_c.x + o.x - s.x * 0.5) < 8.0:
			o.x = s.x * 0.5 - base_c.x           # click into the middle of the screen
			_guide_x = true
		var c := base_c + o
		c = Vector2(clampf(c.x, 0.0, s.x), clampf(c.y, 0.0, s.y))
		o = c - base_c
		HudLayout.set_v(_sel, "ox", roundf(o.x))
		HudLayout.set_v(_sel, "oy", roundf(o.y))
	elif _mode == "scale":
		var c := _screen_rect(_sel).get_center()
		var d0 := maxf((_m0 - c).length(), 1.0)
		var sc := clampf(roundf(_sc0 * (pos - c).length() / d0 / 0.05) * 0.05, 0.5, 2.0)
		HudLayout.set_v(_sel, "scale", sc)
	_apply()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if not _movable(_sel):
		return
	var step := 10.0 if key.shift_pressed else 1.0
	var d := Vector2.ZERO
	match key.keycode:
		KEY_LEFT:
			d = Vector2(-step, 0.0)
		KEY_RIGHT:
			d = Vector2(step, 0.0)
		KEY_UP:
			d = Vector2(0.0, -step)
		KEY_DOWN:
			d = Vector2(0.0, step)
		_:
			return
	get_viewport().set_input_as_handled()
	HudLayout.set_v(_sel, "ox", HudLayout.num(_sel, "ox") + d.x)
	HudLayout.set_v(_sel, "oy", HudLayout.num(_sel, "oy") + d.y)
	_apply()

# ---------- drawing ----------

func _dashed(r: Rect2, col: Color, w: float) -> void:
	var edges := [
		[r.position, Vector2.RIGHT, r.size.x],
		[Vector2(r.position.x, r.end.y), Vector2.RIGHT, r.size.x],
		[r.position, Vector2.DOWN, r.size.y],
		[Vector2(r.end.x, r.position.y), Vector2.DOWN, r.size.y],
	]
	for e: Array in edges:
		var p: Vector2 = e[0]
		var dir: Vector2 = e[1]
		var ln: float = e[2]
		var t := 0.0
		while t < ln:
			draw_line(p + dir * t, p + dir * minf(t + 7.0, ln), col, w)
			t += 12.0

func _draw() -> void:
	if not visible or hud == null:
		return
	var w := Settings.WORLD_SIZE
	if _grid_on:
		var st := 40.0 * Settings.hud_scale
		var x := 0.0
		while x < w.x:
			draw_line(Vector2(x, 0), Vector2(x, w.y), Color(1, 1, 1, 0.06), 1.0)
			x += st
		var y := 0.0
		while y < w.y:
			draw_line(Vector2(0, y), Vector2(w.x, y), Color(1, 1, 1, 0.06), 1.0)
			y += st
	draw_line(Vector2(w.x * 0.5, 0), Vector2(w.x * 0.5, w.y), Color(1.0, 0.9, 0.4, 0.55 if _guide_x else 0.12), 2.0 if _guide_x else 1.0)
	var order: Array = []
	for id: String in HudLayout.IDS:
		if id != _sel and _movable(id):
			order.append(id)
	order.append(_sel)
	for id: String in order:
		var r := _screen_rect(id)
		var is_sel := id == _sel
		var col := Color(1.0, 0.85, 0.3, 0.95) if is_sel else (Color(1, 1, 1, 0.85) if id == _hover else Color(0.85, 0.65, 0.2, 0.5))
		if is_sel and not _movable(id):
			col = Color(0.7, 0.8, 0.9, 0.5)
		if is_sel:
			draw_rect(r, Color(1.0, 0.85, 0.3, 0.07))
		_dashed(r, col, 2.0 if is_sel else 1.0)
		var tag_pos := Vector2(r.position.x + 2.0, r.position.y - 7.0)
		if tag_pos.y < 22.0:
			tag_pos.y = r.position.y + 20.0
		if is_sel or id == _hover:
			PixelUI.text(self, tag_pos, Loc.t(HudLayout.NAMES[id]), 20, col, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
		if is_sel and _movable(id):
			var hr := Rect2(r.end - Vector2(9.0, 9.0), Vector2(18.0, 18.0))
			draw_rect(hr.grow(3.0), PixelUI.OUTLINE)
			draw_rect(hr, Color(1.0, 0.85, 0.3))
	# hint
	var hint := Loc.t("Drag to move  -  corner square = size  -  arrow keys = nudge (Shift = x10)  -  Esc = save & close")
	var hw := PixelUI.ui_font().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelUI.mfs(20)).x + 40.0
	var cx := (w.x - _panel.size.x) * 0.5 + (0.0 if _dock_right else _panel.size.x)
	draw_style_box(PixelUI.box(PixelUI.WIN_BG, PixelUI.BRONZE, 2), Rect2(cx - hw * 0.5, 14.0, hw, 44.0))
	PixelUI.text(self, Vector2(cx - hw * 0.5, 44.0), hint, 20, PixelUI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, hw, 0)
