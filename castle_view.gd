class_name CastleView
extends Control

# A castle on display (the Shipyard): the baked castle sprite floating over a soft shadow. The next stage gets a golden
# glow and sparkles. Hover it to read its stats; `pop()` plays the grow animation.

const BOX := Vector2(300.0, 310.0)
const MAX_H := 262.0

var tier: int = 0
var upcoming: bool = false
var tip_title: String = ""
var tip_body: String = ""
var tip_foot: String = ""
var _t: float = 0.0
var _pop: float = 0.0

func _init() -> void:
	custom_minimum_size = BOX
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(t: int, is_next: bool) -> void:
	tier = t
	upcoming = is_next
	_t = float(t) * 0.7 + (1.3 if is_next else 0.0)
	Tip.attach(self, tip_title, tip_body, "walls", tip_foot)
	queue_redraw()

func set_tip(title: String, body: String, foot: String) -> void:
	tip_title = title
	tip_body = body
	tip_foot = foot
	Tip.attach(self, title, body, "walls", foot)

func pop() -> void:
	_pop = 1.0

func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(_pop - delta * 1.4, 0.0)
	queue_redraw()

func _draw() -> void:
	var tex := CastleArt.tex(tier)
	if tex == null:
		return
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var k := floorf(minf(MAX_H / h, 2.0) * 4.0) / 4.0
	var cx := size.x * 0.5
	var ground := size.y - 26.0
	var bob := sin(_t * 1.6) * 5.0
	var hot := Color(1.0, 0.85, 0.3)
	if upcoming:
		var pulse := 0.5 + 0.5 * sin(_t * 2.2)
		PixelFx.disc(self, Vector2(cx, ground - h * k * 0.5), h * k * (0.62 + 0.04 * pulse), Color(hot.r, hot.g, hot.b, 0.07 + 0.05 * pulse))
		PixelFx.disc(self, Vector2(cx, ground - h * k * 0.5), h * k * 0.42, Color(hot.r, hot.g, hot.b, 0.07))
	# shadow on the ground: it shrinks a little while the castle rises
	draw_set_transform(Vector2(cx + 6.0, ground + 8.0), 0.0, Vector2(1.0, 0.26))
	PixelFx.disc(self, Vector2.ZERO, w * k * 0.5 * (1.0 - bob * 0.01), Color(0, 0, 0, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the castle (grow animation: a quick swell and settle)
	var sc := 1.0 + 0.16 * sin(_pop * PI)
	var pos := Vector2(cx - w * k * 0.5, ground - h * k - 14.0 + bob)
	draw_set_transform(Vector2(cx, ground) , 0.0, Vector2(sc, sc))
	draw_texture_rect(tex, Rect2(pos - Vector2(cx, ground), Vector2(w, h) * k), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if upcoming:
		for i in 7:
			var ph := fposmod(_t * 0.45 + float(i) / 7.0, 1.0)
			var a := float(i) * 2.4
			var sp := Vector2(cx + cos(a) * w * k * 0.46, ground - 20.0 - ph * h * k * 0.95)
			var al := sin(ph * PI)
			var arm := 4.0 + 3.0 * al
			draw_rect(Rect2(sp - Vector2(arm, 1.5), Vector2(arm * 2.0, 3.0)), Color(1.0, 0.95, 0.6, al))
			draw_rect(Rect2(sp - Vector2(1.5, arm), Vector2(3.0, arm * 2.0)), Color(1.0, 0.95, 0.6, al))
	if _pop > 0.0:
		var f := 1.0 - _pop
		PixelFx.ring(self, Vector2(cx, ground - h * k * 0.45), h * k * (0.3 + 0.7 * f), Color(hot.r, hot.g, hot.b, _pop), 8.0 * _pop + 2.0)

# Three chevrons that light up one after the other: "this becomes that".
class ArrowView extends Control:
	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(130.0, CastleView.BOX.y)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5 - 20.0)
		for i in 3:
			var a := clampf(0.25 + 0.75 * maxf(sin(_t * 4.5 - float(i) * 1.0), 0.0), 0.0, 1.0)
			var x := c.x + (float(i) - 1.0) * 30.0
			var pts := PackedVector2Array([Vector2(x - 11.0, c.y - 30.0), Vector2(x + 11.0, c.y), Vector2(x - 11.0, c.y + 30.0)])
			draw_polyline(pts, Color(0.1, 0.05, 0.02, a), 18.0)
			draw_polyline(pts, Color(1.0, 0.85, 0.3, a), 10.0)
