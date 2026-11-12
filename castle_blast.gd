class_name CastleBlast
extends Node2D

# The death of the player's castle: it shudders and catches fire, a chain of blasts rips through it,
# then one huge detonation (flash, fireball, shockwaves, light streaks) throws burning chunks of
# masonry, bronze and island rock everywhere and leaves a rising column of smoke.
signal shake(amount: float)
signal finished

const BOOM_T := 1.3          # seconds of chain explosions before the big one
const TOTAL := 4.6

var base_ref: Base = null
var radius: float = 120.0

var _t: float = 0.0
var _boom: bool = false
var _fires: Array = []       # pre-blasts: {t, pos, size, done}
var _chunks: Array = []      # {p, v, a, av, s, col, life, max, glow}
var _smoke: Array = []       # {p, v, r, rv, life, max, dark}
var _embers: Array = []      # {p, v, life, max}
var _done_signal: bool = false

const CHUNK_COLS := [
	Color(0.80, 0.70, 0.50), Color(0.62, 0.52, 0.36), Color(0.45, 0.30, 0.14), Color(0.30, 0.20, 0.10),
	Color(0.85, 0.60, 0.20), Color(0.32, 0.55, 0.20), Color(0.22, 0.22, 0.24),
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 8
	var n := 11
	for i in n:
		var a := randf() * TAU
		_fires.append({
			"t": BOOM_T * (0.05 + 0.9 * float(i) / float(n)) + randf_range(-0.04, 0.04),
			"pos": Vector2.RIGHT.rotated(a) * randf_range(0.0, radius * 0.85),
			"size": randf_range(0.8, 1.5) + float(i) * 0.08,
			"done": false,
		})

func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)

func _process(delta: float) -> void:
	_t += delta
	var par := get_parent()
	if not _boom:
		for f: Dictionary in _fires:
			if not f["done"] and _t >= f["t"]:
				f["done"] = true
				var p: Vector2 = position + f["pos"]
				Fx.spawn(par, "explosion", p, Color(1.0, 0.65, 0.25), "", f["size"], 0.55)
				Fx.spawn(par, "spark", p, Color(1.0, 0.9, 0.5), "", 1.6, 0.5)
				Sfx.play("rocket_boom", -3.0)
				shake.emit(8.0 + 10.0 * _t / BOOM_T)
				for i in 3:
					_smoke.append(_new_smoke(f["pos"], randf_range(10.0, 22.0) * f["size"], false))
		if base_ref != null and is_instance_valid(base_ref):
			var k := _t / BOOM_T
			var fl := 0.5 + 0.5 * sin(_t * (20.0 + 30.0 * k))
			base_ref.modulate = Color(1.0, 1.0 - 0.55 * fl * k, 1.0 - 0.7 * fl * k)
			base_ref.rotation = sin(_t * 55.0) * 0.012 * (0.4 + k)
		if _t >= BOOM_T:
			_detonate()
	_step(delta)
	if _t >= TOTAL:
		if not _done_signal:
			_done_signal = true
			finished.emit()
		queue_free()
		return
	queue_redraw()

func _new_smoke(p: Vector2, r: float, dark: bool) -> Dictionary:
	var life := randf_range(1.6, 3.0)
	return {"p": p, "v": Vector2(randf_range(-30.0, 30.0), randf_range(-70.0, -25.0)), "r": r, "rv": randf_range(18.0, 40.0), "life": life, "max": life, "dark": dark}

func _detonate() -> void:
	_boom = true
	_t = BOOM_T
	if base_ref != null and is_instance_valid(base_ref):
		base_ref.rotation = 0.0
		base_ref.modulate = Color.WHITE
		base_ref.visible = false
	var par := get_parent()
	Fx.spawn(par, "explosion", position, Color.WHITE, "", 4.0, 1.1)
	for i in 7:
		var a := TAU * float(i) / 7.0 + randf() * 0.5
		Fx.spawn(par, "explosion", position + Vector2.RIGHT.rotated(a) * radius * randf_range(0.5, 1.2), Color(1.0, 0.55, 0.15), "", randf_range(1.8, 2.8), randf_range(0.7, 1.1))
	Fx.spawn(par, "spark", position, Color(1.0, 0.85, 0.4), "", 4.0, 0.9)
	Sfx.play("boss_die")
	Sfx.play("void_boom", -2.0)
	shake.emit(40.0)
	# chunks of the castle and of the floating island under it
	for i in 70:
		var a := randf() * TAU
		var sp := randf_range(120.0, 760.0)
		var big := i < 16
		_chunks.append({
			"p": Vector2.RIGHT.rotated(a) * randf_range(0.0, radius * 0.6),
			"v": Vector2.RIGHT.rotated(a) * sp + Vector2(0.0, -randf_range(60.0, 260.0)),
			"a": randf() * TAU, "av": randf_range(-9.0, 9.0),
			"s": randf_range(14.0, 30.0) if big else randf_range(5.0, 12.0),
			"col": CHUNK_COLS[randi() % CHUNK_COLS.size()],
			"life": randf_range(1.8, 3.4), "max": 3.4, "glow": randf() < 0.55,
		})
	for i in 40:
		var a := randf() * TAU
		_embers.append({"p": Vector2.ZERO, "v": Vector2.RIGHT.rotated(a) * randf_range(200.0, 900.0), "life": randf_range(0.8, 2.2), "max": 2.2})
	for i in 26:
		_smoke.append(_new_smoke(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, radius * 0.8), randf_range(26.0, 60.0), i % 3 != 0))

func _step(delta: float) -> void:
	for c: Dictionary in _chunks:
		c["life"] -= delta
		c["v"] = c["v"] + Vector2(0.0, 520.0) * delta          # they fall back down
		c["v"] = c["v"] * (1.0 - 0.35 * delta)
		c["p"] = c["p"] + c["v"] * delta
		c["a"] += c["av"] * delta
	_chunks = _chunks.filter(func(c: Dictionary) -> bool: return c["life"] > 0.0)
	for e: Dictionary in _embers:
		e["life"] -= delta
		e["v"] = e["v"] * (1.0 - 1.4 * delta) + Vector2(0.0, 90.0) * delta
		e["p"] = e["p"] + e["v"] * delta
	_embers = _embers.filter(func(e: Dictionary) -> bool: return e["life"] > 0.0)
	for s: Dictionary in _smoke:
		s["life"] -= delta
		s["p"] = s["p"] + s["v"] * delta
		s["r"] += s["rv"] * delta
	_smoke = _smoke.filter(func(s: Dictionary) -> bool: return s["life"] > 0.0)
	if _boom and _t < BOOM_T + 1.2 and randf() < delta * 22.0:
		_smoke.append(_new_smoke(Vector2(randf_range(-radius, radius) * 0.5, randf_range(-radius * 0.3, radius * 0.3)), randf_range(24.0, 48.0), true))

func _draw() -> void:
	# smoke (behind the fire)
	for s: Dictionary in _smoke:
		var k: float = 1.0 - float(s["life"]) / float(s["max"])
		var a: float = (1.0 - k) * (0.55 if s["dark"] else 0.4)
		var col := Color(0.12, 0.10, 0.10, a) if s["dark"] else Color(0.45, 0.40, 0.36, a)
		PixelFx.disc(self, s["p"], s["r"], col)
		PixelFx.disc(self, s["p"] + Vector2(-s["r"] * 0.2, -s["r"] * 0.25), s["r"] * 0.6, col.lightened(0.12))
	if not _boom:
		# the castle is on fire: flames licking up from the walls
		var k := _t / BOOM_T
		for i in int(6.0 + 14.0 * k):
			var fx := sin(float(i) * 12.9 + 3.0) * radius * 0.7
			var fy := cos(float(i) * 7.3) * radius * 0.25
			var h := (10.0 + 26.0 * k) * (0.6 + 0.4 * sin(_t * 18.0 + float(i)))
			PixelFx.disc(self, Vector2(fx, fy - h * 0.4), 7.0 + 8.0 * k, Color(1.0, 0.45, 0.1, 0.65))
			PixelFx.disc(self, Vector2(fx, fy - h * 0.7), 4.0 + 5.0 * k, Color(1.0, 0.85, 0.35, 0.8))
		return
	var bt := _t - BOOM_T
	# fireball: stacked discs from dark red to a white-hot core
	var k1 := bt / 1.5
	if k1 < 1.0:
		var rr := radius * (0.5 + 2.4 * _ease_out(k1))
		var fade := 1.0 - k1
		PixelFx.disc(self, Vector2.ZERO, rr, Color(0.35, 0.05, 0.02, 0.75 * fade))
		PixelFx.disc(self, Vector2.ZERO, rr * 0.86, Color(0.75, 0.14, 0.04, 0.85 * fade))
		PixelFx.disc(self, Vector2.ZERO, rr * 0.68, Color(1.0, 0.42, 0.08, 0.9 * fade))
		PixelFx.disc(self, Vector2.ZERO, rr * 0.48, Color(1.0, 0.75, 0.2, 0.95 * fade))
		PixelFx.disc(self, Vector2.ZERO, rr * 0.28 * (1.0 - 0.6 * k1), Color(1.0, 0.97, 0.8, fade))
		# roiling lobes on the rim
		for i in 9:
			var a := TAU * float(i) / 9.0 + bt * 0.6
			var lr := rr * (0.9 + 0.12 * sin(bt * 9.0 + float(i) * 2.0))
			PixelFx.disc(self, Vector2.RIGHT.rotated(a) * lr * 0.7, rr * 0.24, Color(1.0, 0.5, 0.1, 0.7 * fade))
		# light streaks
		var ln := radius * 7.0 * (1.0 - k1)
		for ang: float in [0.0, PI * 0.5, PI * 0.25, PI * 0.75]:
			var d := Vector2.RIGHT.rotated(ang) * ln
			PixelFx.line(self, -d, d, Color(1.0, 0.9, 0.6, 0.5 * fade), 4.0)
	# shockwaves
	for j in 2:
		var kk := (bt - 0.22 * float(j)) / 1.5
		if kk > 0.0 and kk < 1.0:
			var wr := 1100.0 * _ease_out(kk)
			PixelFx.ring(self, Vector2.ZERO, wr, Color(1.0, 0.85, 0.6, 0.8 * (1.0 - kk)), 10.0 * (1.0 - kk) + 2.0)
			PixelFx.ring(self, Vector2.ZERO, wr * 0.96, Color(0.5, 0.2, 0.1, 0.5 * (1.0 - kk)), 5.0)
	# embers
	for e: Dictionary in _embers:
		var f: float = float(e["life"]) / float(e["max"])
		var tail: Vector2 = Vector2(e["v"]).normalized() * 18.0 * f
		PixelFx.line(self, e["p"], e["p"] - tail, Color(1.0, 0.6, 0.15, f), 3.0)
		PixelFx.square(self, e["p"], 4.0, Color(1.0, 0.95, 0.6, f))
	# chunks, glowing ones trail fire
	for c: Dictionary in _chunks:
		var f: float = clampf(float(c["life"]) / 0.8, 0.0, 1.0)
		var col: Color = c["col"]
		col.a = f
		if c["glow"]:
			PixelFx.disc(self, Vector2(c["p"]) - Vector2(c["v"]).normalized() * c["s"] * 0.8, c["s"] * 0.9, Color(1.0, 0.45, 0.1, 0.55 * f))
		PixelFx.square(self, c["p"], c["s"], Color(0.05, 0.03, 0.02, f))
		PixelFx.square(self, c["p"], c["s"] * 0.72, col)
		PixelFx.square(self, Vector2(c["p"]) + Vector2(-1.0, -1.0) * c["s"] * 0.12, c["s"] * 0.3, col.lightened(0.35))
	# white flash over the whole screen
	if bt < 0.45:
		var fa := 0.95 * (1.0 - bt / 0.45)
		draw_rect(Rect2(-2600.0, -2600.0, 5200.0, 5200.0), Color(1.0, 0.95, 0.85, fa))
