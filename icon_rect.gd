class_name IconRect
extends Control

# Small hand-drawn icons for the shop. kind picks which one to draw.
var kind: String = ""

const BG := Color(0.15, 0.16, 0.21)
const METAL := Color(0.58, 0.60, 0.66)
const DARK_METAL := Color(0.30, 0.31, 0.36)

func _init() -> void:
	custom_minimum_size = Vector2(72, 72)

func _draw() -> void:
	# Icons are drawn on a 64x64 canvas and scaled up to the control size.
	var k := size.x / 64.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	draw_rect(Rect2(0, 0, 64, 64), BG)
	draw_rect(Rect2(1, 1, 62, 62), Color(1, 1, 1, 0.18), false, 2.0)
	match kind:
		"damage":
			_cannon(Vector2.ZERO)
			_fire()
		"regen":
			_bolt()
		"auto":
			_cannon(Vector2(0, 6))
			_gear(Vector2(18, 17))
		"autorate":
			_cannon(Vector2(-4, 8))
			_chevrons()
		"energy":
			_battery()
		"repair":
			_wrench()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _cannon(o: Vector2) -> void:
	draw_line(Vector2(12, 42) + o, Vector2(42, 30) + o, METAL, 12.0)
	draw_line(Vector2(38, 31.5) + o, Vector2(44, 29) + o, DARK_METAL, 15.0)
	draw_circle(Vector2(14, 42) + o, 8.0, DARK_METAL)
	draw_circle(Vector2(22, 48) + o, 9.0, Color(0.45, 0.30, 0.18))
	draw_circle(Vector2(22, 48) + o, 3.0, Color(0.2, 0.13, 0.08))

func _fire() -> void:
	var outer := PackedVector2Array([Vector2(48, 18), Vector2(60, 22), Vector2(55, 27), Vector2(63, 31), Vector2(52, 35), Vector2(46, 30)])
	var inner := PackedVector2Array([Vector2(50, 23), Vector2(57, 25), Vector2(54, 28), Vector2(58, 30), Vector2(51, 32), Vector2(48, 29)])
	draw_colored_polygon(outer, Color.ORANGE_RED)
	draw_colored_polygon(inner, Color.YELLOW)

func _bolt() -> void:
	var pts := PackedVector2Array([Vector2(34, 6), Vector2(16, 35), Vector2(29, 35), Vector2(23, 58), Vector2(48, 25), Vector2(34, 25), Vector2(44, 6)])
	draw_colored_polygon(pts, Color(1.0, 0.9, 0.2))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(1.0, 0.6, 0.1), 2.0)

func _battery() -> void:
	draw_rect(Rect2(10, 18, 38, 30), Color(0.8, 0.85, 0.9), false, 3.0)
	draw_rect(Rect2(48, 28, 6, 10), Color(0.8, 0.85, 0.9))
	draw_rect(Rect2(15, 23, 8, 20), Color.LIME_GREEN)
	draw_rect(Rect2(26, 23, 8, 20), Color.LIME_GREEN)
	draw_rect(Rect2(37, 23, 7, 20), Color(0.3, 0.45, 0.3))

func _gear(c: Vector2) -> void:
	for i in 8:
		var d := Vector2.RIGHT.rotated(TAU * i / 8.0)
		draw_line(c + d * 8.0, c + d * 13.0, Color(0.8, 0.82, 0.88), 4.0)
	draw_circle(c, 10.0, Color(0.8, 0.82, 0.88))
	draw_circle(c, 4.0, BG)

func _chevrons() -> void:
	var cyan := Color(0.3, 0.9, 1.0)
	draw_polyline(PackedVector2Array([Vector2(36, 8), Vector2(46, 17), Vector2(36, 26)]), cyan, 4.0)
	draw_polyline(PackedVector2Array([Vector2(48, 8), Vector2(58, 17), Vector2(48, 26)]), cyan, 4.0)

func _wrench() -> void:
	draw_line(Vector2(14, 52), Vector2(40, 26), Color(0.72, 0.74, 0.80), 9.0)
	draw_circle(Vector2(44, 21), 12.0, Color(0.72, 0.74, 0.80))
	draw_circle(Vector2(50, 15), 6.5, BG)
	draw_line(Vector2(14, 14), Vector2(14, 26), Color.LIME_GREEN, 5.0)
	draw_line(Vector2(8, 20), Vector2(20, 20), Color.LIME_GREEN, 5.0)
