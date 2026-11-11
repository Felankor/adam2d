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
var _xp_front: float = -1.0      # smoothed continuous level value (level + progress)
var _xp_target: float = 0.0
var _xp_glow: float = 0.0        # flares when XP is gained
var _xp_flash: float = 0.0       # full-bar flash on a level-up
var _xp_level_seen: int = 1
var _lvl_anim: float = -1.0      # "LEVEL UP!" banner timer (-1 = not playing)
var _lvl_shown: int = 1
var _combat: bool = false        # enemies are alive (drives the unspent-points reminder)
var _combat_timer: float = 0.0
const LEVELUP_TIME := 2.6
var _ft := PackedFloat32Array()  # recent frame times for the FPS counter
var _ft_i: int = 0
var _fps_timer: float = 0.0
var _fps: int = 0
var _fps_low: int = 0
var _frame_sb := StyleBoxFlat.new()
var _fill_sb := StyleBoxFlat.new()

func _process(delta: float) -> void:
	_t += delta
	_update_fps(delta)
	_update_xp(delta)
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

# FPS and the "1% low" (the average of the slowest 1% of the last ~600 frames).
func _update_fps(delta: float) -> void:
	if _ft.size() < 600:
		_ft.append(delta)
	else:
		_ft[_ft_i] = delta
		_ft_i = (_ft_i + 1) % 600
	_fps_timer -= delta
	if _fps_timer <= 0.0 and _ft.size() >= 30:
		_fps_timer = 0.5
		_fps = int(Engine.get_frames_per_second())
		var arr := Array(_ft)
		arr.sort()
		var worst := maxi(1, arr.size() / 100)
		var sum := 0.0
		for i in worst:
			sum += float(arr[arr.size() - 1 - i])
		_fps_low = int(1.0 / maxf(sum / float(worst), 0.0001))

func _update_xp(delta: float) -> void:
	if base == null:
		return
	var need := Base.xp_needed(base.xp_level)
	var cont := float(base.xp_level) + float(base.xp) / float(need)
	if _xp_front < 0.0:
		_xp_front = cont
		_xp_target = cont
		_xp_level_seen = base.xp_level
	if cont > _xp_target + 0.0001:
		_xp_glow = 1.0
	_xp_target = cont
	if base.xp_level > _xp_level_seen:
		_xp_flash = 1.0
		_lvl_anim = 0.0
		_lvl_shown = base.xp_level
	_xp_level_seen = base.xp_level
	_xp_front = lerpf(_xp_front, cont, 1.0 - exp(-3.0 * delta))
	_xp_glow = maxf(_xp_glow - delta * 1.1, 0.0)
	_xp_flash = maxf(_xp_flash - delta * 1.0, 0.0)
	if _lvl_anim >= 0.0:
		_lvl_anim += delta
		if _lvl_anim > LEVELUP_TIME:
			_lvl_anim = -1.0
	_combat_timer -= delta
	if _combat_timer <= 0.0:
		_combat_timer = 0.3
		_combat = get_tree().get_nodes_in_group("enemies").size() > 0

# "LEVEL UP!": rays, an expanding ring, a bouncing title and rising sparkles.
func _draw_levelup(s: Vector2) -> void:
	if _lvl_anim < 0.0:
		return
	var t := _lvl_anim
	var fade := clampf(t / 0.15, 0.0, 1.0) * clampf((LEVELUP_TIME - t) / 0.7, 0.0, 1.0)
	var c := Vector2(s.x * 0.5, 330.0)
	# bounce: pops in big, settles to 1.0
	var sc := 1.0
	if t < 0.3:
		sc = lerpf(0.3, 1.35, t / 0.3)
	elif t < 0.55:
		sc = lerpf(1.35, 1.0, (t - 0.3) / 0.25)
	else:
		sc = 1.0 + 0.03 * sin(t * 6.0)
	# rotating golden rays
	var ray_len := (110.0 + 90.0 * clampf(t / 0.5, 0.0, 1.0))
	for i in 16:
		var a := TAU * float(i) / 16.0 + t * 0.6
		var dir := Vector2.RIGHT.rotated(a)
		draw_line(c + dir * 70.0, c + dir * (70.0 + ray_len * (0.6 + 0.4 * sin(t * 5.0 + float(i)))), Color(1.0, 0.85, 0.3, 0.42 * fade), 6.0)
	# expanding ring
	var ring := clampf(t / 1.2, 0.0, 1.0)
	draw_arc(c, 60.0 + 300.0 * ring, 0.0, TAU, 72, Color(1.0, 0.9, 0.4, 0.8 * (1.0 - ring) * fade), 8.0 * (1.0 - ring) + 1.0)
	# sparkles
	for i in 18:
		var life := fposmod(t * 0.9 + float(i) * 0.173, 1.0)
		var px := c.x + sin(float(i) * 2.7) * 220.0
		var py := c.y + 60.0 - life * 170.0
		draw_circle(Vector2(px, py), 4.0 * (1.0 - life) + 1.0, Color(1.0, 0.95, 0.6, 0.9 * (1.0 - life) * fade))
	# title and subtitle
	var font := ThemeDB.fallback_font
	var title := Loc.t("LEVEL UP!")
	draw_set_transform(c, 0.0, Vector2(sc, sc))
	draw_string_outline(font, Vector2(-400.0, 24.0), title, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 84, 14, Color(0.25, 0.12, 0.0, fade))
	draw_string(font, Vector2(-400.0, 24.0), title, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 84, Color(1.0, 0.85, 0.25).lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 9.0)) * Color(1, 1, 1, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sub := "%s %d      %s" % [Loc.t("Level"), _lvl_shown, Loc.t("+5 stat points")]
	draw_string_outline(font, Vector2(c.x - 400.0, c.y + 66.0), sub, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 32, 8, Color(0, 0, 0, fade))
	draw_string(font, Vector2(c.x - 400.0, c.y + 66.0), sub, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 32, Color(0.7, 1.0, 0.75, fade))

func _draw_fps(s: Vector2) -> void:
	var col := Color(0.5, 1.0, 0.5) if _fps >= 55 else (Color(1.0, 0.85, 0.3) if _fps >= 30 else Color(1.0, 0.35, 0.3))
	var txt := "FPS %d    1%% low %d" % [_fps, _fps_low]
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(s.x - 330.0, 28.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 316.0, 18, 4, Color.BLACK)
	draw_string(font, Vector2(s.x - 330.0, 28.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 316.0, 18, col)

func _draw() -> void:
	if base == null:
		return
	var s := Settings.WORLD_SIZE
	_draw_coins(s)
	_draw_fps(s)
	var w := 440.0
	var h := 26.0
	var x := (s.x - w) * 0.5
	var hp_text := "%s %d / %d" % [Loc.t("Health"), ceili(base.hp), ceili(base.max_hp)]
	var en_text := "%s %d / %d" % [Loc.t("Mana"), int(base.energy), int(base.max_energy)]
	var hr := clampf(base.hp / base.max_hp, 0.0, 1.0)
	var er := clampf(base.energy / base.max_energy, 0.0, 1.0)
	_bar(Vector2(x, s.y - 126.0), Vector2(w, h), _en_front, _en_front, Color(0.16, 0.42, 0.95), Color(0.5, 0.78, 1.0), en_text, _en_gain, er < 0.2)
	var hp_col := Color(0.86, 0.1, 0.14)       # health is always red
	_bar(Vector2(x, s.y - 160.0), Vector2(w, h), _hp_front, _hp_ghost, hp_col, hp_col.lightened(0.3), hp_text, 0.0, hr < 0.3)
	_draw_skills(s)
	# castle level (XP): a full-width golden bar along the bottom edge, like an MMORPG
	var xp_need := Base.xp_needed(base.xp_level)
	var xp_frac := clampf(float(base.xp) / float(xp_need), 0.0, 1.0)
	var bar_h := 16.0
	var bar_y := s.y - bar_h
	var front_frac := fposmod(_xp_front, 1.0)
	var tgt_frac := fposmod(_xp_target, 1.0)
	if floorf(_xp_target) > floorf(_xp_front) + 0.001:
		tgt_frac = 1.0                      # the bar is still catching up to a level-up
	draw_rect(Rect2(0.0, bar_y, s.x, bar_h), Color(0.07, 0.05, 0.02, 0.88))
	var fw := s.x * front_frac
	var tw := s.x * tgt_frac
	if tw > fw + 1.0:
		var pulse := 0.5 + 0.5 * sin(_t * 12.0)
		draw_rect(Rect2(fw, bar_y, tw - fw, bar_h), Color(1.0, 0.95, 0.6, 0.45 + 0.3 * pulse))      # the XP just earned
	if fw > 1.0:
		draw_rect(Rect2(0.0, bar_y, fw, bar_h), Color(0.9, 0.62, 0.08))
		draw_rect(Rect2(0.0, bar_y, fw, bar_h * 0.5), Color(1.0, 0.85, 0.3))
		draw_rect(Rect2(0.0, bar_y + bar_h * 0.5, fw, bar_h * 0.18), Color(1.0, 0.95, 0.65, 0.35))
		# slow golden shine travelling along the bar
		var shine := fposmod(_t * 220.0, s.x + 300.0) - 150.0
		var sx0 := clampf(shine, 0.0, fw)
		var sx1 := clampf(shine + 90.0, 0.0, fw)
		if sx1 - sx0 > 1.0:
			draw_rect(Rect2(sx0, bar_y, sx1 - sx0, bar_h), Color(1.0, 1.0, 0.85, 0.35))
		# glowing tip
		draw_circle(Vector2(fw, bar_y + bar_h * 0.5), 9.0 + 6.0 * _xp_glow, Color(1.0, 0.9, 0.4, 0.28 + 0.4 * _xp_glow))
	if _xp_glow > 0.02:
		# gain animation: a bright flare and sparkles rising from the tip
		draw_rect(Rect2(0.0, bar_y, maxf(fw, tw), bar_h), Color(1.0, 0.95, 0.6, 0.35 * _xp_glow))
		for k in 7:
			var life := fposmod(_t * 1.8 + float(k) * 0.37, 1.0)
			var spx := fw - 6.0 + sin(float(k) * 2.3) * 26.0
			var spy := bar_y - life * 34.0
			draw_circle(Vector2(spx, spy), 2.6 * (1.0 - life) + 0.8, Color(1.0, 0.92, 0.5, 0.9 * _xp_glow * (1.0 - life)))
	for i in range(1, 10):
		draw_line(Vector2(s.x * float(i) / 10.0, bar_y), Vector2(s.x * float(i) / 10.0, s.y), Color(0, 0, 0, 0.3), 1.0)
	draw_line(Vector2(0.0, bar_y), Vector2(s.x, bar_y), Color(1.0, 0.85, 0.4, 0.5), 1.0)
	if _xp_flash > 0.01:
		# level-up: the whole bar flashes
		draw_rect(Rect2(0.0, bar_y - 3.0, s.x, bar_h + 3.0), Color(1.0, 0.95, 0.55, 0.75 * _xp_flash))
		draw_rect(Rect2(0.0, bar_y - 3.0, s.x, 3.0 + 6.0 * _xp_flash), Color(1.0, 0.9, 0.3, 0.6 * _xp_flash))
	var xp_text := "%s %d     XP %d / %d   (%d%%)" % [Loc.t("Level"), base.xp_level, base.xp, xp_need, int(xp_frac * 100.0)]
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(0.0, s.y - 2.5), xp_text, HORIZONTAL_ALIGNMENT_CENTER, s.x, 13, 4, Color.BLACK)
	draw_string(font, Vector2(0.0, s.y - 2.5), xp_text, HORIZONTAL_ALIGNMENT_CENTER, s.x, 13, Color(1.0, 0.97, 0.85))
	if base.free_points > 0:
		# blinking "[Tab] Stat points: N" tag above the bars
		var blink := 0.5 + 0.5 * sin(_t * 5.0)
		var tag := "[%s]  %s: %d" % [Keybinds.key_text("open_shop"), Loc.t("Stat points"), base.free_points]
		_frame_sb.set_corner_radius_all(10)
		_frame_sb.bg_color = Color(0.2, 0.85, 0.35, 0.12 + 0.30 * blink)
		draw_style_box(_frame_sb, Rect2(x - 12.0, s.y - 222.0 + sin(_t * 6.0) * 2.0, 330.0, 38.0))
		_text(Vector2(x, s.y - 195.0 + sin(_t * 6.0) * 2.0), tag, 24, Color(0.55, 1.0, 0.65).lerp(Color.WHITE, blink))
		# while enemies are around, remind the player at the top middle of the screen
		if _combat and not get_tree().paused:
			var msg := Loc.t("Unspent stat points: %d  -  press [%s]") % [base.free_points, Keybinds.key_text("open_shop")]
			var font_r := ThemeDB.fallback_font
			_frame_sb.set_corner_radius_all(12)
			_frame_sb.bg_color = Color(0.95, 0.6, 0.1, 0.18 + 0.32 * blink)
			draw_style_box(_frame_sb, Rect2(s.x * 0.5 - 300.0, 22.0, 600.0, 44.0))
			draw_string_outline(font_r, Vector2(s.x * 0.5 - 300.0, 52.0), msg, HORIZONTAL_ALIGNMENT_CENTER, 600.0, 24, 5, Color.BLACK)
			draw_string(font_r, Vector2(s.x * 0.5 - 300.0, 52.0), msg, HORIZONTAL_ALIGNMENT_CENTER, 600.0, 24, Color(1.0, 0.9, 0.5).lerp(Color.WHITE, blink))
	_draw_levelup(s)
	_draw_minimap(s)
	_draw_weapon(Vector2(x - 82.0, s.y - 160.0))
	_draw_helpers()

# Round radar at the bottom right: you (orange) in the middle, enemies red, bosses purple.
func _draw_minimap(s: Vector2) -> void:
	var c := Vector2(s.x - 30.0 - MAP_RADIUS, s.y - 30.0 - MAP_RADIUS)
	var k := MAP_RADIUS / MAP_RANGE
	draw_circle(c, MAP_RADIUS, Color(0.04, 0.06, 0.09, 0.62))
	draw_arc(c, MAP_RADIUS * 0.5, 0.0, TAU, 48, Color(1, 1, 1, 0.08), 1.5)
	draw_line(c + Vector2(-MAP_RADIUS, 0.0), c + Vector2(MAP_RADIUS, 0.0), Color(1, 1, 1, 0.06), 1.5)
	draw_line(c + Vector2(0.0, -MAP_RADIUS), c + Vector2(0.0, MAP_RADIUS), Color(1, 1, 1, 0.06), 1.5)
	var tree := get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group("allies"):
			var a := node as Enemy
			if a != null and not a.dead:
				var arel := (a.global_position - base.global_position) * k
				if arel.length() <= MAP_RADIUS - 5.0:
					draw_circle(c + arel, 2.6, Color(0.3, 1.0, 0.4))      # refugees: green
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
	var pos := Vector2(s.x - 230.0, 44.0)
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
	var y := 108.0
	for i in 4:
		var kind: String = kinds[i]
		var n: int = counts[i]
		var dim := n == 0
		Icons.draw(self, kind, Vector2(x, y), 44.0 / 64.0, true)
		if dim:
			draw_rect(Rect2(Vector2(x, y), Vector2(44, 44)), Color(0, 0, 0, 0.55))
		_text(Vector2(x + 50.0, y + 32.0), "x %d" % n, 24, Color(1, 1, 1, 0.45) if dim else Color.WHITE)
		x += 130.0
