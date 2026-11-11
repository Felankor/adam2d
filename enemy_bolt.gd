class_name EnemyBolt
extends Node2D

# Something fired at the base that our shots can destroy. It flies in a STRAIGHT
# line toward where the base was when it was fired (never guided), so moving the
# castle makes it miss.
# style "orb"    = purple boss energy orb
# style "shell"  = orange tank shell
# style "bullet" = rival castle machinegun tracer
# style "rocket" = rival castle rocket
# style "void"   = Void Overlord's void fire
signal hit_base(damage: float)

var style: String = "orb"
var direction: Vector2 = Vector2.RIGHT
var base_ref: Node2D = null
var speed: float = 260.0
var damage: float = 2.0
var reach: float = 40.0
var max_range: float = 3200.0
var _travelled: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("bolts")
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	var step := speed * delta
	position += direction * step
	_travelled += step
	if base_ref != null and position.distance_to(base_ref.position) <= reach:
		hit_base.emit(damage)
		queue_free()
		return
	if _travelled > max_range:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var dir := direction
	match style:
		"shell":
			draw_line(Vector2.ZERO, -dir * 16.0, Color(1.0, 0.5, 0.1, 0.45), 6.0)
			draw_circle(Vector2.ZERO, 9.0, Color(0.95, 0.45, 0.1))
			draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.3))
		"bullet":
			draw_line(Vector2.ZERO, -dir * 22.0, Color(1.0, 0.35, 0.3, 0.55), 4.0)
			draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.8, 0.5))
		"rocket":
			draw_line(Vector2.ZERO, -dir * 26.0, Color(1.0, 0.6, 0.2, 0.5), 7.0)
			draw_circle(Vector2.ZERO, 8.0, Color(0.85, 0.2, 0.2))
			draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.5))
		"void":
			var pulse := 0.5 + 0.5 * sin(_t * 30.0)
			draw_line(Vector2.ZERO, -dir * 30.0, Color(0.55, 0.1, 0.9, 0.5), 7.0)
			draw_circle(Vector2.ZERO, 9.0 + 2.0 * pulse, Color(0.5, 0.1, 0.8, 0.45))
			draw_circle(Vector2.ZERO, 5.5, Color(0.12, 0.0, 0.22))
			draw_circle(Vector2.ZERO, 2.5, Color(0.9, 0.5, 1.0))
		_:
			draw_circle(Vector2.ZERO, 15.0, Color(0.75, 0.3, 1.0, 0.25))
			draw_circle(Vector2.ZERO, 9.0, Color(0.75, 0.3, 1.0))
			draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
