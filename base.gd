class_name Base
extends Node2D

signal destroyed

const TIER_NAMES := ["Village", "Town", "City", "Fortress", "Capital", "Empire", "Death Star"]
const TIER_HP := [20, 40, 70, 110, 160, 230, 350]
const TIER_COLORS := [
	Color(0.55, 0.40, 0.25),
	Color(0.65, 0.50, 0.30),
	Color(0.60, 0.60, 0.65),
	Color(0.45, 0.50, 0.60),
	Color(0.85, 0.70, 0.25),
	Color(0.60, 0.30, 0.70),
	Color(0.55, 0.58, 0.62),
]
const MAX_AUTO := 12
const RANGE_STEP := 40.0
const MAX_RANGE := 1000.0

var tier: int = 0
var max_hp: int = 20
var hp: int = 20
var hp_bonus: int = 0

var max_energy: float = 100.0
var energy: float = 100.0
var energy_regen: float = 20.0
var shot_cost: float = 20.0
var shot_interval: float = 0.2

var cannon_damage: float = 10.0
var auto_damage: float = 6.0
var damage_mult: float = 1.0

var auto_cannons: int = 0
var auto_interval: float = 2.0
var auto_range: float = 450.0

var gunners: int = 0
var smiths: int = 0
var engineers: int = 0
var medics: int = 0

var aim_angle: float = 0.0
var _fire_cd: float = 0.0
var _auto_timer: float = 0.0
var _heal_acc: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func body_radius() -> float:
	return 32.0 + tier * 8.0

func set_tier(new_tier: int) -> void:
	tier = new_tier
	max_hp = TIER_HP[tier] + hp_bonus
	hp = max_hp
	queue_redraw()

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	if hp == 0:
		set_process(false)
		destroyed.emit()

# Each auto-cannon upgrade also extends the range of all auto-cannons.
func add_auto_cannon() -> bool:
	if auto_cannons >= MAX_AUTO:
		return false
	auto_cannons += 1
	auto_range = minf(auto_range + RANGE_STEP, MAX_RANGE)
	return true

func upgrade_auto_rate() -> void:
	auto_interval = maxf(auto_interval * 0.85, 0.3)
	auto_range = minf(auto_range + RANGE_STEP, MAX_RANGE)

func _process(delta: float) -> void:
	energy = minf(energy + energy_regen * delta, max_energy)
	_fire_cd -= delta
	aim_angle = (get_global_mouse_position() - global_position).angle()

	# Manual cannon: hold left mouse button, costs energy
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_cd <= 0.0 and energy >= shot_cost:
		energy -= shot_cost
		_fire_cd = shot_interval
		_shoot(aim_angle, cannon_damage * damage_mult)

	# Auto cannons: share one timer, so shots are evenly spread out
	if auto_cannons > 0:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			var target := _nearest_enemy()
			if target != null:
				_shoot((target.global_position - global_position).angle(), auto_damage * damage_mult)
				_auto_timer = auto_interval / auto_cannons

	# Medics: slow healing
	if medics > 0 and hp < max_hp:
		_heal_acc += medics * 0.5 * delta
		if _heal_acc >= 1.0:
			_heal_acc -= 1.0
			heal(1)

	queue_redraw()

func _shoot(angle: float, dmg: float) -> void:
	var p := Projectile.new()
	var dir := Vector2.RIGHT.rotated(angle)
	p.position = position + dir * (body_radius() + 14.0)
	p.velocity = dir * 800.0
	p.damage = dmg
	get_parent().add_child(p)

func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_dist := auto_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d <= best_dist:
			best = e
			best_dist = d
	return best

func _draw() -> void:
	var r := body_radius()
	var col: Color = TIER_COLORS[tier]
	draw_circle(Vector2(6, 8), r * 1.15, Color(0, 0, 0, 0.25))
	if tier == TIER_NAMES.size() - 1:
		draw_circle(Vector2.ZERO, r, col)
		draw_circle(Vector2(-r * 0.35, -r * 0.35), r * 0.22, col.darkened(0.45))
		draw_line(Vector2(-r, 0), Vector2(r, 0), col.darkened(0.45), 4.0)
	else:
		draw_rect(Rect2(-r * 0.5, -r * 0.5, r, r), col)
		var count := 2 + tier * 2
		var s := 12.0 + tier * 3.0
		for i in count:
			var pos := Vector2.RIGHT.rotated(TAU * i / count) * r * 0.85
			draw_rect(Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), col.darkened(0.25))
	if auto_cannons > 0:
		draw_arc(Vector2.ZERO, auto_range, 0.0, TAU, 96, Color(1, 1, 1, 0.12), 2.0)
		for i in auto_cannons:
			var a := TAU * i / auto_cannons
			draw_circle(Vector2.RIGHT.rotated(a) * (r + 8.0), 7.0, Color.ORANGE)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(aim_angle) * (r + 20.0), Color.DIM_GRAY, 9.0)
