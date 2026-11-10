class_name Enemy
extends Node2D

signal died(enemy: Enemy)
signal arrived(enemy: Enemy)

var is_ally: bool = false
var hp: float = 10.0
var speed: float = 70.0
var reward: int = 1
var damage: int = 1
var target: Vector2 = Vector2.ZERO
var reach: float = 40.0
var radius: float = 16.0
var dead: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("mobs")
	add_to_group("allies" if is_ally else "enemies")

func _process(delta: float) -> void:
	var to_target := target - position
	if to_target.length() <= reach:
		dead = true
		arrived.emit(self)
		queue_free()
		return
	position += to_target.normalized() * speed * delta

func take_damage(amount: float) -> void:
	if dead:
		return
	if is_ally:
		# Allies die from any hit by our own weapons.
		dead = true
		died.emit(self)
		queue_free()
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		died.emit(self)
		queue_free()

func _draw() -> void:
	if is_ally:
		draw_circle(Vector2.ZERO, radius + 2.0, Color(1, 1, 1, 0.9))
		draw_circle(Vector2.ZERO, radius, Color.LIME_GREEN)
		draw_line(Vector2(-8, 0), Vector2(8, 0), Color.WHITE, 4.0)
		draw_line(Vector2(0, -8), Vector2(0, 8), Color.WHITE, 4.0)
	else:
		draw_circle(Vector2.ZERO, radius + 2.0, Color(0, 0, 0, 0.75))
		draw_circle(Vector2.ZERO, radius, Color.CRIMSON)
		draw_circle(Vector2(-4, -4), radius * 0.4, Color(1, 0.5, 0.5, 0.6))
