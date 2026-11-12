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

var base: Base
var _title: Label
var _points: Label
var _info: GridContainer
var _stat_values: Array[Label] = []
var _stat_defaults: Array[Label] = []
var _stat_pts: Array[Label] = []
var _stat_buttons: Array[Button] = []
var _weapon_label: Label
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
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 36)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_title)
	outer.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	outer.add_child(cols)

	# left: castle information
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(620, 0)
	cols.add_child(left)
	var lh := Label.new()
	lh.text = "Castle"
	lh.add_theme_font_size_override("font_size", 26)
	lh.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	left.add_child(lh)
	_info = GridContainer.new()
	_info.columns = 2
	_info.add_theme_constant_override("h_separation", 24)
	_info.add_theme_constant_override("v_separation", 4)
	left.add_child(_info)

	# right: stat points
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(700, 0)
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	_points = Label.new()
	_points.add_theme_font_size_override("font_size", 28)
	_points.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
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
	note.text = Loc.t("Default -> current value, and points spent") + "   |   " + Loc.t("Hold + to spend faster")
	note.add_theme_font_size_override("font_size", 16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(680, 0)
	note.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	right.add_child(note)

	var n := 1
	for s in STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		right.add_child(row)
		var icon := IconRect.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.set_kind(str(s["icon"]))
		row.add_child(icon)
		var name_label := Label.new()
		name_label.text = "[%d]  %s" % [n, Loc.t(str(s["name"]))]
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var dl := Label.new()          # the default value, in grey
		dl.add_theme_font_size_override("font_size", 22)
		dl.add_theme_color_override("font_color", Color(0.55, 0.57, 0.62))
		dl.custom_minimum_size = Vector2(90, 0)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(dl)
		_stat_defaults.append(dl)
		var val := Label.new()
		val.add_theme_font_size_override("font_size", 22)
		val.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		val.custom_minimum_size = Vector2(110, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		_stat_values.append(val)
		var pl := Label.new()
		pl.add_theme_font_size_override("font_size", 20)
		pl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		pl.custom_minimum_size = Vector2(80, 0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pl)
		_stat_pts.append(pl)
		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(56, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.button_down.connect(_on_hold_start.bind(n - 1))
		btn.button_up.connect(_on_hold_end)
		row.add_child(btn)
		_stat_buttons.append(btn)
		n += 1

	right.add_child(HSeparator.new())
	_weapon_label = Label.new()
	_weapon_label.add_theme_font_size_override("font_size", 20)
	_weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_label.custom_minimum_size = Vector2(560, 0)
	right.add_child(_weapon_label)
	_weapon_button = Button.new()
	_weapon_button.focus_mode = Control.FOCUS_NONE
	_weapon_button.custom_minimum_size = Vector2(0, 44)
	_weapon_button.pressed.connect(func() -> void: weapon_upgrade.emit())
	right.add_child(_weapon_button)
	right.add_child(HSeparator.new())
	# compact exchange row:  [coin] price  ->  [star] +5            [Exchange]  (hold to buy faster)
	var ex := HBoxContainer.new()
	ex.add_theme_constant_override("separation", 8)
	right.add_child(ex)
	var coin := IconRect.new()
	coin.custom_minimum_size = Vector2(30, 30)
	coin.with_bg = false
	coin.kind = "coin"
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ex.add_child(coin)
	_ex_price = Label.new()
	_ex_price.add_theme_font_size_override("font_size", 22)
	_ex_price.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	ex.add_child(_ex_price)
	var arrow := Label.new()
	arrow.text = "->"
	arrow.add_theme_font_size_override("font_size", 22)
	ex.add_child(arrow)
	var star := IconRect.new()
	star.custom_minimum_size = Vector2(30, 30)
	star.with_bg = false
	star.kind = "star"
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ex.add_child(star)
	_ex_points = Label.new()
	_ex_points.add_theme_font_size_override("font_size", 22)
	_ex_points.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	ex.add_child(_ex_points)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ex.add_child(spacer)
	_exchange_button = Button.new()
	_exchange_button.focus_mode = Control.FOCUS_NONE
	_exchange_button.custom_minimum_size = Vector2(140, 36)
	_exchange_button.text = "Exchange"
	_exchange_button.tooltip_text = Loc.t("Each exchange makes the next one 10% more expensive. Hold to buy faster.")
	_exchange_button.button_down.connect(_on_hold_start.bind(EXCHANGE_IDX))
	_exchange_button.button_up.connect(_on_hold_end)
	ex.add_child(_exchange_button)
	_laser = CheckButton.new()
	_laser.text = "Laser sight (aim line)"
	_laser.focus_mode = Control.FOCUS_NONE
	_laser.toggled.connect(func(on: bool) -> void: laser_toggled.emit(on))
	right.add_child(_laser)

	outer.add_child(HSeparator.new())
	_close = Button.new()
	_close.focus_mode = Control.FOCUS_NONE
	_close.custom_minimum_size = Vector2(0, 46)
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
		_stat_buttons[_held_idx].text = "+"
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

func _row(label: String, value: String) -> void:
	var a := Label.new()
	a.text = Loc.t(label)
	a.add_theme_font_size_override("font_size", 19)
	a.add_theme_color_override("font_color", Color(0.72, 0.76, 0.85))
	a.custom_minimum_size = Vector2(200, 0)
	_info.add_child(a)
	var b := Label.new()
	b.text = value
	b.add_theme_font_size_override("font_size", 19)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(390, 0)
	_info.add_child(b)

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
	_row("Castle stage", Loc.t(Base.TIER_NAMES[b.tier]))
	_row("Level", "%d" % b.xp_level)
	_row("XP", "%d / %d" % [b.xp, Base.xp_needed(b.xp_level)])
	_row("Health", "%d / %d" % [ceili(b.hp), ceili(b.max_hp)])
	_row("Mana", "%d / %d" % [int(b.energy), int(b.max_energy)])
	_row("Mana regen", "%.1f / s" % b.energy_regen)
	_row("Weapon", Loc.t(Weapons.name_of(w)))
	_row("Damage per shot", "%.1f" % dmg)
	_row("Armor penetration", Loc.t("True damage") if Weapons.is_true(float(Weapons.PEN[w])) else "%d" % int(Weapons.PEN[w]))
	_row("Armor", "%.1f  (-%d%% damage taken)" % [b.armor_points(), roundi((1.0 - Weapons.armor_mult(b.armor_points())) * 100.0)])
	_row("Energy Shield", "%d / %d" % [ceili(maxf(b.shield, 0.0)), ceili(b.shield_cap())])
	_row("Shots per second", "%.1f" % shots)
	_row("Mana per shot", "%d" % int(Weapons.ENERGY_COST[w]))
	_row("Move speed", "%d" % int(b.move_speed * b.move_mult))
	_row("Auto-weapons", "%d  (%.1f s, %d)" % [b.auto_cannons, b.auto_interval / maxf(float(b.auto_cannons), 1.0), int(b.auto_range)])
	_row("Helpers", "%s %d   %s %d   %s %d   %s %d" % [Loc.t("Gunners"), b.gunners, Loc.t("Scientists"), b.scientists, Loc.t("Engineers"), b.engineers, Loc.t("Mechanics"), b.mechanics])
	_row("Skills", "%s %.0f s   %s %.0f s" % [Loc.t("Overcharge"), Base.BOOST_COOLDOWN, Loc.t("Repair"), Base.REPAIR_COOLDOWN])
	_row("Repair cost", "%d" % b.repair_cost())
	_row("Gold", "%d" % coins)
	_row("Wave", "%d  -  %s" % [int(ctx.get("wave", 1)), str(ctx.get("region", ""))])
	_row("Statistics", str(ctx.get("stats", "")))
	_row("Difficulty", str(ctx.get("difficulty", "")))
	_row("Power", "%d" % int(ctx.get("power", 0)))

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
		_stat_defaults[i].text = parts[0]
		_stat_values[i].text = "-> " + parts[1]
		_stat_pts[i].text = "%d %s" % [pts, Loc.t("pts")]
		_stat_buttons[i].disabled = b.free_points <= 0

	if w >= Weapons.MAX_TIER:
		_weapon_label.text = "%s - %s" % [Loc.t(Weapons.name_of(w)), Loc.t("maximum weapon reached")]
		_weapon_button.text = "MAX"
		_weapon_button.icon = null
		_weapon_button.disabled = true
	else:
		var price := int(Weapons.UPGRADE_PRICE[w])
		_weapon_label.text = Loc.t("%s -> %s\nAuto-weapons are upgraded too") % [Loc.t(Weapons.name_of(w)), Loc.t(Weapons.name_of(w + 1))]
		_weapon_button.text = "%s   %d" % [Loc.t("Upgrade weapon"), price]
		_weapon_button.icon = CoinTex.get_texture()
		_weapon_button.disabled = coins < price
	var price := int(ctx.get("exchange_price", EXCHANGE_GOLD))
	_ex_price.text = "%d" % price
	_ex_points.text = "+%d" % EXCHANGE_POINTS
	_exchange_ok = coins >= price
	_exchange_button.disabled = not _exchange_ok
	_laser.set_pressed_no_signal(b.laser)
