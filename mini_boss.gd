class_name MiniBoss
extends Enemy

# A rival castle. It copies the player's base stage, weapon, energy, skills and
# movement, but has 30% less POWER (see Power): 70% of the health and 70% of the
# damage. It hovers around the player, shoots straight shots at the place the
# player was when it fired (never guided), uses Barrier and Overcharge, and its
# Laser Gun locks its target before it fires - so keep moving!
signal fire(origin: Vector2, aim: Vector2, dmg: float, style: String)
signal beam_fire(origin: Vector2, aim: Vector2, dmg: float)
signal announce(text: String, icon: String)

const POWER_RATIO := 0.7
const HP_MULT := 10.0                # Rogue Castles are 10x tougher than the plain 70% copy
const BEAM_CHARGE := 0.7
const STYLES := ["bullet", "shell", "rocket", "bullet"]
const SPEEDS := [700.0, 340.0, 380.0, 700.0]

var tier: int = 0
var weapon_tier: int = 0
var energy: float = 100.0
var max_energy: float = 100.0
var energy_regen: float = 20.0
var weapon_scale: float = 1.0       # damage multiplier (player's x 0.7)
var attack_speed: float = 1.0
var barrier_time: float = 0.0
var boost_time: float = 0.0
var _barrier_cd: float = 0.0
var _boost_cd: float = 6.0
var _fire_cd: float = 1.5
var _anim: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _orbit_angle: float = 0.0
var _orbit_dist: float = 600.0
var _orbit_timer: float = 0.0
var _beam_charge: float = 0.0
var _beam_aim: Vector2 = Vector2.ZERO
var boss_name: String = "Rogue Castle"
var _pix: PixelCastle = null

func _ready() -> void:
	super._ready()
	if PixelCastle.ENABLED:
		z_index = 1
		_pix = PixelCastle.new()
		add_child(_pix)

static func make_from(b: Base) -> MiniBoss:
	var m := MiniBoss.new()
	m.kind = "minicastle"
	m.tier = b.tier
	m.weapon_tier = b.weapon_tier
	m.max_hp = b.max_hp * POWER_RATIO * HP_MULT
	m.hp = m.max_hp
	m.max_energy = b.max_energy
	m.energy = b.max_energy
	m.energy_regen = b.energy_regen
	m.attack_speed = b.attack_speed
	m.weapon_scale = b.damage_mult * POWER_RATIO
	m.speed = b.move_speed * b.move_mult
	m.radius = b.body_radius()
	m.damage = 3.0 * POWER_RATIO
	m.shoots = true
	m.power_mult = 1.0
	return m

# The same formula as the player's PowerScore, using this castle's own stats.
func power() -> float:
	var dps := Power.castle_dps(weapon_tier, energy_regen, weapon_scale, 0, 1.5, attack_speed)
	return Power.score(Power.castle_ehp(max_hp), dps)

func _process(delta: float) -> void:
	_tick_common(delta)
	_anim += delta
	energy = minf(energy + energy_regen * delta, max_energy)
	_barrier_cd = maxf(_barrier_cd - delta, 0.0)
	_boost_cd = maxf(_boost_cd - delta, 0.0)
	boost_time = maxf(boost_time - delta, 0.0)
	barrier_time = maxf(barrier_time - delta, 0.0)
	_heading = (target - position).angle()
	_move(delta)
	_skills()
	_shoot(delta)
	if _pix != null:
		_pix.update_look(tier, radius, 0.55 + 0.45 * clampf(_flash / 0.12, 0.0, 1.0), _anim, sin(_anim * 1.5) * (3.0 + radius * 0.05), radius * 2.6)
	queue_redraw()

# Hovers around the player at a distance, changing its spot now and then.
func _move(delta: float) -> void:
	_orbit_timer -= delta
	if _orbit_timer <= 0.0:
		_orbit_timer = randf_range(2.5, 4.5)
		_orbit_angle = randf() * TAU
		_orbit_dist = randf_range(520.0, 780.0)
	var spot := target + Vector2.RIGHT.rotated(_orbit_angle) * _orbit_dist
	var to_spot := spot - position
	var want := to_spot.normalized() * minf(speed, to_spot.length() * 2.0)
	_vel = _vel.lerp(want, 1.0 - exp(-4.0 * delta))
	position += _vel * delta

func _skills() -> void:
	if _barrier_cd <= 0.0 and barrier_time <= 0.0:
		var in_danger := hp < max_hp * 0.6 and _incoming_shot() != null
		if in_danger or hp < max_hp * 0.25:
			barrier_time = Base.BARRIER_DURATION
			_barrier_cd = Base.BARRIER_COOLDOWN
			Sfx.play("barrier", -6.0)
	if _boost_cd <= 0.0 and energy >= max_energy * 0.5 and position.distance_to(target) < 1100.0:
		boost_time = Base.BOOST_DURATION
		_boost_cd = Base.BOOST_COOLDOWN
		announce.emit(Loc.t("The Rogue Castle overcharges its weapon!"), "damage")

func _shoot(delta: float) -> void:
	var cost: float = Weapons.ENERGY_COST[weapon_tier]
	var dmg: float = Weapons.DAMAGE[weapon_tier] * weapon_scale * (Base.BOOST_MULT if boost_time > 0.0 else 1.0)
	var origin := position + Vector2.RIGHT.rotated(_heading) * (radius + 14.0)
	if _beam_charge > 0.0:
		# Laser Gun: the aim point was locked when the shot was ready.
		_beam_charge -= delta
		if _beam_charge <= 0.0:
			_beam_charge = 0.0
			Sfx.play("laser", -4.0)
			beam_fire.emit(origin, _beam_aim, dmg)
		return
	_fire_cd -= delta
	if _fire_cd > 0.0 or energy < cost or position.distance_to(target) > 1150.0:
		return
	energy -= cost
	_fire_cd = Weapons.INTERVAL[weapon_tier] / attack_speed
	if weapon_tier == 3:
		_beam_charge = BEAM_CHARGE
		_beam_aim = target
		Sfx.play("beam_charge", -8.0)
		return
	var aim := target
	if weapon_tier == 0:
		aim += Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
	Sfx.play(str(Weapons.SOUNDS[weapon_tier]), -9.0)
	fire.emit(origin, aim, dmg, str(STYLES[weapon_tier]))

func take_damage(amount: float) -> void:
	if dead:
		return
	var par := get_parent()
	if barrier_time > 0.0:
		Fx.spawn(par, "spark", position + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)), Color(0.4, 0.85, 1.0), "", 1.2, 0.3)
		Sfx.play("block", -4.0)
		return
	var dealt := amount * dmg_taken_mult
	hp -= dealt
	_flash = 0.12
	_bar_time = 4.0
	Fx.spawn(par, "spark", position + Vector2(randf_range(-radius, radius), randf_range(-radius, radius)), Color(1.0, 0.85, 0.3), "", 1.1, 0.35)
	Fx.spawn(par, "number", position + Vector2(randf_range(-20.0, 20.0), -radius), Color.WHITE, str(int(ceil(dealt))), 1.0, 0.7)
	Sfx.play("boss_hit", -4.0)
	if hp <= 0.0:
		dead = true
		Fx.spawn(par, "explosion", position, Color.WHITE, "", 2.4, 1.0)
		Sfx.play("boss_die")
		died.emit(self)
		queue_free()

func _draw() -> void:
	var r := radius
	var bob := sin(_anim * 1.5) * (3.0 + r * 0.05)
	if _pix == null:
		draw_circle(Vector2(8.0, r * 2.6), r * 1.1, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2(0.0, bob), sin(_anim * 1.1 + 1.0) * 0.015, Vector2.ONE)
		BaseArt.draw_all(self, tier, r, _anim, 0.55 + 0.45 * clampf(_flash / 0.12, 0.0, 1.0))
	else:
		draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	var dir := Vector2.RIGHT.rotated(_heading)
	var col: Color = Weapons.COLORS[weapon_tier]
	draw_line(Vector2.ZERO, dir * (r + 14.0), Color(0.05, 0.05, 0.08, 0.8), 13.0)
	draw_line(Vector2.ZERO, dir * (r + 12.0), col, 8.0)
	if boost_time > 0.0:
		draw_arc(Vector2.ZERO, r * 1.25, 0.0, TAU, 48, Color(1.0, 0.45, 0.15, 0.5), 4.0)
	if barrier_time > 0.0:
		draw_arc(Vector2.ZERO, r * 1.75, 0.0, TAU, 64, Color(0.5, 0.95, 1.0, 0.8), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _beam_charge > 0.0:
		var k := 1.0 - _beam_charge / BEAM_CHARGE
		var to_aim := (_beam_aim - position).normalized() * 1700.0
		draw_line(Vector2.ZERO, to_aim, Color(1.0, 0.2, 0.2, 0.15 + 0.5 * k), 1.5 + 4.0 * k)
	_draw_bar()

func _draw_bar() -> void:
	var w := maxf(220.0, radius * 2.4)
	var pos := Vector2(-w * 0.5, -radius * 1.9 - 30.0)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(pos, Vector2(w, 18.0)), Color(0.12, 0.0, 0.02, 0.85))
	draw_rect(Rect2(pos, Vector2(w * frac, 18.0)), Color(0.9, 0.2, 0.2))
	draw_rect(Rect2(pos, Vector2(w, 18.0)), Color(1.0, 0.7, 0.7), false, 2.0)
	var font := ThemeDB.fallback_font
	var title := "%s  (%d)" % [boss_name, int(power())]
	draw_string_outline(font, pos + Vector2(0, -6), title, HORIZONTAL_ALIGNMENT_CENTER, w, 16, 4, Color.BLACK)
	draw_string(font, pos + Vector2(0, -6), title, HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(1.0, 0.8, 0.8))
