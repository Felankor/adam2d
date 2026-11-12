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
var homing: float = 0.0            # turn rate in radians per second; 0 = flies straight
var dest_mode: bool = false        # grenade: bursts the moment it reaches `dest`
var dest: Vector2 = Vector2.ZERO
var blast_radius: float = 90.0
var pierce: bool = false           # Hell Arrows: cannot be shot down, fly through everything
var max_range: float = 3200.0
var _travelled: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not pierce:
		add_to_group("bolts")      # piercing arrows are not in this group, so our shots pass through them
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	if homing > 0.0 and base_ref != null and is_instance_valid(base_ref):
		var want := (base_ref.position - position).angle()
		var turn := clampf(angle_difference(direction.angle(), want), -homing * delta, homing * delta)
		direction = direction.rotated(turn)
	var step := speed * delta
	position += direction * step
	_travelled += step
	if dest_mode:
		if position.distance_to(dest) <= step + 2.0:
			position = dest
			Fx.spawn(get_parent(), "explosion", dest, Color.WHITE, "", blast_radius / 90.0, 0.6)
			Sfx.play("rocket_boom", -4.0)
			if base_ref != null and is_instance_valid(base_ref) and base_ref.position.distance_to(dest) <= blast_radius + reach * 0.6:
				hit_base.emit(damage)
			queue_free()
			return
	elif base_ref != null and position.distance_to(base_ref.position) <= reach:
		if style == "rock" or style == "missile" or style == "voidorb":
			Fx.spawn(get_parent(), "explosion", position, Color.WHITE, "", 0.7, 0.45)
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
			PixelFx.line(self, Vector2.ZERO, -dir * 16.0, Color(1.0, 0.5, 0.1, 0.5), 6.0)
			PixelFx.disc(self, Vector2.ZERO, 11.0, Color(0.15, 0.05, 0.02))
			PixelFx.disc(self, Vector2.ZERO, 9.0, Color(0.95, 0.45, 0.1))
			PixelFx.disc(self, Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.3))
		"bullet":
			PixelFx.line(self, Vector2.ZERO, -dir * 22.0, Color(1.0, 0.35, 0.3, 0.6), 3.0)
			PixelFx.disc(self, Vector2.ZERO, 6.0, Color(0.15, 0.03, 0.02))
			PixelFx.disc(self, Vector2.ZERO, 5.0, Color(1.0, 0.8, 0.5))
		"rocket":
			PixelFx.line(self, Vector2.ZERO, -dir * 26.0, Color(1.0, 0.6, 0.2, 0.55), 7.0)
			PixelFx.disc(self, Vector2.ZERO, 8.0, Color(0.85, 0.2, 0.2))
			PixelFx.disc(self, Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.5))
		"rock":
			var rr := _t * 6.0
			PixelFx.disc(self, Vector2(2, 3), 15.0, Color(0, 0, 0, 0.3))
			PixelFx.disc(self, Vector2.ZERO, 14.0, Color(0.2, 0.17, 0.15))
			PixelFx.disc(self, Vector2.ZERO, 11.0, Color(0.5, 0.45, 0.4))
			PixelFx.disc(self, Vector2(-3, -3), 5.0, Color(0.72, 0.68, 0.62))
			PixelFx.disc(self, Vector2.RIGHT.rotated(rr) * 6.0, 3.0, Color(0.3, 0.26, 0.23))
		"boulder":
			var rb := _t * 3.0
			PixelFx.disc(self, Vector2(3, 5), 30.0, Color(0, 0, 0, 0.3))
			PixelFx.disc(self, Vector2.ZERO, 28.0, Color(0.16, 0.13, 0.11))
			PixelFx.disc(self, Vector2.ZERO, 24.0, Color(0.46, 0.4, 0.35))
			PixelFx.disc(self, Vector2(-7, -7), 11.0, Color(0.68, 0.62, 0.55))
			for i in 3:
				PixelFx.disc(self, Vector2.RIGHT.rotated(rb + float(i) * 2.1) * 13.0, 5.0, Color(0.26, 0.22, 0.19))
		"fireball":
			var fl := floorf((0.5 + 0.5 * sin(_t * 28.0)) * 2.0)
			PixelFx.line(self, Vector2.ZERO, -dir * 40.0, Color(1.0, 0.4, 0.05, 0.5), 14.0)
			PixelFx.disc(self, Vector2.ZERO, 17.0 + 2.0 * fl, Color(0.8, 0.15, 0.03, 0.7))
			PixelFx.disc(self, Vector2.ZERO, 12.0, Color(1.0, 0.5, 0.1))
			PixelFx.disc(self, Vector2.ZERO, 6.0, Color(1.0, 0.95, 0.6))
		"missile":
			var side2 := dir.orthogonal()
			PixelFx.line(self, -dir * 6.0, -dir * (34.0 + 8.0 * floorf((0.5 + 0.5 * sin(_t * 40.0)) * 2.0)), Color(1.0, 0.55, 0.1, 0.7), 8.0)
			PixelFx.line(self, -dir * 12.0, dir * 12.0, Color(0.08, 0.08, 0.1), 9.0)
			PixelFx.line(self, -dir * 11.0, dir * 11.0, Color(0.55, 0.57, 0.62), 5.0)
			PixelFx.line(self, -dir * 12.0, -dir * 12.0 + side2 * 7.0, Color(0.7, 0.1, 0.1), 3.0)
			PixelFx.line(self, -dir * 12.0, -dir * 12.0 - side2 * 7.0, Color(0.7, 0.1, 0.1), 3.0)
			PixelFx.disc(self, dir * 12.0, 4.5, Color(0.95, 0.2, 0.15))
		"voidorb":
			var vp := floorf((0.5 + 0.5 * sin(_t * 12.0)) * 3.0)
			PixelFx.line(self, Vector2.ZERO, -dir * 36.0, Color(0.5, 0.1, 0.9, 0.5), 12.0)
			PixelFx.disc(self, Vector2.ZERO, 16.0 + 2.0 * vp, Color(0.5, 0.1, 0.8, 0.45))
			PixelFx.disc(self, Vector2.ZERO, 11.0, Color(0.1, 0.0, 0.2))
			PixelFx.disc(self, Vector2.ZERO, 6.0, Color(0.85, 0.5, 1.0))
		"hellarrow":
			var flick := 0.5 + 0.5 * sin(_t * 40.0)
			PixelFx.line(self, -dir * 6.0, -dir * (46.0 + 10.0 * flick), Color(1.0, 0.35, 0.05, 0.55), 9.0)
			PixelFx.line(self, -dir * 6.0, -dir * 30.0, Color(1.0, 0.8, 0.3, 0.8), 4.0)
			PixelFx.line(self, -dir * 22.0, dir * 20.0, Color(0.12, 0.02, 0.03), 5.0)         # shaft
			PixelFx.line(self, -dir * 22.0, dir * 20.0, Color(0.7, 0.1, 0.1), 3.0)
			var side := dir.orthogonal()
			PixelFx.line(self, dir * 20.0, dir * 8.0 + side * 8.0, Color(1.0, 0.45, 0.1), 3.0)   # barbed head
			PixelFx.line(self, dir * 20.0, dir * 8.0 - side * 8.0, Color(1.0, 0.45, 0.1), 3.0)
			PixelFx.disc(self, dir * 20.0, 5.0, Color(1.0, 0.9, 0.5))
		"void":
			var pulse := floorf((0.5 + 0.5 * sin(_t * 30.0)) * 2.0)
			PixelFx.line(self, Vector2.ZERO, -dir * 30.0, Color(0.55, 0.1, 0.9, 0.55), 7.0)
			PixelFx.disc(self, Vector2.ZERO, 9.0 + 3.0 * pulse, Color(0.5, 0.1, 0.8, 0.5))
			PixelFx.disc(self, Vector2.ZERO, 6.0, Color(0.12, 0.0, 0.22))
			PixelFx.disc(self, Vector2.ZERO, 3.0, Color(0.9, 0.5, 1.0))
		_:
			PixelFx.disc(self, Vector2.ZERO, 15.0, Color(0.75, 0.3, 1.0, 0.3))
			PixelFx.disc(self, Vector2.ZERO, 9.0, Color(0.75, 0.3, 1.0))
			PixelFx.disc(self, Vector2.ZERO, 4.0, Color.WHITE)
