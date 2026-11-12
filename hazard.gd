class_name Hazard
extends Node2D

# A telegraphed ground attack used by the bosses. It shows a warning ring for `delay` seconds, then blasts:
# a castle inside the circle takes damage. Optional extras: a lingering pool (damage over time and a pull
# towards the middle), a slow, and an expanding "ring" wave instead of a circle.
#   style "mud"    Mud Colossus geysers: brown, slows the castle
#   style "meteor" Stone Titan meteors: orange fireball falling from the sky
#   style "spike"  Stone Titan stone spikes: grey spikes bursting up
#   style "void"   Void Overlord singularity: purple vortex that pulls the castle in
#   style "ring"   an expanding shockwave (Mud Colossus quake, Void nova); hits once when the wave passes the castle
signal status(text: String, kind: String)

var style: String = "mud"
var radius: float = 160.0
var delay: float = 1.2
var damage: float = 5.0
var pen: float = 20.0
var linger: float = 0.0            # seconds the pool stays and keeps hurting after the blast
var pull: float = 0.0              # pixels per second towards the middle while the pool lasts
var slow_factor: float = 1.0       # < 1: the castle moves slower after being hit
var slow_time: float = 0.0
var true_damage: bool = false
var ring_speed: float = 700.0
var base_ref: Base = null

var _t: float = 0.0
var _blasted: bool = false
var _tick: float = 0.0
var _hit: bool = false
var _seed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("hazards")
	z_index = 1
	_seed = randf() * 100.0

func _col() -> Color:
	match style:
		"mud":
			return Color(0.55, 0.36, 0.16)
		"meteor":
			return Color(1.0, 0.45, 0.1)
		"spike":
			return Color(0.65, 0.62, 0.58)
		"void":
			return Color(0.65, 0.3, 1.0)
	return Color(0.9, 0.6, 0.3)

func _inside(extra: float = 0.0) -> bool:
	return base_ref != null and is_instance_valid(base_ref) and base_ref.hp > 0.0 and base_ref.position.distance_to(position) <= radius + base_ref.hit_radius() * 0.6 + extra

func _hurt(amount: float) -> void:
	if base_ref == null or not is_instance_valid(base_ref):
		return
	base_ref.take_damage(amount, Weapons.TRUE_PEN if true_damage else pen)

func _process(delta: float) -> void:
	_t += delta
	if style == "ring":
		var r := ring_speed * _t
		if not _hit and base_ref != null and is_instance_valid(base_ref):
			var d := base_ref.position.distance_to(position)
			if absf(d - r) <= 40.0 + base_ref.hit_radius() * 0.7:
				_hit = true
				_hurt(damage)
				if slow_time > 0.0:
					base_ref.apply_slow(slow_factor, slow_time)
		if r > radius:
			queue_free()
		queue_redraw()
		return
	if not _blasted:
		if _t >= delay:
			_blasted = true
			_t = 0.0
			_blast()
	else:
		if linger > 0.0 and _t <= linger:
			_tick -= delta
			if _inside(radius * 0.4 if pull > 0.0 else 0.0):
				if _tick <= 0.0:
					_tick = 0.5
					_hurt(damage * 0.18)
			if pull > 0.0 and base_ref != null and is_instance_valid(base_ref):
				var to_mid := position - base_ref.position
				var dist := to_mid.length()
				if dist < radius * 2.4 and dist > 8.0:
					base_ref.shove(to_mid / dist * pull * delta * clampf(1.4 - dist / (radius * 2.4), 0.2, 1.0))
		elif _t > maxf(linger, 0.0) + 0.5:
			queue_free()
	queue_redraw()

func _blast() -> void:
	var par := get_parent()
	match style:
		"meteor":
			Fx.spawn(par, "explosion", position, Color.WHITE, "", radius / 90.0, 0.7)
			Sfx.play("rocket_boom", -2.0)
		"spike":
			Fx.spawn(par, "spark", position, Color(0.8, 0.78, 0.7), "", 2.0, 0.5)
			Sfx.play("explode", -4.0)
		"mud":
			Fx.spawn(par, "spark", position, Color(0.55, 0.36, 0.16), "", 2.0, 0.55)
			Sfx.play("explode", -6.0)
		"void":
			Fx.spawn(par, "void_blast", position, Color.WHITE, "", radius / 120.0, 0.7)
			Sfx.play("boss_split", -4.0)
	if _inside():
		_hurt(damage)
		if slow_time > 0.0 and base_ref != null:
			base_ref.apply_slow(slow_factor, slow_time)

func _draw() -> void:
	var col := _col()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, MobArt.GROUND_SQUASH))
	if style == "ring":
		var r := ring_speed * _t
		var a := clampf(1.0 - r / maxf(radius, 1.0), 0.0, 1.0)
		PixelFx.ring(self, Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.35 * a + 0.1), 30.0 * a + 6.0)
		PixelFx.ring(self, Vector2.ZERO, r, Color(1.0, 0.95, 0.85, 0.8 * a), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if not _blasted:
		var k := clampf(_t / maxf(delay, 0.01), 0.0, 1.0)
		var blink := 0.5 + 0.5 * sin(_t * 18.0)
		PixelFx.disc(self, Vector2.ZERO, radius, Color(col.r, col.g, col.b, 0.10 + 0.16 * k))
		PixelFx.disc(self, Vector2.ZERO, radius * k, Color(col.r, col.g, col.b, 0.22 + 0.2 * blink))
		PixelFx.ring(self, Vector2.ZERO, radius, Color(1.0, 0.3, 0.2, 0.55 + 0.35 * blink), 4.0)
		if style == "void":
			PixelFx.ring(self, Vector2.ZERO, radius * 2.4, Color(0.65, 0.3, 1.0, 0.18), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if style == "meteor":
			var h := (1.0 - k) * (1.0 - k) * 760.0
			var mp := Vector2(-h * 0.25, -h - 20.0)
			PixelFx.line(self, mp, mp + Vector2(h * 0.25, h) * 0.35, Color(1.0, 0.5, 0.1, 0.6), 18.0)
			PixelFx.disc(self, mp, 26.0, Color(0.2, 0.08, 0.04))
			PixelFx.disc(self, mp, 20.0, Color(1.0, 0.45, 0.1))
			PixelFx.disc(self, mp + Vector2(-5, -5), 9.0, Color(1.0, 0.9, 0.5))
		elif style == "spike":
			var n := 7
			for i in n:
				var ang := TAU * float(i) / float(n) + _seed
				var p := Vector2.RIGHT.rotated(ang) * radius * 0.55
				var hh := 8.0 + 26.0 * k
				PixelFx.line(self, p, p + Vector2(0, -hh), Color(0.55, 0.52, 0.5, 0.7), 10.0)
		return
	# blast flash and lingering pool
	var age := _t
	if age < 0.25:
		PixelFx.disc(self, Vector2.ZERO, radius * (0.8 + age), Color(1.0, 0.95, 0.8, 0.7 * (1.0 - age / 0.25)))
	var fade := 1.0
	if linger > 0.0:
		fade = clampf(1.0 - (age - maxf(linger - 0.6, 0.0)) / 0.6, 0.0, 1.0)
	else:
		fade = clampf(1.0 - age / 0.5, 0.0, 1.0)
	match style:
		"void":
			PixelFx.disc(self, Vector2.ZERO, radius, Color(0.08, 0.0, 0.16, 0.55 * fade))
			PixelFx.disc(self, Vector2.ZERO, radius * 0.45, Color(0.01, 0.0, 0.04, 0.85 * fade))
			for i in 4:
				var a0 := age * 3.0 + float(i) * TAU / 4.0
				PixelFx.arc(self, Vector2.ZERO, radius * (0.55 + 0.12 * float(i)), a0, a0 + 1.6, Color(0.75, 0.4, 1.0, 0.8 * fade), 4.0)
		"mud":
			PixelFx.disc(self, Vector2.ZERO, radius, Color(0.32, 0.2, 0.08, 0.6 * fade))
			for i in 8:
				var bp := Vector2.RIGHT.rotated(float(i) * 0.9 + _seed) * radius * (0.2 + 0.6 * fmod(float(i) * 0.37, 1.0))
				PixelFx.disc(self, bp - Vector2(0, 8.0 * (0.5 + 0.5 * sin(age * 5.0 + float(i)))), 8.0, Color(0.55, 0.36, 0.16, 0.8 * fade))
		"meteor":
			PixelFx.disc(self, Vector2.ZERO, radius * 0.8, Color(0.15, 0.05, 0.02, 0.5 * fade))
			PixelFx.ring(self, Vector2.ZERO, radius * 0.8, Color(1.0, 0.4, 0.1, 0.7 * fade), 4.0)
		"spike":
			PixelFx.disc(self, Vector2.ZERO, radius, Color(0.3, 0.28, 0.26, 0.4 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if style == "spike":
		for i in 9:
			var ang := TAU * float(i) / 9.0 + _seed
			var p := Vector2.RIGHT.rotated(ang) * radius * (0.25 + 0.55 * fmod(float(i) * 0.43, 1.0))
			PixelFx.line(self, p, p + Vector2(0, -44.0 * fade), Color(0.12, 0.1, 0.1, fade), 16.0)
			PixelFx.line(self, p, p + Vector2(0, -44.0 * fade), Color(0.72, 0.68, 0.62, fade), 10.0)
