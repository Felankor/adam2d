class_name Hud
extends Control

var base: Base
var coins: int = 0
var ci: CanvasItem                  # what the current element is drawn on: one of the HudPart nodes (or the Hud itself)
var info_wave: int = 1              # the wave plaque in the top-left corner (set by main.gd)
var info_biome: String = ""
var info_castle: String = ""
var info_msg: String = ""
var info_detail: String = ""        # difficulty / power numbers, shown under the helpers when the details key is on
var edit_mode: bool = false         # the HUD editor is open: every element shows, even with nothing to show
var _parts: Dictionary = {}
var _rev_seen: int = -1
# Elements that are separate nodes in main.gd (labels, the pop-up stack): id -> [[node, default position], ...]
const EXT := ["notifier", "bosswarn", "banner"]
var _ext: Dictionary = {}
var _saved: Dictionary = {}

const HUD_K := 2.0                 # one art pixel of the HUD frame on screen
const HUD_UP := 226.0              # top of the HUD frame, measured up from the bottom edge
const SLOT := 64.0
const GAP := 10.0
const HELPERS_Y := 156.0          # default top of the helper plates (under the wave plaque)
const MAP_RADIUS := 115.0           # minimap circle size on screen
const MAP_RANGE := 1700.0           # world distance the minimap shows (a bit beyond where enemies spawn)

# The HUD lays itself out in a virtual screen of WORLD_SIZE / hud_scale and is then scaled up or down,
# so everything stays glued to its screen edge at any scale.
var _applied_scale: float = -1.0

func _vs() -> Vector2:
	return Settings.WORLD_SIZE / Settings.hud_scale

func _apply_scale() -> void:
	_applied_scale = Settings.hud_scale
	scale = Vector2(_applied_scale, _applied_scale)
	size = Settings.WORLD_SIZE / _applied_scale
	if not _parts.is_empty():
		apply_layout()
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	ci = self
	for id in HudLayout.IDS:
		if EXT.has(id):
			continue
		var p := HudPart.new()
		p.hud = self
		p.id = id
		add_child(p)
		_parts[id] = p
	_apply_scale()
	apply_layout()

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
var show_debug: bool = false       # details key: also shows object counts (mobs, shots, effects, nodes, draw calls)
var _hp_last: float = -1.0
var _shards: Array = []           # health bar shards of a critical hit on the player: [pos, vel, size, life]
var _crit_flash: float = 0.0
var _map_tex: ImageTexture = null

# A single drop of more than 25% of max health breaks that slice of the health bar into falling shards.
func _check_crit(delta: float) -> void:
	_crit_flash = maxf(_crit_flash - delta * 2.5, 0.0)
	if _hp_last >= 0.0 and _hp_last - base.hp >= 0.25 * base.max_hp:
		var s := _vs()
		var bw := float(HudArt.TL + HudLayout.bar_extra()) * HUD_K
		var bx := s.x * 0.5 - float(HudArt.TGAP) * HUD_K - bw      # left end of the health tube
		var by := s.y - HUD_UP + float(HudArt.YC - HudArt.TR) * HUD_K
		var f_to := clampf(base.hp / base.max_hp, 0.0, 1.0)
		var f_from := clampf(_hp_last / base.max_hp, 0.0, 1.0)
		var n := 7
		for i in n:
			var fx := lerpf(f_to, f_from, (float(i) + 0.5) / float(n))
			var sw := bw * (f_from - f_to) / float(n)
			_shards.append([Vector2(bx + bw * (1.0 - fx) - sw * 0.5, by), Vector2(randf_range(-90.0, 90.0), randf_range(-260.0, -80.0)), Vector2(maxf(sw, 6.0), 50.0), 1.0])
		_crit_flash = 1.0
	_hp_last = base.hp
	var j := _shards.size() - 1
	while j >= 0:
		var sh: Array = _shards[j]
		sh[1] = (sh[1] as Vector2) + Vector2(0.0, 1100.0 * delta)
		sh[0] = (sh[0] as Vector2) + (sh[1] as Vector2) * delta
		sh[3] = float(sh[3]) - delta * 1.1
		if float(sh[3]) <= 0.0:
			_shards.remove_at(j)
		j -= 1

func _process(delta: float) -> void:
	_t += delta
	if not is_equal_approx(_applied_scale, Settings.hud_scale):
		_apply_scale()
	if _rev_seen != HudLayout.rev:
		apply_layout()
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
		_check_crit(delta)
	queue_redraw()
	for id in _parts:
		if (_parts[id] as HudPart).visible:
			(_parts[id] as HudPart).queue_redraw()

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
	var t := _lvl_anim
	if t < 0.0:
		if not edit_mode:
			return
		t = 0.9
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
		ci.draw_line(c + dir * 70.0, c + dir * (70.0 + ray_len * (0.6 + 0.4 * sin(t * 5.0 + float(i)))), Color(1.0, 0.85, 0.3, 0.42 * fade), 6.0)
	# expanding ring
	var ring := clampf(t / 1.2, 0.0, 1.0)
	ci.draw_arc(c, 60.0 + 300.0 * ring, 0.0, TAU, 72, Color(1.0, 0.9, 0.4, 0.8 * (1.0 - ring) * fade), 8.0 * (1.0 - ring) + 1.0)
	# sparkles
	for i in 18:
		var life := fposmod(t * 0.9 + float(i) * 0.173, 1.0)
		var px := c.x + sin(float(i) * 2.7) * 220.0
		var py := c.y + 60.0 - life * 170.0
		var ssz := 3.0 if life < 0.5 else 3.0
		ci.draw_rect(Rect2(floorf(px / 3.0) * 3.0, floorf(py / 3.0) * 3.0, ssz * (2.0 if life < 0.3 else 1.0), ssz * (2.0 if life < 0.3 else 1.0)), Color(1.0, 0.95, 0.6, 0.9 * (1.0 - life) * fade))
	# title and subtitle
	var title := Loc.t("LEVEL UP!")
	ci.draw_set_transform(c, 0.0, Vector2(sc, sc))
	_tx(Vector2(-400.0, 24.0), title, 84, Color(1.0, 0.85, 0.25).lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 9.0)) * Color(1, 1, 1, fade), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 14, Color(0.25, 0.12, 0.0, fade))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sub := "%s %d      %s" % [Loc.t("Level"), _lvl_shown, Loc.t("+5 stat points")]
	_tx(Vector2(c.x - 400.0, c.y + 66.0), sub, 32, Color(0.7, 1.0, 0.75, fade), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 8, Color(0, 0, 0, fade))

func _draw_fps(s: Vector2) -> void:
	var col := Color(0.5, 1.0, 0.5) if _fps >= 55 else (Color(1.0, 0.85, 0.3) if _fps >= 30 else Color(1.0, 0.35, 0.3))
	var txt := "FPS %d    1%% low %d" % [_fps, _fps_low]
	if HudLayout.text("fps", "detail") == "fps":
		txt = "FPS %d" % _fps
	_tx(Vector2(s.x - 330.0, 28.0), txt, 18, col, HORIZONTAL_ALIGNMENT_RIGHT, 316.0, 4, Color.BLACK)
	if show_debug:
		var dbg := "Mobs %d  Shots %d  Fx %d  Nodes %d  Draw calls %d" % [Field.mobs().size(), Field.shots().size(), Fx.live, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
		_tx(Vector2(s.x - 560.0, 112.0), dbg, 16, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 546.0, 4, Color.BLACK)

# One HUD element, drawn onto its own HudPart node (the part carries the editor's offset, size and opacity).
func draw_part(id: String, node: CanvasItem) -> void:
	if base == null:
		return
	ci = node
	_cur = id
	var s := _vs()
	match id:
		"bars":
			_draw_bars(s)
		"shield":
			if HudLayout.text("shield", "style") == "own":
				_draw_shield_own(s)
		"xp":
			_draw_xp(s, 0.0, s.y - HUD_UP)
		"tag":
			_draw_tag(s)
		"weapon":
			_draw_weapon(part_rect("weapon").position)
		"skills":
			_draw_skills(s)
		"minimap":
			_draw_minimap(s)
		"helpers":
			_draw_helpers()
		"gold":
			_draw_coins(s)
		"fps":
			_draw_fps(s)
		"info":
			_draw_info()
		"bossbar":
			_draw_boss_bars(s)
		"levelup":
			_draw_levelup(s)
	ci = self

# ---------- layout: where each element sits by default (the editor offset is applied by its HudPart) ----------

func _own_shield() -> bool:
	return HudLayout.text("shield", "style") == "own" and HudLayout.flag("shield", "vis")

func part_rect(id: String) -> Rect2:
	var s := _vs()
	var k := HUD_K
	var e := HudLayout.bar_extra()
	var ox := roundf(s.x * 0.5 - float(HudArt.CX + e) * k)
	var oy := s.y - HUD_UP
	match id:
		"bars":
			return Rect2(ox, oy, float(HudArt.CW + 2 * e) * k, float(HudArt.CH) * k)
		"shield":
			if HudLayout.text("shield", "style") == "own":
				var w := float(HudArt.TL) * k
				return Rect2(roundf(s.x * 0.5 - w * 0.5) - 9.0, oy - 33.0, w + 18.0, 32.0)
			var xr := ox + float(HudArt.CX + e - HudArt.TGAP) * k
			return Rect2(xr - float(HudArt.TL + e) * k, oy + float(HudArt.YC - HudArt.TR) * k - 26.0, 170.0, 24.0)
		"xp":
			var xw := maxf(float(HudArt.XW + HudLayout.xp_extra()) * k, 420.0)
			return Rect2(s.x * 0.5 - xw * 0.5, oy + float(HudArt.YC + HudArt.R + 3) * k, xw, 40.0)
		"tag":
			return Rect2(s.x * 0.5 - 110.0, oy - 30.0 - (36.0 if _own_shield() else 0.0), 220.0, 30.0)
		"weapon":
			return Rect2(ox - 68.0, oy + float(HudArt.YC) * k - 31.0, 62.0, 62.0)
		"skills":
			var total := SLOT * 4.0 + HudLayout.num("skills", "gap") * 3.0
			return Rect2((s.x - total) * 0.5, s.y - 92.0, total, SLOT)
		"minimap":
			return Rect2(s.x - 30.0 - MAP_RADIUS * 2.0, s.y - 30.0 - MAP_RADIUS * 2.0, MAP_RADIUS * 2.0, MAP_RADIUS * 2.0)
		"helpers":
			var hs := _helper_size()
			if HudLayout.text("helpers", "layout") == "column":
				return Rect2(28.0, HELPERS_Y, hs.x, (hs.y + 8.0) * 3.0 + hs.y)
			return Rect2(28.0, HELPERS_Y, (hs.x + 10.0) * 3.0 + hs.x, hs.y)
		"gold":
			return Rect2(s.x - 230.0, 44.0, 190.0, 42.0)
		"fps":
			return Rect2(s.x - 330.0, 8.0, 316.0, 28.0)
		"bossbar":
			return Rect2(s.x * 0.5 - 320.0, 40.0, 640.0, 76.0)
		"levelup":
			return Rect2(s.x * 0.5 - 300.0, 200.0, 600.0, 250.0)
		"info":
			var im := _info_metrics()
			return Rect2(28.0, 20.0, im[0], im[1])
		"notifier":
			return Rect2(28.0, Settings.WORLD_SIZE.y - 28.0 - 300.0, 480.0, 300.0)
		"bosswarn":
			return Rect2(Settings.WORLD_SIZE.x * 0.5 - 300.0, 124.0, 600.0, 40.0)
		"banner":
			return Rect2(Settings.WORLD_SIZE.x * 0.5 - 400.0, 150.0, 800.0, 70.0)
	return Rect2()

# The point an element is scaled around (its middle, or the bottom-left corner for the pop-up stack).
func pivot_of(id: String) -> Vector2:
	var r := part_rect(id)
	if id == "notifier":
		return Vector2(r.position.x, r.end.y)
	return r.get_center()

# Parts live on the scaled HUD canvas; the label elements use plain screen pixels.
func space_scale(id: String) -> float:
	return 1.0 if EXT.has(id) else Settings.hud_scale

func attach(id: String, nodes: Array) -> void:
	var list: Array = []
	for n: Control in nodes:
		list.append([n, n.position])
	_ext[id] = list
	apply_layout()

# Pushes the layout (offset, size, opacity, visibility) onto the part nodes.
func apply_layout() -> void:
	_rev_seen = HudLayout.rev
	var s := _vs()
	for id in HudLayout.IDS:
		var p: HudPart = _parts.get(id)
		if p == null:
			continue
		var sc := HudLayout.num(id, "scale")
		var shown := HudLayout.flag(id, "vis")
		if id == "shield" and HudLayout.text("shield", "style") != "own":
			sc = 1.0         # inside the health tube: nothing to place
		p.size = s
		p.pivot_offset = part_rect(id).get_center()
		p.scale = Vector2(sc, sc)
		if id == "shield" and HudLayout.text("shield", "style") != "own":
			p.position = Vector2.ZERO
		else:
			p.position = Vector2(HudLayout.num(id, "ox"), HudLayout.num(id, "oy"))
		p.visible = shown or edit_mode
		p.modulate = Color(1, 1, 1, HudLayout.num(id, "alpha") if shown else 0.25)
		p.queue_redraw()
	for id: String in EXT:
		if not _ext.has(id):
			continue
		var off := Vector2(HudLayout.num(id, "ox"), HudLayout.num(id, "oy"))
		var sc := HudLayout.num(id, "scale")
		var a := HudLayout.num(id, "alpha") if HudLayout.flag(id, "vis") else (0.25 if edit_mode else 0.0)
		var pv := pivot_of(id)
		for item: Array in _ext[id]:
			var n: Control = item[0]
			var dpos: Vector2 = item[1]
			var fid := HudLayout.font_id(id)
			if n.has_method("set_shift"):
				n.call("set_shift", off, sc, a)
				n.call("set_text_style", fid, HudLayout.tmult(id))
				continue
			if id == "bosswarn" or id == "banner":
				n.add_theme_font_override("font", HudFonts.get_font(fid))
				n.add_theme_font_size_override("font_size", HudFonts.size_for(fid, 30.0 if id == "bosswarn" else 52.0, HudLayout.tmult(id)))
			n.position = dpos + off
			n.scale = Vector2(sc, sc)
			n.pivot_offset = pv - dpos
			if id == "banner" or id == "bosswarn":
				n.self_modulate.a = a        # the game animates their modulate (tween / pulse)
			else:
				n.modulate.a = a

func set_edit_mode(on: bool) -> void:
	edit_mode = on
	_demo(on)
	apply_layout()

# While editing, the wave banner and boss warning show sample text so they can be placed.
func _demo(on: bool) -> void:
	var bl: Label = null
	var bn: Label = null
	if _ext.has("bosswarn"):
		bl = (_ext["bosswarn"] as Array)[0][0]
	if _ext.has("banner"):
		bn = (_ext["banner"] as Array)[0][0]
	if bl == null or bn == null:
		return
	if on:
		_saved = {"bw_vis": bl.visible, "bw_txt": bl.text, "bn_txt": bn.text, "bn_a": bn.modulate.a}
		bl.visible = true
		if bl.text == "":
			bl.text = Loc.t("!!  BOSS WAVE  !!")
		if bn.text == "":
			bn.text = Loc.t("Wave 1")
		bn.modulate.a = 1.0
	elif not _saved.is_empty():
		bl.visible = _saved["bw_vis"]
		bl.text = _saved["bw_txt"]
		bn.text = _saved["bn_txt"]
		bn.modulate.a = _saved["bn_a"]
		_saved = {}

# Where an element is on the (unscaled) HUD canvas right now, offset and size included.
func placed_rect(id: String) -> Rect2:
	var r := part_rect(id)
	var sc := HudLayout.num(id, "scale")
	var pv := pivot_of(id)
	var off := Vector2(HudLayout.num(id, "ox"), HudLayout.num(id, "oy"))
	if id == "shield" and HudLayout.text("shield", "style") != "own":
		sc = 1.0
		off = Vector2.ZERO
	return Rect2(pv + off + (r.position - pv) * sc, r.size * sc)

# ---------- health, mana, level medallion ----------

func _shield_frac() -> float:
	var cap := base.shield_cap()
	if cap <= 0.0:
		return 0.7 if edit_mode else 0.0
	return clampf(base.shield / cap, 0.0, 1.0)

func _shield_value() -> int:
	if base.shield_cap() <= 0.0:
		return 70 if edit_mode else 0
	return ceili(base.shield)

func _draw_bars(s: Vector2) -> void:
	var k := HUD_K
	var e := HudLayout.bar_extra()
	var tl := HudArt.TL + e
	var cx := HudArt.CX + e
	var cw := HudArt.CW + 2 * e
	var ox := roundf(s.x * 0.5 - float(cx) * k)
	var oy := s.y - HUD_UP
	var yc := oy + float(HudArt.YC) * k
	var ty := oy + float(HudArt.YC - HudArt.TR) * k
	var th := float(HudArt.TR * 2 + 1) * k
	var xr := ox + float(cx - HudArt.TGAP) * k            # inner edge of the health tube (next to the medallion)
	var xl := ox + float(cx + HudArt.TGAP) * k            # inner edge of the mana tube
	var tw := float(tl) * k
	var hr := clampf(base.hp / base.max_hp, 0.0, 1.0)
	var er := clampf(base.energy / base.max_energy, 0.0, 1.0)
	var warn := HudLayout.flag("bars", "warn")
	ci.draw_texture_rect(HudArt.bar_tex("back", e), Rect2(Vector2(ox, oy), Vector2(float(cw), float(HudArt.CH)) * k), false)
	# damage trail, then the health liquid (it drains towards the left, away from the medallion)
	var gw := floori(float(tl) * clampf(_hp_ghost, 0.0, 1.0))
	var fw := floori(float(tl) * clampf(_hp_front, 0.0, 1.0))
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	var th_a := HudArt.TR * 2 + 1
	if gw > fw and HudLayout.flag("bars", "trail"):
		ci.draw_texture_rect_region(HudArt.bar_tex("ghost_l", e), Rect2(xr - float(gw) * k, ty, float(gw - fw) * k, th), Rect2(tl - gw, 0, gw - fw, th_a))
	if fw > 0:
		ci.draw_texture_rect_region(HudArt.bar_tex("red_l", e), Rect2(xr - float(fw) * k, ty, float(fw) * k, th), Rect2(tl - fw, 0, fw, th_a))
		if hr < 0.3 and warn:
			ci.draw_rect(Rect2(xr - float(fw) * k, ty, float(fw) * k, th), Color(1.0, 0.1, 0.05, 0.22 * floorf(pulse * 2.0)))
		_tube_end(xr - float(fw) * k, ty, th, k, false)
	# mana liquid (drains to the right)
	var ew := floori(float(tl) * clampf(_en_front, 0.0, 1.0))
	if ew > 0:
		ci.draw_texture_rect_region(HudArt.bar_tex("blue_r", e), Rect2(xl, ty, float(ew) * k, th), Rect2(0, 0, ew, th_a))
		if er < 0.2 and warn:
			ci.draw_rect(Rect2(xl, ty, float(ew) * k, th), Color(1.0, 0.1, 0.05, 0.22 * floorf(pulse * 2.0)))
		if _en_gain > 0.05:
			var shx := floorf(fposmod(_t * 70.0, float(tl) + 20.0)) - 10.0
			var x_a := clampf(shx, 0.0, float(ew))
			var x_b := clampf(shx + 5.0, 0.0, float(ew))
			if x_b > x_a:
				ci.draw_rect(Rect2(xl + x_a * k, ty + 2.0 * k, (x_b - x_a) * k, th - 4.0 * k), Color(1, 1, 1, 0.28 * _en_gain))
		_tube_end(xl + float(ew) * k, ty, th, k, true)
	# energy shield as an ice layer inside the top of the health tube (the other style is its own tube, see _draw_shield_own)
	if HudLayout.text("shield", "style") == "layer" and HudLayout.flag("shield", "vis") and _shield_value() > 0:
		var sw := floori(float(tl) * _shield_frac())
		if sw > 0:
			ci.draw_texture_rect_region(HudArt.bar_tex("ice_l", e), Rect2(xr - float(sw) * k, ty + k, float(sw) * k, 7.0 * k), Rect2(tl - sw, 0, sw, 7))
		if HudLayout.flag("shield", "text"):
			_cur = "shield"
			_tx(Vector2(xr - tw + 8.0, ty - 6.0), "%s %d" % [Loc.t("Shield"), _shield_value()], 20, Color(0.75, 0.95, 1.0), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
			_cur = "bars"
	ci.draw_texture_rect(HudArt.bar_tex("front", e), Rect2(Vector2(ox, oy), Vector2(float(cw), float(HudArt.CH)) * k), false)
	if HudLayout.flag("bars", "crit"):
		if _crit_flash > 0.01:
			var cf := Rect2(Vector2(ox + float(cx - HudArt.HALF - e) * k - 6.0, oy + float(HudArt.YC - HudArt.R) * k - 6.0), Vector2(float((HudArt.HALF + e) * 2) * k + 12.0, float(HudArt.R * 2 + 1) * k + 12.0))
			ci.draw_rect(cf, Color(1.0, 0.25, 0.1, 0.8 * _crit_flash * Settings.flash_scale), false, 4.0)
		for sh in _shards:
			var life := float(sh[3])
			ci.draw_rect(Rect2(sh[0] as Vector2, sh[2] as Vector2), Color(0.95, 0.2, 0.15, life))
			ci.draw_rect(Rect2(sh[0] as Vector2, sh[2] as Vector2), Color(1.0, 0.9, 0.7, 0.8 * life), false, 2.0)
	# numbers on the tubes and the level in the medallion
	var mode := HudLayout.text("bars", "nums")
	if mode != "off":
		var nsz: int = {"small": 20, "normal": 30, "large": 40}[HudLayout.text("bars", "numsize")]
		var hp_text := "%d / %d" % [ceili(base.hp), ceili(base.max_hp)]
		var en_text := "%d / %d" % [int(base.energy), int(base.max_energy)]
		if mode == "value":
			hp_text = str(ceili(base.hp))
			en_text = str(int(base.energy))
		var ny := ty + th * 0.5 + float(nsz) / 3.0
		_tx(Vector2(xr - tw, ny), hp_text, nsz, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, tw, 5)
		_tx(Vector2(xl, ny), en_text, nsz, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, tw, 5)
	var lv_size := 40 if base.xp_level < 10 else 30
	_tx(Vector2(s.x * 0.5 - 40.0, yc + (14.0 if lv_size == 40 else 11.0)), str(base.xp_level), lv_size, Color(1.0, 0.9, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 5)

# The shield in a small bronze tube of its own, centred above the level medallion.
func _draw_shield_own(s: Vector2) -> void:
	var k := HUD_K
	var cap := base.shield_cap()
	if cap <= 0.0 and not edit_mode:
		return
	var w := float(HudArt.TL) * k
	var h := 7.0 * k
	var x := roundf(s.x * 0.5 - w * 0.5)
	var y := s.y - HUD_UP - 24.0
	var bronze := [Color(0.08, 0.04, 0.03), Color(0.33, 0.2, 0.1), Color(0.5, 0.31, 0.14), Color(0.68, 0.46, 0.2), Color(0.92, 0.78, 0.47)]
	ci.draw_rect(Rect2(x - 9.0, y - 9.0, w + 18.0, h + 18.0), bronze[0])
	ci.draw_rect(Rect2(x - 6.0, y - 6.0, w + 12.0, h + 12.0), bronze[2])
	ci.draw_rect(Rect2(x - 6.0, y - 6.0, w + 12.0, 2.0), bronze[4])
	ci.draw_rect(Rect2(x - 6.0, y - 4.0, w + 12.0, 2.0), bronze[3])
	ci.draw_rect(Rect2(x - 6.0, y + h + 2.0, w + 12.0, 2.0), bronze[1])
	ci.draw_rect(Rect2(x - 6.0, y + h + 4.0, w + 12.0, 2.0), bronze[0])
	ci.draw_rect(Rect2(x - 3.0, y - 3.0, w + 6.0, h + 6.0), Color(0.03, 0.02, 0.06))
	ci.draw_rect(Rect2(x, y, w, h), Color(0.05, 0.07, 0.12))
	var sw := floori(float(HudArt.TL) * _shield_frac())
	if sw > 0:
		ci.draw_texture_rect_region(HudArt.tex("ice_l"), Rect2(x, y, float(sw) * k, h), Rect2(0, 0, sw, 7))
		ci.draw_rect(Rect2(x + float(sw) * k - k, y + k, k, h - 2.0 * k), Color(1, 1, 1, 0.7))
	if HudLayout.flag("shield", "text"):
		_tx(Vector2(x, y + h * 0.5 + 7.0), "%s %d" % [Loc.t("Shield"), _shield_value()], 20, Color(0.85, 0.97, 1.0), HORIZONTAL_ALIGNMENT_CENTER, w, 4)

# Blinking "[Tab] Stat points: N" tag above the beam.
func _draw_tag(s: Vector2) -> void:
	var pts := base.free_points
	if pts <= 0:
		if not edit_mode:
			return
		pts = 3
	var top := part_rect("tag").position.y
	var blink := 0.5 + 0.5 * sin(_t * 5.0)
	var tag := "[%s]  %s: %d" % [Keybinds.key_text("open_shop"), Loc.t("Stat points"), pts]
	var tag_w := PixelUI.font().get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelUI.fs(20)).x + 30.0
	var bob := roundf(sin(_t * 6.0) * 2.0) if HudLayout.flag("tag", "bounce") else 0.0
	var tag_box := PixelUI.box(Color(0.1, 0.35, 0.16, 0.55 + 0.3 * blink), Color(0.35, 0.9, 0.5), 2)
	ci.draw_style_box(tag_box, Rect2(s.x * 0.5 - tag_w * 0.5, top + bob, tag_w, 30.0))
	_tx(Vector2(s.x * 0.5 - tag_w * 0.5, top + 21.0 + bob), tag, 20, Color(0.55, 1.0, 0.65).lerp(Color.WHITE, blink), HORIZONTAL_ALIGNMENT_CENTER, tag_w, 4)

# Boss health at the top middle of the screen, in the same bronze + glass style as the player bars.
var _boss_ghost: Dictionary = {}     # boss instance id -> slow damage trail (0..1)

func _draw_boss_bars(s: Vector2) -> void:
	var y := 64.0
	var live: Array = []
	for m in Field.mobs():
		if m is Boss and not m.dead:
			live.append(m)
	for id in _boss_ghost.keys():
		var found := false
		for m in live:
			if (m as Node).get_instance_id() == id:
				found = true
		if not found:
			_boss_ghost.erase(id)
	if live.is_empty() and edit_mode:
		_boss_bar(Vector2(s.x * 0.5, y), 560.0, 27.0, 0.65, 0.8, Loc.t("Mud Colossus"), "6500 / 10000")
		return
	var dt := get_process_delta_time()
	for m in live:
		var b: Boss = m
		var frac := clampf(b.hp / b.max_hp, 0.0, 1.0)
		var id := b.get_instance_id()
		var gh: float = _boss_ghost.get(id, frac)
		gh = frac if frac > gh else lerpf(gh, frac, 1.0 - exp(-1.6 * dt))
		_boss_ghost[id] = gh
		var title := b.boss_name
		if b.ability == "titan":
			title = Loc.t("%s  -  Phase %d/3") % [b.boss_name, b.phase]
		_boss_bar(Vector2(s.x * 0.5, y), 560.0, 27.0, frac, gh, title, "%d / %d" % [ceili(b.hp), ceili(b.max_hp)])
		y += 64.0

func _boss_bar(c: Vector2, w: float, h: float, frac: float, ghost: float, title: String, hp_text: String) -> void:
	var u := 3.0
	var x := roundf(c.x - w * 0.5)
	var y := roundf(c.y)
	var cap := 30.0
	# bronze beam with end caps
	var fx := x - cap
	var fw_ := w + cap * 2.0
	var bronze := [Color(0.08, 0.04, 0.03), Color(0.33, 0.2, 0.1), Color(0.5, 0.31, 0.14), Color(0.68, 0.46, 0.2), Color(0.92, 0.78, 0.47)]
	var ft := y - 9.0
	var fh := h + 18.0
	ci.draw_rect(Rect2(fx - 3.0, ft - 3.0, fw_ + 6.0, fh + 6.0), bronze[0])
	ci.draw_rect(Rect2(fx, ft, fw_, fh), bronze[2])
	ci.draw_rect(Rect2(fx, ft, fw_, 3.0), bronze[4])
	ci.draw_rect(Rect2(fx, ft + 3.0, fw_, 3.0), bronze[3])
	ci.draw_rect(Rect2(fx, ft + fh - 6.0, fw_, 3.0), bronze[1])
	ci.draw_rect(Rect2(fx, ft + fh - 3.0, fw_, 3.0), bronze[0])
	for rx in [fx + 12.0, fx + fw_ - 15.0]:
		ci.draw_rect(Rect2(rx, y + h * 0.5 - 6.0, 6.0, 12.0), bronze[1])
		ci.draw_rect(Rect2(rx, y + h * 0.5 - 6.0, 3.0, 3.0), bronze[4])
	# dark trough
	ci.draw_rect(Rect2(x - 3.0, y - 3.0, w + 6.0, h + 6.0), Color(0.03, 0.02, 0.06))
	ci.draw_rect(Rect2(x, y, w, h), Color(0.07, 0.05, 0.12))
	var fw := floorf(w * frac / u) * u
	var gw := floorf(w * ghost / u) * u
	if gw > fw:
		ci.draw_rect(Rect2(x + fw, y, gw - fw, h), Color(1.0, 0.82, 0.95, 0.85))
		ci.draw_rect(Rect2(x + fw, y, gw - fw, u), Color(1, 1, 1, 0.9))
	if fw > 0.0:
		# glass tube shading: dark rim, bright top, body, soft bottom reflection
		var rows: Array = [Color(0.2, 0.05, 0.3), Color(0.9, 0.7, 1.0), Color(0.78, 0.45, 1.0), Color(0.66, 0.3, 0.96), Color(0.58, 0.22, 0.9), Color(0.55, 0.2, 0.86), Color(0.5, 0.17, 0.8), Color(0.42, 0.12, 0.68), Color(0.3, 0.07, 0.5)]
		var rh := h / float(rows.size())
		for i in rows.size():
			ci.draw_rect(Rect2(x, y + floorf(float(i) * rh / u) * u, fw, ceilf(rh / u) * u), rows[i])
		var glint := fposmod(_t * 140.0, w + 160.0) - 80.0
		var g0 := clampf(glint, 0.0, fw)
		var g1 := clampf(glint + 5.0 * u, 0.0, fw)
		if g1 > g0:
			ci.draw_rect(Rect2(x + g0, y + u, g1 - g0, u), Color(1, 1, 1, 0.55))
		ci.draw_rect(Rect2(x + fw - u, y + u, u, h - u * 2.0), Color(1, 1, 1, 0.75))
	# glass streak across the top, even over the empty part
	ci.draw_rect(Rect2(x + u * 2.0, y + u * 2.0, w - u * 4.0, 2.0), Color(1, 1, 1, 0.12))
	_tx(Vector2(x, y - 16.0), title, 20, Color(0.95, 0.82, 1.0), HORIZONTAL_ALIGNMENT_CENTER, w, 4)
	_tx(Vector2(x, y + h * 0.5 + 9.0), hp_text, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w, 4)

# Bright rim on the moving end of a liquid; `grows_right` is true when the liquid extends to the left of x.
func _tube_end(x: float, ty: float, th: float, k: float, liquid_left_of_x: bool) -> void:
	var edge := x - k if liquid_left_of_x else x
	ci.draw_rect(Rect2(edge, ty + 2.0 * k, k, th - 4.0 * k), Color(1, 1, 1, 0.7))
	var glow_x := x - 4.0 * k if liquid_left_of_x else x + k
	ci.draw_rect(Rect2(glow_x, ty + 2.0 * k, 3.0 * k, th - 4.0 * k), Color(1, 1, 1, 0.16))

# Thin gold XP tube under the beam, with the level text under it.
func _draw_xp(s: Vector2, ox: float, oy: float) -> void:
	var k := HUD_K
	var xp_need := Base.xp_needed(base.xp_level)
	var xp_frac := clampf(float(base.xp) / float(xp_need), 0.0, 1.0)
	var xe := HudLayout.xp_extra()
	var xwa := HudArt.XW + xe
	var glow_on := HudLayout.flag("xp", "glow")
	var xr := Rect2(s.x * 0.5 - float(xwa) * k * 0.5, oy + float(HudArt.YC + HudArt.R + 3) * k, float(xwa) * k, float(HudArt.XH) * k)
	var front_frac := fposmod(_xp_front, 1.0)
	var tgt_frac := fposmod(_xp_target, 1.0)
	if floorf(_xp_target) > floorf(_xp_front) + 0.001:
		tgt_frac = 1.0                      # the bar is still catching up to a level-up
	ci.draw_texture_rect(HudArt.xp_tex("xp_back", xe), xr, false)
	var inner := Rect2(xr.position + Vector2(k, k), xr.size - Vector2(2.0 * k, 2.0 * k))
	var fwa := floori(float(xwa) * front_frac)
	var twa := floori(float(xwa) * tgt_frac)
	var fw := float(fwa) * k
	var tw := float(twa) * k
	if twa > fwa + 1:
		var pulse := 0.5 + 0.5 * sin(_t * 12.0)
		ci.draw_rect(Rect2(xr.position.x + fw, inner.position.y, tw - fw, inner.size.y), Color(1.0, 0.95, 0.6, 0.45 + 0.3 * pulse))      # the XP just earned
	if fwa > 1:
		ci.draw_texture_rect_region(HudArt.xp_tex("xp_fill", xe), Rect2(xr.position.x, xr.position.y, fw, xr.size.y), Rect2(0, 0, fwa, HudArt.XH))
		var shine := fposmod(_t * 160.0, xr.size.x + 200.0) - 100.0
		var sx0 := clampf(shine, 0.0, fw)
		var sx1 := clampf(shine + 60.0, 0.0, fw)
		if sx1 - sx0 > 1.0:
			ci.draw_rect(Rect2(xr.position.x + sx0, inner.position.y, sx1 - sx0, inner.size.y), Color(1.0, 1.0, 0.85, 0.35))
		ci.draw_rect(Rect2(xr.position.x + fw - 3.0, xr.position.y - 3.0, 6.0, xr.size.y + 6.0), Color(1.0, 0.9, 0.4, 0.28 + 0.4 * _xp_glow))
		ci.draw_rect(Rect2(xr.position.x + fw - 3.0, inner.position.y, 3.0, inner.size.y), Color(1.0, 1.0, 0.8))
	if _xp_glow > 0.02 and glow_on:
		# gain animation: a bright flare and sparkles rising from the tip
		ci.draw_rect(Rect2(xr.position.x, inner.position.y, maxf(fw, tw), inner.size.y), Color(1.0, 0.95, 0.6, 0.35 * _xp_glow))
		for i in 7:
			var life := fposmod(_t * 1.8 + float(i) * 0.37, 1.0)
			var spx := xr.position.x + fw - 6.0 + sin(float(i) * 2.3) * 26.0
			var spy := xr.position.y - life * 34.0
			ci.draw_rect(Rect2(floorf(spx / 3.0) * 3.0, floorf(spy / 3.0) * 3.0, 3.0, 3.0), Color(1.0, 0.92, 0.5, 0.9 * _xp_glow * (1.0 - life)))
	if _xp_flash > 0.01 and glow_on:
		# level-up: the tube flashes
		ci.draw_rect(Rect2(xr.position.x - 8.0, xr.position.y - 8.0, xr.size.x + 16.0, xr.size.y + 16.0), Color(1.0, 0.95, 0.55, 0.75 * _xp_flash * Settings.flash_scale))
	var xmode := HudLayout.text("xp", "text")
	if xmode != "off":
		var xp_text := "%s %d     XP %d / %d   (%d%%)" % [Loc.t("Level"), base.xp_level, base.xp, xp_need, int(xp_frac * 100.0)]
		if xmode == "level":
			xp_text = "%s %d" % [Loc.t("Level"), base.xp_level]
		_tx(Vector2(0.0, s.y - 98.0), xp_text, 20, Color(1.0, 0.97, 0.85), HORIZONTAL_ALIGNMENT_CENTER, s.x, 5)

# Round radar at the bottom right: you (orange) in the middle, enemies red, bosses purple.
func _draw_minimap(s: Vector2) -> void:
	var c := Vector2(s.x - 30.0 - MAP_RADIUS, s.y - 30.0 - MAP_RADIUS)
	var k := MAP_RADIUS / HudLayout.num("minimap", "range")
	var boss_only := HudLayout.flag("minimap", "bossonly")
	if _map_tex == null:
		_build_map_tex()
	ci.draw_texture_rect(_map_tex, Rect2(c - Vector2(MAP_RADIUS, MAP_RADIUS), Vector2(MAP_RADIUS, MAP_RADIUS) * 2.0), false)
	for a in Field.mobs():
		if a.dead or not a.is_ally or boss_only:
			continue
		var arel := (a.global_position - base.global_position) * k
		if arel.length() <= MAP_RADIUS - 5.0:
			ci.draw_rect(_snap(c + arel, 3.0, 6.0), Color(0.3, 1.0, 0.4))      # refugees: green
	for e in Field.enemies():
		if e.dead:
			continue
		var rel := (e.global_position - base.global_position) * k
		var big := e.kind == "boss" or e.kind == "minicastle"
		if boss_only and not big:
			continue
		var dist := rel.length()
		if dist > MAP_RADIUS - 5.0:
			if not big:
				continue
			rel = rel / dist * (MAP_RADIUS - 6.0)         # bosses stay on the rim so you know where they are
		if big:
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			ci.draw_rect(_snap(c + rel, 3.0, 15.0 if pulse > 0.5 else 12.0), Color(0.7, 0.3, 1.0, 0.35))
			ci.draw_rect(_snap(c + rel, 3.0, 9.0), Color(0.75, 0.35, 1.0))
		else:
			ci.draw_rect(_snap(c + rel, 3.0, 6.0), Color(1.0, 0.2, 0.2))
	ci.draw_rect(_snap(c, 3.0, 12.0), Color(0, 0, 0, 0.6))
	ci.draw_rect(_snap(c, 3.0, 9.0), Color(1.0, 0.6, 0.1))

# a square of `size` px centred on p, snapped to the 3 px pixel grid
func _snap(p: Vector2, unit: float, size: float) -> Rect2:
	return Rect2(floorf((p.x - size * 0.5) / unit + 0.5) * unit, floorf((p.y - size * 0.5) / unit + 0.5) * unit, size, size)

# The radar background as a small pixel image: a filled disc, a bright rim, faint cross and half ring.
func _build_map_tex() -> void:
	var n := int(MAP_RADIUS * 2.0 / 3.0)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := float(n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(float(x) + 0.5 - r, float(y) + 0.5 - r).length()
			if d > r:
				continue
			var c := Color(0.04, 0.06, 0.09, 0.62)
			if d > r - 1.2:
				c = Color(0.9, 0.92, 1.0, 0.85)
			elif d > r - 2.2:
				c = Color(0.02, 0.02, 0.05, 0.85)
			elif absf(d - r * 0.5) < 0.6 or absi(x - int(r)) == 0 or absi(y - int(r)) == 0:
				c = Color(0.5, 0.55, 0.7, 0.35)
			img.set_pixel(x, y, c)
	_map_tex = ImageTexture.create_from_image(img)

func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	_tx(pos, text, font_size, color, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5, Color.BLACK)

# Text in the font and size the HUD editor gave to the element being drawn (`_cur`).
# `size` is what the default font draws; other fonts are snapped to their own pixel grid.
var _cur: String = ""

func _tx(pos: Vector2, s: String, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: int = 0, oc: Color = PixelUI.OUTLINE) -> void:
	var fid := HudLayout.font_id(_cur)
	var f := HudFonts.get_font(fid)
	var sz := HudFonts.size_for(fid, float(size), HudLayout.tmult(_cur))
	if outline > 0:
		ci.draw_string_outline(f, pos, s, align, width, sz, outline, oc)
	ci.draw_string(f, pos, s, align, width, sz, col)

func _tw(id: String, txt: String, size: int) -> float:
	var fid := HudLayout.font_id(id)
	var sz := HudFonts.size_for(fid, float(size), HudLayout.tmult(id))
	return HudFonts.get_font(fid).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x

# Capital letter height of a text of base size `size` for element `id`.
func _cap(id: String, size: int) -> float:
	var fid := HudLayout.font_id(id)
	var sz := float(HudFonts.size_for(fid, float(size), HudLayout.tmult(id)))
	return sz * (float(HudFonts.CAP[fid]) if HudFonts.CAP.has(fid) else 0.7)

# Pixel bar: dark outline, 3 px steps, banded fill (light top / dark bottom), a trailing "damage" ghost,
# a blinking red frame when the value is low.
func _bar(pos: Vector2, bar_size: Vector2, front: float, ghost: float, col: Color, col2: Color, text: String, charge: float, low: bool) -> void:
	var u := 3.0
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	if low:
		ci.draw_rect(Rect2(pos - Vector2(9, 9), bar_size + Vector2(18, 18)), Color(0.9, 0.1, 0.1, (0.10 + 0.22 * pulse) * floorf(1.0 + pulse * 1.99) * 0.5))
	ci.draw_rect(Rect2(pos - Vector2(6, 6), bar_size + Vector2(12, 12)), PixelUI.OUTLINE)
	ci.draw_rect(Rect2(pos - Vector2(3, 3), bar_size + Vector2(6, 6)), col.darkened(0.55).lerp(Color(0.2, 0.2, 0.3), 0.4))
	ci.draw_rect(Rect2(pos, bar_size), Color(0.05, 0.05, 0.08))
	var fw := floorf(bar_size.x * clampf(front, 0.0, 1.0) / u) * u
	var gw := floorf(bar_size.x * clampf(ghost, 0.0, 1.0) / u) * u
	if gw > fw:
		ci.draw_rect(Rect2(pos.x + fw, pos.y, gw - fw, bar_size.y), Color(1.0, 1.0, 1.0, 0.7))
	if fw > 0.0:
		var base_col := col.lerp(Color(1.0, 0.3, 0.3), 0.35 * floorf(pulse * 2.0)) if low else col
		var h := bar_size.y
		ci.draw_rect(Rect2(pos, Vector2(fw, h)), base_col.darkened(0.25))
		ci.draw_rect(Rect2(pos, Vector2(fw, h - u * 2.0)), base_col)
		ci.draw_rect(Rect2(pos, Vector2(fw, u * 2.0)), col2.lerp(base_col, 0.25))
		ci.draw_rect(Rect2(pos + Vector2(0, u), Vector2(fw, u)), col2.lightened(0.25))
		# a lit block travelling along the bar
		var sx := floorf((fposmod(_t * 110.0, bar_size.x + 120.0) - 60.0) / u) * u
		var x0 := clampf(pos.x + sx, pos.x, pos.x + fw)
		var x1 := clampf(pos.x + sx + 4.0 * u, pos.x, pos.x + fw)
		if x1 - x0 > 1.0:
			ci.draw_rect(Rect2(x0, pos.y + u, x1 - x0, h - u * 2.0), Color(1, 1, 1, 0.22))
		if charge > 0.05:
			for i in 3:
				var px := floorf((pos.x + fposmod(_t * 160.0 + i * 140.0, maxf(fw, 1.0))) / u) * u
				var py := pos.y + floorf((h * 0.5 + sin(_t * 9.0 + i) * 4.0) / u) * u
				ci.draw_rect(Rect2(px, py, u, u), Color(1, 1, 0.8, 0.9 * charge))
	# segment ticks, one pixel column every 10%
	for i in range(1, 10):
		var tx := floorf((pos.x + bar_size.x * i / 10.0) / u) * u
		ci.draw_rect(Rect2(tx, pos.y, u, bar_size.y), Color(0, 0, 0, 0.28))
	_tx(pos + Vector2(14, bar_size.y - 6), text, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)

func _draw_coins(s: Vector2) -> void:
	var pos := Vector2(s.x - 230.0, 44.0)
	ci.draw_texture_rect(CoinTex.get_texture(), Rect2(pos, Vector2(42, 42)), false)
	_text(pos + Vector2(56, 33), "x %d" % coins, 32, Color(1.0, 0.9, 0.3))

func _draw_skills(s: Vector2) -> void:
	var gap := HudLayout.num("skills", "gap")
	var total := SLOT * 4.0 + gap * 3.0
	var x0 := (s.x - total) * 0.5
	var y := s.y - 92.0
	var keys_on := HudLayout.flag("skills", "keys")
	var cd_on := HudLayout.flag("skills", "cdnum")
	for i in 4:
		var r := Rect2(x0 + i * (SLOT + gap), y, SLOT, SLOT)
		var id := base.skill_slots[i]
		var active_time := 0.0
		var active_col := Color(0.3, 1.0, 1.0)
		if id == "overcharge":
			active_time = base.boost_time
			active_col = Color(1.0, 0.65, 0.2)
		var active := active_time > 0.0
		ci.draw_rect(r, Color(0.07, 0.05, 0.04, 0.92))
		if id != "":
			_draw_skill_icon(id, r)
			var cd := base.skill_cd[i]
			if cd > 0.0:
				ci.draw_rect(r, Color(0, 0, 0, 0.6))
				var fill_h := SLOT * (1.0 - cd / base.skill_cd_max[i])
				ci.draw_rect(Rect2(r.position.x, r.end.y - fill_h, SLOT, fill_h), Color(1, 1, 1, 0.12))
				if cd_on:
					_text(r.get_center() + Vector2(-8, 10), str(ceili(cd)), 26, Color.WHITE)
			if active:
				_text(r.position + Vector2(8, SLOT - 6), "%.1f" % active_time, 18, active_col.lightened(0.4))
			if id == "repair":
				var price := base.repair_cost()
				var ok := coins >= price
				_text(r.position + Vector2(SLOT - 40.0 - (8.0 if price >= 100 else 0.0), SLOT - 6), str(price), 18, Color(1.0, 0.85, 0.3) if ok else Color(1.0, 0.35, 0.3))
		ci.draw_style_box(PixelUI.plate(Color(0, 0, 0, 0), (active_col if active else Color(0.8, 0.6, 0.3)) if id != "" else Color(0.4, 0.3, 0.2), 2), r)
		if keys_on:
			_text(r.position + Vector2(6, 18), Keybinds.key_text("skill_%d" % (i + 1)), 16, Color(1.0, 0.9, 0.5))

func _draw_skill_icon(id: String, r: Rect2) -> void:
	var c := r.get_center()
	var h := r.size.y
	match id:
		"overcharge":
			Icons.draw(ci, "damage", r.position, h / 64.0, false)
			var glow := 0.5 + 0.5 * sin(_t * 6.0)
			if base.boost_time > 0.0:
				ci.draw_rect(r, Color(1.0, 0.6, 0.15, 0.18 + 0.18 * glow))
		"repair":
			Icons.draw(ci, "repair", r.position, h / 64.0, false)
		"barrier":
			var pts := PackedVector2Array([
				c + Vector2(-0.30, -0.28) * h, c + Vector2(0.30, -0.28) * h,
				c + Vector2(0.32, 0.04) * h, c + Vector2(0.0, 0.36) * h,
				c + Vector2(-0.32, 0.04) * h,
			])
			ci.draw_colored_polygon(pts, Color(0.25, 0.75, 1.0))
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(c + (p - c) * 0.6)
			ci.draw_colored_polygon(inner, Color(0.6, 0.92, 1.0))
			var outline := pts.duplicate()
			outline.append(pts[0])
			ci.draw_polyline(outline, Color.WHITE, 2.5)

# Current weapon icon next to the energy and health bars.
func _draw_weapon(pos: Vector2) -> void:
	Icons.draw(ci, Weapons.id_of(base.weapon_tier), pos, 62.0 / 64.0, true)
	if HudLayout.flag("weapon", "frame"):
		var col: Color = Weapons.COLORS[base.weapon_tier]
		ci.draw_style_box(PixelUI.plate(Color(0, 0, 0, 0), col, 2), Rect2(pos, Vector2(62, 62)))

# Wave plaque: the wave number, the region and the castle stage on a bronze plate.
# Returns [width, height, baseline 1, divider y, baseline 2, baseline 3] (relative to the plate's corner).
func _info_metrics() -> Array:
	var wave := "%s %d" % [Loc.t("Wave"), info_wave]
	var w := maxf(maxf(_tw("info", wave, 40), maxf(_tw("info", info_biome, 30), _tw("info", info_castle, 20))) + 52.0, 260.0)
	var b1 := 14.0 + _cap("info", 40)
	var dv := b1 + 9.0
	var b2 := dv + 8.0 + _cap("info", 30)
	var b3 := b2 + 12.0 + _cap("info", 20)
	return [w, b3 + 16.0, b1, dv, b2, b3]

func _draw_info() -> void:
	var m := _info_metrics()
	var w: float = m[0]
	var h: float = m[1]
	var r := Rect2(28.0, 20.0, w, h)
	ci.draw_style_box(PixelUI.box(Color(0.085, 0.063, 0.045, 0.9), PixelUI.BRONZE, 2), r)
	var tx := r.position.x + 26.0
	var wave := "%s %d" % [Loc.t("Wave"), info_wave]
	_tx(Vector2(tx, r.position.y + float(m[2])), wave, 40, PixelUI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5)
	ci.draw_rect(Rect2(tx, r.position.y + float(m[3]), w - 52.0, 2.0), Color(0.85, 0.65, 0.2, 0.55))
	ci.draw_rect(Rect2(tx, r.position.y + float(m[3]) + 2.0, w - 52.0, 2.0), Color(0, 0, 0, 0.5))
	_tx(Vector2(tx, r.position.y + float(m[4])), info_biome, 30, Color(1.0, 0.95, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5)
	_tx(Vector2(tx, r.position.y + float(m[5])), info_castle, 20, Color(0.8, 0.7, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	# rivets on the plate
	for p in [Vector2(10.0, 10.0), Vector2(w - 16.0, 10.0), Vector2(10.0, h - 16.0), Vector2(w - 16.0, h - 16.0)]:
		ci.draw_rect(Rect2(r.position + p, Vector2(6.0, 6.0)), Color(0.33, 0.2, 0.1))
		ci.draw_rect(Rect2(r.position + p, Vector2(4.0, 4.0)), Color(0.92, 0.78, 0.47))
	if info_msg != "":
		var mh := _cap("info", 20) + 24.0
		var mw := _tw("info", info_msg, 20) + 32.0
		var mr := Rect2(r.end.x + 12.0, r.position.y + 8.0, mw, mh)
		ci.draw_style_box(PixelUI.plate(Color(0.07, 0.05, 0.04, 0.92), Color(1.0, 0.8, 0.3), 2), mr)
		_tx(Vector2(mr.position.x + 16.0, mr.position.y + mh - 11.0), info_msg, 20, Color(1.0, 0.92, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	if show_debug and info_detail != "":
		var y := part_rect("helpers").end.y + 12.0
		for line in info_detail.split("\n"):
			_tx(Vector2(28.0, y + _cap("info", 20)), line, 20, PixelUI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
			y += _cap("info", 20) + 12.0

# Size of one helper plate: [width, height].
func _helper_size() -> Vector2:
	var most := 99
	if base != null:
		most = maxi(maxi(base.gunners, base.scientists), maxi(base.engineers, base.mechanics))
	var cap := _cap("helpers", 40)
	return Vector2(maxf(128.0, 62.0 + _tw("helpers", "x%d" % maxi(most, 10), 40) + 14.0), maxf(56.0, cap + 24.0))

# Helper allies: a small bronze plate each with the icon and the count.
func _draw_helpers() -> void:
	var kinds := ["gunner", "scientist", "engineer", "mechanic"]
	var counts := [base.gunners, base.scientists, base.engineers, base.mechanics]
	var ps := _helper_size()
	var x := 28.0
	var y := HELPERS_Y
	var column := HudLayout.text("helpers", "layout") == "column"
	var hide_empty := HudLayout.flag("helpers", "hide_empty") and not edit_mode
	for i in 4:
		var kind: String = kinds[i]
		var n: int = counts[i]
		if hide_empty and n == 0:
			continue
		var dim := n == 0
		var pr := Rect2(x, y, ps.x, ps.y)
		ci.draw_style_box(PixelUI.plate(Color(0.07, 0.05, 0.04, 0.9), Color(0.55, 0.45, 0.3) if dim else Color(0.85, 0.65, 0.2), 2), pr)
		var iy := y + (ps.y - 40.0) * 0.5
		Icons.draw(ci, kind, Vector2(x + 10.0, iy), 40.0 / 64.0, true)
		if dim:
			ci.draw_rect(Rect2(Vector2(x + 10.0, iy), Vector2(40, 40)), Color(0, 0, 0, 0.55))
		_tx(Vector2(x + 62.0, y + ps.y * 0.5 + _cap("helpers", 40) * 0.5), "x%d" % n, 40, Color(1, 1, 1, 0.45) if dim else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5)
		if column:
			y += ps.y + 8.0
		else:
			x += ps.x + 10.0
