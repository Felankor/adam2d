class_name Projectile
extends Node2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var life: float = 2.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("shots")

func _process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	# "mobs" holds both enemies and allies: our shots hit everything.
	for node in get_tree().get_nodes_in_group("mobs"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		if position.distance_to(e.position) <= e.radius + 5.0:
			e.take_damage(damage)
			queue_free()
			return
	# Boss energy bolts can be shot down.
	for node in get_tree().get_nodes_in_group("bolts"):
		var b := node as Node2D
		if b != null and position.distance_to(b.position) <= 20.0:
			Fx.spawn(get_parent(), "spark", b.position, Color(0.8, 0.4, 1.0), "", 1.1, 0.35)
			Sfx.play("hit")
			b.queue_free()
			queue_free()
			return

func _draw() -> void:
	var dir := velocity.normalized()
	draw_line(Vector2.ZERO, -dir * 18.0, Color(1.0, 0.6, 0.1, 0.45), 5.0)
	draw_circle(Vector2.ZERO, 6.0, Color.ORANGE_RED)
	draw_circle(Vector2.ZERO, 3.0, Color.YELLOW)
