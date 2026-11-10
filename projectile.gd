class_name Projectile
extends Node2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var life: float = 2.0

func _process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		if position.distance_to(e.position) <= e.radius + 4.0:
			e.take_damage(damage)
			queue_free()
			return

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color.ORANGE_RED)
