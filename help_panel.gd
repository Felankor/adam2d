class_name HelpPanel
extends VBoxContainer

# "How to play" page of the Esc menu, with drawings and icons. Rebuilt every time it opens so
# the key names, prices and numbers always match the player's current settings and the game's
# real values. All text goes through Loc.t() (English is the key, see loc.gd).
signal back_pressed

const GOLD := Color(1.0, 0.85, 0.4)
const KEY_COL := Color(1.0, 0.9, 0.5)
const DIM := Color(0.82, 0.76, 0.66)

var _content: VBoxContainer

# ---------- small drawn helpers ----------

# A horizontal bar (used for the "damage against a Tank" comparison).
class BarCtl extends Control:
	var frac: float = 1.0
	var col: Color = Color.WHITE
	func _init() -> void:
		custom_minimum_size = Vector2(330, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.08, 0.06))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(frac, 0.0, 1.0), size.y)), col)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.25), false, 1.0)

# A numbered circle that ties a legend line to a spot on the screen drawing.
class Badge extends Control:
	var n: int = 1
	func _init() -> void:
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 13.0, Color(1.0, 0.85, 0.3))
		draw_arc(c, 13.0, 0.0, TAU, 24, Color(0.2, 0.15, 0.0), 2.0)
		var font := ThemeDB.fallback_font
		draw_string(font, c + Vector2(-20, 7), str(n), HORIZONTAL_ALIGNMENT_CENTER, 40, PixelUI.fs(19), Color(0.15, 0.1, 0.0))

# A small picture of the game screen: every part of the HUD with a number.
class HudDiagram extends Control:
	const K := 780.0 / 1920.0
	func _init() -> void:
		custom_minimum_size = Vector2(780, 439)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _p(x: float, y: float) -> Vector2:
		return Vector2(x, y) * K
	func _badge(pos: Vector2, n: int) -> void:
		draw_circle(pos, 11.0, Color(1.0, 0.85, 0.3))
		draw_arc(pos, 11.0, 0.0, TAU, 20, Color(0.2, 0.15, 0.0), 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-20, 6), str(n), HORIZONTAL_ALIGNMENT_CENTER, 40, PixelUI.fs(16), Color(0.15, 0.1, 0.0))
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.18, 0.28, 0.2))
		for i in 12:                                     # a little grass texture
			draw_circle(Vector2(fmod(float(i) * 97.0, w), fmod(float(i) * 53.0 + 40.0, h)), 22.0, Color(0.2, 0.32, 0.22, 0.6))
		# castle in the middle, aiming at the mouse cursor
		var castle := _p(960, 500)
		var cross := _p(1290, 300)
		draw_circle(castle, 24.0, Color(0.42, 0.44, 0.52))
		draw_circle(castle, 24.0, Color(1, 1, 1, 0.3), false, 2.0)
		draw_line(castle, castle + (cross - castle).normalized() * 40.0, Color(0.2, 0.2, 0.25), 6.0)
		draw_line(castle + (cross - castle).normalized() * 40.0, cross, Color(1.0, 0.3, 0.3, 0.35), 1.5)
		draw_arc(cross, 9.0, 0.0, TAU, 16, Color(1.0, 0.4, 0.3), 2.0)
		draw_line(cross - Vector2(14, 0), cross + Vector2(14, 0), Color(1.0, 0.4, 0.3), 2.0)
		draw_line(cross - Vector2(0, 14), cross + Vector2(0, 14), Color(1.0, 0.4, 0.3), 2.0)
		for q in [_p(520, 330), _p(560, 760), _p(1360, 760), _p(1500, 560)]:
			draw_circle(q, 6.0, Color(0.9, 0.2, 0.2))
		draw_circle(_p(1420, 180), 12.0, Color(0.7, 0.3, 0.95))
		draw_circle(_p(380, 560), 5.0, Color(0.3, 0.9, 0.4))
		# [1] wave / region information, top left
		draw_rect(Rect2(_p(20, 16), Vector2(300, 52) * K), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(_p(30, 28), Vector2(220, 8) * K), Color(1, 1, 1, 0.7))
		draw_rect(Rect2(_p(30, 46), Vector2(160, 8) * K), Color(1, 1, 1, 0.45))
		_badge(_p(330, 30), 1)
		# [2] helpers (left)
		for i in 4:
			Icons.draw(self, ["gunner", "scientist", "engineer", "mechanic"][i], _p(28 + 130 * i, 108), 44.0 * K / 64.0, true)
		_badge(_p(28 + 130 * 3 + 70, 120), 2)
		# [3] gold and FPS, top right
		draw_texture_rect(CoinTex.get_texture(), Rect2(_p(1690, 44), Vector2(42, 42) * K), false)
		draw_rect(Rect2(_p(1750, 52), Vector2(110, 22) * K), Color(1.0, 0.9, 0.3, 0.8))
		draw_rect(Rect2(_p(1600, 14), Vector2(260, 12) * K), Color(0.5, 1.0, 0.5, 0.6))
		_badge(_p(1670, 70), 3)
		# [4] minimap, bottom right
		var mc := _p(1775, 935)
		var mr := 115.0 * K
		draw_circle(mc, mr, Color(0.05, 0.07, 0.1, 0.8))
		draw_arc(mc, mr, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
		draw_circle(mc, 4.0, Color(1.0, 0.6, 0.15))
		draw_circle(mc + Vector2(20, -14), 3.0, Color(0.95, 0.2, 0.2))
		draw_circle(mc + Vector2(-24, 10), 3.0, Color(0.95, 0.2, 0.2))
		draw_circle(mc + Vector2(8, 28), 5.0, Color(0.7, 0.3, 0.95))
		draw_circle(mc + Vector2(-8, -26), 3.0, Color(0.3, 0.9, 0.4))
		_badge(mc + Vector2(-mr - 8.0, -mr + 8.0), 4)
		# [9] unspent stat points tag, [5] health and mana, [6] weapon, [7] skills, [8] XP
		draw_rect(Rect2(_p(728, 858), Vector2(330, 38) * K), Color(0.2, 0.85, 0.35, 0.35))
		draw_rect(Rect2(_p(740, 872), Vector2(220, 8) * K), Color(0.6, 1.0, 0.7, 0.9))
		_badge(_p(1075, 877), 9)
		draw_rect(Rect2(_p(740, 920), Vector2(440, 26) * K), Color(0.86, 0.1, 0.14))
		draw_rect(Rect2(_p(740, 954), Vector2(440, 26) * K), Color(0.16, 0.42, 0.95))
		_badge(_p(1195, 945), 5)
		Icons.draw(self, "void", _p(658, 920), 62.0 * K / 64.0, true)
		_badge(_p(645, 925), 6)
		var sx := (1920.0 - (64.0 * 4.0 + 10.0 * 3.0)) * 0.5
		for i in 4:
			var sr := Rect2(_p(sx + float(i) * 74.0, 988), Vector2(64, 64) * K)
			draw_rect(sr, Color(0.08, 0.09, 0.13, 0.9))
			if i < 3:
				Icons.draw(self, ["shield", "damage", "repair"][i], sr.position, sr.size.x / 64.0, false)
			draw_rect(sr, Color(1, 1, 1, 0.3), false, 1.0)
		_badge(_p(sx - 28.0, 1020), 7)
		draw_rect(Rect2(0, h - 7.0, w, 7.0), Color(0.9, 0.62, 0.08))
		draw_rect(Rect2(0, h - 7.0, w * 0.55, 3.0), Color(1.0, 0.85, 0.3))
		_badge(Vector2(w * 0.55 + 4.0, h - 20.0), 8)
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.4), false, 2.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", PixelUI.fs(40))
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(380, 52)
	back.add_theme_font_size_override("font_size", PixelUI.fs(22))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)

func refresh() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	# ---------------- goal and quick start ----------------
	_heading("Goal")
	_text(Loc.t("Defend your castle. Enemies walk in one by one - shoot them to earn gold and XP. Clear every wave to grow from a Village into an Eye of End. Every 10th wave is a boss wave."))

	_heading("Quick start")
	_step_row("sight", Loc.t("1. Aim with the mouse, hold the left button to fire. Every shot costs mana."))
	_step_row("coin", Loc.t("2. Kills give gold and XP. Don't shoot refugees - they become your helpers."))
	_step_row("star", Loc.t("3. Each new XP level gives 5 stat points. Open the Castle window and spend them."))
	_step_row("laser", Loc.t("4. Spend gold on better weapons (Castle window) and use your skills at the right moment."))

	# ---------------- the screen ----------------
	_heading("The screen")
	var diagram := HudDiagram.new()
	diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(diagram)
	_legend(1, Loc.t("Wave and region. Press %s for more details.") % Keybinds.key_text("toggle_info"))
	_legend(2, Loc.t("Your helpers (gunners, scientists, engineers, mechanics) and how many you have."))
	_legend(3, Loc.t("Gold, and the FPS counter with the 1% low."))
	_legend(4, Loc.t("Minimap: you are orange, enemies red, bosses purple, refugees green."))
	_legend(5, Loc.t("Health (red, left) and Mana (blue, right) on the bronze bar, with your level in the middle. The ice-blue layer on top of the health tube is the Energy Shield."))
	_legend(6, Loc.t("Your current weapon."))
	_legend(7, Loc.t("Skills: Overcharge, Repair."))
	_legend(8, Loc.t("XP bar. When it fills you gain a level."))
	_legend(9, Loc.t("Blinks when you have unspent stat points."))

	# ---------------- controls ----------------
	_heading("Controls")
	_key_row("Aim", [Loc.t("Mouse")], "sight")
	_key_row("Fire (hold)", [Loc.t("Left mouse button")], "mouse")
	_key_row("Move the castle", [Keybinds.key_text("move_up"), Keybinds.key_text("move_left"), Keybinds.key_text("move_down"), Keybinds.key_text("move_right")])
	_key_row("Zoom in / out", [Loc.t("Mouse wheel")], "wheel")
	_key_row("Pause game", [Keybinds.key_text("pause_game")])
	_key_row("Castle window", [Keybinds.key_text("open_shop")])
	_key_row("Show details", [Keybinds.key_text("toggle_info")])
	_key_row("Skill slot 1", [Keybinds.key_text("skill_1")])
	_key_row("Skill slot 2 (Overcharge)", [Keybinds.key_text("skill_2")], "damage")
	_key_row("Skill slot 3 (Repair: costs gold)", [Keybinds.key_text("skill_3")], "repair")
	_key_row("Skill slot 4", [Keybinds.key_text("skill_4")])
	_key_row("Pause menu / go back", ["Esc"])
	_key_row("Spend a stat point", [Loc.t("Number keys 1-9 or click")])
	_text(Loc.t("You can change these keys in Settings > Controls."))

	# ---------------- weapons ----------------
	_heading("Mana and weapons")
	_text(Loc.t("Every shot costs mana, and mana refills over time. Upgrade your weapon in the Castle window - auto-weapons use the same weapon. Each upgrade has a price in gold:"))
	var ids := ["mg", "cannon", "rocket", "laser", "void"]
	var notes := [
		Loc.t("Very fast, cheap, but weak: useless against armor."),
		Loc.t("Solid all-round shell."),
		Loc.t("Explodes: damages everything around the target."),
		Loc.t("Instant beam that pierces every mob on its line."),
		Loc.t("Dark orb with a huge blast. TRUE DAMAGE: ignores armor and shields."),
	]
	for i in ids.size():
		var price_text := Loc.t("Start") if i == 0 else "%d" % int(Weapons.UPGRADE_PRICE[i - 1])
		_weapon_row(str(ids[i]), Loc.t(Weapons.name_of(i)), price_text, str(notes[i]))
	_text(Loc.t("When you switch to a new weapon, the points you spent on Weapon damage are given back so you can spend them again."))

	_heading("Armor")
	_text(Loc.t("Armor takes a part of every hit. Armor penetration cancels armor. Tanks, golems and bosses are heavily armored, so pick weapons that penetrate. Damage dealt to a Tank (armor 40):"))
	var bar_cols := [Color(0.9, 0.8, 0.3), Color(0.95, 0.6, 0.2), Color(0.95, 0.4, 0.25), Color(0.3, 0.9, 1.0), Color(0.65, 0.25, 1.0)]
	for i in ids.size():
		var m := Weapons.armor_mult(40.0, float(Weapons.PEN[i]))
		_bar_row(str(ids[i]), Loc.t(Weapons.name_of(i)), m, bar_cols[i], "%d%%" % roundi(m * 100.0))
	_text(Loc.t("Your castle has armor too (it grows with the castle stage and the Armor stat). Enemy shells and beams have their own penetration."))

	_icon_row("eshield", Loc.t("Energy Shield: a cyan barrier that soaks damage (after armor) before your health, from physical and energy weapons alike. It recharges when you have not been hit for a few seconds. Void Gun shots are TRUE DAMAGE: they ignore both armor and the Energy Shield. Spend points on the Energy Shield stat to make it bigger."), 40)

	_heading("Critical hits")
	_icon_row("damage", Loc.t("A single hit that removes more than 25% of a target's max health is a CRITICAL HIT: a bigger number, a burst effect, and its health bar shatters. It works on you too - watch your own bar!"), 40)

	# ---------------- leveling ----------------
	_heading("Leveling")
	_text(Loc.t("Every kill gives XP (bosses and Rogue Castles give a lot). Each new level gives you 5 stat points. Open the Castle window and spend them: every point adds +1% to the CURRENT value of a stat, so points build on each other."))
	var stat_ids := [["damage", "Weapon damage"], ["atkspeed", "Attack speed"], ["regen", "Mana regen"], ["energy", "Max mana"], ["walls", "Max health"], ["speed", "Move speed"], ["autorate", "Auto fire rate"], ["shield", "Armor"], ["eshield", "Energy Shield"]]
	for s in stat_ids:
		_icon_row(str(s[0]), Loc.t(str(s[1])), 36)
	_text(Loc.t("Wrong click? The Reset points button (click twice) gives every spent point back."))
	_text(Loc.t("Tip: hold the left mouse button on a + to spend points faster. The amount doubles every second (1, 2, 4, 8, 16, 32)."))
	_icon_row("coin", Loc.t("Exchange: trade gold for stat points in the Castle window - %d gold for %d points to start, and every purchase makes the next one 10%% more expensive. Hold the button to buy faster.") % [CastleMenu.EXCHANGE_GOLD, CastleMenu.EXCHANGE_POINTS], 40)

	# ---------------- skills ----------------
	_heading("Skills")
	_skill_row("damage", Loc.t("Overcharge"), Loc.t("Weapon damage +30%% for %d s. Cooldown %d s.") % [int(Base.BOOST_DURATION), int(Base.BOOST_COOLDOWN)])
	_skill_row("repair", Loc.t("Repair"), Loc.t("Costs gold, heals 50% of your max health. 1 s cooldown."))

	# ---------------- refugees ----------------
	_heading("Refugees")
	_enemy_row(["ally"], Loc.t("Refugees (red clothes, white flag) are innocent - don't shoot them! Let one reach your castle and it becomes a helper. They stop coming in the Space biome:"))
	_ally_row("gunner", Loc.t("Builds an extra auto-weapon"))
	_ally_row("scientist", Loc.t("Weapon damage +15%"))
	_ally_row("engineer", Loc.t("Mana regen +5 per second"))
	_ally_row("mechanic", Loc.t("Slowly repairs the castle"))

	# ---------------- enemies ----------------
	_heading("Enemies")
	_enemy_row(["soldier"], Loc.t("Soldier: the standard foe. No armor."))
	_enemy_row(["tank"], Loc.t("Tank (armor 40): slow; stops at a distance and shells your castle. Shoot the shells down."))
	_enemy_row(["heavytank"], Loc.t("Heavy Tank (from wave 8): a grey Tank that is 30% bigger, stronger and more armored, with a double barrel."))
	_enemy_row(["apoctank"], Loc.t("Apocalypse Tank (from wave 14): darker and bigger still, with 50% more health than a Heavy Tank and a launcher that fires guided anti-air missiles. Shoot the missiles down!"))
	_enemy_row(["mech"], Loc.t("Mechanized vehicle: very fast, dodges shots, and explodes into 3 soldiers."))
	_enemy_row(["medic"], Loc.t("Medic (from wave 6): heals the enemies around it. Kill it first!"))
	_enemy_row(["aegis"], Loc.t("Aegis (from wave 9): an energy shield soaks damage first and recharges if you stop hitting it. Burst it down."))

	_heading("Biome enemies")
	_enemy_row(["worm"], Loc.t("Mudland - Bloodworm: tiny and very fast, with double the health it used to have. They come in swarms."))
	_enemy_row(["golem"], Loc.t("Rocky Mountain - Golem (armor 30): throws rocks from far away and slams the ground to summon 3 Earthworms under your castle. When it is destroyed it leaves two smaller golems behind."))
	_enemy_row(["earthworm"], Loc.t("Earthworm: the grey cousin of the Bloodworm with half its health. Golems summon them under your castle."))
	_enemy_row(["demon"], Loc.t("Hell - Demon (armor 20): throws fireballs that burst the moment they land, and spawns 5 Sinners. Kill every Sinner and it spawns 5 more at once!"))
	_enemy_row(["sinner"], Loc.t("Sinner: a black, unarmed zombie that shambles toward your castle. Demons keep spawning them."))
	_enemy_row(["hunter"], Loc.t("Space - Hunter: arrives in a pack of 5. Dodges again and again and shoots from twice as far as a tank."))
	_enemy_row(["soldier", "tank", "mech"], Loc.t("In the Space biome soldiers become kamikaze drones, tanks become starships and mechanized vehicles become space corvettes. They are faster and dodge shots."), true)

	_heading("Bosses and Rogue Castles")
	_icon_row("skull", Loc.t("Each biome ends with a boss: heavily armored, with a huge amount of health. It moves, dodges and summons soldiers. Shoot down its energy orbs. If the Void Overlord charges its beam, keep moving: it is TRUE DAMAGE and ignores armor and shield!"), 40)
	_icon_row("skull", Loc.t("Rogue Castles are rival castles that fly in and fight with your kind of weapon. They are much tougher than normal mobs and give a lot of XP and gold. They start around level 5-6, show up a little later in each wave, and never join boss waves."), 40)

# ---------- building blocks ----------

func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", PixelUI.fs(26))
	l.add_theme_color_override("font_color", GOLD)
	_content.add_child(HSeparator.new())
	_content.add_child(l)

func _text(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", PixelUI.fs(19))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(780, 0)
	_content.add_child(l)

func _wrap_label(text: String, font_px: int, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", PixelUI.fs(font_px))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_content.add_child(row)
	return row

func _icon(row: Control, kind: String, px: float) -> void:
	var ic := IconRect.new()
	ic.custom_minimum_size = Vector2(px, px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.kind = kind
	row.add_child(ic)

func _icon_row(icon: String, text: String, px: float) -> void:
	var row := _row()
	_icon(row, icon, px)
	row.add_child(_wrap_label(text, 19, 710))

func _step_row(icon: String, text: String) -> void:
	var row := _row()
	_icon(row, icon, 44.0)
	row.add_child(_wrap_label(text, 20, 700))

func _legend(n: int, text: String) -> void:
	var row := _row()
	var b := Badge.new()
	b.n = n
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	row.add_child(_wrap_label(text, 19, 720))

# Real, animated enemy drawings (the same art as in the game) next to a description.
func _enemy_row(kinds: Array, text: String, space: bool = false) -> void:
	var row := _row()
	for k in kinds:
		row.add_child(_enemy_preview(str(k), space))
	row.add_child(_wrap_label(text, 19, 690 - 84.0 * float(kinds.size() - 1)))

func _enemy_preview(kind: String, space: bool) -> SubViewportContainer:
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(84, 84)
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.size = Vector2i(84, 84)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(vp)
	var e: Enemy = Enemy.make_ally() if kind == "ally" else Enemy.make(kind, 1)
	e.preview = true
	e.space = space
	e.position = Vector2(42, 46)
	var k := minf(1.0, 36.0 / maxf(e.radius, 1.0))
	e.scale = Vector2(k, k)
	vp.add_child(e)
	return svc

func _ally_row(icon: String, text: String) -> void:
	var row := _row()
	_icon(row, icon, 40.0)
	row.add_child(_wrap_label(text, 20, 700))

func _skill_row(icon: String, title_text: String, text: String) -> void:
	var row := _row()
	_icon(row, icon, 52.0)
	var col := VBoxContainer.new()
	row.add_child(col)
	var n := Label.new()
	n.text = title_text
	n.add_theme_font_size_override("font_size", PixelUI.fs(21))
	n.add_theme_color_override("font_color", KEY_COL)
	col.add_child(n)
	col.add_child(_wrap_label(text, 18, 690))

func _weapon_row(icon: String, title_text: String, price: String, note: String) -> void:
	var row := _row()
	_icon(row, icon, 52.0)
	var col := VBoxContainer.new()
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var n := Label.new()
	n.text = title_text
	n.add_theme_font_size_override("font_size", PixelUI.fs(21))
	n.add_theme_color_override("font_color", KEY_COL)
	head.add_child(n)
	var coin := IconRect.new()
	coin.custom_minimum_size = Vector2(22, 22)
	coin.with_bg = false
	coin.kind = "coin"
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(coin)
	var p := Label.new()
	p.text = price
	p.add_theme_font_size_override("font_size", PixelUI.fs(19))
	p.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	head.add_child(p)
	col.add_child(_wrap_label(note, 18, 690))

func _bar_row(icon: String, title_text: String, frac: float, col: Color, value: String) -> void:
	var row := _row()
	_icon(row, icon, 36.0)
	var n := Label.new()
	n.text = title_text
	n.add_theme_font_size_override("font_size", PixelUI.fs(19))
	n.custom_minimum_size = Vector2(170, 0)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(n)
	var bar := BarCtl.new()
	bar.frac = frac
	bar.col = col
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", PixelUI.fs(19))
	v.add_theme_color_override("font_color", KEY_COL)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)

# One line of the controls list: an optional icon, the action and key caps.
func _key_row(action: String, keys: Array, icon: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(36, 36)
	row.add_child(slot)
	if icon != "":
		var ic := IconRect.new()
		ic.custom_minimum_size = Vector2(32, 32)
		ic.position = Vector2(2, 2)
		ic.kind = icon
		ic.with_bg = icon != "mouse" and icon != "wheel"
		slot.add_child(ic)
	var a := Label.new()
	a.text = action
	a.custom_minimum_size = Vector2(390, 0)
	a.add_theme_font_size_override("font_size", PixelUI.fs(20))
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(a)
	for k in keys:
		row.add_child(_keycap(str(k)))

func _keycap(text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := PixelUI.plate(Color(0.2, 0.14, 0.09), Color(0.85, 0.65, 0.2), 2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", PixelUI.fs(19))
	l.add_theme_color_override("font_color", KEY_COL)
	pc.add_child(l)
	return pc
