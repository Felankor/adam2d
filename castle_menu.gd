class_name CastleMenu
extends Control

# The Castle window (Tab key): every stat of the castle on the left, and on the right
# the stat points you spend. Each level gives 5 points; each point is +1% over the default.
# It replaces the old shop. Number keys 1-9 spend a point on the matching row.
signal spend(id: String, count: int)
signal weapon_upgrade
signal reset_pressed
signal exchange_pressed(count: int)
signal laser_toggled(on: bool)
signal continue_pressed

const EXCHANGE_GOLD := 10            # Exchange: this much gold...
const EXCHANGE_POINTS := 5           # ...buys this many stat points
const EXCHANGE_RISE := 1.10          # every purchase makes the next one 10% more expensive
const EXCHANGE_IDX := 100            # "held button" id of the exchange button

# Price of the next exchange after n purchases so far.
static func exchange_price(n: int) -> int:
	return int(round(float(EXCHANGE_GOLD) * pow(EXCHANGE_RISE, float(n))))

const STATS := [
	{"id": "damage", "name": "Weapon damage", "icon": "damage"},
	{"id": "attack", "name": "Attack speed", "icon": "atkspeed"},
	{"id": "regen", "name": "Mana regen", "icon": "regen"},
	{"id": "energy", "name": "Max mana", "icon": "energy"},
	{"id": "health", "name": "Max health", "icon": "walls"},
	{"id": "speed", "name": "Move speed", "icon": "speed"},
	{"id": "autorate", "name": "Auto fire rate", "icon": "autorate"},
	{"id": "armor", "name": "Armor", "icon": "shield"},
	{"id": "eshield", "name": "Energy Shield", "icon": "eshield"},
]

# A glass tube in a bronze trough with text on it (health, mana, shield, xp): the same look as the HUD bars.
class StatBar extends Control:
	var value: float = 0.0
	var max_value: float = 1.0
	var col: Color = Color.WHITE
	var text: String = ""
	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var u := 3.0
		var w := floorf(size.x / u) * u
		var h := floorf(size.y / u) * u
		var bronze := [Color(0.08, 0.04, 0.03), Color(0.33, 0.2, 0.1), Color(0.5, 0.31, 0.14), Color(0.68, 0.46, 0.2), Color(0.92, 0.78, 0.47)]
		# bronze beam around the tube
		draw_rect(Rect2(0, 0, w, h), bronze[0])
		draw_rect(Rect2(u, u, w - 2.0 * u, h - 2.0 * u), bronze[2])
		draw_rect(Rect2(u, u, w - 2.0 * u, u), bronze[4])
		draw_rect(Rect2(u, 2.0 * u, w - 2.0 * u, u), bronze[3])
		draw_rect(Rect2(u, h - 3.0 * u, w - 2.0 * u, u), bronze[1])
		for rx in [u + 3.0, w - u - 6.0]:
			draw_rect(Rect2(rx, h * 0.5 - 3.0, 3.0, 6.0), bronze[1])
			draw_rect(Rect2(rx, h * 0.5 - 3.0, 3.0, 3.0), bronze[4])
		# dark trough
		var x := 4.0 * u
		var y := 3.0 * u
		var tw := w - 8.0 * u
		var th := h - 6.0 * u
		draw_rect(Rect2(x - 3.0, y - 3.0, tw + 6.0, th + 6.0), Color(0.03, 0.02, 0.06))
		draw_rect(Rect2(x, y, tw, th), Color(0.07, 0.05, 0.1))
		var f := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
		var fw := floorf(tw * f / u) * u
		if fw > 0.0:
			var rows: Array = [col.darkened(0.7), col.lightened(0.7), col.lightened(0.35), col, col.darkened(0.22), col.darkened(0.5)]
			var rh := th / float(rows.size())
			for i in rows.size():
				draw_rect(Rect2(x, y + floorf(float(i) * rh / u) * u, fw, ceilf(rh / u) * u), rows[i])
			var glint := fposmod(_t * 120.0, tw + 160.0) - 80.0
			var g0 := clampf(glint, 0.0, fw)
			var g1 := clampf(glint + 5.0 * u, 0.0, fw)
			if g1 > g0:
				draw_rect(Rect2(x + g0, y + u, g1 - g0, u), Color(1, 1, 1, 0.5))
			draw_rect(Rect2(x + fw - u, y + u, u, th - 2.0 * u), Color(1, 1, 1, 0.7))
		# glass streak across the top, even over the empty part
		draw_rect(Rect2(x + 2.0 * u, y + 2.0, tw - 4.0 * u, 2.0), Color(1, 1, 1, 0.14))
		PixelUI.text(self, Vector2(x + 8.0, y + th * 0.5 + 7.0), text, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)

# A section heading: a gold diamond, the title and a bronze rule running to the edge.
class Ornament extends Control:
	var text: String = ""

	func _init() -> void:
		custom_minimum_size = Vector2(0, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := floorf(size.y * 0.5)
		var d := Vector2(10.0, y)
		draw_colored_polygon(PackedVector2Array([d + Vector2(-9, 0), d + Vector2(0, -9), d + Vector2(9, 0), d + Vector2(0, 9)]), Color(0.08, 0.04, 0.03))
		draw_colored_polygon(PackedVector2Array([d + Vector2(-6, 0), d + Vector2(0, -6), d + Vector2(6, 0), d + Vector2(0, 6)]), Color(0.92, 0.78, 0.47))
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, 0), d + Vector2(6, 0), d + Vector2(0, 6)]), Color(0.68, 0.46, 0.2))
		PixelUI.text(self, Vector2(28.0, y + 7.0), text, 20, PixelUI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		var tw := PixelUI.ui_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelUI.mfs(20)).x
		var x0 := floorf(28.0 + tw + 14.0)
		var rw := size.x - x0
		if rw > 12.0:
			draw_rect(Rect2(x0, y - 4.0, rw, 8.0), Color(0.08, 0.04, 0.03))
			draw_rect(Rect2(x0 + 2.0, y - 2.0, rw - 4.0, 2.0), Color(0.92, 0.78, 0.47))
			draw_rect(Rect2(x0 + 2.0, y, rw - 4.0, 2.0), Color(0.5, 0.31, 0.14))
			draw_rect(Rect2(x0 + rw - 14.0, y - 4.0, 4.0, 8.0), Color(0.92, 0.78, 0.47))

var base: Base
var _title: Label
var _points: Label
var _info: VBoxContainer
var _stat_names: Array[Label] = []
var _stat_values: Array[Label] = []
var _stat_pts: Array[Label] = []
var _stat_buttons: Array[Button] = []
var _weapon_label: Label
var _weapon_note: Label
var _w_from: IconRect
var _w_to: IconRect
var _w_arrow: Label
var _weapon_button: Button
var _exchange_button: Button
var _reset_button: Button
var _reset_armed: bool = false
var _ex_price: Label
var _ex_points: Label
var _exchange_ok: bool = false
var _laser: CheckButton
var _close: Button
var _awaiting: bool = false
# Holding a "+" button keeps spending points, and doubles the amount every second (1, 2, 4 ... 32 per step).
const HOLD_DELAY := 0.35
const HOLD_STEP_TIME := 0.1
const HOLD_MAX_POWER := 5
var _held_idx: int = -1
var _held_time: float = 0.0
var _held_tick: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PixelUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := PixelUI.box(PixelUI.WIN_BG, PixelUI.BRONZE)
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	PixelUI.fit(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", PixelUI.mfs(36))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_title(_title)
	outer.add_child(_title)
	outer.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	outer.add_child(cols)

	# left: castle information, grouped into small sections (see refresh)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	cols.add_child(left)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 6)
	left.add_child(_info)

	# right: stat points
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(700, 0)
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	_points = Label.new()
	_points.add_theme_font_size_override("font_size", PixelUI.mfs(28))
	_points.add_theme_color_override("font_color", PixelUI.GOOD)
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var points_row := HBoxContainer.new()
	points_row.add_theme_constant_override("separation", 12)
	right.add_child(points_row)
	points_row.add_child(_points)
	_reset_button = Button.new()
	_reset_button.focus_mode = Control.FOCUS_NONE
	_reset_button.custom_minimum_size = Vector2(190, 36)
	_reset_button.text = Loc.t("Reset points")
	_reset_button.tooltip_text = Loc.t("Takes back all spent stat points so you can spend them again. Click twice to confirm.")
	_reset_button.pressed.connect(_on_reset_pressed)
	points_row.add_child(_reset_button)
	var note := Label.new()
	note.text = Loc.t("Hold + to spend faster") + "   |   " + Loc.t("Hover a name to see its default value")
	note.add_theme_font_size_override("font_size", PixelUI.mfs(16))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(680, 0)
	note.add_theme_color_override("font_color", PixelUI.DIM)
	right.add_child(note)

	var n := 1
	for s in STATS:
		var row_panel := PanelContainer.new()
		var rs := PixelUI._flat(Color(0.055, 0.04, 0.03, 0.85) if n % 2 == 1 else Color(0.075, 0.055, 0.04, 0.85), Color(0.3, 0.2, 0.09), 2)
		rs.set_content_margin_all(3)
		row_panel.add_theme_stylebox_override("panel", rs)
		right.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)
		var icon := IconRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.set_kind(str(s["icon"]))
		row.add_child(icon)
		var name_label := Label.new()
		name_label.text = "[%d]  %s" % [n, Loc.t(str(s["name"]))]
		name_label.add_theme_font_size_override("font_size", PixelUI.mfs(22))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(name_label)
		_stat_names.append(name_label)
		var val := Label.new()
		val.add_theme_font_size_override("font_size", PixelUI.mfs(24))
		val.add_theme_color_override("font_color", PixelUI.GOLD)
		val.add_theme_constant_override("outline_size", PixelUI.ol(4))
		val.custom_minimum_size = Vector2(130, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		_stat_values.append(val)
		var pl := Label.new()
		pl.add_theme_font_size_override("font_size", PixelUI.mfs(18))
		pl.add_theme_color_override("font_color", PixelUI.GOOD.darkened(0.15))
		pl.custom_minimum_size = Vector2(90, 0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pl)
		_stat_pts.append(pl)
		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(72, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.button_down.connect(_on_hold_start.bind(n - 1))
		btn.button_up.connect(_on_hold_end)
		row.add_child(btn)
		_stat_buttons.append(btn)
		n += 1

	# --- weapon upgrade: [current] > [next]  name, who can use it            [Upgrade  coin price] ---
	var up_head := Ornament.new()
	up_head.text = Loc.t("Weapon upgrade")
	right.add_child(up_head)
	var up_panel := PanelContainer.new()
	up_panel.add_theme_stylebox_override("panel", PixelUI.plate(Color(0.045, 0.032, 0.024, 0.9), PixelUI.BRONZE, 2))
	right.add_child(up_panel)
	var up := HBoxContainer.new()
	up.add_theme_constant_override("separation", 10)
	up_panel.add_child(up)
	_w_from = IconRect.new()
	_w_from.custom_minimum_size = Vector2(52, 52)
	_w_from.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	up.add_child(_w_from)
	_w_arrow = Label.new()
	_w_arrow.text = ">>"
	_w_arrow.add_theme_font_size_override("font_size", PixelUI.mfs(24))
	_w_arrow.add_theme_color_override("font_color", PixelUI.GOLD)
	_w_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	up.add_child(_w_arrow)
	_w_to = IconRect.new()
	_w_to.custom_minimum_size = Vector2(52, 52)
	_w_to.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	up.add_child(_w_to)
	var up_mid := VBoxContainer.new()
	up_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up_mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	up_mid.add_theme_constant_override("separation", 0)
	up.add_child(up_mid)
	_weapon_label = Label.new()
	_weapon_label.add_theme_font_size_override("font_size", PixelUI.mfs(20))
	_weapon_label.add_theme_color_override("font_color", PixelUI.CREAM)
	_weapon_label.add_theme_constant_override("outline_size", PixelUI.ol(4))
	up_mid.add_child(_weapon_label)
	var note_row := HBoxContainer.new()
	note_row.add_theme_constant_override("separation", 6)
	up_mid.add_child(note_row)
	var gi := IconRect.new()
	gi.custom_minimum_size = Vector2(22, 22)
	gi.set_kind("gunner")
	gi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note_row.add_child(gi)
	_weapon_note = Label.new()
	_weapon_note.add_theme_font_size_override("font_size", PixelUI.mfs(14))
	_weapon_note.add_theme_color_override("font_color", PixelUI.DIM)
	note_row.add_child(_weapon_note)
	_weapon_button = Button.new()
	_weapon_button.focus_mode = Control.FOCUS_NONE
	_weapon_button.custom_minimum_size = Vector2(190, 48)
	_weapon_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_weapon_button.pressed.connect(func() -> void: weapon_upgrade.emit())
	up.add_child(_weapon_button)

	# --- exchange: gold -> stat points ---
	var ex_head := Ornament.new()
	ex_head.text = Loc.t("Exchange")
	right.add_child(ex_head)
	var ex_panel := PanelContainer.new()
	ex_panel.add_theme_stylebox_override("panel", PixelUI.plate(Color(0.045, 0.032, 0.024, 0.9), PixelUI.BRONZE, 2))
	right.add_child(ex_panel)
	var ex := HBoxContainer.new()
	ex.add_theme_constant_override("separation", 8)
	ex_panel.add_child(ex)
	var coin := IconRect.new()
	coin.custom_minimum_size = Vector2(30, 30)
	coin.with_bg = false
	coin.kind = "coin"
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ex.add_child(coin)
	_ex_price = Label.new()
	_ex_price.add_theme_font_size_override("font_size", PixelUI.mfs(24))
	_ex_price.add_theme_color_override("font_color", PixelUI.GOLD)
	_ex_price.add_theme_constant_override("outline_size", PixelUI.ol(4))
	ex.add_child(_ex_price)
	var arrow := Label.new()
	arrow.text = ">>"
	arrow.add_theme_font_size_override("font_size", PixelUI.mfs(24))
	arrow.add_theme_color_override("font_color", PixelUI.GOLD)
	ex.add_child(arrow)
	var star := IconRect.new()
	star.custom_minimum_size = Vector2(30, 30)
	star.with_bg = false
	star.kind = "star"
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ex.add_child(star)
	_ex_points = Label.new()
	_ex_points.add_theme_font_size_override("font_size", PixelUI.mfs(24))
	_ex_points.add_theme_color_override("font_color", PixelUI.GOOD)
	_ex_points.add_theme_constant_override("outline_size", PixelUI.ol(4))
	ex.add_child(_ex_points)
	var ex_note := Label.new()
	ex_note.text = Loc.t("gold for stat points")
	ex_note.add_theme_font_size_override("font_size", PixelUI.mfs(14))
	ex_note.add_theme_color_override("font_color", PixelUI.DIM)
	ex_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ex_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ex.add_child(ex_note)
	_exchange_button = Button.new()
	_exchange_button.focus_mode = Control.FOCUS_NONE
	_exchange_button.custom_minimum_size = Vector2(190, 44)
	_exchange_button.text = "Exchange"
	_exchange_button.tooltip_text = Loc.t("Each exchange makes the next one 10% more expensive. Hold to buy faster.")
	_exchange_button.button_down.connect(_on_hold_start.bind(EXCHANGE_IDX))
	_exchange_button.button_up.connect(_on_hold_end)
	ex.add_child(_exchange_button)

	# --- laser sight toggle ---
	var lz := HBoxContainer.new()
	lz.add_theme_constant_override("separation", 8)
	right.add_child(lz)
	var lic := IconRect.new()
	lic.custom_minimum_size = Vector2(34, 34)
	lic.set_kind("sight")
	lic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lz.add_child(lic)
	_laser = CheckButton.new()
	_laser.text = Loc.t("Laser sight (aim line)")
	_laser.focus_mode = Control.FOCUS_NONE
	_laser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_laser.toggled.connect(func(on: bool) -> void: laser_toggled.emit(on))
	lz.add_child(_laser)

	outer.add_child(HSeparator.new())
	_close = Button.new()
	_close.focus_mode = Control.FOCUS_NONE
	_close.custom_minimum_size = Vector2(300, 50)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER    # only the button itself is clickable, not the whole row
	_close.pressed.connect(func() -> void: continue_pressed.emit())
	outer.add_child(_close)

func open(title: String, awaiting_start: bool) -> void:
	_awaiting = awaiting_start
	_title.text = title if title != "" else Loc.t("Castle")
	_close.text = Loc.t("Continue") if awaiting_start else Loc.t("Close")
	visible = true

func _on_hold_start(idx: int) -> void:
	_held_idx = idx
	_held_time = 0.0
	_held_tick = HOLD_DELAY
	if idx == EXCHANGE_IDX:
		exchange_pressed.emit(1)
	else:
		spend.emit(str(STATS[idx]["id"]), 1)

func _on_hold_end() -> void:
	if _held_idx == EXCHANGE_IDX:
		_exchange_button.text = Loc.t("Exchange")
	elif _held_idx >= 0:
		_stat_buttons[_held_idx].text = "MAX" if (str(STATS[_held_idx]["id"]) == "autorate" and base != null and base.auto_rate_maxed()) else "+"
	_held_idx = -1

func _hold_amount() -> int:
	return 1 << mini(int(_held_time), HOLD_MAX_POWER)

func _process(delta: float) -> void:
	if _held_idx < 0:
		return
	if not visible or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_hold_end()
		return
	_held_time += delta
	_held_tick -= delta
	var amount := _hold_amount()
	if _held_tick <= 0.0:
		_held_tick = HOLD_STEP_TIME
		if _held_idx == EXCHANGE_IDX:
			exchange_pressed.emit(amount)
		else:
			spend.emit(str(STATS[_held_idx]["id"]), amount)
	if _held_idx == EXCHANGE_IDX:
		if not _exchange_ok:
			_on_hold_end()
			return
		_exchange_button.text = "x%d" % amount if amount > 1 else Loc.t("Exchange")
		return
	if base != null and base.free_points <= 0:
		_on_hold_end()
		return
	_stat_buttons[_held_idx].text = "x%d" % amount if amount > 1 else "+"

# Two clicks (so a stray click cannot wipe the build): the first arms the button for 3 seconds.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = Loc.t("Click again to confirm")
		get_tree().create_timer(3.0, true).timeout.connect(_disarm_reset)
		return
	_disarm_reset()
	reset_pressed.emit()

func _disarm_reset() -> void:
	_reset_armed = false
	if _reset_button != null:
		_reset_button.text = Loc.t("Reset points")

func _heading(text: String) -> void:
	var o := Ornament.new()
	o.text = Loc.t(text)
	_info.add_child(o)

func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", PixelUI.mfs(17))
	l.add_theme_color_override("font_color", PixelUI.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(540, 0)
	_info.add_child(l)
	return l

func _bar(v: float, mx: float, col: Color, text: String) -> void:
	var sb := StatBar.new()
	sb.value = v
	sb.max_value = mx
	sb.col = col
	sb.text = text
	_info.add_child(sb)

# A big number with a small caption under it, on a small bronze plate.
func _tile(parent: Node, value: String, caption: String) -> void:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", PixelUI.plate(Color(0.045, 0.032, 0.024, 0.9), PixelUI.BRONZE, 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", PixelUI.mfs(26))
	v.add_theme_color_override("font_color", PixelUI.GOLD)
	v.add_theme_constant_override("outline_size", PixelUI.ol(4))
	box.add_child(v)
	var c := Label.new()
	c.text = Loc.t(caption)
	c.add_theme_font_size_override("font_size", PixelUI.mfs(14))
	c.add_theme_color_override("font_color", PixelUI.DIM)
	box.add_child(c)
	pc.add_child(box)
	parent.add_child(pc)

func _pill(parent: Node, icon: String, count: int, tip: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.tooltip_text = Loc.t(tip)
	var ic := IconRect.new()
	ic.custom_minimum_size = Vector2(36, 36)
	ic.set_kind(icon)
	h.add_child(ic)
	var l := Label.new()
	l.text = "%d" % count
	l.add_theme_font_size_override("font_size", PixelUI.mfs(24))
	l.add_theme_color_override("font_color", PixelUI.CREAM)
	l.add_theme_constant_override("outline_size", PixelUI.ol(4))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	parent.add_child(h)

# ctx: wave, region, difficulty, power (strings / numbers prepared by main)
func refresh(coins: int, ctx: Dictionary) -> void:
	if base == null:
		return
	var b := base
	for c in _info.get_children():
		_info.remove_child(c)
		c.queue_free()
	var w := b.weapon_tier
	var dmg := float(Weapons.DAMAGE[w]) * b.dmg_factor()
	var shots := b.attack_speed / float(Weapons.INTERVAL[w])

	# --- header: castle name, where you are, experience ---
	var name_l := Label.new()
	name_l.text = Loc.t(Base.TIER_NAMES[b.tier])
	name_l.add_theme_font_size_override("font_size", PixelUI.mfs(30))
	PixelUI.style_title(name_l)
	_info.add_child(name_l)
	_dim("%s %d   -   %s %d   -   %s   -   %s" % [Loc.t("Level"), b.xp_level, Loc.t("Wave"), int(ctx.get("wave", 1)), str(ctx.get("region", "")), str(ctx.get("difficulty", ""))])
	_bar(float(b.xp), float(Base.xp_needed(b.xp_level)), Color(0.75, 0.55, 0.2), "XP   %d / %d" % [b.xp, Base.xp_needed(b.xp_level)])

	# --- vitals ---
	_heading("Vitals")
	_bar(b.hp, b.max_hp, Color(0.8, 0.22, 0.18), "%s   %d / %d" % [Loc.t("Health"), ceili(b.hp), ceili(b.max_hp)])
	_bar(b.energy, b.max_energy, Color(0.22, 0.45, 0.9), "%s   %d / %d" % [Loc.t("Mana"), int(b.energy), int(b.max_energy)])
	_bar(maxf(b.shield, 0.0), maxf(b.shield_cap(), 1.0), Color(0.3, 0.85, 0.95), "%s   %d / %d" % [Loc.t("Energy Shield"), ceili(maxf(b.shield, 0.0)), ceili(b.shield_cap())])
	_dim("%s %.1f  (-%d%% %s)" % [Loc.t("Armor"), b.armor_points(), roundi((1.0 - Weapons.armor_mult(b.armor_points())) * 100.0), Loc.t("damage taken")])

	# --- weapon ---
	_heading("Weapon")
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 14)
	_info.add_child(wrow)
	var wic := IconRect.new()
	wic.custom_minimum_size = Vector2(60, 60)
	wic.set_kind(Weapons.id_of(w))
	wic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrow.add_child(wic)
	var wn := Label.new()
	wn.text = Loc.t(Weapons.name_of(w))
	wn.add_theme_font_size_override("font_size", PixelUI.mfs(26))
	wn.add_theme_color_override("font_color", PixelUI.CREAM)
	wn.add_theme_constant_override("outline_size", PixelUI.ol(4))
	wn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrow.add_child(wn)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	_info.add_child(tiles)
	_tile(tiles, "%.1f" % dmg, "Damage per shot")
	_tile(tiles, "%.1f" % shots, "Shots per second")
	_tile(tiles, "%d" % int(Weapons.ENERGY_COST[w]), "Mana per shot")
	_tile(tiles, Loc.t("True damage") if Weapons.is_true(float(Weapons.PEN[w])) else "%d" % int(Weapons.PEN[w]), "Armor penetration")

	# --- helpers and turrets ---
	_heading("Helpers")
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 10)
	_info.add_child(pills)
	_pill(pills, "gunner", b.gunners, "Gunners")
	_pill(pills, "scientist", b.scientists, "Scientists")
	_pill(pills, "engineer", b.engineers, "Engineers")
	_pill(pills, "mechanic", b.mechanics, "Mechanics")
	_dim("%s %d / %d   -   %s %d" % [Loc.t("Turrets"), b.auto_cannons, b.max_auto(), Loc.t("Range"), int(b.auto_range)])

	# --- the rest, small ---
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	_info.add_child(gold_row)
	var gc := IconRect.new()
	gc.custom_minimum_size = Vector2(28, 28)
	gc.with_bg = false
	gc.kind = "coin"
	gc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_row.add_child(gc)
	var gl := Label.new()
	gl.text = "%d" % coins
	gl.add_theme_font_size_override("font_size", PixelUI.mfs(24))
	gl.add_theme_color_override("font_color", PixelUI.GOLD)
	gl.add_theme_constant_override("outline_size", PixelUI.ol(4))
	gold_row.add_child(gl)
	_dim("%s %d   -   %s %d s / %d s   -   %s" % [Loc.t("Repair cost"), b.repair_cost(), Loc.t("Skills"), int(Base.BOOST_COOLDOWN), int(Base.REPAIR_COOLDOWN), str(ctx.get("stats", ""))])
	_dim("%s %d" % [Loc.t("Power"), int(ctx.get("power", 0))])

	_points.text = "%s: %d" % [Loc.t("Stat points"), b.free_points]
	var spent_total := 0
	for k in b.stat_pts.keys():
		spent_total += int(b.stat_pts[k])
	_reset_button.disabled = spent_total <= 0
	for i in STATS.size():
		var id := str(STATS[i]["id"])
		var pts := int(b.stat_pts.get(id, 0))
		var bv: String = ""
		match id:
			"damage":
				bv = "%.1f -> %.1f" % [float(Weapons.DAMAGE[w]), float(Weapons.DAMAGE[w]) * b.damage_mult]
			"attack":
				bv = "100%% -> %d%%" % roundi(b.attack_speed * 100.0)
			"regen":
				bv = "20.0 -> %.1f" % b.energy_regen
			"energy":
				bv = "100 -> %d" % int(b.max_energy)
			"health":
				bv = "%d -> %d" % [int(Base.TIER_HP[b.tier] + b.hp_bonus), ceili(b.hp_total())]
			"speed":
				bv = "%d -> %d" % [int(b.move_speed), int(b.move_speed * b.move_mult)]
			"armor":
				bv = "%.1f -> %.1f" % [3.0 * float(b.tier), b.armor_points()]
			"autorate":
				bv = "100%% -> %d%%" % roundi(b.auto_rate_factor() * 100.0)
			"eshield":
				bv = "%d -> %d" % [int(b.max_hp * Base.SHIELD_BASE), int(b.shield_cap())]
		var parts := bv.split(" -> ")
		_stat_names[i].tooltip_text = "%s: %s" % [Loc.t("Default"), parts[0]]
		_stat_values[i].text = parts[1]
		_stat_pts[i].text = "%d %s" % [pts, Loc.t("pts")]
		var maxed := id == "autorate" and b.auto_rate_maxed()
		_stat_buttons[i].disabled = b.free_points <= 0 or maxed
		if _held_idx != i:
			_stat_buttons[i].text = "MAX" if maxed else "+"

	_w_from.set_kind(Weapons.id_of(w))
	if w >= Weapons.MAX_TIER:
		_w_to.visible = false
		_w_arrow.visible = false
		_weapon_label.text = Loc.t("maximum weapon reached")
		_weapon_note.text = Loc.t("Gunners can only use up to the Gatling Gun")
		_weapon_button.text = "MAX"
		_weapon_button.icon = null
		_weapon_button.disabled = true
	else:
		_w_to.visible = true
		_w_arrow.visible = true
		_w_to.set_kind(Weapons.id_of(w + 1))
		var wprice := int(Weapons.UPGRADE_PRICE[w])
		_weapon_label.text = Loc.t(Weapons.name_of(w + 1))
		_weapon_note.text = Loc.t("Gunners use it too") if w + 1 <= Weapons.AUTO_MAX_TIER else Loc.t("Gunners stay with the Gatling Gun")
		_weapon_button.text = "%s  %d" % [Loc.t("Upgrade"), wprice]
		_weapon_button.icon = CoinTex.get_texture()
		_weapon_button.disabled = coins < wprice
	var price := int(ctx.get("exchange_price", EXCHANGE_GOLD))
	_ex_price.text = "%d" % price
	_ex_points.text = "+%d" % EXCHANGE_POINTS
	_exchange_ok = coins >= price
	_exchange_button.disabled = not _exchange_ok
	_laser.set_pressed_no_signal(b.laser)
