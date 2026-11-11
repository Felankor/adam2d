class_name Weather
extends Node2D

# Screen-space weather for each biome. Particles drift on their own and also slide
# opposite to the castle's flight, so the sky feels like part of the moving world.
#   0 Greenland: drifting petals + soft sun rays      1 Mudland: heavy rain + lightning
#   2 Rocky Mountain: snow in gusty wind               3 Hell: rising embers + red glow
#   4 Space: meteors streaking by + drifting dust
const COUNTS := [48, 150, 130, 100, 40]
const PETALS := [Color(1.0, 0.6, 0.75), Color(1.0, 0.92, 0.35), Color(1.0, 1.0, 1.0), Color(0.75, 0.62, 1.0)]

var biome: int = 0
var zoom: float = 0.75
var _scroll: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _fade: float = 0.0
var _p := PackedVector2Array()
var _v := PackedVector2Array()
var _s := PackedFloat32Array()
var _ph := PackedFloat32Array()
var _flash: float = 0.0
var _flash_timer: float = 6.0
var _mp := PackedVector2Array()
var _mv := PackedVector2Array()
var _ml := PackedFloat32Array()
var _meteor_timer: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func set_biome(b: int) -> void:
	biome = b
	_fade = 0.0
	_p.clear()
	_v.clear()
	_s.clear()
	_ph.clear()
	_mp.clear()
	_mv.clear()
	_ml.clear()
	for i in int(COUNTS[clampi(b, 0, 4)]):
		_add_particle()

# Called every frame with how far the camera moved in the world.
func feed(world_move: Vector2, cam_zoom: float) -> void:
	_scroll += world_move
	zoom = cam_zoom

func _add_particle() -> void:
	var w := Settings.WORLD_SIZE
	var pos := Vector2(randf_range(-40.0, w.x + 40.0), randf_range(-40.0, w.y + 40.0))
	var vel := Vector2.ZERO
	var sz := 1.0
	match biome:
		0:
			vel = Vector2(randf_range(30.0, 80.0), randf_range(35.0, 80.0))
			sz = randf_range(3.0, 6.0)
		1:
			vel = Vector2(randf_range(-160.0, -100.0), randf_range(900.0, 1150.0))
			sz = randf_range(0.7, 1.2)
		2:
			vel = Vector2(randf_range(-70.0, -20.0), randf_range(40.0, 95.0))
			sz = randf_range(1.5, 3.5)
		3:
			vel = Vector2(randf_range(-25.0, 25.0), randf_range(-170.0, -60.0))
			sz = randf_range(1.2, 3.2)
		_:
			vel = Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
			sz = randf_range(0.8, 2.0)
	_p.append(pos)
	_v.append(vel)
	_s.append(sz)
	_ph.append(randf() * TAU)

func _process(delta: float) -> void:
	_t += delta
	_fade = minf(_fade + delta * 0.5, 1.0)
	modulate.a = _fade
	var w := Settings.WORLD_SIZE
	var shift := -_scroll * zoom * 0.55
	_scroll = Vector2.ZERO
	var wind := sin(_t * 0.3) * 40.0
	for i in _p.size():
		var p := _p[i] + _v[i] * delta + shift
		_ph[i] += delta * (2.0 + _s[i])
		if biome == 0:
			p.x += sin(_ph[i]) * 30.0 * delta
		elif biome == 2:
			p.x += (sin(_ph[i] * 0.7) * 20.0 + wind) * delta
		if p.x < -50.0:
			p.x += w.x + 100.0
		elif p.x > w.x + 50.0:
			p.x -= w.x + 100.0
		if p.y < -50.0:
			p.y += w.y + 100.0
		elif p.y > w.y + 50.0:
			p.y -= w.y + 100.0
		_p[i] = p
	if biome == 1:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash = 1.0
			_flash_timer = randf_range(7.0, 16.0)
		_flash = maxf(_flash - delta * 2.2, 0.0)
	elif biome == 4:
		_meteor_timer -= delta
		if _meteor_timer <= 0.0:
			_meteor_timer = randf_range(0.8, 2.5)
			_mp.append(Vector2(randf_range(w.x * 0.3, w.x * 1.1), -60.0))
			_mv.append(Vector2(-1100.0, 700.0) * randf_range(0.8, 1.3))
			_ml.append(1.8)
		var i := _mp.size() - 1
		while i >= 0:
			_mp[i] = _mp[i] + _mv[i] * delta + shift
			_ml[i] -= delta
			if _ml[i] <= 0.0 or _mp[i].x < -300.0 or _mp[i].y > w.y + 300.0:
				_mp.remove_at(i)
				_mv.remove_at(i)
				_ml.remove_at(i)
			i -= 1
	queue_redraw()

func _draw() -> void:
	var w := Settings.WORLD_SIZE
	var full := Rect2(Vector2.ZERO, w)
	match biome:
		0:
			for k in 3:
				var x0 := w.x * (0.15 + 0.3 * float(k)) + sin(_t * 0.2 + float(k)) * 90.0
				draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 130.0, 0), Vector2(x0 + 440.0, w.y), Vector2(x0 + 260.0, w.y)]), Color(1.0, 1.0, 0.7, 0.05))
			for i in _p.size():
				var a := _ph[i]
				var d1 := Vector2(cos(a), sin(a)) * _s[i]
				var d2 := Vector2(-sin(a), cos(a)) * _s[i] * 0.5
				draw_colored_polygon(PackedVector2Array([_p[i] + d1, _p[i] + d2, _p[i] - d1, _p[i] - d2]), PETALS[i % 4])
		1:
			draw_rect(full, Color(0.05, 0.07, 0.1, 0.18))
			for i in _p.size():
				draw_line(_p[i], _p[i] - _v[i] * 0.02 * _s[i], Color(0.72, 0.82, 0.95, 0.35), 1.5)
			if _flash > 0.0:
				draw_rect(full, Color(1.0, 1.0, 1.0, 0.45 * _flash))
		2:
			draw_rect(full, Color(0.75, 0.85, 1.0, 0.07))
			for i in _p.size():
				draw_circle(_p[i], _s[i], Color(1.0, 1.0, 1.0, 0.8))
		3:
			draw_rect(full, Color(1.0, 0.25, 0.0, 0.05 + 0.035 * sin(_t * 1.5)))
			for i in _p.size():
				var c := Color(1.0, 0.7, 0.2).lerp(Color(1.0, 0.2, 0.05), fposmod(_ph[i] * 0.2, 1.0))
				draw_circle(_p[i], _s[i] * 2.4, Color(c.r, c.g, c.b, 0.18))
				draw_circle(_p[i], _s[i], c)
		_:
			draw_rect(full, Color(0.25, 0.1, 0.45, 0.05))
			for i in _p.size():
				draw_circle(_p[i], _s[i], Color(0.85, 0.9, 1.0, 0.25 + 0.3 * (0.5 + 0.5 * sin(_ph[i] * 1.5))))
			for i in _mp.size():
				var dir := _mv[i].normalized()
				for seg in 3:
					var f := float(seg)
					draw_line(_mp[i] - dir * 90.0 * f, _mp[i] - dir * 90.0 * (f + 1.0), Color(0.7, 0.85, 1.0, 0.55 - 0.17 * f), 5.0 - 1.4 * f)
				draw_circle(_mp[i], 4.5, Color.WHITE)
