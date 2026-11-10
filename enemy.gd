class_name Enemy
extends Node2D

signal died(enemy: Enemy)
signal arrived(enemy: Enemy)
signal shoot(origin: Vector2, dmg: float)    # tanks fire shells at the base

var kind: String = "soldier"      # "soldier", "tank", "mech", "void" (Boss uses "boss")
var is_minion: bool = false       # summoned by a boss: no gold, vanishes when the boss dies
var is_ally: bool = false
var hp: float = 10.0
var max_hp: float = 10.0
var speed: float = 70.0
var reward: int = 1
var damage: float = 1.0
var armor: float = 0.0            # fraction of each hit that is absorbed
var target: Vector2 = Vector2.ZERO
var reach: float = 40.0
var radius: float = 15.0
var dead: bool = false
var dmg_taken_mult: float = 1.0   # < 1 means this enemy absorbs part of every hit

# Ranged enemies (tanks) stop at shoot_range and fire at the base.
var shoots: bool = false
var shoot_range: float = 430.0
var _shoot_cd: float = 0.8

# Dodging (mechs and bosses): sidestep shots that fly straight at us.
var dodge_chance: float = 0.0
var dodge_cd_time: float = 1.2
var dodge_dash: float = 450.0
var _dodge_cd: float = 0.0
var _dodge_scan: float = 0.0
var _dash: Vector2 = Vector2.ZERO
var _dash_time: float = 0.0

var _flash: float = 0.0
var _bar_time: float = 0.0
var _walk: float = 0.0
var _scale_pop: float = 0.0
var _heading: float = 0.0
var _push: Vector2 = Vector2.ZERO   # knockback velocity, decays smoothly
var _slow_time: float = 0.0         # while > 0 the enemy moves slower after a hit

# Builds an enemy of the given kind with stats for the given level.
# Enemy damage grows by +25% of the base value with every level cleared.
static func make(k: String, level: int) -> Enemy:
	var e := Enemy.new()
	e.kind = k
	var lvl := float(level - 1)
	var dmg_mult := 1.0 + 0.25 * lvl
	match k:
		"tank":
			e.hp = (40.0 + lvl * 12.0) * GameState.hp_mult()
			e.speed = minf(32.0 + lvl * 1.5, 70.0) * GameState.speed_mult()
			e.damage = 3.0 * dmg_mult
			e.shoots = true
			e.shoot_range = randf_range(400.0, 470.0)
			e._shoot_cd = randf_range(0.5, 1.4)
			e.armor = 0.35
			e.reward = 4 + int(level * 0.5)
			e.radius = 27.0
		"mech":
			e.hp = (20.0 + lvl * 2.5) * GameState.hp_mult()
			e.dodge_chance = 0.6
			e.dodge_cd_time = 1.1
			e.dodge_dash = 460.0
			e.speed = minf(170.0 + lvl * 6.0, 320.0) * GameState.speed_mult()
			e.damage = 2.0 * dmg_mult
			e.reward = 3 + int(level * 0.4)
			e.radius = 22.0
		_:
			e.kind = "soldier"
			e.hp = (10.0 + lvl * 4.0) * GameState.hp_mult()
			e.speed = minf(70.0 + lvl * 5.0, 180.0) * GameState.speed_mult()
			e.damage = 1.0 * dmg_mult
			e.reward = 1 + int(level * 0.5)
			e.radius = 15.0
	e.max_hp = e.hp
	return e

# A weak soldier summoned by a boss. Gives no gold.
static func make_minion(level: int, hp_scale: float = 0.35) -> Enemy:
	var e := Enemy.make("soldier", level)
	e.hp = maxf(e.hp * hp_scale, 3.0)
	e.max_hp = e.hp
	e.damage *= 0.5
	e.reward = 0
	e.is_minion = true
	return e

# A "lesser Void Overlord": half the speed and damage of its master.
static func make_void_lesser(hp: float, dmg: float, spd: float) -> Enemy:
	var e := Enemy.new()
	e.kind = "void"
	e.hp = hp
	e.max_hp = hp
	e.damage = dmg
	e.speed = spd
	e.reward = 0
	e.radius = 24.0
	e.is_minion = true
	return e

static func make_ally() -> Enemy:
	var e := Enemy.new()
	e.kind = "soldier"
	e.is_ally = true
	e.speed = 50.0
	e.radius = 15.0
	return e

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("mobs")
	add_to_group("allies" if is_ally else "enemies")
	if is_minion:
		add_to_group("minions")
	if kind == "void":
		add_to_group("void_lessers")

func _tick_common(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_bar_time = maxf(_bar_time - delta, 0.0)
	_scale_pop = maxf(_scale_pop - delta, 0.0)
	_slow_time = maxf(_slow_time - delta, 0.0)
	if _push != Vector2.ZERO:
		position += _push * delta
		_push = _push.move_toward(Vector2.ZERO, 900.0 * delta)

# Speed after the hit-slow is applied (35% speed right after a hit, recovering).
func _move_speed() -> float:
	if _slow_time <= 0.0:
		return speed
	return speed * lerpf(1.0, 0.35, clampf(_slow_time / 0.4, 0.0, 1.0))

# Called on every hit: pushes the enemy back a little and slows it briefly.
func _hit_reaction(from_dir: Vector2, strength: float) -> void:
	_push = from_dir * strength
	_slow_time = 0.4

func _process(delta: float) -> void:
	_tick_common(delta)
	var to_target := target - position
	var dist := to_target.length()
	# Tanks stop in range and shell the base until they are destroyed.
	if shoots and dist <= shoot_range:
		_heading = to_target.angle()
		_shoot_cd -= delta
		if _shoot_cd <= 0.0:
			_shoot_cd = 2.4
			shoot.emit(position + Vector2.RIGHT.rotated(_heading) * 38.0, damage)
			Sfx.play("tank_fire", -3.0)
		queue_redraw()
		return
	if dist <= reach:
		dead = true
		arrived.emit(self)
		queue_free()
		return
	var dir := to_target / dist
	_heading = dir.angle()
	var spd := _move_speed()
	position += (dir * spd + _update_dodge(delta)) * delta
	_walk += delta * spd * 0.12
	queue_redraw()

# Finds one of our shots flying straight at us (used for dodging).
func _incoming_shot() -> Projectile:
	for node in get_tree().get_nodes_in_group("shots"):
		var shot := node as Projectile
		if shot == null:
			continue
		var to_me := position - shot.position
		var dist := to_me.length()
		if dist < 300.0 and dist > 10.0 and shot.velocity.normalized().dot(to_me / dist) > 0.93:
			return shot
	return null

# Returns the extra sideways velocity of a dodge dash (zero when not dodging).
func _update_dodge(delta: float) -> Vector2:
	if dodge_chance <= 0.0 or is_ally:
		return Vector2.ZERO
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	if _dash_time > 0.0:
		_dash_time -= delta
		return _dash
	_dodge_scan -= delta
	if _dodge_cd <= 0.0 and _dodge_scan <= 0.0:
		_dodge_scan = 0.05
		var shot := _incoming_shot()
		if shot != null:
			if randf() < dodge_chance:
				var side := 1.0 if randf() < 0.5 else -1.0
				_dash = shot.velocity.normalized().orthogonal() * side * dodge_dash
				_dash_time = 0.22
				_dodge_cd = dodge_cd_time
				Sfx.play("dodge", -8.0)
			else:
				_dodge_cd = 0.35   # failed the roll: try again shortly
	return Vector2.ZERO

func take_damage(amount: float) -> void:
	if dead:
		return
	var par := get_parent()
	if is_ally:
		# Allies die from any hit by our own weapons.
		dead = true
		Fx.spawn(par, "spark", position, Color(0.4, 1.0, 0.4), "", 1.3, 0.45)
		Sfx.play("kill", -4.0)
		died.emit(self)
		queue_free()
		return
	var dealt := amount * (1.0 - armor) * dmg_taken_mult
	hp -= dealt
	_flash = 0.12
	_bar_time = 2.5
	_scale_pop = 0.12
	var back := -Vector2.RIGHT.rotated(_heading)
	match kind:
		"tank":
			_hit_reaction(back, 35.0)    # heavy: barely moves
		"mech":
			_hit_reaction(back, 260.0)   # light: gets thrown back
		_:
			_hit_reaction(back, 170.0)
	if armor > 0.0:
		Fx.spawn(par, "spark", position, Color(0.8, 0.85, 0.95), "", 0.9, 0.3)
		Sfx.play("block")
	else:
		Fx.spawn(par, "spark", position, Color(1.0, 0.85, 0.3), "", 1.0, 0.35)
		Sfx.play("hit")
	Fx.spawn(par, "number", position + Vector2(0, -radius - 12.0), Color.WHITE, str(int(ceil(dealt))), 1.0, 0.7)
	if hp <= 0.0:
		dead = true
		if kind == "mech":
			Fx.spawn(par, "explosion", position, Color.WHITE, "", 1.0, 0.6)
			Sfx.play("explode")
		else:
			Fx.spawn(par, "spark", position, Color(0.9, 0.2, 0.2), "", 1.7, 0.5)
			Sfx.play("kill")
		died.emit(self)
		queue_free()

# Colour helper: flashes white for a moment after being hit.
func _c(col: Color) -> Color:
	return col.lerp(Color.WHITE, clampf(_flash / 0.12, 0.0, 1.0) * 0.8)

func _draw() -> void:
	var sgn := -1.0 if cos(_heading) < 0.0 else 1.0
	var s := 1.0 + _scale_pop * 2.0
	match kind:
		"tank":
			_draw_tank(s)
		"mech":
			_draw_mech(s)
		"void":
			_draw_void_lesser(s)
		_:
			_draw_soldier(sgn, s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_bar()

func _draw_bar() -> void:
	if _bar_time <= 0.0 or is_ally:
		return
	var w := maxf(radius * 2.4, 36.0)
	var y := -radius - 20.0
	var a := clampf(_bar_time / 0.5, 0.0, 1.0)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w * 0.5, y, w, 7.0), Color(0, 0, 0, 0.7 * a))
	draw_rect(Rect2(-w * 0.5, y, w * frac, 7.0), Color(0.9, 0.2, 0.2, a))
	draw_rect(Rect2(-w * 0.5, y, w, 7.0), Color(1, 1, 1, 0.6 * a), false, 1.0)

func _draw_soldier(sgn: float, s: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sgn * s, s))
	var swing := sin(_walk) * 6.0
	var dark := _c(Color(0.18, 0.2, 0.15))
	var skin := _c(Color(0.9, 0.72, 0.55))
	var jacket := _c(Color(0.35, 0.47, 0.25))
	var helmet := _c(Color(0.28, 0.36, 0.2))
	if is_ally:
		jacket = _c(Color(0.25, 0.7, 0.3))
		helmet = _c(Color(0.95, 0.95, 0.95))
	draw_circle(Vector2(0, 17), 8.0, Color(0, 0, 0, 0.22))
	draw_line(Vector2(-2, 6), Vector2(-2 + swing, 16), dark, 4.0)
	draw_line(Vector2(2, 6), Vector2(2 - swing, 16), dark, 4.0)
	draw_rect(Rect2(-6, -6, 12, 13), jacket)
	draw_line(Vector2(0, 0), Vector2(17, -3), dark, 3.0)
	draw_line(Vector2(2, -4), Vector2(8, 0), skin, 3.0)
	draw_circle(Vector2(0, -11), 5.0, skin)
	draw_circle(Vector2(0, -13), 5.5, helmet)
	draw_circle(Vector2(2.5, -10), 1.0, dark)
	if is_ally:
		draw_line(Vector2(0, -4), Vector2(0, 4), Color.WHITE, 2.5)
		draw_line(Vector2(-3, 0), Vector2(3, 0), Color.WHITE, 2.5)

func _draw_tank(s: float) -> void:
	draw_set_transform(Vector2.ZERO, _heading, Vector2(s, s))
	var track := _c(Color(0.14, 0.15, 0.13))
	var tread := _c(Color(0.32, 0.32, 0.29))
	draw_rect(Rect2(-27, -23, 54, 11), track)
	draw_rect(Rect2(-27, 12, 54, 11), track)
	for i in 7:
		var x := -26.0 + fposmod(i * 8.0 + _walk * 3.0, 52.0)
		draw_line(Vector2(x, -23), Vector2(x, -12), tread, 2.0)
		draw_line(Vector2(x, 12), Vector2(x, 23), tread, 2.0)
	draw_rect(Rect2(-24, -14, 48, 28), _c(Color(0.30, 0.38, 0.25)))
	draw_rect(Rect2(-19, -10, 22, 20), _c(Color(0.36, 0.45, 0.30)))
	draw_circle(Vector2(2, 0), 11.0, _c(Color(0.38, 0.47, 0.32)))
	draw_rect(Rect2(6, -3, 32, 6), _c(Color(0.20, 0.24, 0.18)))
	draw_rect(Rect2(34, -4, 7, 8), _c(Color(0.12, 0.14, 0.11)))

func _draw_mech(s: float) -> void:
	draw_set_transform(Vector2.ZERO, _heading, Vector2(s, s))
	for i in 3:
		draw_line(Vector2(-24 - i * 8, -7 + i * 7), Vector2(-42 - i * 8, -7 + i * 7), Color(1, 1, 1, 0.25), 2.0)
	var dark := _c(Color(0.12, 0.13, 0.16))
	for sx in [-12.0, 12.0]:
		for sy in [-13.0, 13.0]:
			var wc := Vector2(sx, sy)
			draw_circle(wc, 7.0, dark)
			draw_line(wc, wc + Vector2.RIGHT.rotated(_walk * 2.0) * 5.0, _c(Color(0.6, 0.6, 0.65)), 2.0)
	draw_rect(Rect2(-21, -10, 42, 20), _c(Color(0.45, 0.50, 0.62)))
	draw_rect(Rect2(-2, -8, 14, 16), _c(Color(0.5, 0.85, 0.95)))
	draw_rect(Rect2(10, -3, 20, 6), _c(Color(0.25, 0.27, 0.33)))
	draw_circle(Vector2(-16, 0), 3.0, _c(Color(1.0, 0.2, 0.2)))

func _draw_void_lesser(s: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var bob := sin(_walk * 0.8) * 2.0
	draw_circle(Vector2(5, 10), radius, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(0, bob), radius + 6.0, Color(0.55, 0.2, 0.9, 0.22))
	draw_circle(Vector2(0, bob), radius, _c(Color(0.22, 0.08, 0.35)))
	draw_arc(Vector2(0, bob), radius * 0.8, _walk * 0.3, _walk * 0.3 + 4.0, 16, Color(0.7, 0.4, 1.0, 0.8), 2.5)
	var f := Vector2.RIGHT.rotated(_heading)
	draw_circle(Vector2(0, bob) + f * radius * 0.25, radius * 0.38, Color(0.95, 0.92, 1.0))
	draw_circle(Vector2(0, bob) + f * radius * 0.4, radius * 0.2, Color(0.6, 0.2, 0.95))
	draw_circle(Vector2(0, bob) + f * radius * 0.45, radius * 0.08, Color.BLACK)
