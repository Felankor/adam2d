class_name BaseArt
extends RefCounted
# Floating-castle art for the Base. Everything is drawn in code.
# Units are "k-units": 1 unit = k pixels, k = body_radius / 60.
# Origin = middle of the base. Island top surface is at y = 22.

const GY := 22.0

static func _tn(c: Color, t: float) -> Color:
	return c.lerp(Color(1.0, 0.25, 0.25), t * 0.6)

static func _poly(ci: CanvasItem, k: float, pts: Array, col: Color) -> void:
	var v := PackedVector2Array()
	for q: Vector2 in pts:
		v.append(q * k)
	ci.draw_colored_polygon(v, col)

static func _rect(ci: CanvasItem, k: float, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(x * k, y * k, w * k, h * k), col)

static func _tri(ci: CanvasItem, k: float, x1: float, y1: float, x2: float, y2: float, x3: float, y3: float, col: Color) -> void:
	var v := PackedVector2Array()
	v.append(Vector2(x1, y1) * k)
	v.append(Vector2(x2, y2) * k)
	v.append(Vector2(x3, y3) * k)
	ci.draw_colored_polygon(v, col)

static func _ell(ci: CanvasItem, k: float, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var v := PackedVector2Array()
	for i in range(24):
		var a: float = TAU * float(i) / 24.0
		v.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry) * k)
	ci.draw_colored_polygon(v, col)

static func _ball(ci: CanvasItem, k: float, x: float, y: float, rad: float, col: Color) -> void:
	ci.draw_circle(Vector2(x, y) * k, rad * k, col)

static func _line(ci: CanvasItem, k: float, x1: float, y1: float, x2: float, y2: float, col: Color, w: float) -> void:
	ci.draw_line(Vector2(x1, y1) * k, Vector2(x2, y2) * k, col, maxf(w * k, 1.0))

static func _win(ci: CanvasItem, k: float, x: float, y: float, w: float, h: float, tm: float) -> void:
	var glow: float = 0.8 + 0.2 * sin(tm * 3.0 + x)
	_rect(ci, k, x - w * 0.5, y, w, h, Color(1.0 * glow, 0.82 * glow, 0.35 * glow))

static func _flag(ci: CanvasItem, k: float, x: float, y: float, tm: float, col: Color) -> void:
	_rect(ci, k, x - 0.7, y, 1.4, 16.0, Color(0.25, 0.22, 0.2))
	var w: float = sin(tm * 4.0 + x) * 2.0
	_tri(ci, k, x, y, x + 13.0, y + 3.0 + w, x, y + 8.0, col)

static func _tree(ci: CanvasItem, k: float, x: float, yb: float, s: float, t: float) -> void:
	_rect(ci, k, x - 1.5 * s, yb - 8.0 * s, 3.0 * s, 8.0 * s, Color(0.35, 0.24, 0.15))
	_ball(ci, k, x, yb - 14.0 * s, 8.0 * s, _tn(Color(0.2, 0.5, 0.22), t))
	_ball(ci, k, x - 3.0 * s, yb - 11.0 * s, 6.0 * s, _tn(Color(0.26, 0.58, 0.26), t))

static func _house(ci: CanvasItem, k: float, x: float, yb: float, w: float, h: float, wall: Color, roof: Color, t: float, tm: float) -> void:
	_rect(ci, k, x - w * 0.5, yb - h, w, h, _tn(wall, t))
	_rect(ci, k, x, yb - h, w * 0.5, h, _tn(wall, t).darkened(0.18))
	_tri(ci, k, x - w * 0.5 - 3.0, yb - h, x + w * 0.5 + 3.0, yb - h, x, yb - h - w * 0.55, _tn(roof, t))
	_tri(ci, k, x, yb - h - w * 0.55, x + w * 0.5 + 3.0, yb - h, x, yb - h, _tn(roof, t).darkened(0.2))
	_win(ci, k, x - w * 0.18, yb - h * 0.62, 3.0, 4.5, tm)

# A tower: roof_h > 0 gives a pointed roof, roof_h == 0 gives battlements.
static func _tower(ci: CanvasItem, k: float, x: float, yb: float, w: float, h: float, wall: Color, roof: Color, roof_h: float, t: float, tm: float) -> void:
	var wl: Color = _tn(wall, t)
	_rect(ci, k, x - w * 0.5, yb - h, w, h, wl)
	_rect(ci, k, x, yb - h, w * 0.5, h, wl.darkened(0.2))
	_rect(ci, k, x - w * 0.5 - 1.5, yb - h, w + 3.0, 3.0, wl.darkened(0.1))
	if roof_h > 0.0:
		_tri(ci, k, x - w * 0.5 - 3.0, yb - h, x + w * 0.5 + 3.0, yb - h, x, yb - h - roof_h, _tn(roof, t))
		_tri(ci, k, x, yb - h - roof_h, x + w * 0.5 + 3.0, yb - h, x, yb - h, _tn(roof, t).darkened(0.22))
	else:
		var n: int = maxi(2, int(w / 6.0))
		var mw: float = (w + 3.0) / float(n * 2 - 1)
		for i in range(n):
			_rect(ci, k, x - w * 0.5 - 1.5 + mw * float(i * 2), yb - h - 4.0, mw, 4.5, wl)
	_win(ci, k, x - w * 0.12, yb - h * 0.7, 3.0, 6.0, tm)
	if h > 40.0:
		_win(ci, k, x - w * 0.12, yb - h * 0.4, 3.0, 6.0, tm + 1.0)

static func _wall(ci: CanvasItem, k: float, x1: float, x2: float, yb: float, h: float, col: Color, t: float) -> void:
	var c: Color = _tn(col, t)
	_rect(ci, k, x1, yb - h, x2 - x1, h, c)
	_rect(ci, k, x1, yb - h, x2 - x1, 2.5, c.lightened(0.12))
	var x: float = x1
	while x < x2 - 3.0:
		_rect(ci, k, x, yb - h - 3.5, 4.0, 4.0, c)
		x += 8.0

static func _gate(ci: CanvasItem, k: float, x: float, yb: float, w: float, h: float) -> void:
	_rect(ci, k, x - w * 0.5, yb - h, w, h, Color(0.08, 0.07, 0.1))
	_tri(ci, k, x - w * 0.5, yb - h, x + w * 0.5, yb - h, x, yb - h - w * 0.4, Color(0.08, 0.07, 0.1))

static func _crystal(ci: CanvasItem, k: float, x: float, y: float, s: float, tm: float) -> void:
	var g: float = 0.5 + 0.5 * sin(tm * 2.2 + x * 0.3)
	_ball(ci, k, x, y, 11.0 * s, Color(0.3, 0.75, 1.0, 0.10 + 0.12 * g))
	_poly(ci, k, [Vector2(x, y - 9.0 * s), Vector2(x + 4.0 * s, y), Vector2(x, y + 9.0 * s), Vector2(x - 4.0 * s, y)], Color(0.35 + 0.2 * g, 0.8, 1.0))
	_poly(ci, k, [Vector2(x, y - 9.0 * s), Vector2(x + 4.0 * s, y), Vector2(x, y)], Color(0.75, 0.95, 1.0))

static func _island(ci: CanvasItem, k: float, t: float, tm: float, grass: Color) -> void:
	var rock: Color = _tn(Color(0.3, 0.27, 0.3), t)
	_poly(ci, k, [Vector2(-80, 22), Vector2(-72, 40), Vector2(-60, 54), Vector2(-50, 80), Vector2(-32, 94), Vector2(-20, 120), Vector2(0, 138), Vector2(13, 114), Vector2(28, 98), Vector2(42, 82), Vector2(54, 60), Vector2(68, 44), Vector2(80, 22)], rock)
	_poly(ci, k, [Vector2(0, 30), Vector2(13, 114), Vector2(28, 98), Vector2(42, 82), Vector2(54, 60), Vector2(68, 44), Vector2(80, 22)], rock.darkened(0.3))
	_poly(ci, k, [Vector2(-80, 22), Vector2(-72, 40), Vector2(-60, 54), Vector2(-50, 80), Vector2(-40, 50), Vector2(-52, 30)], rock.lightened(0.12))
	_poly(ci, k, [Vector2(-18, 40), Vector2(-32, 94), Vector2(-20, 120), Vector2(-6, 80)], rock.darkened(0.12))
	_crystal(ci, k, -38.0, 64.0, 1.0, tm)
	_crystal(ci, k, 34.0, 70.0, 1.2, tm + 1.0)
	_crystal(ci, k, -4.0, 104.0, 0.9, tm + 2.0)
	# chains
	for j in range(2):
		var cx: float = -56.0 + 106.0 * float(j)
		var cy: float = 46.0
		for i in range(5):
			var sway: float = sin(tm * 1.3 + float(i) * 0.5 + float(j)) * float(i) * 0.9
			var nx: float = cx + sway
			var ny: float = cy + 7.0
			_line(ci, k, cx, cy, nx, ny, Color(0.5, 0.5, 0.56), 1.6)
			_ball(ci, k, nx, ny, 1.8, Color(0.62, 0.62, 0.68))
			cx = nx
			cy = ny
	# soil rim and grass top
	_ell(ci, k, 0.0, 25.0, 80.0, 17.0, _tn(Color(0.38, 0.27, 0.18), t))
	_ell(ci, k, 0.0, 21.0, 80.0, 15.0, _tn(grass, t))
	_ell(ci, k, -6.0, 19.0, 62.0, 10.0, _tn(grass.lightened(0.1), t))
	# floating debris
	for i in range(3):
		var dx: float = -30.0 + 34.0 * float(i)
		var dy: float = 146.0 + float(i % 2) * 16.0 + sin(tm * 2.0 + float(i) * 2.0) * 3.0
		_ball(ci, k, dx, dy, 4.0 - float(i) * 0.7, rock.lightened(0.05))

static func _village(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var wall := Color(0.78, 0.68, 0.52)
	_tree(ci, k, -60.0, 24.0, 1.0, t)
	_tree(ci, k, 58.0, 24.0, 1.1, t)
	_house(ci, k, -36.0, 24.0, 22.0, 16.0, wall, Color(0.7, 0.3, 0.25), t, tm)
	_house(ci, k, 34.0, 24.0, 24.0, 18.0, wall, Color(0.62, 0.3, 0.24), t, tm)
	_house(ci, k, -2.0, 26.0, 28.0, 24.0, Color(0.82, 0.74, 0.58), Color(0.75, 0.28, 0.22), t, tm)
	_flag(ci, k, -2.0, -22.0, tm, Color(0.9, 0.75, 0.2))

static func _town(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var stone := Color(0.55, 0.55, 0.6)
	_wall(ci, k, -64.0, 64.0, 24.0, 12.0, stone, t)
	_house(ci, k, -44.0, 24.0, 20.0, 18.0, Color(0.78, 0.68, 0.52), Color(0.6, 0.28, 0.24), t, tm)
	_house(ci, k, 44.0, 24.0, 20.0, 18.0, Color(0.78, 0.68, 0.52), Color(0.6, 0.28, 0.24), t, tm)
	_tower(ci, k, 0.0, 26.0, 26.0, 46.0, stone.lightened(0.08), Color(0.25, 0.32, 0.55), 22.0, t, tm)
	_gate(ci, k, 0.0, 26.0, 10.0, 12.0)
	_flag(ci, k, 0.0, -44.0, tm, Color(0.85, 0.2, 0.2))

static func _city(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var stone := Color(0.5, 0.5, 0.58)
	var roof := Color(0.24, 0.3, 0.55)
	_wall(ci, k, -66.0, 66.0, 25.0, 26.0, stone, t)
	_tower(ci, k, -56.0, 26.0, 16.0, 44.0, stone, roof, 18.0, t, tm)
	_tower(ci, k, 56.0, 26.0, 16.0, 44.0, stone, roof, 18.0, t, tm)
	_tower(ci, k, -26.0, 26.0, 14.0, 52.0, stone.lightened(0.06), roof, 16.0, t, tm)
	_tower(ci, k, 26.0, 26.0, 14.0, 52.0, stone.lightened(0.06), roof, 16.0, t, tm)
	_tower(ci, k, 0.0, 27.0, 30.0, 66.0, stone.lightened(0.12), roof, 28.0, t, tm)
	_gate(ci, k, 0.0, 27.0, 12.0, 16.0)
	_flag(ci, k, 0.0, -68.0, tm, Color(0.85, 0.2, 0.2))
	_flag(ci, k, -56.0, -36.0, tm + 1.0, Color(0.9, 0.75, 0.2))
	_flag(ci, k, 56.0, -36.0, tm + 2.0, Color(0.9, 0.75, 0.2))

static func _fortress(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var stone := Color(0.3, 0.31, 0.38)
	var roof := Color(0.14, 0.18, 0.34)
	_wall(ci, k, -68.0, 68.0, 25.0, 30.0, stone, t)
	_tower(ci, k, -60.0, 26.0, 18.0, 60.0, stone, roof, 0.0, t, tm)
	_tower(ci, k, 60.0, 26.0, 18.0, 60.0, stone, roof, 0.0, t, tm)
	_tower(ci, k, -32.0, 26.0, 16.0, 56.0, stone.lightened(0.05), roof, 22.0, t, tm)
	_tower(ci, k, 32.0, 26.0, 16.0, 56.0, stone.lightened(0.05), roof, 22.0, t, tm)
	_tower(ci, k, 0.0, 27.0, 34.0, 78.0, stone.lightened(0.1), roof, 36.0, t, tm)
	_gate(ci, k, 0.0, 27.0, 14.0, 18.0)
	# cannons poking out of the outer towers
	_line(ci, k, -68.0, -22.0, -82.0, -26.0, Color(0.12, 0.12, 0.15), 4.0)
	_line(ci, k, 68.0, -22.0, 82.0, -26.0, Color(0.12, 0.12, 0.15), 4.0)
	_flag(ci, k, 0.0, -116.0, tm, Color(0.6, 0.1, 0.15))
	_ball(ci, k, -24.0, 8.0, 1.6, Color(1.0, 0.6, 0.2))
	_ball(ci, k, 24.0, 8.0, 1.6, Color(1.0, 0.6, 0.2))

static func _capital(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var stone := Color(0.56, 0.57, 0.68)
	var gold := Color(0.88, 0.7, 0.22)
	var blue := Color(0.2, 0.28, 0.58)
	_wall(ci, k, -70.0, 70.0, 25.0, 30.0, stone.darkened(0.1), t)
	_tower(ci, k, -62.0, 26.0, 18.0, 62.0, stone, blue, 24.0, t, tm)
	_tower(ci, k, 62.0, 26.0, 18.0, 62.0, stone, blue, 24.0, t, tm)
	_tower(ci, k, -38.0, 26.0, 16.0, 74.0, stone.lightened(0.05), gold, 26.0, t, tm)
	_tower(ci, k, 38.0, 26.0, 16.0, 74.0, stone.lightened(0.05), gold, 26.0, t, tm)
	_tower(ci, k, -16.0, 27.0, 14.0, 62.0, stone.lightened(0.1), blue, 20.0, t, tm)
	_tower(ci, k, 16.0, 27.0, 14.0, 62.0, stone.lightened(0.1), blue, 20.0, t, tm)
	_tower(ci, k, 0.0, 28.0, 30.0, 96.0, stone.lightened(0.15), gold, 44.0, t, tm)
	_gate(ci, k, 0.0, 28.0, 14.0, 18.0)
	_rect(ci, k, -70.0, -6.0, 140.0, 2.0, _tn(gold, t))
	_flag(ci, k, 0.0, -160.0, tm, Color(0.85, 0.15, 0.2))
	_flag(ci, k, -38.0, -126.0, tm + 1.0, Color(0.85, 0.15, 0.2))
	_flag(ci, k, 38.0, -126.0, tm + 2.0, Color(0.85, 0.15, 0.2))

static func _flame(ci: CanvasItem, k: float, x: float, y: float, w: float, ln: float, tm: float) -> void:
	var f: float = 0.8 + 0.2 * sin(tm * 22.0 + x)
	_ball(ci, k, x, y + ln * 0.4, w * 1.1, Color(1.0, 0.5, 0.15, 0.16))
	_tri(ci, k, x - w * 0.5, y, x + w * 0.5, y, x, y + ln * f, Color(1.0, 0.5, 0.15))
	_tri(ci, k, x - w * 0.25, y, x + w * 0.25, y, x, y + ln * f * 0.6, Color(1.0, 0.9, 0.5))

static func _lights(ci: CanvasItem, k: float, x1: float, x2: float, y: float, n: int, tm: float, col: Color) -> void:
	for i in range(n):
		var x: float = x1 + (x2 - x1) * float(i) / float(maxi(n - 1, 1))
		var on: float = 0.45 + 0.55 * maxf(0.0, sin(tm * 3.0 - float(i) * 0.7))
		_rect(ci, k, x - 1.2, y, 2.4, 2.4, Color(col.r * on, col.g * on, col.b * on))

static func _turret(ci: CanvasItem, k: float, x: float, y: float, rad: float, dx: float, dy: float, col: Color) -> void:
	_line(ci, k, x, y, x + dx, y + dy, Color(0.1, 0.1, 0.13), rad * 0.7)
	_ball(ci, k, x, y, rad, col.darkened(0.25))
	_ball(ci, k, x - rad * 0.2, y - rad * 0.25, rad * 0.65, col)

static func _battlestation(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var hull: Color = _tn(Color(0.4, 0.44, 0.55), t)
	var gold := Color(0.9, 0.72, 0.25)
	_poly(ci, k, [Vector2(-18, 22), Vector2(18, 22), Vector2(10, 40), Vector2(-10, 40)], hull.darkened(0.5))
	_poly(ci, k, [Vector2(-64, 2), Vector2(64, 2), Vector2(50, 24), Vector2(-50, 24)], hull.darkened(0.3))
	_poly(ci, k, [Vector2(-64, 2), Vector2(-52, -14), Vector2(52, -14), Vector2(64, 2)], hull)
	_rect(ci, k, -64.0, 1.0, 128.0, 2.0, _tn(gold, t))
	_rect(ci, k, -11.0, -42.0, 22.0, 30.0, hull.lightened(0.1))
	_rect(ci, k, 0.0, -42.0, 11.0, 30.0, hull.darkened(0.1))
	_ball(ci, k, 0.0, -46.0, 12.0, hull.lightened(0.2))
	_ball(ci, k, -3.0, -49.0, 5.0, Color(0.7, 0.95, 1.0))
	_line(ci, k, 0.0, -58.0, 0.0, -74.0, Color(0.7, 0.7, 0.75), 1.2)
	_ball(ci, k, 0.0, -74.0, 2.0, Color(1.0, 0.3, 0.3))
	for x: float in [-44.0, -26.0, 26.0, 44.0]:
		_turret(ci, k, x, -14.0, 7.0, 7.0 * signf(x), -8.0, hull.lightened(0.1))
	_lights(ci, k, -54.0, 54.0, 9.0, 14, tm, Color(0.5, 0.9, 1.0))
	_lights(ci, k, -44.0, 44.0, 16.0, 10, tm + 1.0, Color(1.0, 0.8, 0.4))
	_flame(ci, k, -36.0, 24.0, 9.0, 20.0, tm)
	_flame(ci, k, 36.0, 24.0, 9.0, 20.0, tm + 1.0)
	_flame(ci, k, 0.0, 40.0, 8.0, 18.0, tm + 2.0)

static func _juggernaut(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var hull: Color = _tn(Color(0.42, 0.34, 0.34), t)
	var plate: Color = hull.lightened(0.15)
	_tri(ci, k, -68.0, -8.0, -88.0, 0.0, -68.0, 8.0, hull.darkened(0.4))
	_tri(ci, k, 68.0, -8.0, 88.0, 0.0, 68.0, 8.0, hull.darkened(0.4))
	_poly(ci, k, [Vector2(-70, -6), Vector2(-58, -26), Vector2(58, -26), Vector2(70, -6), Vector2(64, 22), Vector2(40, 36), Vector2(-40, 36), Vector2(-64, 22)], hull.darkened(0.25))
	_poly(ci, k, [Vector2(-70, -6), Vector2(-58, -26), Vector2(58, -26), Vector2(70, -6)], hull)
	_rect(ci, k, -64.0, 0.0, 128.0, 6.0, plate)
	_rect(ci, k, -58.0, 12.0, 116.0, 6.0, plate.darkened(0.1))
	_rect(ci, k, -9.0, -40.0, 18.0, 16.0, hull.lightened(0.1))
	_rect(ci, k, -5.0, -36.0, 10.0, 4.0, Color(1.0, 0.3, 0.25))
	for i in range(3):
		var x: float = -40.0 + 40.0 * float(i)
		_rect(ci, k, x - 11.0, -32.0, 22.0, 8.0, plate)
		_turret(ci, k, x, -32.0, 9.0, 0.0, -14.0, plate)
		_line(ci, k, x - 3.0, -34.0, x - 3.0, -48.0, Color(0.1, 0.1, 0.13), 4.0)
		_line(ci, k, x + 3.0, -34.0, x + 3.0, -48.0, Color(0.1, 0.1, 0.13), 4.0)
	_lights(ci, k, -56.0, 56.0, 8.0, 12, tm, Color(1.0, 0.3, 0.2))
	for i in range(4):
		_flame(ci, k, -33.0 + 22.0 * float(i), 36.0, 10.0, 22.0, tm + float(i))

static func _dreadnaught(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var hull: Color = _tn(Color(0.3, 0.42, 0.44), t)
	_tri(ci, k, -20.0, 20.0, 20.0, 20.0, 0.0, 40.0, hull.darkened(0.5))
	_poly(ci, k, [Vector2(-80, 4), Vector2(-60, -8), Vector2(-14, -12), Vector2(14, -12), Vector2(60, -8), Vector2(80, 4), Vector2(60, 18), Vector2(14, 24), Vector2(-14, 24), Vector2(-60, 18)], hull.darkened(0.25))
	_poly(ci, k, [Vector2(-80, 4), Vector2(-60, -8), Vector2(-14, -12), Vector2(14, -12), Vector2(60, -8), Vector2(80, 4)], hull)
	_rect(ci, k, -10.0, -36.0, 20.0, 26.0, hull.lightened(0.08))
	_rect(ci, k, 0.0, -36.0, 10.0, 26.0, hull.darkened(0.1))
	_rect(ci, k, -6.0, -50.0, 12.0, 14.0, hull.lightened(0.18))
	_rect(ci, k, -5.0, -46.0, 10.0, 3.0, Color(0.6, 0.95, 1.0))
	_line(ci, k, 0.0, -50.0, 0.0, -66.0, Color(0.7, 0.75, 0.75), 1.2)
	_ball(ci, k, 0.0, -66.0, 2.5, Color(0.6, 0.95, 1.0))
	for i in range(5):
		var gx: float = 20.0 + 12.0 * float(i)
		_turret(ci, k, gx, -10.0, 4.5, 6.0, -5.0, hull.lightened(0.1))
		_turret(ci, k, -gx, -10.0, 4.5, -6.0, -5.0, hull.lightened(0.1))
	_lights(ci, k, -70.0, 70.0, 6.0, 20, tm, Color(0.5, 1.0, 0.9))
	_lights(ci, k, -60.0, 60.0, 13.0, 16, tm + 1.5, Color(1.0, 0.75, 0.35))
	_tri(ci, k, -26.0, 22.0, -44.0, 22.0, -36.0, 36.0, hull.darkened(0.4))
	_tri(ci, k, 26.0, 22.0, 44.0, 22.0, 36.0, 36.0, hull.darkened(0.4))
	for i in range(3):
		var fy: float = -2.0 + 7.0 * float(i)
		_poly(ci, k, [Vector2(-80, fy), Vector2(-80, fy + 5.0), Vector2(-96.0 - sin(tm * 20.0 + float(i)) * 3.0, fy + 2.5)], Color(1.0, 0.55, 0.2))
		_poly(ci, k, [Vector2(80, fy), Vector2(80, fy + 5.0), Vector2(96.0 + sin(tm * 20.0 + float(i)) * 3.0, fy + 2.5)], Color(1.0, 0.55, 0.2))

# A planet-eater: dark horned core with a golden ring and a glaring eye.
static func _worldeater(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var body: Color = _tn(Color(0.3, 0.14, 0.45), t)
	var gold := Color(0.95, 0.78, 0.3)
	_ball(ci, k, 0.0, 0.0, 64.0, Color(0.7, 0.3, 1.0, 0.07))
	for i in range(5):
		var a: float = TAU * float(i) / 10.0 + PI * 0.5
		var tipk: float = 70.0 + float(i % 2) * 10.0 + sin(tm * 2.0 + float(i)) * 2.0
		for side in range(2):
			var aa: float = a + PI * float(side)
			_poly(ci, k, [Vector2(cos(aa - 0.2), sin(aa - 0.2)) * 30.0, Vector2(cos(aa), sin(aa)) * tipk, Vector2(cos(aa + 0.2), sin(aa + 0.2)) * 30.0], body.lightened(0.12))
			_poly(ci, k, [Vector2(cos(aa), sin(aa)) * 30.0, Vector2(cos(aa), sin(aa)) * tipk, Vector2(cos(aa + 0.2), sin(aa + 0.2)) * 30.0], body.darkened(0.2))
	_ball(ci, k, 0.0, 0.0, 38.0, body.darkened(0.5))
	_ball(ci, k, -2.0, -2.0, 35.0, body.darkened(0.15))
	_ball(ci, k, -8.0, -9.0, 22.0, body.lightened(0.1))
	for i in range(30):
		var ra: float = TAU * float(i) / 30.0 + tm * 0.5
		var depth: float = sin(ra)
		_ball(ci, k, cos(ra) * 66.0, depth * 18.0 + 4.0, 1.4 + 0.8 * maxf(depth, 0.0), gold)
	var pulse: float = 0.5 + 0.5 * sin(tm * 2.5)
	_ball(ci, k, 0.0, 0.0, 17.0 + pulse * 4.0, Color(1.0, 0.2, 0.8, 0.2))
	_ball(ci, k, 0.0, 0.0, 12.0, Color(0.95, 0.25, 0.75))
	_ball(ci, k, 0.0, 0.0, 6.0, Color(1.0, 0.85, 0.95))
	_rect(ci, k, -1.4, -10.0, 2.8, 20.0, Color(0.15, 0.03, 0.2))
	for i in range(5):
		var oa: float = tm * 0.7 + TAU * float(i) / 5.0
		_ball(ci, k, cos(oa) * 84.0, sin(oa) * 30.0 + 4.0, 2.0 + float(i % 2), Color(0.6, 0.45, 0.7))

static func _death_star(ci: CanvasItem, k: float, t: float, tm: float) -> void:
	var rad: float = 58.0
	var base := _tn(Color(0.17, 0.17, 0.22), t)
	var pulse: float = 0.5 + 0.5 * sin(tm * 2.6)
	_ball(ci, k, 0.0, 0.0, rad + 16.0, Color(0.8, 0.08, 0.12, 0.05 + 0.05 * pulse))
	_ball(ci, k, 0.0, 0.0, rad + 7.0, Color(0.8, 0.08, 0.12, 0.07 + 0.05 * pulse))
	_ball(ci, k, 0.0, 0.0, rad, base.darkened(0.6))
	_ball(ci, k, -3.0, -3.0, rad * 0.94, base.darkened(0.3))
	_ball(ci, k, -8.0, -8.0, rad * 0.74, base)
	_ball(ci, k, -14.0, -14.0, rad * 0.36, base.lightened(0.06))
	# hull plating seams and greebles
	var seam: Color = base.darkened(0.55)
	_rect(ci, k, -34.0, 14.0, 22.0, 2.0, seam)
	_rect(ci, k, -18.0, 24.0, 30.0, 2.0, seam)
	_rect(ci, k, 14.0, 20.0, 20.0, 2.0, seam)
	_rect(ci, k, -40.0, -22.0, 12.0, 2.0, seam)
	_rect(ci, k, -2.0, 34.0, 2.0, 12.0, seam)
	_rect(ci, k, -24.0, 28.0, 2.0, 10.0, seam)
	_rect(ci, k, -30.0, -8.0, 8.0, 4.0, seam)
	# equator trench with blinking red lights
	_rect(ci, k, -rad * 0.98, -2.5, rad * 1.96, 5.0, Color(0.02, 0.02, 0.04))
	for i in range(11):
		var on: float = 0.35 + 0.65 * maxf(0.0, sin(tm * 3.0 - float(i) * 0.6))
		_rect(ci, k, -rad * 0.9 + float(i) * rad * 0.18, -1.0, 2.0, 2.0, Color(1.0 * on, 0.12 * on, 0.1 * on))
	# the superlaser dish: a baleful red eye
	_ball(ci, k, 20.0, -20.0, 18.0, Color(0.03, 0.03, 0.05))
	_ball(ci, k, 20.0, -20.0, 14.0, base.darkened(0.45))
	_ball(ci, k, 20.0, -20.0, 11.0 + pulse * 3.0, Color(1.0, 0.1, 0.08, 0.28))
	_ball(ci, k, 20.0, -20.0, 7.0 + pulse * 1.5, Color(1.0, 0.18, 0.12))
	_ball(ci, k, 20.0, -20.0, 3.0, Color(1.0, 0.8, 0.7))
	# orbiting red warning lights
	for i in range(4):
		var a: float = tm * 0.9 + TAU * float(i) / 4.0
		_ball(ci, k, cos(a) * (rad + 14.0), sin(a) * (rad + 14.0) * 0.35 + 6.0, 2.2, Color(1.0, 0.2, 0.15, 0.9))

static func draw_all(ci: CanvasItem, tier: int, r: float, tm: float, hurt: float) -> void:
	var k: float = r / 60.0
	if tier == 5:
		_battlestation(ci, k, hurt, tm)
		return
	if tier == 6:
		_juggernaut(ci, k, hurt, tm)
		return
	if tier == 7:
		_dreadnaught(ci, k, hurt, tm)
		return
	if tier == 8:
		_worldeater(ci, k, hurt, tm)
		return
	if tier >= 9:
		_death_star(ci, k, hurt, tm)
		return
	var grass := Color(0.3, 0.6, 0.28)
	if tier >= 3:
		grass = Color(0.26, 0.5, 0.3)
	_island(ci, k, hurt, tm, grass)
	if tier == 0:
		_village(ci, k, hurt, tm)
	elif tier == 1:
		_town(ci, k, hurt, tm)
	elif tier == 2:
		_city(ci, k, hurt, tm)
	elif tier == 3:
		_fortress(ci, k, hurt, tm)
	else:
		_capital(ci, k, hurt, tm)
