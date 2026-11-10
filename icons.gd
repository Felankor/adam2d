class_name Icons
extends RefCounted

# All icons are hand-drawn with draw_* calls on a 64x64 canvas, so they can be
# used on any CanvasItem (shop, cards, HUD, notifications) at any size.

const BG := Color(0.15, 0.16, 0.21)
const METAL := Color(0.62, 0.64, 0.70)
const DARK_METAL := Color(0.30, 0.31, 0.36)

static func draw(ci: CanvasItem, kind: String, origin: Vector2, k: float, with_bg: bool = true) -> void:
	ci.draw_set_transform(origin, 0.0, Vector2(k, k))
	if with_bg:
		ci.draw_rect(Rect2(0, 0, 64, 64), BG)
		ci.draw_rect(Rect2(1, 1, 62, 62), Color(1, 1, 1, 0.18), false, 2.0)
	match kind:
		# weapons
		"mg":
			_machinegun(ci)
		"cannon":
			_cannon(ci, Vector2.ZERO)
		"rocket":
			_rocket_launcher(ci)
		"laser":
			_laser_gun(ci)
		# shop / reward icons
		"damage":
			_impact(ci)
		"regen":
			_bolt(ci)
		"autorate":
			_cannon(ci, Vector2(-4, 8))
			_chevrons(ci)
		"energy":
			_battery(ci)
		"repair":
			_wrench_plus(ci)
		"walls":
			_walls(ci)
		"sight":
			_sight(ci)
		"speed":
			_speed(ci)
		"coin":
			ci.draw_texture_rect(CoinTex.get_texture(), Rect2(8, 8, 48, 48), false)
		# helpers
		"gunner":
			_gunner(ci)
		"scientist":
			_scientist(ci)
		"engineer":
			_engineer(ci)
		"mechanic":
			_mechanic(ci)
		# notification icons
		"hit":
			_hit(ci)
		"shield":
			_shield(ci)
		"ally":
			_ally(ci)
		"skull":
			_skull(ci)
		"star":
			_star(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _speed(ci: CanvasItem) -> void:
	for y in [18.0, 32.0, 46.0]:
		ci.draw_line(Vector2(6, y), Vector2(22, y), Color(0.6, 0.9, 1.0, 0.7), 3.0)
	for i in 2:
		var x := 26.0 + i * 16.0
		var pts := PackedVector2Array([Vector2(x, 14), Vector2(x + 14, 32), Vector2(x, 50), Vector2(x + 7, 32)])
		ci.draw_colored_polygon(pts, Color(0.35, 0.85, 1.0) if i == 0 else Color(0.7, 0.95, 1.0))

# ---------- weapons ----------

static func _machinegun(ci: CanvasItem) -> void:
	# stock, body, magazine, barrel with muzzle flash
	ci.draw_rect(Rect2(6, 28, 12, 10), Color(0.45, 0.30, 0.18))
	ci.draw_rect(Rect2(16, 26, 26, 12), DARK_METAL)
	ci.draw_rect(Rect2(18, 28, 22, 4), METAL)
	ci.draw_rect(Rect2(40, 29, 14, 4), METAL)
	ci.draw_rect(Rect2(52, 27, 4, 8), DARK_METAL)
	ci.draw_rect(Rect2(24, 38, 9, 14), Color(0.55, 0.45, 0.2))
	ci.draw_rect(Rect2(24, 38, 9, 14), Color(0, 0, 0, 0.4), false, 1.5)
	ci.draw_line(Vector2(34, 38), Vector2(30, 46), DARK_METAL, 3.0)
	var flash := PackedVector2Array([Vector2(56, 31), Vector2(62, 26), Vector2(60, 31), Vector2(63, 35), Vector2(56, 33)])
	ci.draw_colored_polygon(flash, Color(1.0, 0.85, 0.2))
	ci.draw_line(Vector2(48, 14), Vector2(60, 12), Color(1.0, 0.9, 0.4, 0.8), 2.0)
	ci.draw_line(Vector2(44, 20), Vector2(60, 19), Color(1.0, 0.9, 0.4, 0.6), 2.0)

static func _cannon(ci: CanvasItem, o: Vector2) -> void:
	ci.draw_line(Vector2(12, 42) + o, Vector2(42, 30) + o, METAL, 12.0)
	ci.draw_line(Vector2(38, 31.5) + o, Vector2(44, 29) + o, DARK_METAL, 15.0)
	ci.draw_circle(Vector2(14, 42) + o, 8.0, DARK_METAL)
	ci.draw_circle(Vector2(22, 48) + o, 9.0, Color(0.45, 0.30, 0.18))
	ci.draw_circle(Vector2(22, 48) + o, 3.0, Color(0.2, 0.13, 0.08))

static func _rocket_launcher(ci: CanvasItem) -> void:
	# long tube on a shoulder rest with a rocket nose sticking out
	ci.draw_line(Vector2(8, 40), Vector2(46, 24), Color(0.36, 0.42, 0.32), 14.0)
	ci.draw_line(Vector2(8, 40), Vector2(14, 37.5), DARK_METAL, 16.0)
	ci.draw_line(Vector2(30, 31), Vector2(34, 29.4), Color(0.75, 0.75, 0.3), 15.0)
	ci.draw_line(Vector2(24, 44), Vector2(30, 36), DARK_METAL, 4.0)
	var nose := PackedVector2Array([Vector2(46, 17), Vector2(58, 20), Vector2(52, 31), Vector2(44, 28)])
	ci.draw_colored_polygon(nose, Color(0.9, 0.25, 0.2))
	ci.draw_line(Vector2(5, 46), Vector2(2, 54), Color(1.0, 0.6, 0.2), 4.0)
	ci.draw_line(Vector2(10, 47), Vector2(9, 57), Color(1.0, 0.8, 0.3), 3.0)

static func _laser_gun(ci: CanvasItem) -> void:
	# sci-fi blaster with a cyan beam
	ci.draw_rect(Rect2(8, 26, 30, 14), Color(0.38, 0.42, 0.55))
	ci.draw_rect(Rect2(8, 26, 30, 4), Color(0.6, 0.65, 0.8))
	ci.draw_rect(Rect2(36, 29, 12, 8), DARK_METAL)
	ci.draw_rect(Rect2(14, 40, 9, 14), Color(0.30, 0.33, 0.44))
	ci.draw_circle(Vector2(20, 33), 3.0, Color(0.35, 0.95, 1.0))
	ci.draw_circle(Vector2(48, 33), 4.0, Color(0.7, 1.0, 1.0))
	ci.draw_line(Vector2(50, 33), Vector2(63, 33), Color(0.3, 0.9, 1.0, 0.35), 8.0)
	ci.draw_line(Vector2(50, 33), Vector2(63, 33), Color(0.7, 1.0, 1.0), 3.0)
	ci.draw_line(Vector2(55, 14), Vector2(58, 21), Color(0.5, 1.0, 1.0, 0.8), 2.0)
	ci.draw_line(Vector2(55, 52), Vector2(58, 45), Color(0.5, 1.0, 1.0, 0.8), 2.0)

# ---------- shop and reward icons ----------

static func _impact(ci: CanvasItem) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var rr := 26.0 if i % 2 == 0 else 14.0
		outer.append(Vector2(32, 32) + Vector2.RIGHT.rotated(a) * rr)
		inner.append(Vector2(32, 32) + Vector2.RIGHT.rotated(a) * rr * 0.55)
	ci.draw_colored_polygon(outer, Color.ORANGE_RED)
	ci.draw_colored_polygon(inner, Color.YELLOW)
	ci.draw_line(Vector2(32, 56), Vector2(32, 44), Color(1, 1, 1, 0.9), 4.0)
	ci.draw_line(Vector2(26, 50), Vector2(32, 43), Color(1, 1, 1, 0.9), 4.0)
	ci.draw_line(Vector2(38, 50), Vector2(32, 43), Color(1, 1, 1, 0.9), 4.0)

static func _bolt(ci: CanvasItem) -> void:
	var pts := PackedVector2Array([Vector2(34, 6), Vector2(16, 35), Vector2(29, 35), Vector2(23, 58), Vector2(48, 25), Vector2(34, 25), Vector2(44, 6)])
	ci.draw_colored_polygon(pts, Color(1.0, 0.9, 0.2))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(1.0, 0.6, 0.1), 2.0)

static func _battery(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(10, 18, 38, 30), Color(0.8, 0.85, 0.9), false, 3.0)
	ci.draw_rect(Rect2(48, 28, 6, 10), Color(0.8, 0.85, 0.9))
	ci.draw_rect(Rect2(15, 23, 8, 20), Color.LIME_GREEN)
	ci.draw_rect(Rect2(26, 23, 8, 20), Color.LIME_GREEN)
	ci.draw_rect(Rect2(37, 23, 7, 20), Color(0.3, 0.45, 0.3))

static func _chevrons(ci: CanvasItem) -> void:
	var cyan := Color(0.3, 0.9, 1.0)
	ci.draw_polyline(PackedVector2Array([Vector2(36, 8), Vector2(46, 17), Vector2(36, 26)]), cyan, 4.0)
	ci.draw_polyline(PackedVector2Array([Vector2(48, 8), Vector2(58, 17), Vector2(48, 26)]), cyan, 4.0)

static func _wrench_plus(ci: CanvasItem) -> void:
	ci.draw_line(Vector2(14, 52), Vector2(40, 26), Color(0.72, 0.74, 0.80), 9.0)
	ci.draw_circle(Vector2(44, 21), 12.0, Color(0.72, 0.74, 0.80))
	ci.draw_circle(Vector2(50, 15), 6.5, BG)
	ci.draw_line(Vector2(14, 14), Vector2(14, 26), Color.LIME_GREEN, 5.0)
	ci.draw_line(Vector2(8, 20), Vector2(20, 20), Color.LIME_GREEN, 5.0)

static func _walls(ci: CanvasItem) -> void:
	var brick := Color(0.72, 0.38, 0.28)
	var mortar := Color(0.85, 0.8, 0.7)
	for row in 4:
		var y := 12.0 + row * 11.0
		var shift := 0.0 if row % 2 == 0 else 8.0
		for col in 4:
			var x := 6.0 + col * 16.0 - shift
			ci.draw_rect(Rect2(x, y, 14, 9), brick)
			ci.draw_rect(Rect2(x, y, 14, 9), mortar, false, 1.5)
	ci.draw_rect(Rect2(0, 0, 64, 10), BG)
	ci.draw_rect(Rect2(0, 54, 64, 10), BG)
	ci.draw_rect(Rect2(1, 1, 62, 62), Color(1, 1, 1, 0.18), false, 2.0)

static func _sight(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(40, 32), 14.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.3), 3.0)
	ci.draw_circle(Vector2(40, 32), 3.0, Color(1.0, 0.4, 0.4))
	ci.draw_line(Vector2(8, 32), Vector2(24, 32), Color(1.0, 0.3, 0.3, 0.4), 7.0)
	ci.draw_line(Vector2(8, 32), Vector2(24, 32), Color(1.0, 0.4, 0.4), 2.0)
	ci.draw_line(Vector2(40, 12), Vector2(40, 20), Color(1.0, 0.3, 0.3), 3.0)
	ci.draw_line(Vector2(40, 44), Vector2(40, 52), Color(1.0, 0.3, 0.3), 3.0)
	ci.draw_line(Vector2(56, 32), Vector2(60, 32), Color(1.0, 0.3, 0.3), 3.0)

# ---------- helpers ----------

static func _gunner(ci: CanvasItem) -> void:
	# helmet over a crosshair
	var green := Color(0.35, 0.55, 0.28)
	ci.draw_arc(Vector2(32, 38), 20.0, 0.0, TAU, 32, Color(1.0, 0.7, 0.2, 0.55), 3.0)
	ci.draw_line(Vector2(32, 14), Vector2(32, 22), Color(1.0, 0.7, 0.2, 0.7), 3.0)
	ci.draw_line(Vector2(32, 54), Vector2(32, 62), Color(1.0, 0.7, 0.2, 0.7), 3.0)
	ci.draw_line(Vector2(8, 38), Vector2(16, 38), Color(1.0, 0.7, 0.2, 0.7), 3.0)
	ci.draw_line(Vector2(48, 38), Vector2(56, 38), Color(1.0, 0.7, 0.2, 0.7), 3.0)
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(Vector2(32, 36) + Vector2(cos(a) * 17.0, sin(a) * 17.0))
	ci.draw_colored_polygon(dome, green)
	ci.draw_rect(Rect2(13, 35, 38, 6), green.darkened(0.25))
	ci.draw_rect(Rect2(26, 40, 12, 10), Color(0.9, 0.72, 0.55))
	ci.draw_rect(Rect2(23, 24, 18, 3), green.lightened(0.25))

static func _scientist(ci: CanvasItem) -> void:
	# round-bottom flask with green liquid and bubbles
	var glass := Color(0.8, 0.92, 1.0)
	var neck := PackedVector2Array([Vector2(26, 8), Vector2(38, 8), Vector2(38, 24), Vector2(52, 50), Vector2(12, 50), Vector2(26, 24)])
	ci.draw_colored_polygon(neck, Color(0.8, 0.92, 1.0, 0.2))
	var liquid := PackedVector2Array([Vector2(21, 38), Vector2(43, 38), Vector2(52, 50), Vector2(12, 50)])
	ci.draw_colored_polygon(liquid, Color(0.35, 0.95, 0.45))
	var outline := neck.duplicate()
	outline.append(neck[0])
	ci.draw_polyline(outline, glass, 3.0)
	ci.draw_line(Vector2(23, 8), Vector2(41, 8), glass, 4.0)
	ci.draw_circle(Vector2(30, 32), 3.0, Color(0.7, 1.0, 0.75, 0.9))
	ci.draw_circle(Vector2(36, 26), 2.0, Color(0.7, 1.0, 0.75, 0.9))
	ci.draw_circle(Vector2(33, 44), 2.5, Color(0.8, 1.0, 0.85, 0.9))
	ci.draw_arc(Vector2(50, 14), 7.0, 0.0, TAU, 20, Color(0.5, 0.8, 1.0), 2.0)
	ci.draw_circle(Vector2(50, 14), 2.0, Color(0.5, 0.8, 1.0))

static func _engineer(ci: CanvasItem) -> void:
	# yellow hard hat with a small gear
	var yellow := Color(1.0, 0.82, 0.15)
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(Vector2(32, 38) + Vector2(cos(a) * 22.0, sin(a) * 20.0))
	ci.draw_colored_polygon(dome, yellow)
	ci.draw_rect(Rect2(6, 37, 52, 7), yellow.darkened(0.15))
	ci.draw_rect(Rect2(28, 16, 8, 21), yellow.lightened(0.2))
	ci.draw_circle(Vector2(32, 54), 8.0, Color(0.8, 0.82, 0.88))
	for i in 8:
		var d := Vector2.RIGHT.rotated(TAU * i / 8.0)
		ci.draw_line(Vector2(32, 54) + d * 7.0, Vector2(32, 54) + d * 11.0, Color(0.8, 0.82, 0.88), 3.5)
	ci.draw_circle(Vector2(32, 54), 3.0, BG)

static func _mechanic(ci: CanvasItem) -> void:
	# crossed wrench and screwdriver
	ci.draw_line(Vector2(14, 52), Vector2(44, 22), Color(0.72, 0.74, 0.80), 8.0)
	ci.draw_circle(Vector2(47, 19), 11.0, Color(0.72, 0.74, 0.80))
	ci.draw_circle(Vector2(53, 13), 6.0, BG)
	ci.draw_line(Vector2(50, 52), Vector2(24, 26), Color(0.85, 0.3, 0.25), 8.0)
	ci.draw_line(Vector2(24, 26), Vector2(16, 18), Color(0.8, 0.82, 0.88), 3.5)
	ci.draw_line(Vector2(14, 16), Vector2(18, 20), Color(0.8, 0.82, 0.88), 3.0)

# ---------- notification icons ----------

static func _hit(ci: CanvasItem) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var rr := 26.0 if i % 2 == 0 else 13.0
		pts.append(Vector2(32, 32) + Vector2.RIGHT.rotated(TAU * i / 14.0) * rr)
	ci.draw_colored_polygon(pts, Color(0.9, 0.15, 0.15))
	ci.draw_line(Vector2(32, 18), Vector2(32, 36), Color.WHITE, 6.0)
	ci.draw_circle(Vector2(32, 45), 3.5, Color.WHITE)

static func _shield(ci: CanvasItem) -> void:
	var pts := PackedVector2Array([Vector2(14, 12), Vector2(50, 12), Vector2(52, 34), Vector2(32, 56), Vector2(12, 34)])
	ci.draw_colored_polygon(pts, Color(0.25, 0.75, 1.0))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(Vector2(32, 34) + (p - Vector2(32, 34)) * 0.62)
	ci.draw_colored_polygon(inner, Color(0.6, 0.92, 1.0))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color.WHITE, 3.0)

static func _ally(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(32, 32), 17.0, Color(0.9, 0.72, 0.55))
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(Vector2(32, 30) + Vector2(cos(a) * 19.0, sin(a) * 18.0))
	ci.draw_colored_polygon(dome, Color(0.78, 0.2, 0.22))
	ci.draw_line(Vector2(46, 8), Vector2(46, 30), Color(0.5, 0.38, 0.25), 2.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(46, 8), Vector2(60, 12), Vector2(46, 20)]), Color.WHITE)
	ci.draw_circle(Vector2(26, 34), 2.0, Color(0.15, 0.15, 0.15))
	ci.draw_circle(Vector2(38, 34), 2.0, Color(0.15, 0.15, 0.15))
	ci.draw_arc(Vector2(32, 40), 6.0, 0.2, PI - 0.2, 12, Color(0.4, 0.15, 0.1), 2.0)

static func _skull(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(32, 28), 20.0, Color(0.92, 0.92, 0.88))
	ci.draw_rect(Rect2(21, 38, 22, 16), Color(0.92, 0.92, 0.88))
	ci.draw_circle(Vector2(24, 28), 6.0, Color(0.1, 0.05, 0.15))
	ci.draw_circle(Vector2(40, 28), 6.0, Color(0.1, 0.05, 0.15))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(32, 34), Vector2(28, 42), Vector2(36, 42)]), Color(0.1, 0.05, 0.15))
	for i in 4:
		ci.draw_line(Vector2(25 + i * 4.7, 46), Vector2(25 + i * 4.7, 54), Color(0.1, 0.05, 0.15), 1.5)

static func _star(ci: CanvasItem) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := 26.0 if i % 2 == 0 else 11.0
		pts.append(Vector2(32, 34) + Vector2.RIGHT.rotated(-PI / 2.0 + TAU * i / 10.0) * rr)
	ci.draw_colored_polygon(pts, Color(1.0, 0.85, 0.2))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(1.0, 0.6, 0.1), 2.5)
