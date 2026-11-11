class_name Hud
extends Control

var base: Base
var coins: int = 0

const SLOT := 64.0
const GAP := 10.0
const MAP_RADIUS := 115.0           # minimap circle size on screen
const MAP_RANGE := 1700.0           # world distance the minimap shows (a bit beyond where enemies spawn)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

var _t: float = 0.0
var _hp_front: float = 1.0       # smoothed fill
var _hp_ghost: float = 1.0       # slow "damage trail"
var _en_front: float = 1.0
var _en_prev: float = 1.0
var _en_gain: float = 0.0        # glows while energy is refilling
var _frame_sb := StyleBoxFlat.new()
var _fill_sb := StyleBoxFlat.new()

func _process(delta: float) -> void:
	_t += delta
	if base != null:
		var hr := clampf(base.hp / base.max_hp, 0.0, 1.0)
		var er := clampf(base.energy / base.max_energy, 0.0, 1.0)
		_hp_front = lerpf(_hp_front, hr, 1.0 - exp(-14.0 * delta))
		if hr > _hp_ghost:
			_hp_ghost = hr
		else:
			_hp_ghost = lerpf(_hp_ghost, hr, 1.0 - exp(-1.6 * delta))
		_en_front = lerpf(_en_front, er, 1.0 - exp(-18.0 * delta))
		_en_gain = lerpf(_en_gain, 1.0 if er > _en_prev + 0.0005 and er < 0.999 else 0.0, 1.0 - exp(-6.0 * delta))
		_en_prev = er
	queue_redraw()

func _draw() -> void:
	if base == null:
		return
	var s := Settings.WORLD_SIZE
	_draw_coins(s)
	var w := 440.0
	var h := 26.0
	var x := (s.x - w) * 0.5
	var hp_text := "%s %d / %d" % [Loc.t("Health"), ceili(base.hp), ceili(base.max_hp)]
	var en_text := "%s %d / %d" % [Loc.t("Energy"), int(base.energy), int(base.max_energy)]
	var hr := clampf(base.hp / base.max_hp, 0.0, 1.0)
	var er := clampf(base.energy / base.max_energy, 0.0, 1.0)
	_bar(Vector2(x, s.y - 160.0), Vector2(w, h), _en_front, _en_front, Color(1.0, 0.62, 0.12), Color(1.0, 0.85, 0.3), en_text, _en_gain, er < 0.2)
	var hp_col := Color(0.9, 0.2, 0.2).lerp(Color(0.25, 0.85, 0.35), clampf(hr * 1.4, 0.0, 1.0))
	_bar(Vector2(x, s.y - 126.0), Vector2(w, h), _hp_front, _hp_ghost, hp_col, hp_col.lightened(0.3), hp_text, 0.0, hr < 0.3)
	_draw_skills(s)
	_draw_minimap(s)
	_draw_weapon(Vector2(x - 82.0, s.y - 160.0))
	_draw_helpers()

# Round radar at the bottom left: you (orange) in the middle, enemies red, bosses purple.
func _draw_minimap(s: Vector2) -> void:
	var c := Vector2(30.0 + MAP_RADIUS, s.y - 30.0 - MAP_RADIUS)
	var k := MAP_RADIUS / MAP_RANGE
	draw_circle(c, MAP_RADIUS, Color(0.04, 0.06, 0.09, 0.62))
	draw_arc(c, MAP_RADIUS * 0.5, 0.0, TAU, 48, Color(1, 1, 1, 0.08), 1.5)
	draw_line(c + Vector2(-MAP_RADIUS, 0.0), c + Vector2(MAP_RADIUS, 0.0), Color(1, 1, 1, 0.06), 1.5)
	draw_line(c + Vector2(0.0, -MAP_RADIUS), c + Vector2(0.0, MAP_RADIUS), Color(1, 1, 1, 0.06), 1.5)
	var tree := get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e == null or e.dead:
				continue
			var rel := (e.global_position - base.global_position) * k
			var big := e.kind == "boss" or e.kind == "minicastle"
			var dist := rel.length()
			if dist > MAP_RADIUS - 5.0:
				if not big:
					continue
				rel = rel / dist * (MAP_RADIUS - 6.0)         # bosses stay on the rim so you know where they are
			if big:
				var pulse := 0.5 + 0.5 * sin(_t * 6.0)
				draw_circle(c + rel, 6.5 + pulse, Color(0.7, 0.3, 1.0, 0.35))
				draw_circle(c + rel, 4.5, Color(0.7, 0.3, 1.0))
			else:
				draw_circle(c + rel, 2.4, Color(1.0, 0.2, 0.2))
	draw_circle(c, 5.5, Color(0, 0, 0, 0.6))
	draw_circle(c, 4.0, Color(1.0, 0.6, 0.1))
	draw_arc(c, MAP_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.55), 3.0)

func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

# Modern bar: rounded frame, smooth fill with a gloss, a moving shine, a trailing
# "damage" ghost, and a pulsing red glow when the value is low.
func _bar(pos: Vector2, bar_size: Vector2, front: float, ghost: float, col: Color, col2: Color, text: String, charge: float, low: bool) -> void:
	var rad := int(bar_size.y * 0.5)
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	if low:
		_frame_sb.bg_color = Color(0.9, 0.1, 0.1, 0.10 + 0.22 * pulse)
		_frame_sb.set_corner_radius_all(rad + 6)
		draw_style_box(_frame_sb, Rect2(pos - Vector2(6, 6), bar_size + Vector2(12, 12)))
	_frame_sb.bg_color = Color(0.05, 0.06, 0.09, 0.88)
	_frame_sb.set_corner_radius_all(rad + 3)
	draw_style_box(_frame_sb, Rect2(pos - Vector2(3, 3), bar_size + Vector2(6, 6)))
	var inner := Rect2(pos, bar_size)
	var fw := bar_size.x * clampf(front, 0.0, 1.0)
	var gw := bar_size.x * clampf(ghost, 0.0, 1.0)
	_fill_sb.set_corner_radius_all(rad)
	if gw > fw + 1.0:
		_fill_sb.bg_color = Color(1.0, 1.0, 1.0, 0.55)
		draw_style_box(_fill_sb, Rect2(pos, Vector2(gw, bar_size.y)))
	if fw > 1.0:
		var base_col := col.lerp(Color(1.0, 0.3, 0.3), 0.35 * pulse) if low else col
		_fill_sb.bg_color = base_col.darkened(0.15)
		draw_style_box(_fill_sb, Rect2(pos, Vector2(fw, bar_size.y)))
		# lighter upper half (gloss)
		_fill_sb.bg_color = col2.lerp(base_col, 0.3)
		_fill_sb.set_corner_radius_all(rad)
		draw_style_box(_fill_sb, Rect2(pos + Vector2(0, 2), Vector2(fw, bar_size.y * 0.45)))
		# moving shine
		var sx := fposmod(_t * 110.0, bar_size.x + 120.0) - 60.0
		var x0 := clampf(pos.x + sx, pos.x, pos.x + fw)
		var x1 := clampf(pos.x + sx + 36.0, pos.x, pos.x + fw)
		if x1 - x0 > 1.0:
			draw_rect(Rect2(x0, pos.y + 2.0, x1 - x0, bar_size.y - 4.0), Color(1, 1, 1, 0.20))
		# glowing tip
		draw_circle(Vector2(pos.x + fw, pos.y + bar_size.y * 0.5), 6.0 + 2.0 * pulse, Color(col2.r, col2.g, col2.b, 0.35))
		# refill sparkle: little lights run along a bar that is charging
		if charge > 0.05:
			for i in 3:
				var px := pos.x + fposmod(_t * 160.0 + i * 140.0, maxf(fw, 1.0))
				draw_circle(Vector2(px, pos.y + bar_size.y * 0.5 + sin(_t * 9.0 + i) * 4.0), 2.2, Color(1, 1, 0.8, 0.8 * charge))
	# segment ticks
	for i in range(1, 10):
		var tx := pos.x + bar_size.x * i / 10.0
		draw_line(Vector2(tx, pos.y + 3.0), Vector2(tx, pos.y + bar_size.y - 3.0), Color(0, 0, 0, 0.22), 1.0)
	_fill_sb.bg_color = Color(0, 0, 0, 0)
	_fill_sb.set_border_width_all(2)
	_fill_sb.border_color = Color(1, 1, 1, 0.55)
	_fill_sb.set_corner_radius_all(rad)
	draw_style_box(_fill_sb, inner)
	_fill_sb.set_border_width_all(0)
	_text(pos + Vector2(14, bar_size.y - 6), text, 17, Color.WHITE)

func _draw_coins(s: Vector2) -> void:
	var pos := Vector2(s.x - 230.0, 24.0)
	draw_texture_rect(CoinTex.get_texture(), Rect2(pos, Vector2(42, 42)), false)
	_text(pos + Vector2(56, 33), "x %d" % coins, 32, Color(1.0, 0.9, 0.3))

func _draw_skills(s: Vector2) -> void:
	var total := SLOT * 4.0 + GAP * 3.0
	var x0 := (s.x - total) * 0.5
	var y := s.y - 92.0
	for i in 4:
		var r := Rect2(x0 + i * (SLOT + GAP), y, SLOT, SLOT)
		var id := base.skill_slots[i]
		var active_time := 0.0
		var active_col := Color(0.3, 1.0, 1.0)
		if id == "barrier":
			active_time = base.barrier_time
		elif id == "overcharge":
			active_time = base.boost_time
			active_col = Color(1.0, 0.65, 0.2)
		var active := active_time > 0.0
		draw_rect(r, Color(0.08, 0.09, 0.13, 0.9))
		if id != "":
			_draw_skill_icon(id, r)
			var cd := base.skill_cd[i]
			if cd > 0.0:
				draw_rect(r, Color(0, 0, 0, 0.6))
				var fill_h := SLOT * (1.0 - cd / base.skill_cd_max[i])
				draw_rect(Rect2(r.position.x, r.end.y - fill_h, SLOT, fill_h), Color(1, 1, 1, 0.12))
				_text(r.get_center() + Vector2(-8, 10), str(ceili(cd)), 26, Color.WHITE)
			if active:
				_text(r.position + Vector2(8, SLOT - 6), "%.1f" % active_time, 18, active_col.lightened(0.4))
			if id == "repair":
				var price := base.repair_cost()
				var ok := coins >= price
				_text(r.position + Vector2(SLOT - 40.0 - (8.0 if price >= 100 else 0.0), SLOT - 6), str(price), 18, Color(1.0, 0.85, 0.3) if ok else Color(1.0, 0.35, 0.3))
		var border := Color(1, 1, 1, 0.2)
		if active:
			border = active_col
		elif id != "":
			border = Color(1, 1, 1, 0.6)
		draw_rect(r, border, false, 3.0 if active else 2.0)
		_text(r.position + Vector2(6, 18), Keybinds.key_text("skill_%d" % (i + 1)), 16, Color(1.0, 0.9, 0.5))

func _draw_skill_icon(id: String, r: Rect2) -> void:
	var c := r.get_center()
	var h := r.size.y
	match id:
		"overcharge":
			Icons.draw(self, "damage", r.position, h / 64.0, false)
			var glow := 0.5 + 0.5 * sin(_t * 6.0)
			if base.boost_time > 0.0:
				draw_rect(r, Color(1.0, 0.6, 0.15, 0.18 + 0.18 * glow))
		"repair":
			Icons.draw(self, "repair", r.position, h / 64.0, false)
		"barrier":
			var pts := PackedVector2Array([
				c + Vector2(-0.30, -0.28) * h, c + Vector2(0.30, -0.28) * h,
				c + Vector2(0.32, 0.04) * h, c + Vector2(0.0, 0.36) * h,
				c + Vector2(-0.32, 0.04) * h,
			])
			draw_colored_polygon(pts, Color(0.25, 0.75, 1.0))
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(c + (p - c) * 0.6)
			draw_colored_polygon(inner, Color(0.6, 0.92, 1.0))
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, Color.WHITE, 2.5)

# Current weapon icon next to the energy and health bars.
func _draw_weapon(pos: Vector2) -> void:
	Icons.draw(self, Weapons.id_of(base.weapon_tier), pos, 62.0 / 64.0, true)
	var col: Color = Weapons.COLORS[base.weapon_tier]
	draw_rect(Rect2(pos, Vector2(62, 62)), col, false, 2.0)

# Helper allies as icons with counts (no profession names, just like the coin).
func _draw_helpers() -> void:
	var kinds := ["gunner", "scientist", "engineer", "mechanic"]
	var counts := [base.gunners, base.scientists, base.engineers, base.mechanics]
	var x := 28.0
	var y := 62.0
	for i in 4:
		var kind: String = kinds[i]
		var n: int = counts[i]
		var dim := n == 0
		Icons.draw(self, kind, Vector2(x, y), 44.0 / 64.0, true)
		if dim:
			draw_rect(Rect2(Vector2(x, y), Vector2(44, 44)), Color(0, 0, 0, 0.55))
		_text(Vector2(x + 50.0, y + 32.0), "x %d" % n, 24, Color(1, 1, 1, 0.45) if dim else Color.WHITE)
		x += 130.0
