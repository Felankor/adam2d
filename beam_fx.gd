class_name BeamFx
extends Node2D

# The short flash of a Laser Gun shot.
var start: Vector2 = Vector2.ZERO
var finish: Vector2 = Vector2.ZERO
var life: float = 0.14
var _max: float = 0.14
var thick: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 4

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var a := clampf(life / _max, 0.0, 1.0)
	PixelFx.line(self, start, finish, Color(0.3, 0.9, 1.0, 0.3 * a), 15.0 * thick)
	PixelFx.line(self, start, finish, Color(0.4, 0.95, 1.0, 0.8 * a), 6.0 * thick)
	PixelFx.line(self, start, finish, Color(1, 1, 1, a), 3.0)
