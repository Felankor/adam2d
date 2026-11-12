class_name PetekBomb
extends Node2D

# Garden Warden's Petek Bomb: a honey bomb lobbed near the castle. It lands, ticks for
# 3 seconds (the red ring shows the blast area), then bursts in a poison cloud. A castle
# caught in the cloud is poisoned: 2 HP per second for 4 seconds. Fly away, or use the Barrier!
const FLIGHT := 0.9
const FUSE := 3.0
const BLAST_RADIUS := 170.0
const POISON_DPS := 2.0
const POISON_SECONDS := 4.0

var start: Vector2 = Vector2.ZERO
var dest: Vector2 = Vector2.ZERO
var base_ref: Base = null
var _t: float = 0.0
var _burst: float = -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("bombs")
	z_index = 2
	position = start

func _process(delta: float) -> void:
	_t += delta
	if _burst >= 0.0:
		_burst += delta
		if _burst > 0.7:
			queue_free()
		queue_redraw()
		return
	if _t < FLIGHT:
		var k := _t / FLIGHT
		position = start.lerp(dest, k) + Vector2(0.0, -sin(k * PI) * 160.0)
	else:
		position = dest
		if _t >= FLIGHT + FUSE:
			_explode()
	queue_redraw()

func _explode() -> void:
	_burst = 0.0
	Sfx.play("rocket_boom", -3.0)
	Fx.spawn(get_parent(), "explosion", dest, Color(0.7, 0.95, 0.2), "", 1.6, 0.7)
	if base_ref != null and is_instance_valid(base_ref):
		if base_ref.position.distance_to(dest) <= BLAST_RADIUS + base_ref.hit_radius():
			base_ref.apply_poison(POISON_DPS, POISON_SECONDS)

func _draw() -> void:
	if _burst >= 0.0:
		var k := clampf(_burst / 0.7, 0.0, 1.0)
		PixelFx.disc(self, Vector2.ZERO, BLAST_RADIUS * (0.6 + 0.4 * k), Color(0.55, 0.9, 0.15, 0.35 * (1.0 - k)))
		PixelFx.ring(self, Vector2.ZERO, BLAST_RADIUS, Color(0.8, 1.0, 0.3, 0.8 * (1.0 - k)), 6.0)
		return
	if _t >= FLIGHT:
		var left := clampf(1.0 - (_t - FLIGHT) / FUSE, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_t * (8.0 + 14.0 * (1.0 - left)))
		PixelFx.disc(self, Vector2.ZERO, BLAST_RADIUS, Color(0.7, 0.9, 0.1, 0.07 + 0.08 * pulse))
		PixelFx.ring(self, Vector2.ZERO, BLAST_RADIUS, Color(0.9, 0.95, 0.2, 0.55 + 0.3 * pulse), 3.0)
		PixelFx.ring(self, Vector2.ZERO, BLAST_RADIUS * (1.0 - left), Color(1.0, 0.5, 0.15, 0.7), 3.0)
	# the bomb: a honey-coloured comb with dark stripes
	var up := 0.0
	if _t < FLIGHT:
		up = sin(_t / FLIGHT * PI) * 160.0
		PixelFx.disc(self, Vector2(0.0, up + 6.0), 10.0, Color(0, 0, 0, 0.25))
	PixelFx.disc(self, Vector2.ZERO, 18.0, Color(0.2, 0.12, 0.03))
	PixelFx.disc(self, Vector2.ZERO, 15.0, Color(0.95, 0.72, 0.12))
	draw_rect(Rect2(-12.0, -6.0, 24.0, 3.0), Color(0.25, 0.16, 0.05))
	draw_rect(Rect2(-12.0, 3.0, 24.0, 3.0), Color(0.25, 0.16, 0.05))
	PixelFx.disc(self, Vector2(-5.0, -7.0), 4.0, Color(1.0, 0.92, 0.55, 0.9))
