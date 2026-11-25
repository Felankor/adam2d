class_name Fx
extends Node2D

# Short-lived visual effects: sparks, floating damage numbers, explosions.
var kind: String = "spark"
var life: float = 0.4
var max_life: float = 0.4
var color: Color = Color.WHITE
var text: String = ""
var power: float = 1.0
var _parts: Array = []
var _drift: float = 0.0

# Effects alive right now. Under heavy fire the cheap ones are skipped so the frame rate holds.
static var live: int = 0
const MAX_SPARKS := 90
const MAX_NUMBERS := 140
const MAX_ALL := 220
const VITAL_EXTRA := 80

static func spawn(parent: Node, k: String, pos: Vector2, col: Color = Color.WHITE, txt: String = "", pw: float = 1.0, duration: float = 0.4, vital: bool = false) -> void:
	if parent == null:
		return
	# Death effects (vital) are never dropped because the screen is busy: ordinary hit sparks and numbers are cut first.
	if vital:
		if live >= MAX_ALL + VITAL_EXTRA:
			return
	elif live >= MAX_ALL or (k == "spark" and live >= MAX_SPARKS) or ((k == "number" or k == "coin") and live >= MAX_NUMBERS):
		return
	var f := Fx.new()
	f.kind = k
	f.position = pos
	f.color = col
	f.text = txt
	f.power = pw
	f.life = duration
	f.max_life = duration
	parent.add_child(f)

func _ready() -> void:
	live += 1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 5
	if kind == "number":
		_drift = randf_range(-22.0, 22.0)
	if kind == "coin":
		# power = how many coins pop out; each one: [landing spot, arc height, spin phase, delay]
		for i in clampi(int(power), 1, 6):
			var spot := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(24.0, 85.0)
			_parts.append([spot, randf_range(38.0, 70.0), randf() * TAU, randf() * 0.12])
	if kind == "join":
		# little green pluses drift up around the castle: [start, velocity, size]
		for i in 9:
			_parts.append([Vector2(randf_range(-power * 0.9, power * 0.9), randf_range(0.6, 1.1) * power), Vector2(randf_range(-14.0, 14.0), randf_range(-120.0, -55.0)), randf_range(3.0, 6.0)])
	if kind == "spark" or kind == "explosion" or kind == "void_blast":
		var count := 9 if kind == "spark" else 28
		for i in count:
			var a := randf() * TAU
			var sp := randf_range(70.0, 240.0) * power
			_parts.append([Vector2.ZERO, Vector2.RIGHT.rotated(a) * sp, randf_range(2.0, 5.0)])

# The critical-hit icon: a spiky, fiery starburst in pixel art (red rim, orange, yellow, white-hot core, dark outline).
# Built once as a list of [x, y, colour] cells on a 15x15 grid.
const CRIT_GRID := 15
static var _crit_cells: Array = []

static func _crit_icon_cells() -> Array:
	if not _crit_cells.is_empty():
		return _crit_cells
	var c := CRIT_GRID / 2
	var fill := {}
	for y in CRIT_GRID:
		for x in CRIT_GRID:
			var dx := float(x - c)
			var dy := float(y - c)
			var d := sqrt(dx * dx + dy * dy)
			var a := atan2(dy, dx)
			var rad := 2.2 + 4.8 * pow(absf(cos(4.0 * a)), 2.5)
			if d <= rad:
				var q := d / maxf(rad, 0.01)
				var col := Color(0.86, 0.17, 0.1)
				if d < 1.5:
					col = Color(1.0, 1.0, 0.92)
				elif q < 0.55:
					col = Color(1.0, 0.92, 0.3)
				elif q < 0.82:
					col = Color(1.0, 0.55, 0.12)
				fill[Vector2i(x, y)] = col
	for y in CRIT_GRID:
		for x in CRIT_GRID:
			var p := Vector2i(x, y)
			if fill.has(p):
				_crit_cells.append([x, y, fill[p]])
			elif fill.has(p + Vector2i(1, 0)) or fill.has(p + Vector2i(-1, 0)) or fill.has(p + Vector2i(0, 1)) or fill.has(p + Vector2i(0, -1)):
				_crit_cells.append([x, y, Color(0.14, 0.03, 0.05)])
	return _crit_cells

func _exit_tree() -> void:
	live = maxi(live - 1, 0)

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if kind != "coin":                  # coin parts hold [landing spot, arc height, spin, delay] and are animated in _draw
		for p in _parts:
			p[0] += p[1] * delta
			p[1] *= 0.93
	if kind == "number":
		position.y -= (70.0 if power >= 1.5 else 45.0) * delta * (life / max_life + 0.3)
		position.x += _drift * delta
	queue_redraw()

func life_frac_coin() -> float:
	return 1.0 - life / max_life

func _draw() -> void:
	var t := 1.0 - life / max_life
	var a := 1.0 - t
	match kind:
		"spark":
			for p in _parts:
				PixelFx.square(self, p[0], maxf(p[2] * a, 1.0) * 1.4, Color(color.r, color.g, color.b, a))
		"explosion":
			var ring := 20.0 + 120.0 * power * t
			PixelFx.disc(self, Vector2.ZERO, ring * 0.7, Color(1.0, 0.55, 0.1, 0.5 * a))
			PixelFx.ring(self, Vector2.ZERO, ring, Color(1.0, 0.9, 0.5, a), 6.0 * a + 3.0)
			for p in _parts:
				PixelFx.square(self, p[0], p[2] * 1.8 * a, Color(1.0, 0.45 + 0.4 * t, 0.1, a))
		"crit":
			var cr := 16.0 + 80.0 * power * t
			for i in 8:
				var ang := TAU * float(i) / 8.0 + 0.2
				var dirv := Vector2.RIGHT.rotated(ang)
				PixelFx.line(self, dirv * cr * 0.35, dirv * cr, Color(1.0, 0.85, 0.3, a), 5.0 * a + 3.0)
			PixelFx.ring(self, Vector2.ZERO, cr * 0.6, Color(1.0, 0.3, 0.15, a), 3.0)
			PixelFx.disc(self, Vector2.ZERO, cr * 0.3, Color(1.0, 0.95, 0.7, 0.5 * a))
		"void_blast":
			var vr := 30.0 + 150.0 * power * t
			PixelFx.disc(self, Vector2.ZERO, vr * 0.8, Color(0.08, 0.0, 0.16, 0.6 * a))
			PixelFx.disc(self, Vector2.ZERO, vr * 0.45, Color(0.02, 0.0, 0.05, 0.75 * a))
			PixelFx.ring(self, Vector2.ZERO, vr, Color(0.75, 0.4, 1.0, a), 6.0 * a + 3.0)
			PixelFx.ring(self, Vector2.ZERO, vr * 0.7, Color(0.5, 0.15, 0.9, 0.8 * a), 3.0)
			for p in _parts:
				PixelFx.square(self, p[0], p[2] * 1.7 * a, Color(0.6 + 0.3 * t, 0.2, 1.0, a))
		"coin":
			# Coins pop out of the wreck, fly in a little arc, spin, land, sparkle and fade.
			var tex := CoinTex.get_texture()
			var u := life_frac_coin()
			for p in _parts:
				var w := clampf((u - float(p[3])) / 0.55, 0.0, 1.0)
				if u < float(p[3]):
					continue
				var ease_w := 1.0 - pow(1.0 - w, 2.0)
				var h := 4.0 * float(p[1]) * w * (1.0 - w)
				var bounce := 0.0
				if w >= 1.0:
					var w2 := clampf((u - float(p[3]) - 0.55) / 0.2, 0.0, 1.0)
					bounce = 4.0 * 10.0 * w2 * (1.0 - w2)
				var pos := (p[0] as Vector2) * ease_w + Vector2(0.0, -h - bounce)
				var spin := absf(cos(u * TAU * 2.5 + float(p[2])))
				var fade := 1.0 if u < 0.7 else 1.0 - (u - 0.7) / 0.3
				var sx := 22.0 * (0.25 + 0.75 * spin)
				draw_set_transform(pos, 0.0, Vector2.ONE)
				draw_texture_rect(tex, Rect2(Vector2(-sx * 0.5, -11.0), Vector2(sx, 22.0)), false, Color(1, 1, 1, fade))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if w > 0.0 and w < 0.35:
					PixelFx.ring(self, pos, 10.0 + 22.0 * w, Color(1.0, 0.9, 0.4, 0.8 * (1.0 - w / 0.35)), 2.0)
		"join":
			# A refugee joined: a green ring ripples over the castle and a big "+1" pops up, bobs and fades. `power` = distance down to the castle's centre.
			var rise := 1.0 - pow(1.0 - minf(t / 0.5, 1.0), 3.0)
			var hover := sin(t * 14.0) * 3.0 * (1.0 - t)
			var fade_j := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
			var centre := Vector2(0.0, power)
			if t < 0.45:
				var w := t / 0.45
				PixelFx.ring(self, centre, power * (0.7 + 0.55 * w), Color(color.r, color.g, color.b, 0.75 * (1.0 - w)), 5.0 * (1.0 - w) + 1.5)
				PixelFx.ring(self, centre, power * (0.55 + 0.45 * w), Color(0.9, 1.0, 0.9, 0.45 * (1.0 - w)), 2.0)
			for p in _parts:
				var q: Vector2 = p[0]
				var s: float = p[2] * (1.0 - t * 0.5)
				var ca := Color(color.r, color.g, color.b, fade_j)
				PixelFx.line(self, q + Vector2(-s, 0.0), q + Vector2(s, 0.0), ca, 2.0)
				PixelFx.line(self, q + Vector2(0.0, -s), q + Vector2(0.0, s), ca, 2.0)
			var jy := -62.0 * rise + hover
			var jsz := 40 if t < 0.12 else 30
			var jf := PixelUI.font()
			var jp := Vector2(-200.0, jy + float(jsz) * 0.35)
			var edge_j := Color(0.02, 0.1, 0.04, fade_j)
			draw_string_outline(jf, jp, text, HORIZONTAL_ALIGNMENT_CENTER, 400, jsz, 10, edge_j)
			draw_string(jf, jp + Vector2(0.0, 4.0), text, HORIZONTAL_ALIGNMENT_CENTER, 400, jsz, Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, fade_j))
			draw_string(jf, jp, text, HORIZONTAL_ALIGNMENT_CENTER, 400, jsz, Color(color.r * 0.5 + 0.5, color.g * 0.5 + 0.5, color.b * 0.5 + 0.5, fade_j))
		"number":
			# Pixel-font damage number: pops in big, settles, drifts up and sideways, fades out at the end.
			var crit_n := power >= 1.5
			var base_sz := 30 if crit_n else 20
			var pop := 1.0
			if t < 0.18:
				pop = 1.0 + (0.18 - t) / 0.18 * (0.5 if crit_n else 0.3)
			var fsz := int(round(float(base_sz) * pop / 10.0)) * 10
			var fade := 1.0 if t < 0.55 else 1.0 - (t - 0.55) / 0.45
			var col_a := Color(color.r, color.g, color.b, fade)
			var edge := Color(0.04, 0.03, 0.08, fade)
			var f := PixelUI.font()
			var p0 := Vector2(-80.0, float(fsz) * 0.35)
			if crit_n:
				# the crit icon sits to the left of the number, the pair centred on the hit
				var shown := text.trim_suffix("!")
				var tw := f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
				var px := maxf(1.0, roundf(float(fsz) / 11.0))
				var iw := px * float(CRIT_GRID)
				var gap := px * 2.0
				var left := -(iw + gap + tw) * 0.5
				var tp := Vector2(left + iw + gap, float(fsz) * 0.35)
				var spin := 1.0 + 0.1 * sin(t * 30.0) * (1.0 - t)
				var cy := -float(fsz) * 0.28
				for cell in _crit_icon_cells():
					var cc: Color = cell[2]
					var rp := Vector2(float(cell[0]) - 7.0, float(cell[1]) - 7.0) * px * spin
					draw_rect(Rect2(Vector2(left + iw * 0.5, cy) + rp - Vector2(px, px) * 0.5, Vector2(px, px)), Color(cc.r, cc.g, cc.b, fade))
				draw_string_outline(f, tp, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 8, edge)
				draw_string(f, tp + Vector2(0, 3), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(0.5, 0.1, 0.05, fade))
				draw_string(f, tp, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col_a)
			else:
				draw_string_outline(f, p0, text, HORIZONTAL_ALIGNMENT_CENTER, 160, fsz, 8, edge)
				draw_string(f, p0, text, HORIZONTAL_ALIGNMENT_CENTER, 160, fsz, col_a)
