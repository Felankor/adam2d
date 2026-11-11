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

static func spawn(parent: Node, k: String, pos: Vector2, col: Color = Color.WHITE, txt: String = "", pw: float = 1.0, duration: float = 0.4) -> void:
	if parent == null:
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
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 5
	if kind == "spark" or kind == "explosion" or kind == "void_blast":
		var count := 9 if kind == "spark" else 28
		for i in count:
			var a := randf() * TAU
			var sp := randf_range(70.0, 240.0) * power
			_parts.append([Vector2.ZERO, Vector2.RIGHT.rotated(a) * sp, randf_range(2.0, 5.0)])

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for p in _parts:
		p[0] += p[1] * delta
		p[1] *= 0.93
	if kind == "number":
		position.y -= 45.0 * delta
	queue_redraw()

func _draw() -> void:
	var t := 1.0 - life / max_life
	var a := 1.0 - t
	match kind:
		"spark":
			for p in _parts:
				draw_circle(p[0], p[2] * a, Color(color.r, color.g, color.b, a))
		"explosion":
			var ring := 20.0 + 120.0 * power * t
			draw_circle(Vector2.ZERO, ring * 0.7, Color(1.0, 0.55, 0.1, 0.45 * a))
			draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, Color(1.0, 0.9, 0.5, a), 5.0 * a + 1.0)
			for p in _parts:
				draw_circle(p[0], p[2] * 1.6 * a, Color(1.0, 0.45 + 0.4 * t, 0.1, a))
		"void_blast":
			var vr := 30.0 + 150.0 * power * t
			draw_circle(Vector2.ZERO, vr * 0.8, Color(0.08, 0.0, 0.16, 0.55 * a))
			draw_circle(Vector2.ZERO, vr * 0.45, Color(0.02, 0.0, 0.05, 0.7 * a))
			draw_arc(Vector2.ZERO, vr, 0.0, TAU, 64, Color(0.75, 0.4, 1.0, a), 6.0 * a + 1.0)
			draw_arc(Vector2.ZERO, vr * 0.7, 0.0, TAU, 48, Color(0.5, 0.15, 0.9, 0.8 * a), 3.0)
			for p in _parts:
				draw_circle(p[0], p[2] * 1.5 * a, Color(0.6 + 0.3 * t, 0.2, 1.0, a))
		"number":
			var font := ThemeDB.fallback_font
			var pos := Vector2(-40, 0)
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, 22, 6, Color(0, 0, 0, a))
			draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, 22, Color(color.r, color.g, color.b, a))
