class_name Base
extends Node2D

signal destroyed
signal damaged(amount: float)
signal critical(amount: float)
signal blocked
signal shield_broken
signal poisoned
signal burning(dps: float)
signal status(text: String, kind: String)

const TIER_NAMES := ["Hoverin Village", "High Town", "Flyin City", "Fortress of the Wind", "Capital", "Battlestation", "Juggernaut", "Dreadnaught", "Galactus", "Eye of End"]
const TIER_HP := [20, 40, 70, 110, 160, 230, 310, 400, 520, 650]
const TIER_COLORS := [
	Color(0.55, 0.40, 0.25),
	Color(0.65, 0.50, 0.30),
	Color(0.60, 0.60, 0.65),
	Color(0.45, 0.50, 0.60),
	Color(0.85, 0.70, 0.25),
	Color(0.45, 0.50, 0.60),
	Color(0.50, 0.35, 0.35),
	Color(0.35, 0.48, 0.50),
	Color(0.45, 0.20, 0.60),
	Color(0.55, 0.58, 0.62),
]
const MAX_AUTO := 12
# Auto-weapon slots on the island: each castle tier has a fixed number of them.
const AUTO_SLOTS := [2, 3, 4, 6, 8, 9, 10, 11, 12, 12]
const SLOT_ORDER := [90.0, 30.0, 150.0, 0.0, 180.0, 330.0, 210.0, 60.0, 120.0, 300.0, 240.0, 270.0]
const ISLAND_F := [0.68, 0.76, 0.85, 0.93, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
const RANGE_STEP := 40.0
const MAX_RANGE := 1000.0
const BARRIER_DURATION := 3.0
const BARRIER_COOLDOWN := 10.0
const SHIELD_BASE := 0.25          # Energy Shield capacity: 25% of max health, +1% per Energy Shield point
const SHIELD_DELAY := 4.0          # seconds without damage before it recharges
const SHIELD_RECHARGE := 0.2       # then it refills 20% of its capacity per second
const BOOST_DURATION := 5.0        # Overcharge skill: +30% weapon damage for 5 s
const BOOST_COOLDOWN := 15.0
const BOOST_MULT := 1.3
const REPAIR_COOLDOWN := 1.0       # Repair skill: costs gold, heals 50% of max health
const REPAIR_HEAL := 0.5

var tier: int = 0
var max_hp: float = 20.0
var hp: float = 20.0
var hp_bonus: int = 0
var xp_level: int = 1               # castle level (XP): every new level gives 5 stat points
var xp: int = 0                     # XP towards the next level
var free_points: int = 0            # unspent stat points (5 per level)
var stat_pts: Dictionary = {}       # points spent per stat id; each point = +1% over the default

var max_energy: float = 100.0
var energy: float = 100.0
var energy_regen: float = 20.0

# 0 Machinegun, 1 Cannon, 2 Rocket Launcher, 3 Laser Gun (see Weapons)
var weapon_tier: int = 0
var damage_mult: float = 1.0

const AUTO_INTERVAL_MIN := 0.9       # each auto-weapon fires at most about once per 0.9 s
const AUTO_RATE_CAP := 1.3
var auto_cannons: int = 0          # number of auto-weapons (built by Gunner allies)
var auto_interval: float = 1.5
var auto_range: float = 450.0
var laser: bool = false            # laser SIGHT (aim line), not the Laser Gun

var gunners: int = 0
var scientists: int = 0
var engineers: int = 0
var mechanics: int = 0

# Active skills: 4 slots, triggered with the skill keybinds (V, B, N, M by default).
var skill_slots: Array[String] = ["", "overcharge", "repair", ""]     # slot 1 (Barrier) is removed for now
var skill_cd: Array[float] = [0.0, 0.0, 0.0, 0.0]
var skill_cd_max: Array[float] = [BARRIER_COOLDOWN, BOOST_COOLDOWN, REPAIR_COOLDOWN, 1.0]
var barrier_time: float = 0.0       # the Barrier skill is switched off for now (kept so it can come back)
var shield: float = -1.0            # Energy Shield; -1 = fill up on the first frame
var _shield_idle: float = 0.0
var _sh_hit: float = 0.0           # 1 -> 0 after the shield absorbs a hit (ripple + flash)
var _sh_hit_ang: float = 0.0
var _sh_break: float = 0.0         # 1 -> 0 after the shield breaks (shatter ring)
var boost_time: float = 0.0
var move_speed: float = 280.0
var move_mult: float = 1.0          # Thrusters perk: +5% per reward pick
var attack_speed: float = 1.0       # Attack speed perk: +5% per pick (manual and auto weapons)
var poison_time: float = 0.0        # seconds of poison left
var poison_dps: float = 0.0
var _poison_acc: float = 0.0
var burn_time: float = 0.0          # seconds of burning left (Hell Lord fire and arrows)
var burn_dps: float = 0.0
var _burn_acc: float = 0.0
var slow_time: float = 0.0          # seconds the castle is slowed (Mud Colossus mud)
var slow_factor: float = 1.0
var _vel: Vector2 = Vector2.ZERO

var aim_angle: float = 0.0
var _fire_cd: float = 0.0
var _auto_timer: float = 0.0
var _heal_acc: float = 0.0
var _anim: float = 0.0
var _hurt: float = 0.0
var _muzzle: float = 0.0
var _pix: PixelCastle = null
const MAX_SHOTS := 400
var _zap_cd: float = 0.0
var _lvlfx: float = 0.0             # level-up effect timer
const LEVELUP_FX := 1.4

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if PixelCastle.ENABLED:
		z_index = 1                 # the pixel castle (z -1) lands on the normal layer; barrel and barrier draw above it
		_pix = PixelCastle.new()
		add_child(_pix)

func body_radius() -> float:
	return 42.0 + tier * 5.0

# Radius of the whole floating base (the hitbox and the size of every effect around the castle).
func hit_radius() -> float:
	if tier < CastleArt.TIERS:
		return 94.0 * float(ISLAND_F[tier]) * body_radius() / 48.0 * 0.92
	return body_radius()

# XP needed to go from this level to the next one.
static func xp_needed(lv: int) -> int:
	return 30 + 15 * lv + 2 * lv * lv

# Adds XP; returns how many levels were gained.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_needed(xp_level):
		xp -= xp_needed(xp_level)
		xp_level += 1
		free_points += 5
		gained += 1
	return gained

# Max health including the Max health stat points (+1% per point).
func hp_total() -> float:
	return float(TIER_HP[tier] + hp_bonus) * pow(1.01, float(int(stat_pts.get("health", 0))))

# Spends one stat point (each point = +1% over the default value).
func spend_point(id: String) -> bool:
	if free_points <= 0:
		return false
	match id:
		"damage":
			damage_mult *= 1.01          # every point is +1% of the CURRENT value (compounding)
		"attack":
			attack_speed *= 1.01
		"regen":
			energy_regen *= 1.01         # default 20 per second
		"energy":
			max_energy *= 1.01           # default 100
		"health":
			var old := max_hp
			stat_pts["health"] = int(stat_pts.get("health", 0)) + 1
			max_hp = hp_total()
			hp += max_hp - old
			free_points -= 1
			return true
		"speed":
			move_mult *= 1.01
		"autorate", "armor":
			pass
		"eshield":
			var old_cap := shield_cap()
			stat_pts["eshield"] = int(stat_pts.get("eshield", 0)) + 1
			shield += shield_cap() - old_cap
			free_points -= 1
			return true
		_:
			return false
	stat_pts[id] = int(stat_pts.get(id, 0)) + 1
	free_points -= 1
	return true

# Energy Shield capacity. Compounds like every other stat: +1% per point.
func shield_cap() -> float:
	return max_hp * SHIELD_BASE * pow(1.01, float(int(stat_pts.get("eshield", 0))))

# Takes back EVERY spent stat point (for wrong clicks) and returns how many were refunded.
func reset_stat_points() -> int:
	var total := 0
	for id in stat_pts.keys():
		total += int(stat_pts[id])
	if total <= 0:
		return 0
	damage_mult /= pow(1.01, float(int(stat_pts.get("damage", 0))))
	attack_speed /= pow(1.01, float(int(stat_pts.get("attack", 0))))
	energy_regen /= pow(1.01, float(int(stat_pts.get("regen", 0))))
	max_energy /= pow(1.01, float(int(stat_pts.get("energy", 0))))
	move_mult /= pow(1.01, float(int(stat_pts.get("speed", 0))))
	energy = minf(energy, max_energy)
	stat_pts.clear()
	max_hp = hp_total()
	hp = minf(hp, max_hp)
	free_points += total
	queue_redraw()
	return total

func auto_rate_factor() -> float:
	return minf(pow(1.01, float(int(stat_pts.get("autorate", 0)))), AUTO_RATE_CAP)      # capped so auto fire cannot snowball

func set_tier(new_tier: int) -> void:
	tier = new_tier
	max_hp = hp_total()
	hp = max_hp
	queue_redraw()

# Golden rings, sparkles and a glow around the castle when the player gains a level.
func play_level_up() -> void:
	_lvlfx = LEVELUP_FX

# While the Barrier is up, any ordinary mob that touches it is destroyed (bosses and Rogue
# Castles are too big and are only blocked). It counts as a kill, so it gives gold and XP.
func _barrier_zap(delta: float) -> void:
	_zap_cd = maxf(_zap_cd - delta, 0.0)
	var reach_r := hit_radius() * 1.3
	var killed := 0
	for e in Field.near(position, reach_r):
		if e.is_ally or e.dead or e.kind == "boss" or e.kind == "minicastle":
			continue
		if position.distance_to(e.position) <= reach_r + e.radius * 0.4:
			e.barrier_kill()
			killed += 1
	if killed > 0 and _zap_cd <= 0.0:
		_zap_cd = 0.08
		Sfx.play("kill", -6.0)

func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)

# Castle armor: 3 per castle stage plus 0.5 per Armor stat point.
func armor_points() -> float:
	return 3.0 * float(tier) + 0.5 * float(int(stat_pts.get("armor", 0)))

# pen = armor penetration of the attacker. Poison ignores armor.
func take_damage(amount: float, pen: float = 0.0) -> void:
	if hp <= 0.0:
		return
	var dealt := amount
	var absorbed := 0.0
	if not Weapons.is_true(pen):
		# armor first, then the Energy Shield; Void Gun hits (true damage) skip both
		dealt = amount * Weapons.armor_mult(armor_points(), pen)
		_shield_idle = 0.0
		if shield > 0.0:
			absorbed = minf(shield, dealt)
			shield -= absorbed
			dealt -= absorbed
			_sh_hit = 1.0
			_sh_hit_ang = randf() * TAU
			if shield <= 0.0:
				shield = 0.0
				_sh_break = 1.0
				shield_broken.emit()
	if dealt <= 0.0:
		if absorbed > 0.0:
			blocked.emit()
		return
	var was_crit := max_hp > 0.0 and dealt >= 0.25 * max_hp      # a single hit over 25% of max health
	hp = maxf(hp - dealt, 0.0)
	_hurt = 0.25
	damaged.emit(dealt)
	if was_crit:
		critical.emit(dealt)
	if hp <= 0.0:
		set_process(false)
		destroyed.emit()

# Poison (Petek Bomb clouds and bee stings): HP loss every second. It ignores armor and the Energy Shield.
func apply_poison(dps: float, seconds: float) -> void:
	if barrier_time > 0.0 or hp <= 0.0:
		blocked.emit()
		return
	poison_dps = maxf(poison_dps, dps)
	poison_time = maxf(poison_time, seconds)
	poisoned.emit()

# Burning (Hell Lord flames and Hell Arrows): HP loss every second for a few seconds. Ignores armor and the Energy Shield.
func apply_burn(dps: float, seconds: float) -> void:
	if barrier_time > 0.0 or hp <= 0.0:
		return
	var fresh := burn_time <= 0.0
	burn_dps = maxf(burn_dps, dps)
	burn_time = maxf(burn_time, seconds)
	if fresh:
		burning.emit(burn_dps)

# Slow (mud, ...): the castle moves slower for a while. Not applied while the Barrier is up.
func apply_slow(factor: float, seconds: float) -> void:
	if barrier_time > 0.0 or hp <= 0.0:
		return
	var fresh := slow_time <= 0.0
	slow_factor = minf(slow_factor if slow_time > 0.0 else 1.0, factor)
	slow_time = maxf(slow_time, seconds)
	if fresh:
		status.emit("Slowed!  Movement -%d%% for %d s" % [int((1.0 - factor) * 100.0), int(ceil(seconds))], "slow")

# A push from outside (a black hole pulls the castle in).
func shove(v: Vector2) -> void:
	position += v

func max_auto() -> int:
	return AUTO_SLOTS[clampi(tier, 0, AUTO_SLOTS.size() - 1)]

# Where weapon slot i sits relative to the castle position (on the rim of the island top).
func slot_pos(i: int, r: float) -> Vector2:
	var a := deg_to_rad(float(SLOT_ORDER[i]))
	if tier < CastleArt.TIERS:
		var s := r / 48.0
		var rx := 94.0 * float(ISLAND_F[tier]) * s * 0.84
		return Vector2(cos(a) * rx, 11.0 * s + sin(a) * rx * 0.72)
	return Vector2.RIGHT.rotated(a) * (r + 8.0)

# Each auto-cannon upgrade also extends the range of all auto-cannons.
func add_auto_cannon() -> bool:
	if auto_cannons >= max_auto():
		return false
	auto_cannons += 1
	auto_range = minf(auto_range + RANGE_STEP, MAX_RANGE)
	return true

func upgrade_auto_rate() -> void:
	auto_interval = maxf(auto_interval * 0.85, AUTO_INTERVAL_MIN)
	auto_range = minf(auto_range + RANGE_STEP, MAX_RANGE)

func upgrade_weapon() -> bool:
	if weapon_tier >= Weapons.MAX_TIER:
		return false
	weapon_tier += 1
	refunded_damage_pts = refund_damage_points()
	queue_redraw()
	return true

var refunded_damage_pts: int = 0     # points handed back by the last weapon upgrade (main shows a toast)

# A new weapon has a different base damage, so the Weapon damage points are given back to be re-spent.
func refund_damage_points() -> int:
	var pts := int(stat_pts.get("damage", 0))
	if pts <= 0:
		return 0
	damage_mult /= pow(1.01, float(pts))
	stat_pts["damage"] = 0
	free_points += pts
	return pts

# Gold price of one Repair use (grows with the castle stage).
func repair_cost() -> int:
	return 15 + tier * 5

func use_skill(slot: int) -> bool:
	if slot < 0 or slot >= skill_slots.size():
		return false
	var id := skill_slots[slot]
	if id == "" or skill_cd[slot] > 0.0:
		return false
	match id:
		"barrier":
			barrier_time = BARRIER_DURATION
			skill_cd[slot] = BARRIER_COOLDOWN
			skill_cd_max[slot] = BARRIER_COOLDOWN
			return true
		"overcharge":
			boost_time = BOOST_DURATION
			skill_cd[slot] = BOOST_COOLDOWN
			skill_cd_max[slot] = BOOST_COOLDOWN
			return true
	return false

# Total damage multiplier (upgrades, allies and the Overcharge skill).
func dmg_factor() -> float:
	return damage_mult * (BOOST_MULT if boost_time > 0.0 else 1.0)

func to_dict() -> Dictionary:
	return {
		"tier": tier,
		"hp": hp,
		"hp_bonus": hp_bonus,
		"free_points": free_points,
		"xp_level": xp_level,
		"xp": xp,
		"stat_pts": stat_pts.duplicate(),
		"max_energy": max_energy,
		"energy_regen": energy_regen,
		"damage_mult": damage_mult,
		"move_mult": move_mult,
		"attack_speed": attack_speed,
		"weapon_tier": weapon_tier,
		"auto_cannons": auto_cannons,
		"auto_interval": auto_interval,
		"auto_range": auto_range,
		"laser": laser,
		"gunners": gunners,
		"scientists": scientists,
		"engineers": engineers,
		"mechanics": mechanics,
		"skills": skill_slots.duplicate(),
	}

# A number from a save file: NaN, infinity and silly values fall back to a safe range.
static func _num(v: Variant, def: float, lo: float, hi: float) -> float:
	var x := float(v)
	if is_nan(x) or is_inf(x):
		return def
	return clampf(x, lo, hi)

func from_dict(d: Dictionary) -> void:
	tier = clampi(int(d.get("tier", 0)), 0, TIER_NAMES.size() - 1)
	hp_bonus = int(d.get("hp_bonus", 0))
	free_points = maxi(int(d.get("free_points", 0)), 0)
	xp_level = maxi(int(d.get("xp_level", 1)), 1)
	xp = maxi(int(d.get("xp", 0)), 0)
	stat_pts = {}
	var saved_pts := d.get("stat_pts", {}) as Dictionary
	for k in saved_pts:
		stat_pts[str(k)] = maxi(int(saved_pts[k]), 0)
	max_hp = hp_total()
	hp = minf(float(d.get("hp", max_hp)), max_hp)
	max_energy = _num(d.get("max_energy", 100.0), 100.0, 10.0, 1.0e9)
	energy = max_energy
	energy_regen = _num(d.get("energy_regen", 20.0), 20.0, 0.0, 1.0e9)
	damage_mult = _num(d.get("damage_mult", 1.0), 1.0, 0.1, 1.0e9)
	move_mult = _num(d.get("move_mult", 1.0), 1.0, 0.1, 1.0e6)
	attack_speed = _num(d.get("attack_speed", 1.0), 1.0, 0.1, 1.0e9)
	weapon_tier = clampi(int(d.get("weapon_tier", 0)), 0, Weapons.MAX_TIER)
	auto_cannons = int(d.get("auto_cannons", 0))
	auto_interval = _num(d.get("auto_interval", 1.5), 1.5, AUTO_INTERVAL_MIN, 100.0)
	auto_range = float(d.get("auto_range", 450.0))
	laser = bool(d.get("laser", false))
	gunners = int(d.get("gunners", 0))
	scientists = int(d.get("scientists", d.get("smiths", 0)))
	engineers = int(d.get("engineers", 0))
	mechanics = int(d.get("mechanics", d.get("medics", 0)))
	var saved: Array = d.get("skills", [])
	for i in skill_slots.size():
		if i < saved.size() and str(saved[i]) != "" and str(saved[i]) != "barrier":
			skill_slots[i] = str(saved[i])
	queue_redraw()

func _process(delta: float) -> void:
	_anim += delta
	_hurt = maxf(_hurt - delta, 0.0)
	_sh_hit = maxf(_sh_hit - delta * 3.0, 0.0)
	_sh_break = maxf(_sh_break - delta * 1.6, 0.0)
	_muzzle = maxf(_muzzle - delta, 0.0)
	_lvlfx = maxf(_lvlfx - delta, 0.0)
	energy = minf(energy + energy_regen * delta, max_energy)
	_fire_cd -= delta
	var cap := shield_cap()
	if shield < 0.0 or shield > cap:
		shield = cap if shield < 0.0 else minf(shield, cap)
	_shield_idle += delta
	if _shield_idle >= SHIELD_DELAY and shield < cap:
		shield = minf(shield + cap * SHIELD_RECHARGE * delta, cap)
	if poison_time > 0.0:
		poison_time = maxf(poison_time - delta, 0.0)
		_poison_acc += delta
		if _poison_acc >= 1.0:
			_poison_acc -= 1.0
			if barrier_time <= 0.0:
				hp = maxf(hp - poison_dps, 0.0)
				_hurt = 0.15
				damaged.emit(poison_dps)
				if hp <= 0.0:
					set_process(false)
					destroyed.emit()
					return
		if poison_time <= 0.0:
			poison_dps = 0.0
			_poison_acc = 0.0
	if slow_time > 0.0:
		slow_time = maxf(slow_time - delta, 0.0)
		if slow_time <= 0.0:
			slow_factor = 1.0
	if burn_time > 0.0:
		burn_time = maxf(burn_time - delta, 0.0)
		_burn_acc += delta
		if _burn_acc >= 1.0:
			_burn_acc -= 1.0
			if barrier_time <= 0.0:
				hp = maxf(hp - burn_dps, 0.0)
				_hurt = 0.15
				damaged.emit(burn_dps)
				if hp <= 0.0:
					set_process(false)
					destroyed.emit()
					return
		if burn_time <= 0.0:
			burn_dps = 0.0
			_burn_acc = 0.0
	aim_angle = (get_global_mouse_position() - global_position).angle()
	_move(delta)

	for i in skill_cd.size():
		skill_cd[i] = maxf(skill_cd[i] - delta, 0.0)
	if boost_time > 0.0:
		boost_time = maxf(boost_time - delta, 0.0)
	if barrier_time > 0.0:
		_barrier_zap(delta)
		barrier_time -= delta
		if barrier_time <= 0.0:
			barrier_time = 0.0
			Sfx.play("barrier_end")

	# Manual weapon: hold left mouse button, costs energy
	var cost: float = Weapons.ENERGY_COST[weapon_tier]
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_cd <= 0.0 and energy >= cost:
		energy -= cost
		_fire_cd = Weapons.INTERVAL[weapon_tier] / attack_speed
		var dmg: float = Weapons.DAMAGE[weapon_tier]
		var angle := aim_angle
		if weapon_tier == 0:
			angle += randf_range(-0.045, 0.045)   # automatic rifle spread
		elif weapon_tier == 2:
			angle += randf_range(-0.03, 0.03)     # gatling spread
		_fire(angle, dmg * dmg_factor(), false)
		_muzzle = 0.07

	# Auto-weapons: share one timer, so shots are evenly spread out.
	# They use the manual weapon tier, up to the Gatling Gun.
	if auto_cannons > 0:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			var target := _nearest_enemy()
			if target != null:
				var adm: float = Weapons.AUTO_DAMAGE[mini(weapon_tier, Weapons.AUTO_MAX_TIER)]
				_fire((target.global_position - global_position).angle(), adm * dmg_factor(), true)
				_auto_timer = auto_interval / auto_cannons / attack_speed / auto_rate_factor()

	# Mechanics: slow repairs
	if mechanics > 0 and hp < max_hp:
		_heal_acc += mechanics * 0.5 * delta
		if _heal_acc >= 1.0:
			_heal_acc -= 1.0
			heal(1.0)

	if _pix != null:
		var pr := body_radius()
		_pix.update_look(tier, pr, clampf(_hurt / 0.25, 0.0, 1.0), _anim, sin(_anim * 1.5) * (3.0 + pr * 0.05), pr * 3.0)
	queue_redraw()

# The castle can be flown around the map with the move keys (WASD by default).
func _move(delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	_vel = _vel.lerp(dir * move_speed * move_mult * (slow_factor if slow_time > 0.0 else 1.0), 1.0 - exp(-7.0 * delta))
	if _vel.length() < 1.0 and dir == Vector2.ZERO:
		_vel = Vector2.ZERO
		return
	position += _vel * delta      # the camera follows, so the castle stays centered and the world scrolls

func _fire(angle: float, dmg: float, is_auto: bool) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var muzzle := position + dir * (hit_radius() * 0.6 + 14.0)
	var wt: int = mini(weapon_tier, Weapons.AUTO_MAX_TIER) if is_auto else weapon_tier
	var sound: String = Weapons.SOUNDS[wt]
	Sfx.play(sound, -6.0 if is_auto else 0.0)
	if wt == 4:
		_fire_beam(muzzle, dir, dmg)
		return
	if Field.shots().size() >= MAX_SHOTS:       # safety cap: never flood the scene with projectiles
		return
	var p := Projectile.new()
	p.position = muzzle
	match wt:
		0:
			p.kind = "bullet"
			p.velocity = dir * 1500.0
			p.life = 1.4
		1:
			p.kind = "bullet"
			p.velocity = dir * 1750.0
			p.life = 1.25
		2:
			p.kind = "bullet"                # Gatling Gun: the fastest bullets of all
			p.velocity = dir * 2300.0
			p.life = 1.0
		3:
			p.kind = "rocket"
			p.velocity = dir * 640.0
			p.life = 2.5
			p.splash = 110.0
		5:
			p.kind = "void"
			p.velocity = dir * 1520.0      # 2x faster than before
			p.life = 1.2                   # same range as before (about 1820)
			p.splash = Weapons.VOID_SPLASH
		_:
			p.kind = "shell"
			p.velocity = dir * 850.0
			p.life = 2.0
	p.damage = dmg
	p.pen = float(Weapons.PEN[wt])
	get_parent().add_child(p)

# Laser Gun: an instant beam that pierces everything on its line.
func _fire_beam(origin: Vector2, dir: Vector2, dmg: float) -> void:
	var length := 1700.0
	Enemy.hit_sound = "laser_hit"       # softer hit sound while the beam damages mobs
	for e in Field.mobs():
		if e.dead:
			continue
		var rel := e.position - origin
		var along := rel.dot(dir)
		if along < -e.radius or along > length:
			continue
		if absf(rel.cross(dir)) <= e.radius + 4.0:
			e.take_damage(dmg, float(Weapons.PEN[4]))
	Enemy.hit_sound = "hit"
	for b in Field.bolts():
		if b.is_queued_for_deletion():
			continue
		var rel_b := b.position - origin
		if rel_b.dot(dir) > 0.0 and absf(rel_b.cross(dir)) <= 18.0:
			Fx.spawn(get_parent(), "spark", b.position, Color(0.5, 1.0, 1.0), "", 1.1, 0.35)
			b.queue_free()
	var fx := BeamFx.new()
	fx.start = origin
	fx.finish = origin + dir * length
	get_parent().add_child(fx)

func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_dist := auto_range
	for e in Field.enemies():
		if e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d <= best_dist:
			best = e
			best_dist = d
	return best

# Where the laser sight ends: at the first enemy or ally on the aim line.
func _laser_length() -> float:
	var dir := Vector2.RIGHT.rotated(aim_angle)
	var best := 1400.0
	for e in Field.mobs():
		if e.dead:
			continue
		var rel := e.global_position - global_position
		var along := rel.dot(dir)
		if along <= 0.0 or along > best:
			continue
		var off := absf(rel.cross(dir))
		if off <= e.radius:
			best = along - sqrt(maxf(e.radius * e.radius - off * off, 0.0))
	return best

func _draw() -> void:
	var rb := body_radius()
	var r := hit_radius()
	var tint := clampf(_hurt / 0.25, 0.0, 1.0)
	# gentle PlayStation-style hover: slow bob plus a tiny sway
	var bob := sin(_anim * 1.5) * (3.0 + rb * 0.05)
	var tilt := sin(_anim * 1.1 + 1.0) * 0.015
	var drop := rb * 3.0
	if _pix == null:
		# the shadow stays on the ground and shrinks as the castle rises
		draw_set_transform(Vector2(6.0, drop), 0.0, Vector2(1.0, 0.28))
		PixelFx.disc(self, Vector2.ZERO, rb * 1.2 * (1.0 - bob / (rb * 6.0)), Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_set_transform(Vector2(0.0, bob), tilt, Vector2.ONE)
		BaseArt.draw_all(self, tier, rb, _anim, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	if boost_time > 0.0:
		var flick := 0.5 + 0.5 * sin(_anim * 14.0)
		PixelFx.ring(self, Vector2.ZERO, r * 1.25, Color(1.0, 0.6, 0.15, 0.35 + 0.3 * flick), 4.0)
		PixelFx.arc(self, Vector2.ZERO, r * 1.4, _anim * 3.0, _anim * 3.0 + 4.0, Color(1.0, 0.85, 0.3, 0.7), 3.0)
	if auto_cannons > 0:
		PixelFx.ring(self, Vector2.ZERO, auto_range, Color(1, 1, 1, 0.12), 2.0)
	var sr := maxf(6.0, rb * 0.13)
	for i in max_auto():
		var sp := slot_pos(i, rb)
		PixelFx.disc(self, sp + Vector2(0.0, 2.0), sr + 2.0, Color(0.07, 0.04, 0.02, 0.8))
		PixelFx.disc(self, sp, sr, Color(0.36, 0.22, 0.09))
		if i < auto_cannons:
			PixelFx.disc(self, sp, sr - 2.0, Color(0.72, 0.5, 0.18))
			PixelFx.disc(self, sp, sr * 0.55, Weapons.COLORS[weapon_tier])
		else:
			PixelFx.disc(self, sp, sr - 2.0, Color(0.13, 0.08, 0.04))
			PixelFx.ring(self, sp, sr, Color(0.72, 0.5, 0.18, 0.7), 1.5)
	var dir := Vector2.RIGHT.rotated(aim_angle)
	if laser:
		var laser_start := dir * (r + 20.0)
		var laser_end := dir * _laser_length()
		PixelFx.line(self, laser_start, laser_end, Color(1.0, 0.1, 0.1, 0.18), 7.0)
		PixelFx.line(self, laser_start, laser_end, Color(1.0, 0.25, 0.25, 0.8), 1.8)
		PixelFx.disc(self, laser_end, 4.0, Color(1.0, 0.35, 0.35, 0.9))
	_draw_barrel(dir, r)
	_draw_energy_shield(r)
	if barrier_time > 0.0:
		var blink := 1.0
		if barrier_time < 1.0:
			blink = 0.5 + 0.5 * sin(_anim * 24.0)
		var pulse := 0.5 + 0.5 * sin(_anim * 8.0)
		PixelFx.disc(self, Vector2.ZERO, r * 1.75, Color(0.3, 0.8, 1.0, (0.16 + 0.08 * pulse) * blink))
		PixelFx.ring(self, Vector2.ZERO, r * 1.75, Color(0.5, 0.95, 1.0, 0.9 * blink), 4.0)
	if _lvlfx > 0.0:
		var k := 1.0 - _lvlfx / LEVELUP_FX
		PixelFx.disc(self, Vector2.ZERO, r * 1.3, Color(1.0, 0.9, 0.4, 0.2 * (1.0 - k)))
		for ring in 2:
			var kk := clampf(k - 0.18 * float(ring), 0.0, 1.0)
			PixelFx.ring(self, Vector2.ZERO, r * (1.1 + 2.6 * kk), Color(1.0, 0.85, 0.3, 0.85 * (1.0 - kk)), 6.0 * (1.0 - kk) + 1.0)
		for i in 14:
			var a := TAU * float(i) / 14.0 + k * 1.6
			var d := r * (1.0 + 1.7 * k)
			PixelFx.disc(self, Vector2.RIGHT.rotated(a) * d - Vector2(0.0, k * 60.0), 4.0 * (1.0 - k) + 1.0, Color(1.0, 0.95, 0.55, 0.95 * (1.0 - k)))
	if burn_time > 0.0:
		# flames licking up off the castle
		PixelFx.disc(self, Vector2.ZERO, r * 1.1, Color(1.0, 0.35, 0.05, 0.14))
		for i in 9:
			var ph := fmod(_anim * 1.7 + float(i) * 0.23, 1.0)
			var fx := sin(float(i) * 2.7 + _anim * 3.0) * r * 0.85
			var col := Color(1.0, 0.85, 0.3, 0.85 * (1.0 - ph)).lerp(Color(0.9, 0.15, 0.05, 0.7 * (1.0 - ph)), ph)
			PixelFx.disc(self, Vector2(fx, r * 0.5 - ph * r * 1.7), 3.0 + 6.0 * (1.0 - ph), col)
	if poison_time > 0.0:
		# green poison bubbles rising off the castle
		PixelFx.disc(self, Vector2.ZERO, r * 1.1, Color(0.4, 0.9, 0.2, 0.12))
		for i in 6:
			var ph := fmod(_anim * 0.9 + float(i) * 0.37, 1.0)
			var bx := sin(float(i) * 2.1 + _anim) * r * 0.8
			PixelFx.disc(self, Vector2(bx, r * 0.4 - ph * r * 1.5), 3.0 + 3.0 * (1.0 - ph), Color(0.55, 1.0, 0.3, 0.7 * (1.0 - ph)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# The manual weapon changes its look with the weapon tier.
func _draw_barrel(dir: Vector2, r: float) -> void:
	var tip := dir * (r + 22.0)
	var col: Color = Weapons.COLORS[weapon_tier]
	PixelFx.line(self, Vector2.ZERO, tip, Color(0.05, 0.05, 0.08, 0.8), 13.0)
	PixelFx.disc(self, Vector2.ZERO, 10.0, Color(0.05, 0.05, 0.08, 0.8))
	match weapon_tier:
		0:
			var side := dir.orthogonal() * 3.5
			PixelFx.line(self, side, tip + side, Color(0.45, 0.46, 0.5), 4.5)
			PixelFx.line(self, -side, tip - side, Color(0.45, 0.46, 0.5), 4.5)
			PixelFx.disc(self, Vector2.ZERO, 8.0, Color(0.3, 0.3, 0.34))
		1:
			PixelFx.line(self, Vector2.ZERO, tip, Color.DIM_GRAY, 9.0)
			PixelFx.line(self, dir * 10.0, dir * (r + 12.0), Color(0.3, 0.3, 0.34), 13.0)
			PixelFx.disc(self, tip, 5.0, Color(0.15, 0.15, 0.18))
		2:
			# Gatling: three barrels that turn around each other, held by two rings
			var side2 := dir.orthogonal()
			for k in 3:
				var off := side2 * sin(_anim * 14.0 + TAU * float(k) / 3.0) * 5.0
				PixelFx.line(self, off, tip + off, Color(0.5, 0.5, 0.55), 4.0)
			PixelFx.line(self, dir * (r * 0.6), dir * (r * 0.6 + 4.0), Color(0.2, 0.2, 0.24), 17.0)
			PixelFx.line(self, dir * (r + 10.0), dir * (r + 14.0), Color(0.2, 0.2, 0.24), 17.0)
			PixelFx.disc(self, Vector2.ZERO, 9.0, Color(0.3, 0.3, 0.34))
		3:
			PixelFx.line(self, Vector2.ZERO, dir * (r + 28.0), Color(0.35, 0.42, 0.3), 15.0)
			PixelFx.line(self, dir * (r + 22.0), dir * (r + 29.0), Color(0.75, 0.3, 0.2), 16.0)
		5:
			PixelFx.line(self, Vector2.ZERO, tip, Color(0.16, 0.1, 0.26), 10.0)
			PixelFx.line(self, Vector2.ZERO, tip, Color(0.4, 0.2, 0.65), 3.0)
			PixelFx.disc(self, tip, 7.0, Color(0.04, 0.0, 0.1))
			PixelFx.disc(self, tip, 12.0, Color(0.5, 0.15, 0.9, 0.3))
			PixelFx.arc(self, tip, 9.0, _anim * 6.0, _anim * 6.0 + 4.0, Color(0.8, 0.55, 1.0, 0.9), 2.0)
		4:
			PixelFx.line(self, Vector2.ZERO, tip, Color(0.32, 0.36, 0.5), 8.0)
			PixelFx.disc(self, tip, 6.0, Color(0.5, 0.95, 1.0, 0.9))
			PixelFx.disc(self, tip, 10.0, Color(0.3, 0.9, 1.0, 0.25))
	if _muzzle > 0.0:
		PixelFx.disc(self, tip + dir * 6.0, 10.0 * (_muzzle / 0.07), Color(col.r, col.g, col.b, 0.9))


# ---------- Energy Shield: a glowing, slowly turning glass globe ----------
# Drawn as a sphere seen from slightly above: a rim that glows brighter at the edge (fresnel), a
# turning wireframe of meridians and latitudes (only the front half), a specular highlight, a
# ripple where it was hit, a flicker when it is nearly gone and a shatter ring when it breaks.

const SHIELD_TILT := 0.45

func _draw_energy_shield(r: float) -> void:
	var cap := shield_cap()
	var sf := clampf(shield / cap, 0.0, 1.0) if cap > 0.0 else 0.0
	var R := r * 1.5
	if _sh_break > 0.0:
		var k := 1.0 - _sh_break
		PixelFx.ring(self, Vector2.ZERO, R * (1.0 + 0.7 * k), Color(1.0, 0.6, 0.3, 0.8 * _sh_break), 5.0 * _sh_break + 1.0)
		PixelFx.ring(self, Vector2.ZERO, R * (1.0 + 0.35 * k), Color(1.0, 0.95, 0.7, 0.6 * _sh_break), 2.0)
		for i in 12:
			var a := TAU * float(i) / 12.0 + 0.3
			var d0 := R * (0.9 + 0.5 * k)
			PixelFx.line(self, Vector2.RIGHT.rotated(a) * d0, Vector2.RIGHT.rotated(a) * (d0 + R * 0.25 * _sh_break), Color(1.0, 0.8, 0.5, _sh_break), 2.5)
	if shield <= 0.5:
		return
	var low := sf < 0.25
	var base_col := Color(0.3, 0.8, 1.0).lerp(Color(1.0, 0.6, 0.25), 1.0 - clampf(sf * 4.0, 0.0, 1.0))
	var rim_col := base_col.lightened(0.45)
	var flick := 1.0
	if low:
		flick = 0.55 + 0.45 * sin(_anim * 22.0)
	var pulse := 0.5 + 0.5 * sin(_anim * 2.6)
	var glow := 0.35 + 0.65 * sf
	var hit := _sh_hit
	# body: glassy fill, denser towards the edge
	for i in 6:
		var f := float(i) / 5.0
		PixelFx.disc(self, Vector2.ZERO, R * (0.45 + 0.55 * f), Color(base_col.r, base_col.g, base_col.b, (0.015 + 0.03 * f * f) * glow * flick))
	PixelFx.disc(self, Vector2.ZERO, R, Color(base_col.r, base_col.g, base_col.b, (0.05 + 0.18 * hit) * flick))
	# turning wireframe (front half only, faded towards the sides)
	var rot := _anim * 0.5
	var wire_a := (0.28 + 0.2 * pulse + 0.4 * hit) * glow * flick
	for m in 8:
		var lon := rot + PI * float(m) / 8.0 * 2.0
		_shield_line(R, lon, -1.0, true, rim_col, wire_a)
	for lat_i in 5:
		var lat := (float(lat_i) - 2.0) * 0.5
		_shield_line(R, 0.0, lat, false, rim_col, wire_a * 0.8)
	# rim: soft outer halo, bright edge, thin inner edge
	PixelFx.ring(self, Vector2.ZERO, R * 1.04, Color(base_col.r, base_col.g, base_col.b, (0.12 + 0.12 * pulse + 0.3 * hit) * glow * flick), 7.0)
	PixelFx.ring(self, Vector2.ZERO, R, Color(rim_col.r, rim_col.g, rim_col.b, (0.55 + 0.35 * sf + 0.2 * hit) * flick), 2.5 + 1.5 * sf)
	PixelFx.ring(self, Vector2.ZERO, R * 0.93, Color(rim_col.r, rim_col.g, rim_col.b, 0.14 * flick), 1.5)
	# recharging: a bright spot travels around the rim
	if _shield_idle >= SHIELD_DELAY and sf < 0.999:
		var sa := _anim * 3.0
		PixelFx.arc(self, Vector2.ZERO, R, sa, sa + 0.7, Color(1.0, 1.0, 1.0, 0.8), 4.0)
	# specular highlights (top left)
	var hl := Vector2(-0.42, -0.5) * R
	PixelFx.disc(self, hl, R * 0.17, Color(1.0, 1.0, 1.0, 0.07 * flick))
	PixelFx.disc(self, hl, R * 0.10, Color(1.0, 1.0, 1.0, 0.10 * flick))
	PixelFx.arc(self, Vector2.ZERO, R * 0.86, PI * 1.12, PI * 1.38, Color(1.0, 1.0, 1.0, 0.45 * flick), 3.0)
	# ripple where the last hit landed
	if hit > 0.0:
		var hp_pos := Vector2.RIGHT.rotated(_sh_hit_ang) * R
		var k2 := 1.0 - hit
		PixelFx.disc(self, hp_pos, R * 0.22 * (0.5 + k2), Color(1.0, 1.0, 1.0, 0.45 * hit))
		PixelFx.ring(self, hp_pos, R * (0.12 + 0.55 * k2), Color(rim_col.r, rim_col.g, rim_col.b, 0.9 * hit), 3.0 * hit + 1.0)
		PixelFx.arc(self, Vector2.ZERO, R, _sh_hit_ang - 0.7, _sh_hit_ang + 0.7, Color(1.0, 1.0, 1.0, 0.9 * hit), 5.0)

# One line of the globe: a meridian (lon) or a latitude (lat), drawn only where it faces us.
func _shield_line(R: float, lon: float, lat: float, meridian: bool, col: Color, alpha: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var steps := 20 if meridian else 32
	var ct := cos(SHIELD_TILT)
	var st := sin(SHIELD_TILT)
	for i in steps + 1:
		var u := float(i) / float(steps)
		var phi := lat
		var lam := lon
		if meridian:
			phi = -PI * 0.5 + PI * u
		else:
			lam = TAU * u
		var x := cos(phi) * sin(lam)
		var y0 := sin(phi)
		var z0 := cos(phi) * cos(lam)
		var y := -(y0 * ct - z0 * st)       # tilt the globe towards the viewer
		var z := y0 * st + z0 * ct
		if z > 0.0:
			pts.append(Vector2(x, y) * R)
			cols.append(Color(col.r, col.g, col.b, alpha * (0.25 + 0.75 * z)))
		else:
			if pts.size() > 1:
				PixelFx.polyline_colors(self, pts, cols)
			pts = PackedVector2Array()
			cols = PackedColorArray()
	if pts.size() > 1:
		PixelFx.polyline_colors(self, pts, cols)
