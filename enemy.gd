class_name Enemy
extends Node2D

signal died(enemy: Enemy)
signal arrived(enemy: Enemy)

var is_ally: bool = false
var hp: float = 10.0
var speed: float = 60.0
var reward: int = 1
var damage: int = 1
var target: Vector2 = Vector2.ZERO
var reach: float = 40.0
var radius: float = 12.0
var dead: bool = false

func _ready() -> void:
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
	if dead or is_ally:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		died.emit(self)
		queue_free()

func _draw() -> void:
	if is_ally:
		draw_circle(Vector2.ZERO, radius, Color.LIME_GREEN)
		draw_line(Vector2(-6, 0), Vector2(6, 0), Color.WHITE, 3.0)
		draw_line(Vector2(0, -6), Vector2(0, 6), Color.WHITE, 3.0)
	else:
		draw_circle(Vector2.ZERO, radius, Color.CRIMSON)
