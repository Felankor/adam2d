class_name Base
extends Node2D

signal destroyed
signal damaged(amount: float)
signal blocked
signal poisoned

const TIER_NAMES := ["Hoverin Village", "High Town", "Flyin City", "Fortress of the Wind", "Capital", "Battlestation", "Juggernaut", "Dreadnaught", "Galactus", "Death Star"]
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
const RANGE_STEP := 40.0
const MAX_RANGE := 1000.0
const BARRIER_DURATION := 3.0
const BARRIER_COOLDOWN := 10.0
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

var auto_cannons: int = 0          # number of auto-weapons (built by Gunner allies)
var auto_interval: float = 1.5
var auto_range: float = 450.0
var laser: bool = false            # laser SIGHT (aim line), not the Laser Gun

var gunners: int = 0
var scientists: int = 0
var engineers: int = 0
var mechanics: int = 0

# Active skills: 4 slots, triggered with the skill keybinds (V, B, N, M by default).
var skill_slots: Array[String] = ["barrier", "overcharge", "repair", ""]
var skill_cd: Array[float] = [0.0, 0.0, 0.0, 0.0]
var skill_cd_max: Array[float] = [BARRIER_COOLDOWN, BOOST_COOLDOWN, REPAIR_COOLDOWN, 1.0]
var barrier_time: float = 0.0
var boost_time: float = 0.0
var move_speed: float = 280.0
var move_mult: float = 1.0          # Thrusters perk: +5% per reward pick
var attack_speed: float = 1.0       # Attack speed perk: +5% per pick (manual and auto weapons)
var poison_time: float = 0.0        # seconds of poison left
var poison_dps: float = 0.0
var _poison_acc: float = 0.0
var _vel: Vector2 = Vector2.ZERO

var aim_angle: float = 0.0
var _fire_cd: float = 0.0
var _auto_timer: float = 0.0
var _heal_acc: float = 0.0
var _anim: float = 0.0
var _hurt: float = 0.0
var _muzzle: float = 0.0
var _pix: PixelCastle = null
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
	return float(TIER_HP[tier] + hp_bonus) * (1.0 + 0.01 * float(int(stat_pts.get("health", 0))))

# Spends one stat point (each point = +1% over the default value).
func spend_point(id: String) -> bool:
	if free_points <= 0:
		return false
	match id:
		"damage":
			damage_mult += 0.01
		"attack":
			attack_speed += 0.01
		"regen":
			energy_regen += 0.2          # default 20 per second
		"energy":
			max_energy += 1.0            # default 100
		"health":
			var old := max_hp
			stat_pts["health"] = int(stat_pts.get("health", 0)) + 1
			max_hp = hp_total()
			hp += max_hp - old
			free_points -= 1
			return true
		"speed":
			move_mult += 0.01
		"autorate", "armor":
			pass
		_:
			return false
	stat_pts[id] = int(stat_pts.get(id, 0)) + 1
	free_points -= 1
	return true

func auto_rate_factor() -> float:
	return 1.0 + 0.01 * float(int(stat_pts.get("autorate", 0)))

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
	var reach_r := body_radius() * 1.75
	var killed := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead or e.kind == "boss" or e.kind == "minicastle":
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
	if barrier_time > 0.0:
		blocked.emit()
		return
	var dealt := amount * Weapons.armor_mult(armor_points(), pen)
	hp = maxf(hp - dealt, 0.0)
	_hurt = 0.25
	damaged.emit(dealt)
	if hp <= 0.0:
		set_process(false)
		destroyed.emit()

# Poison (Petek Bomb clouds and bee stings): HP loss every second. The Barrier blocks it.
func apply_poison(dps: float, seconds: float) -> void:
	if barrier_time > 0.0 or hp <= 0.0:
		blocked.emit()
		return
	poison_dps = maxf(poison_dps, dps)
	poison_time = maxf(poison_time, seconds)
	poisoned.emit()

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

func upgrade_weapon() -> bool:
	if weapon_tier >= Weapons.MAX_TIER:
		return false
	weapon_tier += 1
	queue_redraw()
	return true

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

func from_dict(d: Dictionary) -> void:
	tier = clampi(int(d.get("tier", 0)), 0, TIER_NAMES.size() - 1)
	hp_bonus = int(d.get("hp_bonus", 0))
	free_points = int(d.get("free_points", 0))
	xp_level = maxi(int(d.get("xp_level", 1)), 1)
	xp = int(d.get("xp", 0))
	stat_pts = (d.get("stat_pts", {}) as Dictionary).duplicate()
	max_hp = hp_total()
	hp = minf(float(d.get("hp", max_hp)), max_hp)
	max_energy = float(d.get("max_energy", 100.0))
	energy = max_energy
	energy_regen = float(d.get("energy_regen", 20.0))
	damage_mult = float(d.get("damage_mult", 1.0))
	move_mult = float(d.get("move_mult", 1.0))
	attack_speed = float(d.get("attack_speed", 1.0))
	weapon_tier = clampi(int(d.get("weapon_tier", 1)), 0, Weapons.MAX_TIER)
	auto_cannons = int(d.get("auto_cannons", 0))
	auto_interval = float(d.get("auto_interval", 1.5))
	auto_range = float(d.get("auto_range", 450.0))
	laser = bool(d.get("laser", false))
	gunners = int(d.get("gunners", 0))
	scientists = int(d.get("scientists", d.get("smiths", 0)))
	engineers = int(d.get("engineers", 0))
	mechanics = int(d.get("mechanics", d.get("medics", 0)))
	var saved: Array = d.get("skills", [])
	for i in skill_slots.size():
		if i < saved.size() and str(saved[i]) != "":
			skill_slots[i] = str(saved[i])
	queue_redraw()

func _process(delta: float) -> void:
	_anim += delta
	_hurt = maxf(_hurt - delta, 0.0)
	_muzzle = maxf(_muzzle - delta, 0.0)
	_lvlfx = maxf(_lvlfx - delta, 0.0)
	energy = minf(energy + energy_regen * delta, max_energy)
	_fire_cd -= delta
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
			angle += randf_range(-0.045, 0.045)   # machinegun spread
		_fire(angle, dmg * dmg_factor(), false)
		_muzzle = 0.07

	# Auto-weapons: share one timer, so shots are evenly spread out.
	# They use the same weapon tier as the manual weapon.
	if auto_cannons > 0:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			var target := _nearest_enemy()
			if target != null:
				var adm: float = Weapons.AUTO_DAMAGE[weapon_tier]
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
		_pix.update_look(tier, pr, clampf(_hurt / 0.25, 0.0, 1.0), _anim, sin(_anim * 1.5) * (3.0 + pr * 0.05), pr * 3.0 if tier <= 4 else pr * 1.7)
	queue_redraw()

# The castle can be flown around the map with the move keys (WASD by default).
func _move(delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	_vel = _vel.lerp(dir * move_speed * move_mult, 1.0 - exp(-7.0 * delta))
	if _vel.length() < 1.0 and dir == Vector2.ZERO:
		_vel = Vector2.ZERO
		return
	position += _vel * delta      # the camera follows, so the castle stays centered and the world scrolls

func _fire(angle: float, dmg: float, is_auto: bool) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var muzzle := position + dir * (body_radius() + 14.0)
	var sound: String = Weapons.SOUNDS[weapon_tier]
	Sfx.play(sound, -6.0 if is_auto else 0.0)
	if weapon_tier == 3:
		_fire_beam(muzzle, dir, dmg)
		return
	var p := Projectile.new()
	p.position = muzzle
	match weapon_tier:
		0:
			p.kind = "bullet"
			p.velocity = dir * 1500.0
			p.life = 1.4
		2:
			p.kind = "rocket"
			p.velocity = dir * 640.0
			p.life = 2.5
			p.splash = 110.0
		4:
			p.kind = "void"
			p.velocity = dir * 760.0
			p.life = 2.4
			p.splash = Weapons.VOID_SPLASH
		_:
			p.kind = "shell"
			p.velocity = dir * 850.0
			p.life = 2.0
	p.damage = dmg
	p.pen = float(Weapons.PEN[weapon_tier])
	get_parent().add_child(p)

# Laser Gun: an instant beam that pierces everything on its line.
func _fire_beam(origin: Vector2, dir: Vector2, dmg: float) -> void:
	var length := 1700.0
	Enemy.hit_sound = "laser_hit"       # softer hit sound while the beam damages mobs
	for node in get_tree().get_nodes_in_group("mobs"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		var rel := e.position - origin
		var along := rel.dot(dir)
		if along < -e.radius or along > length:
			continue
		if absf(rel.cross(dir)) <= e.radius + 4.0:
			e.take_damage(dmg, float(Weapons.PEN[weapon_tier]))
	Enemy.hit_sound = "hit"
	for node in get_tree().get_nodes_in_group("bolts"):
		var b := node as Node2D
		if b == null:
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
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead:
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
	for node in get_tree().get_nodes_in_group("mobs"):
		var e := node as Enemy
		if e == null or e.dead:
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
	var r := body_radius()
	var tint := clampf(_hurt / 0.25, 0.0, 1.0)
	# gentle PlayStation-style hover: slow bob plus a tiny sway
	var bob := sin(_anim * 1.5) * (3.0 + r * 0.05)
	var tilt := sin(_anim * 1.1 + 1.0) * 0.015
	var drop := r * 3.0 if tier <= 4 else r * 1.7
	if _pix == null:
		# the shadow stays on the ground and shrinks as the castle rises
		draw_set_transform(Vector2(6.0, drop), 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, r * 1.2 * (1.0 - bob / (r * 6.0)), Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_set_transform(Vector2(0.0, bob), tilt, Vector2.ONE)
		BaseArt.draw_all(self, tier, r, _anim, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	if boost_time > 0.0:
		var flick := 0.5 + 0.5 * sin(_anim * 14.0)
		draw_arc(Vector2.ZERO, r * 1.25, 0.0, TAU, 48, Color(1.0, 0.6, 0.15, 0.35 + 0.3 * flick), 4.0)
		draw_arc(Vector2.ZERO, r * 1.4, _anim * 3.0, _anim * 3.0 + 4.0, 24, Color(1.0, 0.85, 0.3, 0.7), 3.0)
	if auto_cannons > 0:
		draw_arc(Vector2.ZERO, auto_range, 0.0, TAU, 96, Color(1, 1, 1, 0.12), 2.0)
		var auto_col: Color = Weapons.COLORS[weapon_tier]
		for i in auto_cannons:
			var a := TAU * i / auto_cannons
			draw_circle(Vector2.RIGHT.rotated(a) * (r + 8.0), 7.0, auto_col)
	var dir := Vector2.RIGHT.rotated(aim_angle)
	if laser:
		var laser_start := dir * (r + 20.0)
		var laser_end := dir * _laser_length()
		draw_line(laser_start, laser_end, Color(1.0, 0.1, 0.1, 0.18), 7.0)
		draw_line(laser_start, laser_end, Color(1.0, 0.25, 0.25, 0.8), 1.8)
		draw_circle(laser_end, 4.0, Color(1.0, 0.35, 0.35, 0.9))
	_draw_barrel(dir, r)
	if barrier_time > 0.0:
		var blink := 1.0
		if barrier_time < 1.0:
			blink = 0.5 + 0.5 * sin(_anim * 24.0)
		var pulse := 0.5 + 0.5 * sin(_anim * 8.0)
		draw_circle(Vector2.ZERO, r * 1.75, Color(0.3, 0.8, 1.0, (0.16 + 0.08 * pulse) * blink))
		draw_arc(Vector2.ZERO, r * 1.75, 0.0, TAU, 64, Color(0.5, 0.95, 1.0, 0.9 * blink), 4.0)
	if _lvlfx > 0.0:
		var k := 1.0 - _lvlfx / LEVELUP_FX
		draw_circle(Vector2.ZERO, r * 1.3, Color(1.0, 0.9, 0.4, 0.2 * (1.0 - k)))
		for ring in 2:
			var kk := clampf(k - 0.18 * float(ring), 0.0, 1.0)
			draw_arc(Vector2.ZERO, r * (1.1 + 2.6 * kk), 0.0, TAU, 64, Color(1.0, 0.85, 0.3, 0.85 * (1.0 - kk)), 6.0 * (1.0 - kk) + 1.0)
		for i in 14:
			var a := TAU * float(i) / 14.0 + k * 1.6
			var d := r * (1.0 + 1.7 * k)
			draw_circle(Vector2.RIGHT.rotated(a) * d - Vector2(0.0, k * 60.0), 4.0 * (1.0 - k) + 1.0, Color(1.0, 0.95, 0.55, 0.95 * (1.0 - k)))
	if poison_time > 0.0:
		# green poison bubbles rising off the castle
		draw_circle(Vector2.ZERO, r * 1.1, Color(0.4, 0.9, 0.2, 0.12))
		for i in 6:
			var ph := fmod(_anim * 0.9 + float(i) * 0.37, 1.0)
			var bx := sin(float(i) * 2.1 + _anim) * r * 0.8
			draw_circle(Vector2(bx, r * 0.4 - ph * r * 1.5), 3.0 + 3.0 * (1.0 - ph), Color(0.55, 1.0, 0.3, 0.7 * (1.0 - ph)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# The manual weapon changes its look with the weapon tier.
func _draw_barrel(dir: Vector2, r: float) -> void:
	var tip := dir * (r + 22.0)
	var col: Color = Weapons.COLORS[weapon_tier]
	draw_line(Vector2.ZERO, tip, Color(0.05, 0.05, 0.08, 0.8), 13.0)
	draw_circle(Vector2.ZERO, 10.0, Color(0.05, 0.05, 0.08, 0.8))
	match weapon_tier:
		0:
			var side := dir.orthogonal() * 3.5
			draw_line(side, tip + side, Color(0.45, 0.46, 0.5), 4.5)
			draw_line(-side, tip - side, Color(0.45, 0.46, 0.5), 4.5)
			draw_circle(Vector2.ZERO, 8.0, Color(0.3, 0.3, 0.34))
		1:
			draw_line(Vector2.ZERO, tip, Color.DIM_GRAY, 9.0)
		2:
			draw_line(Vector2.ZERO, dir * (r + 28.0), Color(0.35, 0.42, 0.3), 15.0)
			draw_line(dir * (r + 22.0), dir * (r + 29.0), Color(0.75, 0.3, 0.2), 16.0)
		4:
			draw_line(Vector2.ZERO, tip, Color(0.16, 0.1, 0.26), 10.0)
			draw_line(Vector2.ZERO, tip, Color(0.4, 0.2, 0.65), 3.0)
			draw_circle(tip, 7.0, Color(0.04, 0.0, 0.1))
			draw_circle(tip, 12.0, Color(0.5, 0.15, 0.9, 0.3))
			draw_arc(tip, 9.0, _anim * 6.0, _anim * 6.0 + 4.0, 12, Color(0.8, 0.55, 1.0, 0.9), 2.0)
		3:
			draw_line(Vector2.ZERO, tip, Color(0.32, 0.36, 0.5), 8.0)
			draw_circle(tip, 6.0, Color(0.5, 0.95, 1.0, 0.9))
			draw_circle(tip, 10.0, Color(0.3, 0.9, 1.0, 0.25))
	if _muzzle > 0.0:
		draw_circle(tip + dir * 6.0, 10.0 * (_muzzle / 0.07), Color(col.r, col.g, col.b, 0.9))
