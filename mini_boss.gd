class_name MiniBoss
extends Enemy

# A rival castle. It copies the player's base stage, weapon and movement, with 70% of the
# health, but its damage is budgeted (see make_from and Power) so it can never one-shot the player. It hovers around the player, shoots straight shots at the place the
# player was when it fired (never guided), uses Overcharge, and its
# Laser Gun locks its target before it fires - so keep moving!
signal fire(origin: Vector2, aim: Vector2, dmg: float, style: String)
signal beam_fire(origin: Vector2, aim: Vector2, dmg: float)
signal announce(text: String, icon: String)

const HP_RATIO := 0.7               # health: 70% of the player's (then x HP_MULT)
const SPEED_RATIO := 0.9            # move speed: 10% slower than the player
const ATTACK_RATIO := 1.0           # attack speed: as fast as the player
const DAMAGE_RATIO := 1.0           # damage: the same as the player (still limited by the threat budget)
const HP_MULT := 30.0                # Rogue Castles are 30x tougher than the plain 70% copy (was 100x: too much)
const DMG_BOOST := 1.8               # ...but they hit harder: their budgeted damage is multiplied by this
const ATTACK_MAX := 2.5            # attack speed ceiling (stat points can push the player far higher)
const SCALE_MIN := 0.3             # damage multiplier floor
const BEAM_CHARGE := 0.7
const SALVO_EVERY := 7.0           # every few seconds it fires a spread of three shots
const SALVO_SPREAD := 0.16         # radians between the three shots
const STYLES := ["bullet", "bullet", "bullet", "rocket", "bullet", "void"]
const SPEEDS := [700.0, 560.0, 820.0, 380.0, 700.0, 520.0]

var tier: int = 0
var weapon_tier: int = 0
var energy: float = 100.0
var max_energy: float = 100.0
var energy_regen: float = 20.0
var weapon_scale: float = 1.0       # damage multiplier (budgeted, see make_from)
var attack_speed: float = 1.0
var barrier_time: float = 0.0
var boost_time: float = 0.0
var _barrier_cd: float = 0.0
var _boost_cd: float = 4.0
var _fire_cd: float = 1.0
var _salvo_cd: float = 4.0
var _flash_gun: float = 0.0
var _anim: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _orbit_angle: float = 0.0
var _orbit_dist: float = 600.0
var _orbit_timer: float = 0.0
var _beam_charge: float = 0.0
var _beam_aim: Vector2 = Vector2.ZERO
var boss_name: String = "Rogue Castle"
var _brain: Brain = null           # shared tactical AI (see brain.gd): positioning, dodging, predictive aim
var _pix: PixelCastle = null

# The size of its turret: its muzzle sits just outside the castle, like the player's.
func _gun_k() -> float:
	return clampf((radius + 14.0) / float(WeaponArt.TIP[weapon_tier]), 0.7, 1.8)

func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if PixelCastle.ENABLED:
		z_index = 1
		_pix = PixelCastle.new()
		add_child(_pix)

# Stats come from a THREAT BUDGET, not from copying the player's stat points (those compound
# and would make the rival one-shot the player). Health, speed and weapon tier follow the player;
# damage is damped (square root of the player's multiplier) and then limited so that, after the
# player's armor, one hit never exceeds a small share of the player's health and the sustained
# damage per second never kills the player faster than Power.dps_cap allows.
static func make_from(b: Base, level: int = 1, randomized: bool = false) -> MiniBoss:
	var m := MiniBoss.new()
	m.kind = "minicastle"
	m.tier = b.tier
	m.weapon_tier = b.weapon_tier
	m.armor = b.armor_points()
	m.armor_pen = float(Weapons.PEN[b.weapon_tier])
	m.max_hp = b.max_hp * HP_RATIO * HP_MULT
	m.hp = m.max_hp
	var wt := b.weapon_tier
	var cost: float = Weapons.ENERGY_COST[wt]
	var interval: float = Weapons.INTERVAL[wt]
	m.attack_speed = minf(b.attack_speed * ATTACK_RATIO, ATTACK_MAX)
	# only as much energy as it needs to keep firing at its own rate
	var need := cost * m.attack_speed / interval
	m.energy_regen = minf(b.energy_regen, need * 1.1)
	m.max_energy = minf(b.max_energy, cost * 20.0)
	m.energy = m.max_energy
	var scale := maxf(pow(maxf(b.damage_mult, 0.01), 0.5) * DAMAGE_RATIO, SCALE_MIN)
	# what actually reaches the player: armor and the rival's penetration, plus Overcharge
	var through := Power.armor_mult(b.armor_points(), m.armor_pen) * Base.BOOST_MULT
	var raw: float = Weapons.DAMAGE[wt]
	var shot_scale := Power.shot_cap(b.max_hp, level) / maxf(raw * through, 0.001)
	var dps_one := Power.castle_dps(wt, m.energy_regen, 1.0, 0, 1.5, m.attack_speed) * through
	var dps_scale := Power.dps_cap(b.max_hp, level) / maxf(dps_one, 0.001)
	m.weapon_scale = minf(scale, minf(shot_scale, dps_scale)) * DMG_BOOST
	m.speed = b.move_speed * b.move_mult * SPEED_RATIO
	m.radius = b.body_radius()
	m.damage = 3.0 * DAMAGE_RATIO
	if randomized:
		# Every rival is a little different, and never stronger than the budget above allows:
		# each factor only lowers its stat.
		m.max_hp *= randf_range(0.55, 1.0)
		m.hp = m.max_hp
		m.speed *= randf_range(0.7, 1.0)
		m.attack_speed *= randf_range(0.6, 1.0)
		m.weapon_scale *= randf_range(0.6, 1.0)
		m.energy_regen *= randf_range(0.8, 1.0)
		m.tier = clampi(b.tier - randi() % 2, 0, b.tier)
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
	_salvo_cd = maxf(_salvo_cd - delta, 0.0)
	_flash_gun = maxf(_flash_gun - delta, 0.0)
	boost_time = maxf(boost_time - delta, 0.0)
	barrier_time = maxf(barrier_time - delta, 0.0)
	_heading = (target - position).angle()
	_move(delta)
	_skills()
	_shoot(delta)
	if _pix != null:
		_pix.update_look(tier, radius, 0.55 + 0.45 * clampf(_flash / 0.12, 0.0, 1.0), _anim, sin(_anim * 1.5) * (3.0 + radius * 0.05), radius * 2.6)
	queue_redraw()

# Each Rogue Castle gets its own personality: cautious ones kite from afar, aggressive ones press in close.
func _brain_get() -> Brain:
	if _brain == null:
		var aggr := randf_range(0.2, 0.8)
		_brain = Brain.new(randf_range(0.55, 0.85), aggr, lerpf(540.0, 380.0, aggr), lerpf(780.0, 560.0, aggr))
	return _brain

# Holds a distance from the player, circles, sidesteps incoming shots and backs off when hurt (see brain.gd).
func _move(delta: float) -> void:
	var br := _brain_get()
	var far := position.distance_to(target) > br.lod_far
	_vel = br.tick(delta, position, target, hp / maxf(max_hp, 1.0), energy / maxf(max_energy, 1.0), speed, radius, far)
	position += _vel * delta

func _skills() -> void:
	if _boost_cd <= 0.0 and energy >= max_energy * 0.5 and position.distance_to(target) < 1100.0 and _brain_get().opening():
		boost_time = Base.BOOST_DURATION
		_boost_cd = Base.BOOST_COOLDOWN
		announce.emit(Loc.t("The Rogue Castle overcharges its weapon!"), "damage")

func _shoot(delta: float) -> void:
	var cost: float = Weapons.cost(weapon_tier)
	var dmg: float = Weapons.DAMAGE[weapon_tier] * weapon_scale * (Base.BOOST_MULT if boost_time > 0.0 else 1.0)
	var origin := position + WeaponArt.muzzle(weapon_tier, _heading, Vector2(0.0, sin(_anim * 1.5) * (3.0 + radius * 0.05) - radius * 0.03), _gun_k())
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
	_flash_gun = 0.07
	_fire_cd = Weapons.INTERVAL[weapon_tier] / attack_speed
	if weapon_tier == 4:
		_beam_charge = BEAM_CHARGE
		_beam_aim = _brain_get().lead(target, BEAM_CHARGE)
		Sfx.play("beam_charge", -8.0)
		return
	var aim := _brain_get().aim_point(origin, target, float(SPEEDS[weapon_tier]))      # leads a moving target; accuracy follows its skill
	Sfx.play(str(Weapons.SOUNDS[weapon_tier]), -9.0)
	if _salvo_cd <= 0.0:
		# a salvo: the same shot three times in a fan, so one dodge is not enough
		_salvo_cd = SALVO_EVERY * randf_range(0.8, 1.2)
		var base_dir := (aim - origin)
		for k in [-1, 0, 1]:
			fire.emit(origin, origin + base_dir.rotated(float(k) * SALVO_SPREAD), dmg * 0.7, str(STYLES[weapon_tier]))
		return
	fire.emit(origin, aim, dmg, str(STYLES[weapon_tier]))

func take_damage(amount: float, pen: float = 0.0) -> void:
	if dead:
		return
	var par := get_parent()
	if barrier_time > 0.0:
		Fx.spawn(par, "spark", position + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)), Color(0.4, 0.85, 1.0), "", 1.2, 0.3)
		Sfx.play("block", -4.0)
		return
	var dealt := amount * Weapons.armor_mult(armor, pen) * dmg_taken_mult
	Enemy.dealt_total += dealt
	var hp_before := hp
	hp -= dealt
	_brain_get().note_damage(dealt / maxf(max_hp, 1.0))
	var crit := _is_crit(dealt)
	_record_chunk(hp_before, crit)
	_flash = 0.12
	_bar_time = 4.0
	Fx.spawn(par, "spark", position + Vector2(randf_range(-radius, radius), randf_range(-radius, radius)), Color(1.0, 0.85, 0.3), "", 1.1, 0.35)
	if crit:
		_crit_effects(par, 2.0)
	Fx.spawn(par, "number", position + Vector2(randf_range(-20.0, 20.0), -radius), Color(1.0, 0.35, 0.12) if crit else Color.WHITE, str(int(ceil(dealt))) + ("!" if crit else ""), 1.9 if crit else 1.0, 1.0 if crit else 0.7)
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
		PixelFx.disc(self, Vector2(8.0, r * 2.6), r * 1.1, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2(0.0, bob), sin(_anim * 1.1 + 1.0) * 0.015, Vector2.ONE)
		BaseArt.draw_all(self, tier, r, _anim, 0.55 + 0.45 * clampf(_flash / 0.12, 0.0, 1.0))
	else:
		draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	var dir := Vector2.RIGHT.rotated(_heading)
	var col: Color = Weapons.COLORS[weapon_tier]
	var gk := _gun_k()
	var piv := Vector2(0.0, bob - r * 0.03)
	var tipp := -Vector2(0.0, bob) + WeaponArt.draw(self, weapon_tier, _heading, piv, _flash_gun > 0.0, _anim * 3.0, gk)
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	if _flash_gun > 0.0:
		var f := _flash_gun / 0.07
		PixelFx.disc(self, tipp + dir * 5.0 * gk, 12.0 * f * gk, Color(col.r, col.g, col.b, 0.85))
		PixelFx.disc(self, tipp + dir * 5.0 * gk, 6.0 * f * gk, Color(1.0, 1.0, 0.9, 0.95))
	if boost_time > 0.0:
		PixelFx.ring(self, Vector2.ZERO, r * 1.25, Color(1.0, 0.45, 0.15, 0.5), 4.0)
	if barrier_time > 0.0:
		PixelFx.ring(self, Vector2.ZERO, r * 1.75, Color(0.5, 0.95, 1.0, 0.8), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _beam_charge > 0.0:
		var k := 1.0 - _beam_charge / BEAM_CHARGE
		var to_aim := (_beam_aim - position).normalized() * 1700.0
		PixelFx.line(self, Vector2.ZERO, to_aim, Color(1.0, 0.2, 0.2, 0.15 + 0.5 * k), 1.5 + 4.0 * k)
	_draw_bar()

func _draw_bar() -> void:
	var w := maxf(300.0, radius * 2.6)
	var bh := 26.0
	var pos := Vector2(-w * 0.5, -radius * 1.9 - 36.0)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(pos, Vector2(w, bh)), Color(0.12, 0.0, 0.02, 0.85))
	draw_rect(Rect2(pos, Vector2(w * frac, bh)), Color(0.9, 0.2, 0.2))
	_draw_chunk(pos.x, pos.y, w, bh, 1.0)
	draw_rect(Rect2(pos, Vector2(w, bh)), Color(1.0, 0.7, 0.7), false, 2.0)
	_draw_armor_tag(pos + Vector2(-34.0, 5.0))
	# the name above the bar, shrunk until it fits the bar's width
	var title := "%s  (%d)" % [Loc.t(boss_name), int(power())]
	var tsz := 22
	while tsz > 10 and PixelUI.ui_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelUI.mfs(tsz)).x > w:
		tsz -= 1
	var tw := PixelUI.ui_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelUI.mfs(tsz)).x
	PixelUI.text(self, Vector2(pos.x + (w - tw) * 0.5, pos.y - 8.0), title, tsz, Color(1.0, 0.8, 0.8), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	# the health numbers inside the bar
	var nums := "%s / %s" % [_short_num(hp), _short_num(max_hp)]
	var nsz := 18
	var nw := PixelUI.ui_font().get_string_size(nums, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelUI.mfs(nsz)).x
	PixelUI.text(self, Vector2(pos.x + (w - nw) * 0.5, pos.y + bh - 6.0), nums, nsz, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)

# 1,234 -> 1.2K, 1,234,567 -> 1.2M
func _short_num(v: float) -> String:
	var n := maxf(v, 0.0)
	if n >= 1000000.0:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000.0:
		return "%dK" % int(n / 1000.0)
	if n >= 1000.0:
		return "%.1fK" % (n / 1000.0)
	return str(int(ceil(n)))
