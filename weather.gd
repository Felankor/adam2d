class_name Weather
extends Node2D

# Screen-space weather for each biome. Particles drift on their own and also slide
# opposite to the castle's flight, so the sky feels like part of the moving world.
#   0 Greenland: drifting petals + soft sun rays      1 Mudland: heavy rain + lightning
#   2 Rocky Mountain: snow in gusty wind               3 Hell: rising embers + red glow
#   3 Dark Continent: fireflies   4 Forgotten Realm: golden motes   5 Cursed Garden: dead petals + fog   6 Deep Ocean: bubbles
#   7 Hell (above)   8 Space: meteors streaking by + drifting dust
const COUNTS := [48, 150, 130, 90, 70, 70, 60, 100, 40]
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
# Deep Ocean details: 0 ripple ring, 1 leaping fish, 2 gull. Positions slide with the world like the spray.
var _ep := PackedVector2Array()
var _et := PackedFloat32Array()
var _ek := PackedInt32Array()
var _ev := PackedVector2Array()
var _es := PackedFloat32Array()
var _ripple_t: float = 0.5
var _fish_t: float = 3.0
var _gull_t: float = 4.0

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
	_ep.clear()
	_et.clear()
	_ek.clear()
	_ev.clear()
	_es.clear()
	for i in int(COUNTS[clampi(b, 0, COUNTS.size() - 1)]):
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
		3:        # Dark Continent: fireflies and spores drifting in every direction
			vel = Vector2(randf_range(-30.0, 30.0), randf_range(-26.0, 22.0))
			sz = randf_range(1.6, 3.4)
		4:        # Forgotten Realm: golden motes of light rising slowly
			vel = Vector2(randf_range(-10.0, 10.0), randf_range(-45.0, -15.0))
			sz = randf_range(1.8, 3.6)
		5:        # Cursed Garden: dead petals and spores drifting down through a violet fog
			vel = Vector2(randf_range(10.0, 50.0), randf_range(25.0, 70.0))
			sz = randf_range(2.5, 5.0)
		6:        # Deep Ocean: sea spray blown along by the wind
			vel = Vector2(randf_range(50.0, 130.0), randf_range(-12.0, 18.0))
			sz = randf_range(1.4, 3.2)
		7:
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
		elif biome == 5:
			p.x += sin(_ph[i]) * 24.0 * delta
		elif biome == 6:
			p.x += sin(_ph[i] * 1.3) * 22.0 * delta
		elif biome == 3:
			p += Vector2(sin(_ph[i] * 0.8) * 26.0, cos(_ph[i] * 0.6) * 20.0) * delta     # fireflies wander
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
	elif biome == 6:
		_tick_sea(delta, shift)
	elif biome == 8:
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

func _add_sea(pos: Vector2, kind: int, vel: Vector2) -> void:
	if _ep.size() >= 40:
		return
	_ep.append(pos)
	_et.append(0.0)
	_ek.append(kind)
	_ev.append(vel)
	_es.append(randf() * TAU)

func _tick_sea(delta: float, shift: Vector2) -> void:
	var w := Settings.WORLD_SIZE
	_ripple_t -= delta
	if _ripple_t <= 0.0:
		_ripple_t = randf_range(0.3, 0.9)
		_add_sea(Vector2(randf_range(0.0, w.x), randf_range(0.0, w.y)), 0, Vector2.ZERO)
	_fish_t -= delta
	if _fish_t <= 0.0:
		_fish_t = randf_range(3.0, 7.0)
		_add_sea(Vector2(randf_range(w.x * 0.1, w.x * 0.9), randf_range(w.y * 0.15, w.y * 0.9)), 1, Vector2(randf_range(40.0, 70.0), 0.0) * (1.0 if randf() < 0.5 else -1.0))
	_gull_t -= delta
	if _gull_t <= 0.0:
		_gull_t = randf_range(9.0, 18.0)
		var gy := randf_range(w.y * 0.1, w.y * 0.8)
		for k in 3:
			_add_sea(Vector2(-60.0 - 70.0 * float(k), gy + 40.0 * float(k) * (1.0 if k % 2 == 0 else -1.0)), 2, Vector2(randf_range(120.0, 150.0), randf_range(-8.0, 12.0)))
	var i := _ep.size() - 1
	while i >= 0:
		_ep[i] = _ep[i] + _ev[i] * delta + shift
		_et[i] += delta
		var done := false
		if _ek[i] == 0:
			done = _et[i] > 2.4
		elif _ek[i] == 1:
			if _et[i] > 0.8:
				done = true
				_add_sea(_ep[i] + Vector2(_ev[i].x * 0.0, 0.0), 0, Vector2.ZERO)     # it lands: a ripple spreads
		else:
			done = _ep[i].x > w.x + 200.0
		if done:
			_ep.remove_at(i)
			_et.remove_at(i)
			_ek.remove_at(i)
			_ev.remove_at(i)
			_es.remove_at(i)
		i -= 1

func _draw_sea() -> void:
	var sq := MobArt.GROUND_SQUASH
	for i in _ep.size():
		var p := _ep[i]
		var k := _ek[i]
		if k == 0:           # ripple rings lie on the water: flattened by the camera tilt
			var u := _et[i] / 2.4
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, sq))
			var c := Vector2(p.x, p.y / sq)
			draw_arc(c, 5.0 + u * 46.0, 0.0, TAU, 28, Color(0.88, 0.97, 1.0, 0.5 * (1.0 - u)), 2.0)
			if u > 0.25:
				draw_arc(c, 2.0 + (u - 0.25) * 40.0, 0.0, TAU, 24, Color(0.88, 0.97, 1.0, 0.35 * (1.0 - u)), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif k == 1:         # a fish leaps out of the water in an arc
			var u2 := _et[i] / 0.8
			var lift := sin(u2 * PI) * 34.0
			var dirx := signf(_ev[i].x)
			var fp := p + Vector2(0.0, -lift)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, sq))
			draw_circle(Vector2(p.x, p.y / sq), 7.0, Color(0.0, 0.05, 0.12, 0.2))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var tilt := -cos(u2 * PI) * 0.9 * dirx
			var fw := Vector2(cos(tilt), sin(tilt)) * dirx
			var side := fw.orthogonal()
			draw_colored_polygon(PackedVector2Array([fp + fw * 9.0, fp + side * 3.5, fp - fw * 8.0, fp - side * 3.5]), Color(0.62, 0.8, 0.9))
			draw_colored_polygon(PackedVector2Array([fp + fw * 9.0, fp - side * 3.5, fp - fw * 8.0, fp]), Color(0.9, 0.97, 1.0))
			draw_colored_polygon(PackedVector2Array([fp - fw * 7.0, fp - fw * 13.0 + side * 4.0, fp - fw * 13.0 - side * 4.0]), Color(0.45, 0.68, 0.82))
			if u2 < 0.18 or u2 > 0.82:
				for d in 5:
					var a := TAU * float(d) / 5.0 + 0.4
					draw_circle(p + Vector2(cos(a) * 9.0, sin(a) * 5.0 - 6.0), 1.4, Color(1.0, 1.0, 1.0, 0.7))
		else:                # a gull: body, flapping wings, and its shadow slides over the sea
			var flap := sin(_t * 9.0 + _es[i]) * 5.0
			var bob := sin(_t * 1.5 + _es[i]) * 4.0
			var gp := p + Vector2(0.0, bob)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, sq))
			var sp := Vector2(gp.x + 26.0, (gp.y + 62.0) / sq)
			draw_line(sp + Vector2(-3.0, -10.0), sp + Vector2(0.0, 0.0), Color(0.0, 0.05, 0.12, 0.16), 3.0)
			draw_line(sp + Vector2(-3.0, 10.0), sp + Vector2(0.0, 0.0), Color(0.0, 0.05, 0.12, 0.16), 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_line(gp, gp + Vector2(-4.0 + flap * 0.6, -11.0 - flap), Color(0.93, 0.95, 0.98), 3.0)
			draw_line(gp, gp + Vector2(-4.0 + flap * 0.6, 11.0 + flap), Color(0.8, 0.84, 0.9), 3.0)
			draw_circle(gp, 3.2, Color(1.0, 1.0, 1.0))
			draw_circle(gp + Vector2(3.4, 0.0), 1.6, Color(1.0, 1.0, 1.0))
			draw_circle(gp + Vector2(5.0, 0.0), 0.9, Color(1.0, 0.7, 0.2))

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
				draw_rect(full, Color(1.0, 1.0, 1.0, 0.45 * _flash * Settings.flash_scale))
		2:
			draw_rect(full, Color(0.75, 0.85, 1.0, 0.07))
			for i in _p.size():
				draw_circle(_p[i], _s[i], Color(1.0, 1.0, 1.0, 0.8))
		3:
			draw_rect(full, Color(0.02, 0.06, 0.12, 0.22))                       # the jungle night
			for i in _p.size():
				var pulse := 0.5 + 0.5 * sin(_ph[i] * 0.9)
				var c := Color(0.55, 1.0, 0.75) if i % 3 != 0 else Color(1.0, 0.95, 0.5)
				draw_circle(_p[i], _s[i] * 3.2, Color(c.r, c.g, c.b, 0.07 + 0.08 * pulse))
				draw_circle(_p[i], _s[i] * 0.9, Color(c.r, c.g, c.b, 0.35 + 0.6 * pulse))
		4:
			draw_rect(full, Color(1.0, 0.95, 0.7, 0.05 + 0.02 * sin(_t * 0.8)))
			for k in 4:
				var x1 := w.x * (0.1 + 0.25 * float(k)) + sin(_t * 0.15 + float(k) * 1.7) * 120.0
				draw_colored_polygon(PackedVector2Array([Vector2(x1, 0), Vector2(x1 + 90.0, 0), Vector2(x1 + 330.0, w.y), Vector2(x1 + 190.0, w.y)]), Color(1.0, 0.95, 0.7, 0.06))
			for i in _p.size():
				var tw := 0.5 + 0.5 * sin(_ph[i] * 1.2)
				draw_circle(_p[i], _s[i] * 2.6, Color(1.0, 0.92, 0.5, 0.06 + 0.06 * tw))
				draw_circle(_p[i], _s[i], Color(1.0, 0.97, 0.75, 0.4 + 0.5 * tw))
		5:
			draw_rect(full, Color(0.2, 0.08, 0.3, 0.14 + 0.04 * sin(_t * 0.6)))
			for k in 3:
				var fx := fposmod(_t * 14.0 + float(k) * w.x * 0.37, w.x + 600.0) - 300.0
				draw_circle(Vector2(fx, w.y * (0.25 + 0.25 * float(k))), 260.0, Color(0.55, 0.45, 0.7, 0.05))
			for i in _p.size():
				var a := _ph[i]
				var d1 := Vector2(cos(a), sin(a)) * _s[i]
				var d2 := Vector2(-sin(a), cos(a)) * _s[i] * 0.5
				var pc: Color = [Color(0.45, 0.1, 0.3), Color(0.35, 0.3, 0.5), Color(0.5, 0.75, 0.2)][i % 3]
				draw_colored_polygon(PackedVector2Array([_p[i] + d1, _p[i] + d2, _p[i] - d1, _p[i] - d2]), pc)
		6:
			draw_rect(full, Color(1.0, 0.95, 0.8, 0.035))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, MobArt.GROUND_SQUASH))      # shadows lie on the sea: squashed by the camera tilt
			for k in 3:          # cloud shadows drifting over the sea
				var cx := fposmod(w.x * (0.2 + 0.35 * float(k)) + _t * (14.0 + 5.0 * float(k)), w.x + 800.0) - 400.0
				var cy := w.y * (0.22 + 0.3 * float(k)) + sin(_t * 0.1 + float(k)) * 40.0
				draw_circle(Vector2(cx, cy), 230.0, Color(0.0, 0.05, 0.12, 0.06))
				draw_circle(Vector2(cx + 150.0, cy + 30.0), 170.0, Color(0.0, 0.05, 0.12, 0.05))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in _p.size():
				draw_line(_p[i], _p[i] - Vector2(_s[i] * 3.0, 0.0), Color(0.9, 0.98, 1.0, 0.3), maxf(_s[i] * 0.6, 1.0))
				draw_circle(_p[i], maxf(_s[i] * 0.5, 0.8), Color(1.0, 1.0, 1.0, 0.55))
			_draw_sea()
		7:
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
