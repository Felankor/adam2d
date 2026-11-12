class_name Enemy
extends Node2D

signal died(enemy: Enemy)
signal arrived(enemy: Enemy)
signal shoot(origin: Vector2, dmg: float)    # tanks fire shells at the base
signal launch(kind: String, origin: Vector2, aim: Vector2, dmg: float)   # rocks, fireballs, missiles, boulders (see Main._on_enemy_launch)
signal request(what: String, src: Enemy, count: int)                    # "worms" under the base, "sinners" around a demon
signal shake(amount: float)

# Space biome: the same units look like ships/drones, move faster and dodge.
static var space_mode: bool = false
static var hit_sound: String = "hit"        # Base switches this to "laser_hit" while a beam is applying damage (see _hit_sfx)
static var _last_laser_hit_ms: int = 0
const SPEED_SCALE := 1.4    # all hostile mobs move this much faster than their base values (bosses excluded)
var space: bool = false

var kind: String = "soldier"      # "soldier", "tank", "mech", "worm", "golem", "demon", "hunter", "void" (Boss uses "boss")
var is_small: bool = false        # a small golem (spawned when a golem dies) does not split again
var shoot_interval: float = 2.4
var power_mult: float = 1.0       # manual tweak for the PowerScore (see power.gd)
var is_minion: bool = false       # summoned by a boss: no gold, vanishes when the boss dies
var is_ally: bool = false
var hp: float = 10.0
var max_hp: float = 10.0
var speed: float = 70.0
var reward: int = 1
var damage: float = 1.0
var armor: float = 0.0            # armor points (see Weapons.armor_mult): 50 points halve every hit
var armor_pen: float = 0.0        # armor penetration of this enemy's attacks against the castle
var target: Vector2 = Vector2.ZERO
var reach: float = 40.0
var radius: float = 15.0
var dead: bool = false
var preview: bool = false         # drawn inside the How to Play page: no groups, no AI, just the animation
var shield: float = 0.0           # energy shield (Aegis): absorbs damage before health, recharges when left alone
var shield_max: float = 0.0
var heal_aura: bool = false       # Medic: heals nearby enemies
var _shield_idle: float = 0.0
var _heal_cd: float = 1.0
var _heal_ms: int = -10000
var _chunk_from: float = 1.0      # health bar "chunk" that breaks off after a hit (League style)
var _chunk_to: float = 1.0
var _chunk_start_ms: int = -10000
var _chunk_crit: bool = false
const CRIT_FRAC := 0.25           # a single hit that removes more than this share of max health is critical
const HEAL_RADIUS := 260.0
const HEAL_PERCENT := 0.08
var dmg_taken_mult: float = 1.0   # < 1 means this enemy absorbs part of every hit

# Ranged enemies (tanks) stop at shoot_range and fire at the base.
var shoots: bool = false
var shoot_range: float = 430.0
var _shoot_cd: float = 0.8

# Dodging (mechs and bosses): sidestep shots that fly straight at us.
var dodge_chance: float = 0.0
static var terrain_biome: int = 0      # which backdrop is under the battlefield (ground units avoid its water and lava)
var _blocked_t: float = 0.0
var _side: float = 1.0
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
var _sprite: Sprite2D = null
var _art: Dictionary = {}
var _art_key: String = ""
var _push: Vector2 = Vector2.ZERO   # knockback velocity, decays smoothly
var _slow_time: float = 0.0         # while > 0 the enemy moves slower after a hit
var art_scale: float = 1.0          # extra size of the sprite (Heavy / Apocalypse Tank)
var master: Enemy = null            # a Sinner remembers the Demon that spawned it
var _sinners_alive: int = 0
var _sinner_cd: float = 0.5
var _slam_cd: float = 5.0           # Golem: time to the next ground slam (summons earthworms)
var _slam_t: float = 0.0
var _slam_fx: float = 0.0
var _missile_cd: float = 3.0        # Apocalypse Tank: time to the next guided missile
const SLAM_TIME := 0.8

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
			e.shoot_interval = 1.2        # tanks fire twice as often
			e.shoot_range = randf_range(400.0, 470.0)
			e._shoot_cd = randf_range(0.5, 1.4)
			e.armor = 40.0
			e.armor_pen = 10.0
			e.reward = 4 + int(level * 0.5)
			e.radius = 27.0
		"heavytank":  # grey Heavy Tank: 30% bigger, stronger and more armored than a Tank, with a double barrel
			e.hp = (40.0 + lvl * 12.0) * 1.3 * GameState.hp_mult()
			e.speed = minf(32.0 + lvl * 1.5, 70.0) * GameState.speed_mult()
			e.damage = 3.0 * 1.3 * dmg_mult
			e.shoots = true
			e.shoot_interval = 1.4
			e.shoot_range = randf_range(430.0, 490.0)
			e._shoot_cd = randf_range(0.5, 1.5)
			e.armor = 40.0 * 1.3
			e.armor_pen = 12.0
			e.reward = 8 + int(level * 0.8)
			e.radius = 27.0 * 1.3
			e.art_scale = 1.3
		"apoctank":   # dark Apocalypse Tank: 20% bigger, 50% more HP, 25% more powerful than a Heavy Tank; guided missiles
			e.hp = (40.0 + lvl * 12.0) * 1.3 * 1.5 * GameState.hp_mult()
			e.speed = minf(32.0 + lvl * 1.5, 70.0) * 0.9 * GameState.speed_mult()
			e.damage = 3.0 * 1.3 * 1.25 * dmg_mult
			e.shoots = true
			e.shoot_interval = 1.5
			e.shoot_range = randf_range(460.0, 520.0)
			e._shoot_cd = randf_range(0.5, 1.5)
			e._missile_cd = randf_range(2.0, 4.0)
			e.armor = 40.0 * 1.3 * 1.15
			e.armor_pen = 15.0
			e.reward = 16 + int(level * 1.1)
			e.radius = 27.0 * 1.3 * 1.2
			e.art_scale = 1.3 * 1.2
			e.power_mult = 1.3
		"mech":
			e.hp = (20.0 + lvl * 2.5) * GameState.hp_mult()
			e.dodge_chance = 0.6
			e.dodge_cd_time = 1.1
			e.dodge_dash = 460.0
			e.speed = minf(170.0 + lvl * 6.0, 320.0) * GameState.speed_mult()
			e.damage = 2.0 * dmg_mult
			e.armor = 8.0
			e.reward = 3 + int(level * 0.4)
			e.radius = 22.0
		"earthworm":  # grey worm summoned by Golems under the castle: a Bloodworm with half the health
			e.hp = (5.0 + lvl * 1.2) * GameState.hp_mult()
			e.speed = minf(250.0 + lvl * 4.0, 400.0) * GameState.speed_mult()
			e.damage = 0.7 * dmg_mult
			e.reward = 0
			e.radius = 11.0
		"sinner":     # Demon's unarmed black zombie-soldier
			e.hp = (14.0 + lvl * 4.5) * GameState.hp_mult()
			e.speed = minf(42.0 + lvl * 2.5, 100.0) * GameState.speed_mult()
			e.damage = 1.2 * dmg_mult
			e.reward = 1 + int(level * 0.2)
			e.radius = 15.0
		"worm":       # Mudland: Bloodworm - tiny, very fast, tough for its size (double health)
			e.hp = (5.0 + lvl * 1.2) * 2.0 * GameState.hp_mult()
			e.speed = minf(250.0 + lvl * 4.0, 400.0) * GameState.speed_mult()
			e.damage = 0.7 * dmg_mult
			e.reward = 1 + int(level * 0.3)
			e.radius = 11.0
		"golem":      # Rocky Mountain: bigger and stronger than a tank, same speed
			e.hp = (90.0 + lvl * 25.0) * GameState.hp_mult()
			e.speed = minf(32.0 + lvl * 1.5, 70.0) * GameState.speed_mult()
			e.damage = 5.0 * dmg_mult
			e.armor = 30.0
			e.armor_pen = 15.0
			e.reward = 8 + int(level * 0.7)
			e.radius = 38.0
			e.shoots = true                      # throws rocks from far away
			e.shoot_range = randf_range(540.0, 660.0)
			e.shoot_interval = 3.2
			e._shoot_cd = randf_range(1.0, 2.5)
			e._slam_cd = randf_range(3.5, 6.0)
		"demon":      # Hell: faster and stronger than a golem, 3x its health
			e.hp = (90.0 + lvl * 25.0) * 3.0 * GameState.hp_mult()
			e.speed = minf(32.0 + lvl * 1.5, 70.0) * 1.6 * GameState.speed_mult()
			e.damage = 8.0 * dmg_mult
			e.armor = 20.0
			e.armor_pen = 20.0
			e.reward = 25 + int(level * 1.2)
			e.radius = 42.0
			e.shoots = true                      # throws fireballs, spawns sinners
			e.shoot_range = randf_range(480.0, 560.0)
			e.shoot_interval = 3.0
			e._shoot_cd = randf_range(1.5, 2.5)
		"hunter":     # Space: spawn in packs of 5, dodge again and again, shoot from far away
			e.hp = (20.0 + lvl * 2.5) * GameState.hp_mult()
			e.speed = minf(120.0 + lvl * 2.0, 190.0) * GameState.speed_mult()
			e.damage = 1.5 * dmg_mult
			e.shoots = true
			e.shoot_range = randf_range(800.0, 940.0)    # twice a tank's range
			e.shoot_interval = 3.0
			e._shoot_cd = randf_range(0.5, 2.5)
			e.armor = 5.0
			e.dodge_chance = 0.9
			e.dodge_cd_time = 0.3
			e.dodge_dash = 420.0
			e.reward = 3 + int(level * 0.4)
			e.radius = 20.0
			e.space = true
		"medic":      # heals the enemies around it: kill it first
			e.hp = (14.0 + lvl * 2.0) * GameState.hp_mult()
			e.speed = minf(55.0 + lvl * 2.0, 120.0) * GameState.speed_mult()
			e.damage = 0.8 * dmg_mult
			e.heal_aura = true
			e.power_mult = 1.4
			e.reward = 3 + int(level * 0.4)
			e.radius = 16.0
		"aegis":      # energy shield soaks damage first, recharges if you stop hitting it
			e.hp = (24.0 + lvl * 3.5) * GameState.hp_mult()
			e.speed = minf(45.0 + lvl * 1.5, 90.0) * GameState.speed_mult()
			e.damage = 1.8 * dmg_mult
			e.armor = 10.0
			e.shield_max = e.hp * 0.8
			e.shield = e.shield_max
			e.reward = 4 + int(level * 0.5)
			e.radius = 20.0
		_:
			e.kind = "soldier"
			e.hp = (10.0 + lvl * 4.0) * GameState.hp_mult()
			e.speed = minf(70.0 + lvl * 5.0, 180.0) * GameState.speed_mult()
			e.damage = 1.0 * dmg_mult
			e.reward = 1 + int(level * 0.5)
			e.radius = 15.0
	if space_mode and (e.kind == "tank" or e.kind == "heavytank" or e.kind == "apoctank" or e.kind == "mech" or e.kind == "soldier"):
		e.space = true
		match e.kind:
			"tank", "heavytank", "apoctank":      # starship
				e.speed *= 1.4
				e.dodge_chance = 0.5
				e.dodge_cd_time = 1.5
				e.dodge_dash = 380.0
			"mech":      # space corvette
				e.speed *= 1.25
				e.dodge_chance = 0.8
				e.dodge_cd_time = 0.8
				e.dodge_dash = 520.0
			_:           # kamikaze drone
				e.speed *= 1.6
				e.dodge_chance = 0.5
				e.dodge_cd_time = 1.0
				e.dodge_dash = 420.0
	e.speed *= SPEED_SCALE
	e.max_hp = e.hp
	return e

# The smaller golem left behind when a golem is destroyed.
static func make_small_golem(parent: Enemy) -> Enemy:
	var e := Enemy.new()
	e.kind = "golem"
	e.is_small = true
	e.hp = parent.max_hp * 0.4
	e.max_hp = e.hp
	e.speed = parent.speed
	e.damage = parent.damage * 0.55
	e.armor = parent.armor
	e.reward = maxi(parent.reward / 2, 1)
	e.radius = 22.0
	e.shoots = true                          # the little ones throw (smaller) rocks from closer in
	e.shoot_range = randf_range(300.0, 380.0)
	e.shoot_interval = 3.0
	e._shoot_cd = randf_range(1.0, 2.0)
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

# A bee summoned by the Garden Warden: twice as fast as a soldier, weak, but its sting
# poisons the castle (see Base.apply_poison). No gold; vanishes when the boss dies.
static func make_bee(level: int) -> Enemy:
	var s := Enemy.make("soldier", level)
	var e := Enemy.new()
	e.kind = "bee"
	e.speed = s.speed * 2.0
	e.hp = 3.0 * GameState.hp_mult()
	e.max_hp = e.hp
	e.damage = 0.5 * (1.0 + 0.25 * float(level - 1))
	e.reward = 0
	e.radius = 11.0
	e.is_minion = true
	e.dodge_chance = 0.0
	s.free()
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
	_make_sprite()
	if preview:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("mobs")
	add_to_group("allies" if is_ally else "enemies")
	if is_minion:
		add_to_group("minions")
	if kind == "void":
		add_to_group("void_lessers")

# Pixel-art body (see mob_art.gd). The vector drawing below is only used when no sprite exists.
func _make_sprite() -> void:
	_art_key = MobArt.key_for(kind, space, is_ally)
	if _art_key == "" or not MobArt.INFO.has(_art_key):
		return
	_art = MobArt.frames(_art_key)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = (_art["tex"] as Array)[0]
	add_child(_sprite)
	_update_sprite()

func _update_sprite() -> void:
	if _sprite == null:
		return
	if MobArt.directional(_art_key):
		_art = MobArt.frames(_art_key, MobArt.dir_of(_heading))
	_sprite.offset = _art["off"]
	var n: int = _art["n"]
	var fr := int(floorf(_walk * MobArt.frame_rate(_art_key))) % n
	if fr < 0:
		fr += n
	_sprite.texture = (_art["flash" if _flash > 0.0 else "tex"] as Array)[fr]
	var k := MobArt.PX * MobArt.scale_for(_art_key)
	if is_small:
		k *= 0.6
	elif kind == "void":
		k *= clampf(radius / 21.0, 0.4, 1.6)
	k *= art_scale
	k *= 1.0 + _scale_pop * 2.0
	_sprite.scale = Vector2(k, k)
	_sprite.position = Vector2(0.0, -sin(clampf(1.0 - _slam_t / SLAM_TIME, 0.0, 1.0) * PI) * 26.0) if _slam_t > 0.0 else Vector2.ZERO
	if MobArt.rotates(_art_key):
		_sprite.rotation = _heading
	elif MobArt.flips(_art_key):
		_sprite.flip_h = cos(_heading) < 0.0

func _tick_common(delta: float) -> void:
	_update_sprite()
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

# Medic healing pulse and Aegis shield recharge.
func _special_tick(delta: float) -> void:
	_slam_fx = maxf(_slam_fx - delta, 0.0)
	var dist_t := position.distance_to(target)
	match kind:
		"demon":
			# spawns 5 Sinners; when every one of them is gone, 5 new ones come at once
			if _sinners_alive <= 0:
				_sinner_cd -= delta
				if _sinner_cd <= 0.0:
					_sinners_alive = 5
					_sinner_cd = 0.0
					_scale_pop = 0.25
					Sfx.play("boss_summon", -5.0)
					request.emit("sinners", self, 5)
		"golem":
			if not is_small and _slam_t <= 0.0 and dist_t <= shoot_range + 160.0:
				_slam_cd -= delta
				if _slam_cd <= 0.0:
					_slam_cd = 12.0
					_slam_t = SLAM_TIME
					Sfx.play("boss_warn", -6.0)
		"apoctank":
			if dist_t <= shoot_range + 220.0:
				_missile_cd -= delta
				if _missile_cd <= 0.0:
					_missile_cd = 5.0
					launch.emit("missile", position + Vector2.RIGHT.rotated(_heading + PI) * 16.0, target, damage * 0.8)
					Sfx.play("rocket", -5.0)
	if shield_max > 0.0:
		_shield_idle += delta
		if _shield_idle > 3.0 and shield < shield_max:
			shield = minf(shield + shield_max * 0.15 * delta, shield_max)
	if heal_aura:
		_heal_cd -= delta
		if _heal_cd <= 0.0:
			_heal_cd = 1.5
			_heal_ms = Time.get_ticks_msec()
			for e in Field.near(position, HEAL_RADIUS):
				if e == self or e.is_ally or e.dead or e.kind == "boss" or e.kind == "minicastle":
					continue
				if e.hp < e.max_hp and position.distance_to(e.position) <= HEAL_RADIUS:
					e.hp = minf(e.hp + e.max_hp * HEAL_PERCENT, e.max_hp)
					e._bar_time = maxf(e._bar_time, 1.2)
					Fx.spawn(get_parent(), "spark", e.position + Vector2(0.0, -e.radius), Color(0.4, 1.0, 0.5), "", 0.6, 0.35)

# The Golem lands from its slam: the ground shakes and three earthworms burst out under the castle.
func _land() -> void:
	_slam_fx = 0.6
	_scale_pop = 0.3
	shake.emit(11.0)
	Sfx.play("explode", -2.0)
	Fx.spawn(get_parent(), "explosion", position, Color(0.6, 0.5, 0.4), "", 1.1, 0.6)
	request.emit("worms", self, 3)

# One shot of a ranged mob (tanks, golems, demons).
func _do_shot() -> void:
	var f := Vector2.RIGHT.rotated(_heading)
	var origin := position + f * 38.0 * maxf(art_scale, 1.0)
	match kind:
		"heavytank", "apoctank":
			var side := f.orthogonal() * 9.0
			shoot.emit(origin + side, damage)         # the double barrel fires both shells together
			shoot.emit(origin - side, damage)
			Sfx.play("tank_fire", -2.0)
		"golem":
			launch.emit("rock", position + f * radius * 0.8, target, damage * (0.55 if is_small else 0.9))
			Sfx.play("bolt", -4.0)
		"demon":
			launch.emit("fireball", position + f * radius * 0.8, target, damage)
			Sfx.play("rocket", -4.0)
		_:
			shoot.emit(origin, damage)
			Sfx.play("tank_fire", -3.0)

# A Sinner that dies or reaches the castle tells its Demon, which then spawns new ones when all are gone.
func _tell_master() -> void:
	if master != null and is_instance_valid(master) and not master.dead:
		master._sinners_alive = maxi(master._sinners_alive - 1, 0)

# Critical hit: one strike that removes more than 25% of max health.
func _is_crit(dealt: float) -> bool:
	return max_hp > 0.0 and dealt >= CRIT_FRAC * max_hp

# Remembers the slice of the health bar that was just lost, so it can break off.
func _record_chunk(hp_before: float, crit: bool) -> void:
	_chunk_from = clampf(hp_before / maxf(max_hp, 0.001), 0.0, 1.0)
	_chunk_to = clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	_chunk_start_ms = Time.get_ticks_msec()
	_chunk_crit = crit

func _crit_effects(par: Node, scale_k: float) -> void:
	Fx.spawn(par, "crit", position, Color(1.0, 0.8, 0.3), "", scale_k, 0.45)
	Fx.spawn(par, "spark", position, Color(1.0, 0.55, 0.2), "", 1.8, 0.5)
	Sfx.play("crit", -2.0)

# Draws the lost part of a health bar: a white slice that fades, or (critical) a hot slice that
# shatters into shards and falls.
func _draw_chunk(x: float, y: float, w: float, h: float, a: float, ci: CanvasItem = null) -> void:
	var cv: CanvasItem = ci if ci != null else self
	var life := 0.9 if _chunk_crit else 0.55
	var age := float(Time.get_ticks_msec() - _chunk_start_ms) / 1000.0
	if age < 0.0 or age > life or _chunk_from <= _chunk_to:
		return
	var k := age / life
	var x0 := x + w * _chunk_to
	var x1 := x + w * _chunk_from
	if not _chunk_crit:
		cv.draw_rect(Rect2(x0, y, x1 - x0, h), Color(1, 1, 1, 0.9 * (1.0 - k) * a))
		return
	if k < 0.2:
		cv.draw_rect(Rect2(x0, y, x1 - x0, h), Color(1.0, 0.95, 0.7, a))
		cv.draw_rect(Rect2(x0 - 1.0, y - 2.0, x1 - x0 + 2.0, h + 4.0), Color(1.0, 0.6, 0.2, 0.5 * a), false, 2.0)
		return
	var kk := (k - 0.2) / 0.8
	var n := 5
	for i in n:
		var sw := (x1 - x0) / float(n)
		var sx := x0 + sw * float(i) + (float(i) - 2.0) * 14.0 * kk
		var fall := 10.0 * kk + 80.0 * kk * kk * (1.0 + 0.35 * float(i % 3))
		cv.draw_rect(Rect2(sx, y + fall, sw * (1.0 - 0.3 * kk), h * (1.0 - 0.45 * kk)), Color(1.0, 0.3 + 0.3 * kk, 0.15, (1.0 - kk) * a))

# Small shield badge with the armor value next to a health bar.
func _draw_armor_tag(origin: Vector2, ci: CanvasItem = null) -> void:
	var cv: CanvasItem = ci if ci != null else self
	if armor < 5.0:
		return
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(11, 0), Vector2(11, 7), Vector2(5.5, 13), Vector2(0, 7)])
	for i in pts.size():
		pts[i] += origin
	cv.draw_colored_polygon(pts, Color(0.55, 0.75, 0.95, 0.95))
	var outline := pts.duplicate()
	outline.append(pts[0])
	cv.draw_polyline(outline, Color.WHITE, 1.5)
	var font := ThemeDB.fallback_font
	var txt := str(int(armor))
	cv.draw_string_outline(font, origin + Vector2(15, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelUI.fs(12), 3, Color.BLACK)
	cv.draw_string(font, origin + Vector2(15, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelUI.fs(12), Color.WHITE)

func _process(delta: float) -> void:
	if preview:
		_walk += delta * 3.0
		_update_sprite()
		queue_redraw()
		return
	_tick_common(delta)
	_special_tick(delta)
	if _slam_t > 0.0:                           # the Golem leaps and slams the ground: it stands still meanwhile
		_slam_t -= delta
		_heading = (target - position).angle()
		if _slam_t <= 0.0:
			_slam_t = 0.0
			_land()
		queue_redraw()
		return
	var to_target := target - position
	var dist := to_target.length()
	# Tanks stop in range and shell the base until they are destroyed.
	if shoots and dist <= shoot_range:
		_heading = to_target.angle()
		_shoot_cd -= delta
		if _shoot_cd <= 0.0:
			_shoot_cd = shoot_interval
			_do_shot()
		position += _update_dodge(delta) * delta
		queue_redraw()
		return
	if dist <= reach:
		dead = true
		_tell_master()
		arrived.emit(self)
		queue_free()
		return
	var dir := to_target / dist
	_heading = dir.angle()
	var spd := _move_speed()
	var step := (dir * spd + _update_dodge(delta)) * delta
	if kind != "bee":
		step = _avoid_liquid(step, delta)
	position += step
	_walk += delta * spd * 0.12
	queue_redraw()

# Walking units do not cross ponds and lava: they slide along the bank, and only wade through
# (slowly) when they have been stuck for a few seconds, so a wave can never get stuck for good.
func _avoid_liquid(step: Vector2, delta: float) -> Vector2:
	if step == Vector2.ZERO:
		return step
	var look := radius * 0.5 + 18.0
	if not Backdrop.liquid_at(terrain_biome, position + step.normalized() * look):
		_blocked_t = maxf(_blocked_t - delta * 2.0, 0.0)
		return step
	_blocked_t += delta
	if _blocked_t > 3.0:
		return step * 0.45
	if _side == 1.0 and randf() < 0.5:
		_side = -1.0
	for a in [0.7, -0.7, 1.4, -1.4]:
		var d2 := step.rotated(float(a) * _side)
		if not Backdrop.liquid_at(terrain_biome, position + d2.normalized() * look):
			return d2
	return Vector2.ZERO

# Finds one of our shots flying straight at us (used for dodging).
func _incoming_shot() -> Projectile:
	for shot in Field.shots():
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

func take_damage(amount: float, pen: float = 0.0) -> void:
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
	var armor_factor := Weapons.armor_mult(armor, pen)
	var raw := amount * armor_factor * dmg_taken_mult
	var absorbed := 0.0
	if shield > 0.0 and not Weapons.is_true(pen):
		absorbed = minf(shield, raw)
		shield -= absorbed
		_shield_idle = 0.0
	var dealt := raw - absorbed
	var hp_before := hp
	hp -= dealt
	var crit := _is_crit(dealt)
	_record_chunk(hp_before, crit)
	_flash = 0.22 if crit else 0.12
	_bar_time = 3.5 if crit else 2.5
	_scale_pop = 0.2 if crit else 0.12
	var kick := 1.6 if crit else 1.0
	var back := -Vector2.RIGHT.rotated(_heading)
	match kind:
		"tank", "golem", "demon":
			_hit_reaction(back, (35.0 if kind == "tank" else 20.0) * kick)    # heavy: barely moves
		"worm":
			_hit_reaction(back, 300.0 * kick)
		"mech":
			_hit_reaction(back, 260.0 * kick)   # light: gets thrown back
		_:
			_hit_reaction(back, 170.0 * kick)
	var num_col := Color.WHITE
	if absorbed > 0.0 and dealt <= 0.0:
		num_col = Color(0.4, 0.9, 1.0)
		Fx.spawn(par, "spark", position, Color(0.4, 0.9, 1.0), "", 1.0, 0.3)
		_hit_sfx("block")
	elif crit:
		num_col = Color(1.0, 0.35, 0.12)
		_crit_effects(par, maxf(radius / 25.0, 1.0))
	elif armor_factor < 0.85:      # armor soaks a noticeable part of the hit: metallic ping
		num_col = Color(0.7, 0.82, 1.0)
		Fx.spawn(par, "spark", position, Color(0.8, 0.85, 0.95), "", 0.9, 0.3)
		_hit_sfx("block")
	else:
		Fx.spawn(par, "spark", position, Color(1.0, 0.85, 0.3), "", 1.0, 0.35)
		_hit_sfx("hit")
	var shown := str(int(ceil(dealt + absorbed)))
	if crit:
		shown += "!"
	Fx.spawn(par, "number", position + Vector2(0, -radius - 12.0), num_col, shown, 1.8 if crit else 1.0, 1.0 if crit else 0.7)
	if hp <= 0.0:
		dead = true
		_tell_master()
		if kind == "mech" or kind == "golem" or kind == "demon" or kind == "heavytank" or kind == "apoctank":
			Fx.spawn(par, "explosion", position, Color.WHITE, "", 1.0, 0.6)
			Sfx.play("explode")
		else:
			Fx.spawn(par, "spark", position, Color(0.9, 0.2, 0.2), "", 1.7, 0.5)
			Sfx.play("kill")
		died.emit(self)
		queue_free()

# Killed by touching the player's active Barrier: counts as a normal kill (gold and XP).
func barrier_kill() -> void:
	if dead:
		return
	dead = true
	_tell_master()
	Fx.spawn(get_parent(), "spark", position, Color(0.5, 0.95, 1.0), "", 1.5, 0.45)
	died.emit(self)
	queue_free()

# Colour helper: flashes white for a moment after being hit.
func _c(col: Color) -> Color:
	return col.lerp(Color.WHITE, clampf(_flash / 0.12, 0.0, 1.0) * 0.8)

# A dark disc and a coloured ring under every mob so it stands out on busy maps:
# red = hostile, green = refugee (do not shoot).
# Beams cross many mobs at once: they get one soft tick at most every 80 ms instead of the harsh hit sound.
func _hit_sfx(normal: String) -> void:
	if hit_sound == "laser_hit":
		var now := Time.get_ticks_msec()
		if now - _last_laser_hit_ms > 80:
			_last_laser_hit_ms = now
			Sfx.play("laser_hit", -6.0)
	else:
		Sfx.play(normal)

func _draw_marker() -> void:
	var mr := maxf(radius, 12.0) + 5.0
	var ring := Color(0.4, 1.0, 0.5, 0.9) if is_ally else Color(1.0, 0.25, 0.2, 0.9)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, MobArt.GROUND_SQUASH))
	PixelFx.disc(self, Vector2(3, 5), mr, Color(0, 0, 0, 0.36))
	PixelFx.ring(self, Vector2(0, 2), mr, ring, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_overlays() -> void:
	if _slam_fx > 0.0:
		var sk := 1.0 - _slam_fx / 0.6
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, MobArt.GROUND_SQUASH))
		PixelFx.ring(self, Vector2.ZERO, 30.0 + 200.0 * sk, Color(0.8, 0.7, 0.5, 0.8 * (1.0 - sk)), 8.0 * (1.0 - sk) + 2.0)
		PixelFx.ring(self, Vector2.ZERO, 20.0 + 140.0 * sk, Color(0.5, 0.4, 0.3, 0.6 * (1.0 - sk)), 5.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _slam_t > 0.0:
		var wk := 1.0 - _slam_t / SLAM_TIME
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, MobArt.GROUND_SQUASH))
		PixelFx.ring(self, Vector2.ZERO, 40.0 + 120.0 * (1.0 - wk), Color(1.0, 0.4, 0.2, 0.3 + 0.5 * wk), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if kind == "medic":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, MobArt.GROUND_SQUASH))
		PixelFx.ring(self, Vector2.ZERO, HEAL_RADIUS, Color(0.4, 1.0, 0.5, 0.10), 2.0)
		var pk := float(Time.get_ticks_msec() - _heal_ms) / 600.0
		if pk >= 0.0 and pk < 1.0:
			PixelFx.ring(self, Vector2.ZERO, HEAL_RADIUS * pk, Color(0.4, 1.0, 0.5, 0.55 * (1.0 - pk)), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif kind == "aegis":
		var frac := clampf(shield / maxf(shield_max, 0.001), 0.0, 1.0)
		if frac > 0.0:
			draw_set_transform(Vector2.ZERO, _heading, Vector2.ONE)
			PixelFx.arc(self, Vector2.ZERO, 26.0, -1.0, 1.0, Color(0.35, 0.9, 1.0, 0.25 + 0.65 * frac), 6.0)
			PixelFx.arc(self, Vector2.ZERO, 26.0, -1.0, 1.0, Color(0.85, 1.0, 1.0, 0.6 * frac), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	_draw_marker()
	if _sprite != null:
		_draw_overlays()
		_draw_bar()
		return
	var sgn := -1.0 if cos(_heading) < 0.0 else 1.0
	var s := 1.0 + _scale_pop * 2.0
	match kind:
		"tank":
			if space:
				_draw_starship(s)
			else:
				_draw_tank(s)
		"mech":
			if space:
				_draw_corvette(s)
			else:
				_draw_mech(s)
		"worm":
			_draw_worm(s)
		"golem":
			_draw_golem(s)
		"demon":
			_draw_demon(s)
		"hunter":
			_draw_hunter(s)
		"void":
			_draw_void_lesser(s)
		"bee":
			_draw_bee(s)
		"medic":
			_draw_medic(s)
		"aegis":
			_draw_aegis(s)
		_:
			if space:
				_draw_drone(s)
			else:
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
	_draw_chunk(-w * 0.5, y, w, 7.0, a)
	draw_rect(Rect2(-w * 0.5, y, w, 7.0), Color(1, 1, 1, 0.6 * a), false, 1.0)
	if shield_max > 0.0:
		draw_rect(Rect2(-w * 0.5, y - 5.0, w, 4.0), Color(0, 0, 0, 0.7 * a))
		draw_rect(Rect2(-w * 0.5, y - 5.0, w * clampf(shield / shield_max, 0.0, 1.0), 4.0), Color(0.35, 0.85, 1.0, a))
	_draw_armor_tag(Vector2(-w * 0.5 - 30.0, y - 3.0))

func _draw_medic(s: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var swing := sin(_walk) * 5.0
	var coat := _c(Color(0.92, 0.95, 0.92))
	var skin := _c(Color(0.9, 0.72, 0.55))
	var pants := _c(Color(0.3, 0.38, 0.3))
	# faint healing aura, with a pulse that expands each time it heals
	draw_arc(Vector2.ZERO, HEAL_RADIUS, 0.0, TAU, 48, Color(0.4, 1.0, 0.5, 0.10), 2.0)
	var pk := float(Time.get_ticks_msec() - _heal_ms) / 600.0
	if pk >= 0.0 and pk < 1.0:
		draw_arc(Vector2.ZERO, HEAL_RADIUS * pk, 0.0, TAU, 48, Color(0.4, 1.0, 0.5, 0.55 * (1.0 - pk)), 4.0)
	draw_line(Vector2(-4, 8), Vector2(-4 + swing, 20), pants, 4.0)
	draw_line(Vector2(4, 8), Vector2(4 - swing, 20), pants, 4.0)
	draw_rect(Rect2(-9, -8, 18, 18), coat)
	draw_circle(Vector2(0, -14), 7.0, skin)
	draw_rect(Rect2(-8, -24, 16, 7), coat)
	draw_rect(Rect2(-2, -4, 4, 12), _c(Color(0.2, 0.8, 0.3)))
	draw_rect(Rect2(-6, 0, 12, 4), _c(Color(0.2, 0.8, 0.3)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_aegis(s: float) -> void:
	draw_set_transform(Vector2.ZERO, _heading, Vector2(s, s))
	var frac := clampf(shield / maxf(shield_max, 0.001), 0.0, 1.0)
	var steel := _c(Color(0.42, 0.46, 0.55))
	draw_circle(Vector2.ZERO, 15.0, steel)
	draw_circle(Vector2(-3, 0), 9.0, _c(Color(0.28, 0.3, 0.38)))
	draw_circle(Vector2(5, 0), 6.0, _c(Color(0.9, 0.75, 0.3)))
	# energy shield: a bright arc in front of it that fades as the shield is used up
	if frac > 0.0:
		draw_arc(Vector2.ZERO, 26.0, -1.0, 1.0, 20, Color(0.35, 0.9, 1.0, 0.25 + 0.65 * frac), 6.0)
		draw_arc(Vector2.ZERO, 26.0, -1.0, 1.0, 20, Color(0.85, 1.0, 1.0, 0.6 * frac), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_soldier(sgn: float, s: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sgn * s, s))
	var swing := sin(_walk) * 6.0
	var dark := _c(Color(0.18, 0.2, 0.15))
	var skin := _c(Color(0.9, 0.72, 0.55))
	var jacket := _c(Color(0.35, 0.47, 0.25))
	var helmet := _c(Color(0.28, 0.36, 0.2))
	if is_ally:
		# Refugee: reddish clothes and headscarf, carrying a little white flag
		jacket = _c(Color(0.78, 0.25, 0.25))
		helmet = _c(Color(0.6, 0.15, 0.18))
	draw_circle(Vector2(0, 17), 8.0, Color(0, 0, 0, 0.22))
	draw_line(Vector2(-2, 6), Vector2(-2 + swing, 16), dark, 4.0)
	draw_line(Vector2(2, 6), Vector2(2 - swing, 16), dark, 4.0)
	draw_rect(Rect2(-6, -6, 12, 13), jacket)
	if not is_ally:
		draw_line(Vector2(0, 0), Vector2(17, -3), dark, 3.0)
	draw_line(Vector2(2, -4), Vector2(8, 0), skin, 3.0)
	draw_circle(Vector2(0, -11), 5.0, skin)
	draw_circle(Vector2(0, -13), 5.5, helmet)
	draw_circle(Vector2(2.5, -10), 1.0, dark)
	if is_ally:
		var wave := sin(_walk * 1.5) * 1.5
		draw_line(Vector2(8, 0), Vector2(8, -21), Color(0.5, 0.38, 0.25), 1.6)
		_poly([Vector2(8, -21), Vector2(19, -19 + wave), Vector2(8, -13)], Color.WHITE)

func _draw_bee(s: float) -> void:
	var sgn := -1.0 if cos(_heading) < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sgn * s, s))
	var buzz := sin(_walk * 9.0 + position.x * 0.05)
	draw_circle(Vector2(0, 14), 6.0, Color(0, 0, 0, 0.2))
	# wings
	draw_circle(Vector2(-3, -7 + buzz), 6.0, _c(Color(0.85, 0.95, 1.0, 0.65)))
	draw_circle(Vector2(3, -7 - buzz), 6.0, _c(Color(0.85, 0.95, 1.0, 0.65)))
	# striped body
	draw_circle(Vector2(0, 0), 8.5, _c(Color(1.0, 0.8, 0.1)))
	draw_rect(Rect2(-8.0, -3.0, 16.0, 3.0), _c(Color(0.15, 0.1, 0.05)))
	draw_rect(Rect2(-7.0, 3.0, 14.0, 3.0), _c(Color(0.15, 0.1, 0.05)))
	draw_circle(Vector2(8, -1), 5.0, _c(Color(0.2, 0.14, 0.06)))
	draw_circle(Vector2(10, -2), 1.3, Color.WHITE)
	draw_line(Vector2(-8, 1), Vector2(-14, 3), _c(Color(0.2, 0.14, 0.06)), 2.0)

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

# ---------- Space biome looks ----------

func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)

# Draws a polygon and its mirror image (top/bottom) so ships are symmetric.
func _poly_sym(pts: Array, col: Color) -> void:
	_poly(pts, col)
	var m: Array = []
	for p: Vector2 in pts:
		m.append(Vector2(p.x, -p.y))
	_poly(m, col)

func _engine_flame(pos: Vector2, size: float) -> void:
	var f := 0.75 + 0.25 * sin(_walk * 9.0 + pos.y)
	draw_circle(pos + Vector2(-size * 0.5, 0), size * 0.9, Color(1.0, 0.45, 0.15, 0.18))
	_poly([pos + Vector2(0, -size * 0.45), pos + Vector2(0, size * 0.45), pos + Vector2(-size * 1.8 * f, 0)], Color(1.0, 0.5, 0.15))
	_poly([pos + Vector2(0, -size * 0.2), pos + Vector2(0, size * 0.2), pos + Vector2(-size * 1.0 * f, 0)], Color(1.0, 0.92, 0.55))

# Kamikaze drone (replaces the soldier).
func _draw_drone(s: float) -> void:
	draw_set_transform(Vector2.ZERO, _heading, Vector2(s, s))
	var hull := _c(Color(0.24, 0.22, 0.3))
	var blink := 0.5 + 0.5 * sin(_walk * 5.0)
	_engine_flame(Vector2(-9, 0), 6.0)
	_poly_sym([Vector2(-1, -7), Vector2(-12, -17), Vector2(-10, -5)], _c(Color(0.32, 0.3, 0.4)))
	_poly([Vector2(17, 0), Vector2(-3, -9), Vector2(-10, 0), Vector2(-3, 9)], hull)
	_poly([Vector2(17, 0), Vector2(2, -4), Vector2(2, 4)], _c(Color(0.95, 0.25, 0.2)))
	draw_circle(Vector2(-3, 0), 2.4, Color(1.0, 0.3 + 0.4 * blink, 0.25))
	draw_circle(Vector2(5, 0), 2.0, _c(Color(1.0, 0.8, 0.3)))

# Starship (replaces the tank).
func _draw_starship(s: float) -> void:
	draw_set_transform(Vector2.ZERO, _heading, Vector2(s, s))
	var hull := _c(Color(0.3, 0.33, 0.45))
	_engine_flame(Vector2(-29, -6), 7.0)
	_engine_flame(Vector2(-29, 6), 7.0)
	_poly_sym([Vector2(8, -8), Vector2(-20, -27), Vector2(-31, -27), Vector2(-22, -9)], _c(Color(0.2, 0.22, 0.32)))
	_poly([Vector2(38, 0), Vector2(14, -9), Vector2(-26, -11), Vector2(-31, 0), Vector2(-26, 11), Vector2(14, 9)], hull)
	_poly([Vector2(38, 0), Vector2(14, -9), Vector2(14, 9)], _c(Color(0.4, 0.43, 0.56)))
	draw_line(Vector2(-6, -18), Vector2(16, -18), _c(Color(0.12, 0.13, 0.17)), 3.0)
	draw_line(Vector2(-6, 18), Vector2(16, 18), _c(Color(0.12, 0.13, 0.17)), 3.0)
	draw_rect(Rect2(-24, -2, 34, 4), _c(Color(0.85, 0.25, 0.25)))
	_poly([Vector2(20, -3), Vector2(28, 0), Vector2(20, 3)], _c(Color(0.5, 0.9, 1.0)))

# Space corvette (replaces the mechanized unit).
func _draw_corvette(s: float) -> void:
	draw_set_transform(Vector2.ZERO, _heading, Vector2(s, s))
	for i in 3:
		draw_line(Vector2(-26 - i * 8, -6 + i * 6), Vector2(-44 - i * 8, -6 + i * 6), Color(1, 1, 1, 0.22), 2.0)
	_engine_flame(Vector2(-24, -5), 5.0)
	_engine_flame(Vector2(-24, 5), 5.0)
	_poly_sym([Vector2(-8, -10), Vector2(-24, -21), Vector2(-20, -8)], _c(Color(0.28, 0.3, 0.4)))
	_poly([Vector2(30, 0), Vector2(16, -9), Vector2(-14, -12), Vector2(-24, -7), Vector2(-24, 7), Vector2(-14, 12), Vector2(16, 9)], _c(Color(0.42, 0.48, 0.62)))
	draw_line(Vector2(-12, -6), Vector2(18, -4), _c(Color(0.28, 0.3, 0.4)), 2.0)
	draw_line(Vector2(-12, 6), Vector2(18, 4), _c(Color(0.28, 0.3, 0.4)), 2.0)
	draw_circle(Vector2(10, 0), 5.0, _c(Color(0.5, 0.92, 1.0)))
	draw_circle(Vector2(-17, 0), 2.5, _c(Color(1.0, 0.2, 0.2)))

# ---------- Biome-specific enemies ----------

# Mudland: Bloodworm
func _draw_worm(s: float) -> void:
	draw_set_transform(Vector2.ZERO, _heading, Vector2(s, s))
	for i in range(6, 0, -1):
		var y := sin(_walk * 0.35 - float(i) * 0.9) * 4.0
		var rr := 6.0 - float(i) * 0.6
		draw_circle(Vector2(-float(i) * 5.0, y), rr, _c(Color(0.62, 0.1, 0.14).lerp(Color(0.32, 0.04, 0.08), float(i) / 6.0)))
	draw_circle(Vector2(3, 0), 6.0, _c(Color(0.78, 0.16, 0.2)))
	_poly([Vector2(8, -3), Vector2(13, 0), Vector2(8, 3)], Color(0.2, 0.02, 0.04))
	draw_circle(Vector2(4, -3), 1.4, Color(1.0, 0.9, 0.3))
	draw_circle(Vector2(4, 3), 1.4, Color(1.0, 0.9, 0.3))

# Rocky Mountain: Golem (a small golem is the same drawing, scaled down)
func _draw_golem(s: float) -> void:
	var sc := s * (0.6 if is_small else 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	var swing := sin(_walk * 1.5) * 5.0
	var rock := _c(Color(0.42, 0.38, 0.35))
	var dark := _c(Color(0.26, 0.23, 0.22))
	draw_circle(Vector2(6, 34), 28.0, Color(0, 0, 0, 0.22))
	draw_circle(Vector2(-22, 6 + swing), 13.0, dark)
	draw_circle(Vector2(22, 6 - swing), 13.0, dark)
	draw_circle(Vector2(-22, 6 + swing), 10.0, rock)
	draw_circle(Vector2(22, 6 - swing), 10.0, rock)
	draw_circle(Vector2(-10, 26), 10.0, dark)
	draw_circle(Vector2(10, 26), 10.0, dark)
	_poly([Vector2(-20, -12), Vector2(-12, -24), Vector2(12, -24), Vector2(20, -12), Vector2(22, 14), Vector2(10, 28), Vector2(-10, 28), Vector2(-22, 14)], rock)
	_poly([Vector2(-10, -24), Vector2(-6, -36), Vector2(6, -36), Vector2(10, -24)], dark)
	var glow := 0.7 + 0.3 * sin(_walk * 2.0)
	draw_line(Vector2(-12, -8), Vector2(-4, 4), Color(1.0, 0.5, 0.1, glow), 2.0)
	draw_line(Vector2(-4, 4), Vector2(-9, 16), Color(1.0, 0.5, 0.1, glow), 2.0)
	draw_line(Vector2(10, -6), Vector2(4, 8), Color(1.0, 0.5, 0.1, glow), 2.0)
	draw_circle(Vector2(-3, -30), 2.2, Color(1.0, 0.6, 0.15))
	draw_circle(Vector2(3, -30), 2.2, Color(1.0, 0.6, 0.15))

# Hell: Demon
func _draw_demon(s: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var flap := sin(_walk * 0.7) * 8.0
	var red := _c(Color(0.7, 0.1, 0.1))
	var dark := _c(Color(0.32, 0.04, 0.06))
	draw_circle(Vector2(0, 0), 46.0, Color(1.0, 0.4, 0.1, 0.12))
	draw_circle(Vector2(6, 36), 28.0, Color(0, 0, 0, 0.22))
	_poly([Vector2(-8, -10), Vector2(-46, -30 + flap), Vector2(-40, -4), Vector2(-30, 8), Vector2(-14, 10)], dark)
	_poly([Vector2(8, -10), Vector2(46, -30 + flap), Vector2(40, -4), Vector2(30, 8), Vector2(14, 10)], dark)
	draw_line(Vector2(-30, 28), Vector2(-14, 6), dark, 6.0)
	draw_line(Vector2(30, 28), Vector2(14, 6), dark, 6.0)
	_poly([Vector2(-16, -14), Vector2(-10, -22), Vector2(10, -22), Vector2(16, -14), Vector2(18, 14), Vector2(8, 30), Vector2(-8, 30), Vector2(-18, 14)], red)
	draw_circle(Vector2(0, -30), 13.0, red)
	_poly([Vector2(-11, -36), Vector2(-20, -54), Vector2(-5, -40)], _c(Color(0.95, 0.9, 0.8)))
	_poly([Vector2(11, -36), Vector2(20, -54), Vector2(5, -40)], _c(Color(0.95, 0.9, 0.8)))
	draw_circle(Vector2(-5, -31), 2.6, Color(1.0, 0.9, 0.2))
	draw_circle(Vector2(5, -31), 2.6, Color(1.0, 0.9, 0.2))
	draw_line(Vector2(-5, -24), Vector2(5, -24), Color(0.15, 0.0, 0.0), 2.0)
	var fl := 0.6 + 0.4 * sin(_walk * 1.3)
	_poly([Vector2(-6, 30), Vector2(0, 44 + 6.0 * fl), Vector2(6, 30)], Color(1.0, 0.55, 0.1, 0.9))

# Space: Hunter (members of a pack of 5)
func _draw_hunter(s: float) -> void:
	draw_set_transform(Vector2.ZERO, _heading, Vector2(s, s))
	_engine_flame(Vector2(-16, -5), 5.0)
	_engine_flame(Vector2(-16, 5), 5.0)
	_poly_sym([Vector2(8, -6), Vector2(-14, -18), Vector2(-18, -14), Vector2(-8, -4)], _c(Color(0.35, 0.1, 0.25)))
	_poly([Vector2(28, 0), Vector2(8, -8), Vector2(-16, -9), Vector2(-14, 0), Vector2(-16, 9), Vector2(8, 8)], _c(Color(0.62, 0.16, 0.38)))
	_poly([Vector2(28, 0), Vector2(14, -4), Vector2(14, 4)], _c(Color(0.9, 0.9, 0.95)))
	draw_line(Vector2(4, -17), Vector2(22, -17), _c(Color(0.12, 0.05, 0.1)), 2.5)
	draw_line(Vector2(4, 17), Vector2(22, 17), _c(Color(0.12, 0.05, 0.1)), 2.5)
	draw_circle(Vector2(6, 0), 3.0, _c(Color(1.0, 0.85, 0.3)))
