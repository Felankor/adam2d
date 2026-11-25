class_name LevelUpMenu
extends Control

# Shown on every level-up: three buffs to pick from (keys 1, 2, 3 or a click). The game stays paused meanwhile.
signal picked(stat: String, pts: int)
signal reroll_requested

const REROLL_BASE := 100          # gold, plus REROLL_PER_LEVEL per castle level
const REROLL_PER_LEVEL := 12
const REROLL_GROWTH := 1.5        # every reroll of the same pick costs this much more than the last

var coins: int = 0                # set by the game, so the button knows what you can afford
var _base: Base
var _rerolls: int = 0
var _reroll_btn: Button

var _offers: Array = []
var _sub: Label
var _panels: Array[PanelContainer] = []
var _icons: Array[IconRect] = []
var _names: Array[Label] = []
var _vals: Array[Label] = []
var _rars: Array[Label] = []
var _btns: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PixelUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := PixelUI.box(Color(0.07, 0.05, 0.04, 0.97), PixelUI.BRONZE)
	sb.set_content_margin_all(44)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	PixelUI.fit(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.add_child(PixelTitle.make("Level up!  Choose a buff", 38, PixelUI.GOLD))
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", PixelUI.mfs(22))
	_sub.add_theme_color_override("font_color", PixelUI.DIM)
	box.add_child(_sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for i in 3:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(300, 0)
		row.add_child(card)
		_panels.append(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		var pad := MarginContainer.new()
		for side in ["left", "right"]:
			pad.add_theme_constant_override("margin_" + side, 18)
		pad.add_theme_constant_override("margin_top", 14)
		pad.add_theme_constant_override("margin_bottom", 18)
		card.add_child(pad)
		pad.add_child(v)
		var rar := Label.new()
		rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rar.add_theme_font_size_override("font_size", PixelUI.mfs(20))
		v.add_child(rar)
		_rars.append(rar)
		var ic := IconRect.new()
		ic.custom_minimum_size = Vector2(72, 72)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		_icons.append(ic)
		var nm := Label.new()
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", PixelUI.mfs(24))
		nm.custom_minimum_size = Vector2(0, 40)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(nm)
		_names.append(nm)
		var val := Label.new()
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", PixelUI.mfs(34))
		val.add_theme_color_override("font_color", PixelUI.GOOD)
		val.add_theme_constant_override("outline_size", PixelUI.ol(4))
		val.custom_minimum_size = Vector2(0, 46)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(val)
		_vals.append(val)
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(240, 56)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", PixelUI.mfs(26))
		btn.pressed.connect(choose.bind(i))
		v.add_child(btn)
		_btns.append(btn)
	_reroll_btn = Button.new()
	_reroll_btn.focus_mode = Control.FOCUS_NONE
	_reroll_btn.custom_minimum_size = Vector2(420, 52)
	_reroll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_btn.add_theme_font_size_override("font_size", PixelUI.mfs(24))
	_reroll_btn.pressed.connect(request_reroll)
	box.add_child(_reroll_btn)

func reroll_cost() -> int:
	if _base != null and _base.cls == "standard" and _rerolls == 0:
		return 0                                  # Standard is the adaptable castle: one free reroll on every level-up
	var lvl := _base.xp_level if _base != null else 1
	return int(round(float(REROLL_BASE + REROLL_PER_LEVEL * lvl) * pow(REROLL_GROWTH, _rerolls)))

func request_reroll() -> void:
	if visible and coins >= reroll_cost():
		reroll_requested.emit()

# Called by the game once the gold is paid: three fresh cards for the same pick.
func reroll() -> void:
	_rerolls += 1
	Sfx.play("click")
	_show(_base)

func refresh_button() -> void:
	var cost := reroll_cost()
	_reroll_btn.text = ("[R]  %s  -  %s" % [Loc.t("Reroll"), Loc.t("Free")]) if cost <= 0 else ("[R]  %s  -  %d %s" % [Loc.t("Reroll"), cost, Loc.t("gold")])
	_reroll_btn.disabled = coins < cost

func open(b: Base) -> void:
	_rerolls = 0
	_show(b)

func _show(b: Base) -> void:
	_base = b
	_offers = Buffs.offer(b)
	_sub.text = "%s %d   -   %s: %d" % [Loc.t("Level"), b.xp_level, Loc.t("Picks left"), b.picks]
	for i in 3:
		var shown := i < _offers.size()
		_panels[i].visible = shown
		if not shown:
			continue
		var o: Dictionary = _offers[i]
		var col: Color = Buffs.RARITY_COL[int(o["rar"])]
		_panels[i].add_theme_stylebox_override("panel", PixelUI.plate(Color(0.05, 0.04, 0.035, 0.95), col, 2))
		_rars[i].text = Loc.t(str(Buffs.RARITY[int(o["rar"])]))
		_rars[i].add_theme_color_override("font_color", col)
		_icons[i].set_kind(Buffs.icon_of(str(o["stat"])))
		_names[i].text = Loc.t(Buffs.name_of(str(o["stat"])))
		_vals[i].text = Buffs.amount_text(o)
		_btns[i].text = "[%d]  %s" % [i + 1, Loc.t("Choose")]
	# One shared font size per row, so the three cards line up (the longest text decides).
	var ns := PixelUI.mfs(24)
	var vs := PixelUI.mfs(34)
	for i in mini(_offers.size(), 3):
		ns = mini(ns, TextFit.best_size(_names[i].get_theme_font("font"), _names[i].text, PixelUI.mfs(24), 270.0))
		vs = mini(vs, TextFit.best_size(_vals[i].get_theme_font("font"), _vals[i].text, PixelUI.mfs(34), 270.0))
	for i in 3:
		_names[i].add_theme_font_size_override("font_size", ns)
		_vals[i].add_theme_font_size_override("font_size", vs)
	refresh_button()
	visible = true

func choose(i: int) -> void:
	if not visible or i < 0 or i >= _offers.size():
		return
	Sfx.play("click")
	var o: Dictionary = _offers[i]
	picked.emit(str(o["stat"]), int(o["pts"]))
