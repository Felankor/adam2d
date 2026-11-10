class_name Backdrop
extends Node2D

# Draws one themed battlefield. biome: 0 garden, 1 mud, 2 rocks, 3 hell, 4 space.
# Everything is drawn once and cached by Godot, so it costs almost nothing per frame.
const SIZE := Vector2(1920, 1080)

var biome: int = 0

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + biome * 7919
	match biome:
		0:
			_garden(rng)
		1:
			_mud(rng)
		2:
			_rocks(rng)
		3:
			_hell(rng)
		_:
			_space(rng)

# ---------- helpers ----------

func _rp(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(0.0, SIZE.x), rng.randf_range(0.0, SIZE.y))

func _gradient(top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(SIZE.x, 0), SIZE, Vector2(0, SIZE.y)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))

func _blob(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _crack(rng: RandomNumberGenerator, start: Vector2, segs: int, step: float) -> PackedVector2Array:
	var pts := PackedVector2Array([start])
	var a := rng.randf() * TAU
	var p := start
	for i in segs:
		a += rng.randf_range(-0.7, 0.7)
		p += Vector2.RIGHT.rotated(a) * step * rng.randf_range(0.6, 1.3)
		pts.append(p)
	return pts

func _rock_shape(rng: RandomNumberGenerator, center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 8
	for i in n:
		var a := TAU * i / n
		pts.append(center + Vector2.RIGHT.rotated(a) * radius * rng.randf_range(0.7, 1.1))
	return pts

# ---------- biomes ----------

func _garden(rng: RandomNumberGenerator) -> void:
	_gradient(Color(0.36, 0.68, 0.32), Color(0.24, 0.52, 0.22))
	for i in 28:
		var c := Color(0.2, 0.5, 0.2, 0.18) if i % 2 == 0 else Color(0.55, 0.82, 0.4, 0.14)
		_blob(_rp(rng), rng.randf_range(90.0, 240.0), rng.randf_range(60.0, 140.0), c)
	for i in 520:
		var p := _rp(rng)
		var h := rng.randf_range(6.0, 12.0)
		var col := Color(0.15, 0.42, 0.16, 0.8)
		draw_line(p, p + Vector2(-3, -h), col, 1.5)
		draw_line(p, p + Vector2(0, -h - 3), col, 1.5)
		draw_line(p, p + Vector2(3, -h), col, 1.5)
	var petals := [Color(1.0, 0.55, 0.7), Color(1.0, 0.9, 0.3), Color(1, 1, 1), Color(0.75, 0.6, 1.0)]
	for i in 110:
		var f := _rp(rng)
		draw_circle(f, rng.randf_range(3.0, 5.0), petals[rng.randi() % petals.size()])
		draw_circle(f, 1.5, Color(0.95, 0.75, 0.15))
	_blob(Vector2(380, 830), 200.0, 95.0, Color(0.12, 0.28, 0.45))
	_blob(Vector2(380, 830), 180.0, 80.0, Color(0.22, 0.50, 0.75))
	_blob(Vector2(340, 812), 75.0, 22.0, Color(0.6, 0.82, 0.95, 0.5))
	_blob(Vector2(1560, 250), 150.0, 70.0, Color(0.12, 0.28, 0.45))
	_blob(Vector2(1560, 250), 132.0, 58.0, Color(0.22, 0.50, 0.75))
	for i in 16:
		var t := _rp(rng)
		var r := rng.randf_range(30.0, 52.0)
		draw_circle(t + Vector2(9, 11), r, Color(0, 0, 0, 0.18))
		draw_circle(t, r, Color(0.10, 0.38, 0.14))
		draw_circle(t + Vector2(-r * 0.25, -r * 0.25), r * 0.6, Color(0.20, 0.55, 0.22))

func _mud(rng: RandomNumberGenerator) -> void:
	_gradient(Color(0.46, 0.34, 0.22), Color(0.28, 0.20, 0.13))
	for i in 30:
		var c := Color(0.2, 0.13, 0.08, 0.2) if i % 2 == 0 else Color(0.6, 0.45, 0.3, 0.12)
		_blob(_rp(rng), rng.randf_range(90.0, 240.0), rng.randf_range(50.0, 130.0), c)
	for i in 16:
		var p := _rp(rng)
		var rx := rng.randf_range(60.0, 150.0)
		var ry := rx * 0.45
		_blob(p, rx + 10.0, ry + 8.0, Color(0.18, 0.12, 0.08))
		_blob(p, rx, ry, Color(0.30, 0.24, 0.19))
		_blob(p + Vector2(-rx * 0.2, -ry * 0.2), rx * 0.55, ry * 0.4, Color(0.55, 0.60, 0.62, 0.35))
	for i in 30:
		draw_polyline(_crack(rng, _rp(rng), 6, 34.0), Color(0.16, 0.10, 0.07, 0.7), 2.0)
	for i in 90:
		var s := _rp(rng)
		var r := rng.randf_range(3.0, 8.0)
		draw_circle(s + Vector2(2, 2), r, Color(0, 0, 0, 0.25))
		draw_circle(s, r, Color(0.5, 0.46, 0.42))
		draw_circle(s + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(0.7, 0.66, 0.6))
	for i in 140:
		var st := _rp(rng)
		draw_line(st, st + Vector2(rng.randf_range(-5.0, 5.0), -rng.randf_range(8.0, 16.0)), Color(0.55, 0.42, 0.25, 0.8), 1.5)

func _rocks(rng: RandomNumberGenerator) -> void:
	_gradient(Color(0.52, 0.52, 0.56), Color(0.30, 0.31, 0.36))
	for i in 24:
		var c := Color(0.2, 0.2, 0.25, 0.18) if i % 2 == 0 else Color(0.7, 0.7, 0.75, 0.12)
		_blob(_rp(rng), rng.randf_range(90.0, 240.0), rng.randf_range(50.0, 130.0), c)
	for i in 30:
		draw_polyline(_crack(rng, _rp(rng), 7, 40.0), Color(0.15, 0.15, 0.2, 0.6), 2.0)
	# mountain ridge along the top
	var ridge := PackedVector2Array([Vector2(0, 0)])
	var x := 0.0
	while x <= SIZE.x + 140.0:
		ridge.append(Vector2(x, rng.randf_range(70.0, 210.0)))
		x += 140.0
	ridge.append(Vector2(SIZE.x + 140.0, 0))
	draw_colored_polygon(ridge, Color(0.22, 0.23, 0.28))
	for i in range(1, ridge.size() - 1):
		var peak := ridge[i]
		if peak.y < 130.0:
			draw_colored_polygon(PackedVector2Array([peak + Vector2(0, -2), peak + Vector2(-26, 34), peak + Vector2(26, 34)]), Color(0.93, 0.95, 1.0))
	for i in 42:
		var p := _rp(rng)
		var r := rng.randf_range(25.0, 70.0)
		draw_colored_polygon(_rock_shape(rng, p + Vector2(9, 11), r), Color(0, 0, 0, 0.25))
		var shade := rng.randf_range(0.38, 0.58)
		draw_colored_polygon(_rock_shape(rng, p, r), Color(shade, shade, shade + 0.05))
		draw_colored_polygon(_rock_shape(rng, p + Vector2(-r * 0.2, -r * 0.2), r * 0.55), Color(shade + 0.12, shade + 0.12, shade + 0.17, 0.8))

func _space(rng: RandomNumberGenerator) -> void:
	_gradient(Color(0.02, 0.02, 0.08), Color(0.09, 0.03, 0.16))
	var neb := [Color(0.5, 0.2, 0.7, 0.08), Color(0.2, 0.3, 0.8, 0.08), Color(0.8, 0.2, 0.5, 0.06)]
	for i in 10:
		_blob(_rp(rng), rng.randf_range(220.0, 520.0), rng.randf_range(140.0, 300.0), neb[i % neb.size()])
	for i in 420:
		var p := _rp(rng)
		var a := rng.randf_range(0.35, 1.0)
		var tint := rng.randi() % 5
		var col := Color(1, 1, 1, a)
		if tint == 0:
			col = Color(0.7, 0.8, 1.0, a)
		elif tint == 1:
			col = Color(1.0, 0.9, 0.7, a)
		draw_circle(p, rng.randf_range(0.8, 2.2), col)
	for i in 16:
		var b := _rp(rng)
		var l := rng.randf_range(10.0, 18.0)
		draw_circle(b, 9.0, Color(0.7, 0.8, 1.0, 0.12))
		draw_line(b + Vector2(-l, 0), b + Vector2(l, 0), Color(1, 1, 1, 0.8), 1.5)
		draw_line(b + Vector2(0, -l), b + Vector2(0, l), Color(1, 1, 1, 0.8), 1.5)
		draw_circle(b, 2.5, Color.WHITE)
	var planet := Vector2(SIZE.x * 0.85, SIZE.y * 0.2)
	draw_circle(planet, 92.0, Color(0.28, 0.38, 0.70))
	draw_circle(planet + Vector2(-18, -18), 68.0, Color(0.38, 0.50, 0.82))
	draw_circle(planet + Vector2(40, 40), 70.0, Color(0.0, 0.0, 0.05, 0.35))
	draw_set_transform(planet, -0.4, Vector2(1.0, 0.28))
	draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 96, Color(0.85, 0.75, 0.55, 0.7), 6.0)
	draw_arc(Vector2.ZERO, 168.0, 0.0, TAU, 96, Color(0.85, 0.75, 0.55, 0.35), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var moon := Vector2(SIZE.x * 0.12, SIZE.y * 0.82)
	draw_circle(moon, 46.0, Color(0.6, 0.6, 0.64))
	draw_circle(moon + Vector2(-10, -8), 9.0, Color(0.45, 0.45, 0.5))
	draw_circle(moon + Vector2(12, 14), 6.0, Color(0.45, 0.45, 0.5))

func _hell(rng: RandomNumberGenerator) -> void:
	_gradient(Color(0.14, 0.02, 0.02), Color(0.36, 0.07, 0.02))
	for i in 26:
		var c := Color(0.05, 0.0, 0.0, 0.22) if i % 2 == 0 else Color(0.6, 0.12, 0.02, 0.12)
		_blob(_rp(rng), rng.randf_range(90.0, 260.0), rng.randf_range(50.0, 140.0), c)
	for i in 16:
		var p := _rp(rng)
		var r := rng.randf_range(25.0, 60.0)
		draw_colored_polygon(_rock_shape(rng, p, r), Color(0.10, 0.05, 0.05))
		draw_colored_polygon(_rock_shape(rng, p + Vector2(-r * 0.15, -r * 0.15), r * 0.55), Color(0.18, 0.09, 0.08))
	for i in 18:
		var line := _crack(rng, _rp(rng), 9, 55.0)
		draw_polyline(line, Color(1.0, 0.3, 0.0, 0.18), 18.0)
		draw_polyline(line, Color(1.0, 0.45, 0.05), 7.0)
		draw_polyline(line, Color(1.0, 0.85, 0.25), 2.5)
	for i in 8:
		var p := _rp(rng)
		var rx := rng.randf_range(70.0, 140.0)
		var ry := rx * 0.5
		_blob(p, rx + 14.0, ry + 10.0, Color(0.15, 0.03, 0.02))
		_blob(p, rx, ry, Color(0.9, 0.3, 0.05))
		_blob(p, rx * 0.65, ry * 0.6, Color(1.0, 0.6, 0.1))
		_blob(p, rx * 0.3, ry * 0.3, Color(1.0, 0.9, 0.4))
	for i in 170:
		var e := _rp(rng)
		var col := Color(1.0, 0.55, 0.1, rng.randf_range(0.4, 0.95)) if i % 3 != 0 else Color(1.0, 0.9, 0.3, rng.randf_range(0.4, 0.95))
		draw_circle(e, rng.randf_range(1.2, 3.2), col)
	var x := 0.0
	while x < SIZE.x:
		var h := rng.randf_range(30.0, 90.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, SIZE.y), Vector2(x + 30.0, SIZE.y - h), Vector2(x + 60.0, SIZE.y)]), Color(0.06, 0.02, 0.02))
		x += 60.0
