class_name EnemyShield
extends Node2D

# The golden bubble of an Apocalypse Tank's Invincibility. It is a child drawn above the tank sprite.
var radius: float = 40.0
var fade: float = 1.0
var glow: float = 0.0

func setup(r: float, f: float, g: float) -> void:
	radius = r
	fade = f
	glow = g
	queue_redraw()

func _draw() -> void:
	var rr := radius * 1.3
	var c := Vector2(0.0, -radius * 0.2)
	var t := float(Time.get_ticks_msec()) / 1000.0
	PixelFx.disc(self, c, rr, Color(1.0, 0.82, 0.25, (0.20 + 0.12 * glow) * fade))
	PixelFx.disc(self, c, rr * 0.8, Color(1.0, 0.92, 0.5, (0.10 + 0.08 * glow) * fade))
	PixelFx.ring(self, c, rr, Color(1.0, 0.95, 0.5, (0.85 + 0.15 * glow) * fade), 5.0)
	PixelFx.ring(self, c, rr - 7.0, Color(1.0, 0.8, 0.2, 0.55 * fade), 3.0)
	PixelFx.ring(self, c, rr + 6.0, Color(1.0, 1.0, 0.85, 0.5 * glow * fade), 2.0)
	# bright glints running around the rim
	for i in 6:
		var a := t * 2.2 + float(i) * TAU / 6.0
		var p := c + Vector2(cos(a), sin(a)) * rr
		draw_rect(Rect2(floorf(p.x / 3.0) * 3.0 - 3.0, floorf(p.y / 3.0) * 3.0 - 3.0, 6.0, 6.0), Color(1.0, 1.0, 0.8, 0.95 * fade))
