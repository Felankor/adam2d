class_name Projectile
extends Node2D

# kind: "bullet" (machinegun), "shell" (cannon), "rocket" (splash damage)
var kind: String = "shell"
var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var life: float = 2.0
var splash: float = 0.0
var pen: float = 0.0              # armor penetration
var gen: int = 0                  # Void Gun: 0 = main shot, 1 = one of the 4 lesser fragments it splits into
var skip: Enemy = null            # a fragment ignores the mob its parent just hit
var _t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("shots")

func _process(delta: float) -> void:
	_t += delta
	var prev := position
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var hit_radius := 3.0 if kind == "bullet" else 5.0
	# "mobs" holds both enemies and allies: our shots hit everything. Only mobs near this
	# frame's path are looked at (see Field); the nearest one along the path is the one hit.
	var best: Enemy = null
	var best_d := INF
	var best_pt := position
	for e in Field.near((prev + position) * 0.5, hit_radius + prev.distance_to(position) * 0.5):
		if e.dead or e == skip:
			continue
		# swept check along this frame's path, so fast shots cannot skip over small mobs
		var closest := Geometry2D.get_closest_point_to_segment(e.position, prev, position)
		if closest.distance_to(e.position) <= e.radius + hit_radius:
			var d := prev.distance_squared_to(closest)
			if d < best_d:
				best_d = d
				best = e
				best_pt = closest
	if best != null:
		position = best_pt
		if kind == "rocket" or kind == "void":
			_explode(best)
		else:
			best.take_damage(damage, pen)
		queue_free()
		return
	# Enemy shells and boss orbs can be shot down.
	for b in Field.bolts():
		if b.is_queued_for_deletion():
			continue
		if position.distance_to(b.position) <= 20.0:
			Fx.spawn(get_parent(), "spark", b.position, Color(0.8, 0.4, 1.0), "", 1.1, 0.35)
			Sfx.play("hit")
			b.queue_free()
			queue_free()
			return
	if kind == "rocket" or kind == "void":
		queue_redraw()

func _explode(hit: Enemy = null) -> void:
	var par := get_parent()
	if kind == "void":
		Fx.spawn(par, "void_blast", position, Color(0.55, 0.15, 0.95), "", splash / 110.0, 0.6)
		Sfx.play("void_boom", -6.0 if gen > 0 else 0.0)
	else:
		Fx.spawn(par, "explosion", position, Color(1.0, 0.7, 0.3), "", 0.6, 0.45)
		Sfx.play("rocket_boom")
	for e in Field.near(position, splash):
		if e.dead:
			continue
		var gap := position.distance_to(e.position) - e.radius
		if gap <= splash:
			var falloff := 1.0 - 0.5 * clampf(gap / splash, 0.0, 1.0)
			e.take_damage(damage * falloff, pen)
	if kind == "void" and gen == 0:
		_split(par, hit)

# The main Void shot bursts into 4 lesser shots; each explodes too if it hits something.
func _split(par: Node, hit: Enemy) -> void:
	var a0 := randf() * TAU
	for i in 4:
		var p := Projectile.new()
		p.kind = "void"
		p.gen = 1
		p.skip = hit
		p.damage = damage * 0.5
		p.splash = splash * 0.55
		p.pen = pen
		p.life = 0.7
		p.velocity = Vector2.RIGHT.rotated(a0 + TAU * float(i) / 4.0) * 460.0
		p.position = position
		par.add_child(p)

func _draw() -> void:
	var dir := velocity.normalized()
	if kind == "void" and gen > 0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.55, 0.55))
	match kind:
		"bullet":
			PixelFx.line(self, Vector2.ZERO, -dir * 15.0, Color(1.0, 0.9, 0.4, 0.55), 3.0)
			PixelFx.square(self, Vector2.ZERO, 6.0, Color(0.1, 0.06, 0.02))
			PixelFx.square(self, Vector2.ZERO, 3.0, Color(1.0, 0.97, 0.7))
		"void":
			var pulse := 0.5 + 0.5 * sin(_t * 18.0)
			for i in 5:
				PixelFx.disc(self, -dir * (10.0 + 11.0 * float(i)), 9.0 - float(i) * 1.4, Color(0.4, 0.08, 0.7, 0.4 - 0.06 * float(i)))
			PixelFx.disc(self, Vector2.ZERO, 18.0 + 3.0 * floorf(pulse * 2.0), Color(0.45, 0.1, 0.8, 0.3))
			PixelFx.disc(self, Vector2.ZERO, 12.0, Color(0.6, 0.2, 1.0))
			PixelFx.disc(self, Vector2.ZERO, 9.0, Color(0.03, 0.0, 0.08))
			PixelFx.ring(self, Vector2.ZERO, 15.0, Color(0.85, 0.6, 1.0, 0.8), 3.0)
		"rocket":
			var flick := 0.7 + 0.3 * sin(_t * 60.0)
			PixelFx.line(self, Vector2.ZERO, -dir * 34.0 * flick, Color(1.0, 0.55, 0.15, 0.7), 9.0)
			PixelFx.line(self, Vector2.ZERO, -dir * 20.0 * flick, Color(1.0, 0.9, 0.4), 6.0)
			PixelFx.line(self, -dir * 4.0, dir * 12.0, Color(0.05, 0.05, 0.08), 12.0)
			PixelFx.line(self, -dir * 4.0, dir * 12.0, Color(0.7, 0.72, 0.78), 6.0)
			PixelFx.square(self, dir * 14.0, 9.0, Color(0.9, 0.2, 0.15))
		_:
			PixelFx.line(self, Vector2.ZERO, -dir * 18.0, Color(1.0, 0.6, 0.1, 0.5), 6.0)
			PixelFx.disc(self, Vector2.ZERO, 8.0, Color(0.15, 0.05, 0.02))
			PixelFx.disc(self, Vector2.ZERO, 6.0, Color.ORANGE_RED)
			PixelFx.disc(self, Vector2.ZERO, 3.0, Color.YELLOW)
