class_name EnemyBolt
extends Node2D

# Something fired at the base that our shots can destroy:
# style "orb"   = purple boss energy orb
# style "shell" = orange tank shell
signal hit_base(damage: float)

var style: String = "orb"
var target: Vector2 = Vector2.ZERO
var speed: float = 260.0
var damage: float = 2.0
var reach: float = 40.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("bolts")
	z_index = 3

func _process(delta: float) -> void:
	var to_t := target - position
	if to_t.length() <= reach:
		hit_base.emit(damage)
		queue_free()
		return
	position += to_t.normalized() * speed * delta
	queue_redraw()

func _draw() -> void:
	if style == "shell":
		var dir := (target - position).normalized()
		draw_line(Vector2.ZERO, -dir * 16.0, Color(1.0, 0.5, 0.1, 0.45), 6.0)
		draw_circle(Vector2.ZERO, 9.0, Color(0.95, 0.45, 0.1))
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.3))
		return
	draw_circle(Vector2.ZERO, 15.0, Color(0.75, 0.3, 1.0, 0.25))
	draw_circle(Vector2.ZERO, 9.0, Color(0.75, 0.3, 1.0))
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
