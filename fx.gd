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

static func spawn(parent: Node, k: String, pos: Vector2, col: Color = Color.WHITE, txt: String = "", pw: float = 1.0, duration: float = 0.4) -> void:
	if parent == null:
		return
	if live >= MAX_ALL or (k == "spark" and live >= MAX_SPARKS) or (k == "number" and live >= MAX_NUMBERS):
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
	if kind == "spark" or kind == "explosion" or kind == "void_blast":
		var count := 9 if kind == "spark" else 28
		for i in count:
			var a := randf() * TAU
			var sp := randf_range(70.0, 240.0) * power
			_parts.append([Vector2.ZERO, Vector2.RIGHT.rotated(a) * sp, randf_range(2.0, 5.0)])

func _exit_tree() -> void:
	live = maxi(live - 1, 0)

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for p in _parts:
		p[0] += p[1] * delta
		p[1] *= 0.93
	if kind == "number":
		position.y -= (70.0 if power >= 1.5 else 45.0) * delta * (life / max_life + 0.3)
		position.x += _drift * delta
	queue_redraw()

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
			draw_string_outline(f, p0, text, HORIZONTAL_ALIGNMENT_CENTER, 160, fsz, 8, edge)
			if crit_n:
				draw_string(f, p0 + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_CENTER, 160, fsz, Color(0.5, 0.1, 0.05, fade))
			draw_string(f, p0, text, HORIZONTAL_ALIGNMENT_CENTER, 160, fsz, col_a)
