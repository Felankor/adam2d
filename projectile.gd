class_name Projectile
extends Node2D

# kind: "bullet" (machinegun), "shell" (cannon), "rocket" (splash damage)
var kind: String = "shell"
var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var life: float = 2.0
var splash: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("shots")

func _process(delta: float) -> void:
	_t += delta
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var hit_radius := 3.0 if kind == "bullet" else 5.0
	# "mobs" holds both enemies and allies: our shots hit everything.
	for node in get_tree().get_nodes_in_group("mobs"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		if position.distance_to(e.position) <= e.radius + hit_radius:
			if kind == "rocket":
				_explode()
			else:
				e.take_damage(damage)
			queue_free()
			return
	# Enemy shells and boss orbs can be shot down.
	for node in get_tree().get_nodes_in_group("bolts"):
		var b := node as Node2D
		if b != null and position.distance_to(b.position) <= 20.0:
			Fx.spawn(get_parent(), "spark", b.position, Color(0.8, 0.4, 1.0), "", 1.1, 0.35)
			Sfx.play("hit")
			b.queue_free()
			queue_free()
			return
	if kind == "rocket":
		queue_redraw()

func _explode() -> void:
	var par := get_parent()
	Fx.spawn(par, "explosion", position, Color(1.0, 0.7, 0.3), "", 0.6, 0.45)
	Sfx.play("rocket_boom")
	for node in get_tree().get_nodes_in_group("mobs"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		var gap := position.distance_to(e.position) - e.radius
		if gap <= splash:
			var falloff := 1.0 - 0.5 * clampf(gap / splash, 0.0, 1.0)
			e.take_damage(damage * falloff)

func _draw() -> void:
	var dir := velocity.normalized()
	match kind:
		"bullet":
			draw_line(Vector2.ZERO, -dir * 16.0, Color(1.0, 0.9, 0.4, 0.5), 3.0)
			draw_circle(Vector2.ZERO, 2.6, Color(1.0, 0.97, 0.7))
		"rocket":
			var flick := 0.7 + 0.3 * sin(_t * 60.0)
			draw_line(Vector2.ZERO, -dir * 34.0 * flick, Color(1.0, 0.55, 0.15, 0.6), 9.0)
			draw_line(Vector2.ZERO, -dir * 20.0 * flick, Color(1.0, 0.9, 0.4), 5.0)
			draw_line(-dir * 4.0, dir * 12.0, Color(0.7, 0.72, 0.78), 8.0)
			draw_circle(dir * 13.0, 5.0, Color(0.9, 0.2, 0.15))
		_:
			draw_line(Vector2.ZERO, -dir * 18.0, Color(1.0, 0.6, 0.1, 0.45), 5.0)
			draw_circle(Vector2.ZERO, 6.0, Color.ORANGE_RED)
			draw_circle(Vector2.ZERO, 3.0, Color.YELLOW)
