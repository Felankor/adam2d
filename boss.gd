class_name Boss
extends Enemy

signal summon(pos: Vector2)
signal bolt(origin: Vector2, dmg: float)

const PALETTES := [
	Color(0.20, 0.55, 0.22),
	Color(0.50, 0.33, 0.16),
	Color(0.52, 0.54, 0.60),
	Color(0.45, 0.22, 0.75),
	Color(0.85, 0.18, 0.06),
]

var biome_idx: int = 0
var boss_name: String = "Boss"
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _dodge_cd: float = 0.0
var _dash: Vector2 = Vector2.ZERO
var _dash_time: float = 0.0
var _summon_timer: float = 6.0
var _bolt_timer: float = 3.0
var _t: float = 0.0

static func make_boss(lvl: int, biome: int) -> Boss:
	var b := Boss.new()
	b.kind = "boss"
	b.biome_idx = biome
	b.hp = (90.0 + lvl * 30.0) * GameState.hp_mult()
	b.max_hp = b.hp
	b.speed = (80.0 + biome * 8.0) * GameState.speed_mult()
	b.damage = 2.5 * (1.0 + 0.25 * float(lvl - 1))
	b.reward = 20 + lvl * 3
	b.radius = 56.0
	b._bolt_timer = 3.5 / GameState.speed_mult()
	return b

func _incoming_shot() -> Projectile:
	for node in get_tree().get_nodes_in_group("shots"):
		var shot := node as Projectile
		if shot == null:
			continue
		var to_me := position - shot.position
		var dist := to_me.length()
		if dist < 280.0 and dist > 10.0 and shot.velocity.normalized().dot(to_me / dist) > 0.93:
			return shot
	return null

func _pick_wander() -> void:
	var a := randf() * TAU
	_wander_target = target + Vector2.RIGHT.rotated(a) * randf_range(330.0, 560.0)
	_wander_timer = randf_range(1.5, 3.0)

func _process(delta: float) -> void:
	_tick_common(delta)
	_t += delta
	_wander_timer -= delta
	if _wander_timer <= 0.0 or position.distance_to(_wander_target) < 30.0:
		_pick_wander()
	var vel := (_wander_target - position).normalized() * _move_speed()
	_heading = vel.angle()

	# Dodge: sidestep when one of our shots is flying straight at the boss.
	_dodge_cd -= delta
	if _dodge_cd <= 0.0:
		var shot := _incoming_shot()
		if shot != null and randf() < 0.65:
			var side := 1.0 if randf() < 0.5 else -1.0
			_dash = shot.velocity.normalized().orthogonal() * side * 520.0
			_dash_time = 0.25
			_dodge_cd = 1.4
	if _dash_time > 0.0:
		_dash_time -= delta
		vel += _dash
	position += vel * delta
	var limit := Settings.WORLD_SIZE
	position = position.clamp(Vector2(100, 150), Vector2(limit.x - 100.0, limit.y - 220.0))

	# Attacks: summon soldiers and lob energy bolts at the base.
	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_summon_timer = 7.0
		summon.emit(position)
		Sfx.play("boss_spawn", -6.0)
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = 3.5 / GameState.speed_mult()
		bolt.emit(position, damage)
		Sfx.play("bolt")
	queue_redraw()

func take_damage(amount: float) -> void:
	if dead:
		return
	var par := get_parent()
	hp -= amount
	_flash = 0.1
	_scale_pop = 0.05
	_slow_time = 0.2   # bosses only stagger slightly
	_push = -Vector2.RIGHT.rotated(_heading) * 40.0
	Fx.spawn(par, "spark", position + Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0)), Color(0.85, 0.5, 1.0), "", 1.2, 0.4)
	Fx.spawn(par, "number", position + Vector2(randf_range(-30.0, 30.0), -radius), Color.WHITE, str(int(ceil(amount))), 1.0, 0.7)
	Sfx.play("boss_hit")
	if hp <= 0.0:
		dead = true
		Fx.spawn(par, "explosion", position, Color.WHITE, "", 2.6, 1.0)
		Sfx.play("boss_die")
		died.emit(self)
		queue_free()

func _draw() -> void:
	var pal: Color = PALETTES[biome_idx]
	var s := 1.0 + _scale_pop * 2.0
	draw_set_transform(Vector2.ZERO, _t * 0.4, Vector2(s, s))
	for i in 10:
		var d := Vector2.RIGHT.rotated(TAU * i / 10.0)
		var spike := PackedVector2Array([d.rotated(-0.14) * radius * 0.95, d * radius * 1.3, d.rotated(0.14) * radius * 0.95])
		draw_colored_polygon(spike, _c(pal.darkened(0.35)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_circle(Vector2(6, 8), radius + 3.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, radius, _c(pal))
	draw_circle(Vector2(-radius * 0.25, -radius * 0.3), radius * 0.55, _c(pal.lightened(0.18)))
	var eye := Color(1.0, 0.9, 0.2)
	for ex in [-18.0, 18.0]:
		draw_circle(Vector2(ex, -8), 9.0, Color(0.05, 0.05, 0.05))
		draw_circle(Vector2(ex, -8), 5.0, eye)
	draw_line(Vector2(-24, 20), Vector2(24, 20), Color(0.05, 0.05, 0.05), 6.0)
	for i in 5:
		var tx := -18.0 + i * 9.0
		draw_line(Vector2(tx, 20), Vector2(tx, 27), Color(0.95, 0.95, 0.9), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_boss_bar()

func _draw_boss_bar() -> void:
	var w := 240.0
	var h := 20.0
	var pos := Vector2(-w * 0.5, -radius - 46.0)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.08, 0.0, 0.12, 0.85))
	draw_rect(Rect2(pos, Vector2(w * frac, h)), Color(0.62, 0.2, 0.92))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.85, 0.6, 1.0), false, 2.0)
	var font := ThemeDB.fallback_font
	var value := "%d/%d" % [ceili(hp), ceili(max_hp)]
	draw_string_outline(font, pos + Vector2(0, 15), value, HORIZONTAL_ALIGNMENT_CENTER, w, 15, 4, Color.BLACK)
	draw_string(font, pos + Vector2(0, 15), value, HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color.WHITE)
	draw_string_outline(font, pos + Vector2(0, -6), boss_name, HORIZONTAL_ALIGNMENT_CENTER, w, 16, 4, Color.BLACK)
	draw_string(font, pos + Vector2(0, -6), boss_name, HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(0.9, 0.75, 1.0))
