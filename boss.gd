class_name Boss
extends Enemy

# One boss per biome, each with its own special ability:
#   Garden Warden   - "speed"  very high speed
#   Mud Colossus    - "regen"  fast health regeneration + takes 25% less damage
#   Stone Titan     - "titan"  3 phases, grows +50% (hp, speed, power, size) after each
#   Hell Lord       - "hell"   summons 15 soldiers every 4 s
#   Void Overlord   - "void"   splits into two lesser copies every 10 s; if they live
#                              for 5 s it fires an uncancellable energy beam (Space biome)
# All other bosses summon 5 soldiers every 5 s and lob energy orbs at the base.

signal summon(pos: Vector2, count: int)
signal summon_lesser(pos: Vector2, hp: float, dmg: float, spd: float)
signal bolt(origin: Vector2, dmg: float)
signal beam(dmg: float, origin: Vector2, aim: Vector2)
signal void_fire(origin: Vector2, aim: Vector2, dmg: float)
signal summon_bees(pos: Vector2, count: int)
signal bomb(origin: Vector2, dest: Vector2)
signal announce(text: String, icon: String)
signal breath(origin: Vector2, angle: float, reach: float, half: float, dmg: float)
signal hell_arrow(origin: Vector2, aim: Vector2, dmg: float)
signal raged
signal hazard(style: String, pos: Vector2, radius: float, delay: float, dmg: float, opts: Dictionary)

const ABILITIES := ["speed", "regen", "titan", "hell", "void"]
const BEAM_CHARGE_TIME := 1.6
const BEAM_FLASH_TIME := 0.5
const BIOME_STEP := 10               # levels per biome (Mud Colossus is 10 levels before the Stone Titan)

var ability: String = "speed"
var biome_idx: int = 0
var boss_name: String = "Boss"
var phase: int = 1
var regen_rate: float = 0.0          # fraction of max health regained per second

var _phase_hp: float = 0.0
var _grow: float = 1.0
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _summon_timer: float = 4.0
var _summon_interval: float = 5.0
var _summon_count: int = 5
var _bolt_timer: float = 4.0
var _lesser_hp: float = 50.0
var _lesser_timer: float = 5.0
var _check_timer: float = -1.0
var _beam_charge: float = 0.0
var _beam_flash: float = 0.0
var _beam_aim: Vector2 = Vector2.ZERO     # locked when the beam starts charging
var _bolt_interval: float = 4.0
var _attack_timer: float = 6.0
var _next_attack: String = "fire"
var _burst_left: int = 0
var _burst_cd: float = 0.0
var _bomb_timer: float = 3.0
var _t: float = 0.0
var _spr_back: Sprite2D = null       # Garden Warden: the ring of leaves, spins on its own
var _spr_body: Sprite2D = null
var _ov: Node2D = null               # drawn on top of the sprites (eyes, glows, bar, beam)
var _bart: Dictionary = {}
# Hell Lord: fire breath, Hell Arrows and ENRAGE
const SIZE_K := 2.0                  # every boss is twice its old size (later biomes a bit more)
const ENRAGE_HP := 0.3
const BREATH_HALF := 0.4             # half-angle of the flame cone, radians
var enraged: bool = false
# ---- extra ability kits (Mud Colossus, Stone Titan, Void Overlord) ----
const KITS := {
	"regen": ["geysers", "barrage", "quake"],
	"titan": ["meteors", "spikes", "hurl"],
	"void": ["singularity", "blink", "orbs"],
}
var _kit_cd: float = 6.0
var _kit_last: String = ""
var _wind: String = ""               # an attack winding up ("quake", "blink")
var _wind_t: float = 0.0
var _wind_max: float = 1.0
var _q_kind: String = ""             # a queued series of projectiles
var _q_left: int = 0
var _q_cd: float = 0.0
var _q_gap: float = 0.3
var _q_spread: float = 90.0
var _q_dmg: float = 1.0
var _hell_mode: String = ""          # "", "charge", "breath", "volley"
var _hell_next: String = "breath"
var _hell_cd: float = 3.0
var _hell_t: float = 0.0
var _breath_angle: float = 0.0
var _breath_tick: float = 0.0
var _volley_left: int = 0
var _volley_cd: float = 0.0

static func make_boss(lvl: int, biome: int) -> Boss:
	var b := Boss.new()
	b.kind = "boss"
	b.biome_idx = biome
	var ab: String = ABILITIES[biome]
	b.ability = ab
	var base_hp := (250.0 + 90.0 * lvl) * 2.0 * 10.0 * GameState.hp_mult()      # bosses have 20x the original health
	b.hp = base_hp
	b.speed = (80.0 + biome * 8.0) * GameState.speed_mult()
	b.damage = 2.5 * (1.0 + 0.25 * float(lvl - 1))
	b.reward = (40 + lvl * 6) * 10          # 10x gold
	b.radius = 56.0 * SIZE_K * (1.0 + 0.12 * float(maxi(biome - 1, 0)))     # tier 3 and later bosses are bigger still
	b.armor = 15.0 + 10.0 * float(biome)      # 15 / 25 / 35 / 45 / 55 armor
	b.armor_pen = 20.0
	b.dodge_chance = 0.65
	b.dodge_cd_time = 1.4
	b.dodge_dash = 520.0
	b._summon_interval = 5.0
	b._summon_count = 5
	b._summon_timer = 4.0
	b._bolt_interval = 4.0 / GameState.speed_mult()
	b._bolt_timer = b._bolt_interval
	match ab:
		"speed":
			# Garden Warden: twice as fast as before, bee swarms, Petek Bombs and a machine-gun-like orb stream
			b.hp = base_hp * 0.9
			b.speed *= 4.8
			b.dodge_dash = 720.0
			b._summon_interval = 3.0
			b._summon_count = 10
			b._summon_timer = 2.0
			b._bolt_interval = 0.4 / GameState.speed_mult()       # 10x the default ranged attack speed
			b._bolt_timer = b._bolt_interval
			b._bomb_timer = 3.0
		"regen":
			b.regen_rate = 0.015
			b.dmg_taken_mult = 0.75
			b.speed *= 0.9
		"titan":
			# starts tougher than the Mud Colossus (the boss 10 levels earlier)
			var mud_hp := (250.0 + 90.0 * float(maxi(lvl - BIOME_STEP, 1))) * 2.0 * 10.0 * GameState.hp_mult()
			b._phase_hp = maxf(base_hp * 0.4, mud_hp * 1.1)
			b.hp = b._phase_hp
		"void":
			b._lesser_hp = base_hp * 0.06
			b._lesser_timer = 5.0
		"hell":
			b.hp = base_hp * 1.1
			b.speed = 300.0 * GameState.speed_mult()      # very fast
			b._summon_interval = 0.8                      # attacks 5x as often
			b._summon_count = 15
			b._summon_timer = 0.8
			b._bolt_interval = 0.8 / GameState.speed_mult()
			b._bolt_timer = b._bolt_interval
	match ab:
		"speed":
			b.power_mult = 2.0
		"regen", "titan":
			b.power_mult = 1.5
		_:
			b.power_mult = 3.0
	b.max_hp = b.hp
	return b

func _ready() -> void:
	super._ready()
	_make_boss_sprites()

func _make_boss_sprites() -> void:
	_bart = MobArt.frames(MobArt.boss_key(ability), 0)
	if ability == "speed":
		_spr_back = _new_layer(MobArt.frames("b_leaves"))
	_spr_body = _new_layer(_bart)
	_ov = Node2D.new()
	_ov.draw.connect(_draw_over)
	add_child(_ov)
	_update_boss_sprites()

func _new_layer(art: Dictionary) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.texture = (art["tex"] as Array)[0]
	sp.set_meta("art", art)
	add_child(sp)
	return sp

func _layer_tex(sp: Sprite2D, idx: int) -> void:
	var art: Dictionary = sp.get_meta("art")
	var n: int = art["n"]
	sp.texture = (art["flash" if _flash > 0.0 else "tex"] as Array)[idx % n]
	sp.offset = art["off"]

func _update_boss_sprites() -> void:
	if _spr_body == null:
		return
	var k := radius / MobArt.BOSS_R * (1.0 + _scale_pop * 2.0)
	var idx := 0
	if ability == "hell":
		idx = int(fposmod(_t * 5.0, TAU) / TAU * 4.0)
	elif ability == "void":
		idx = 1 if _beam_charge > 0.0 else 0           # the iris turns red while the beam charges
	if _spr_back != null:
		_layer_tex(_spr_back, int(floorf(_t * 1.8 * 100.0 / TAU)) % 10)      # the ring of leaves spins
		_spr_back.scale = Vector2(k, k)
	_spr_body.set_meta("art", MobArt.frames(MobArt.boss_key(ability), MobArt.dir_of(_heading)))
	_layer_tex(_spr_body, idx)
	_spr_body.scale = Vector2(k, k)
	_spr_body.modulate = Color(1.0, 0.55 + 0.25 * sin(_t * 9.0), 0.5) if enraged else Color.WHITE      # enraged: pulsing red
	_ov.queue_redraw()

func _pick_wander() -> void:
	var a := randf() * TAU
	_wander_target = target + Vector2.RIGHT.rotated(a) * randf_range(330.0, 560.0)
	_wander_timer = randf_range(1.5, 3.0)

func _process(delta: float) -> void:
	_tick_common(delta)
	_t += delta
	_update_boss_sprites()
	_wander_timer -= delta
	if _wander_timer <= 0.0 or position.distance_to(_wander_target) < 30.0:
		_pick_wander()
	var vel := (_wander_target - position).normalized() * _move_speed()
	_heading = vel.angle()
	vel += _update_dodge(delta)      # bosses sidestep shots that fly straight at them
	if _wind != "":
		vel *= 0.15
	if _hell_mode == "charge" or _hell_mode == "breath":
		vel *= 0.3                   # the Hell Lord plants itself while it breathes fire
	position += vel * delta

	if regen_rate > 0.0 and hp < max_hp:
		hp = minf(hp + max_hp * regen_rate * delta, max_hp)

	if ability == "hell":
		_process_hell(delta)
	if KITS.has(ability):
		_kit_tick(delta)
	if ability == "void":
		_process_void(delta)
	else:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = _summon_interval
			if ability == "speed":
				summon_bees.emit(position, _summon_count)       # the Garden Warden calls bees, not soldiers
			else:
				summon.emit(position, _summon_count)
			Sfx.play("boss_summon", -4.0)
		if ability == "speed":
			_bomb_timer -= delta
			if _bomb_timer <= 0.0:
				_bomb_timer = 5.0
				for i in 2:
					var off := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 230.0)
					bomb.emit(position, target + off)
				announce.emit(Loc.t("Petek Bombs incoming!  Fly out of the ring!"), "skull")
				Sfx.play("boss_warn", -2.0)
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt_timer = _bolt_interval
			bolt.emit(position, damage)
			Sfx.play("bolt")
	queue_redraw()

# ---------- Mud Colossus / Stone Titan / Void Overlord extra attacks ----------

func _kit_tick(delta: float) -> void:
	if _wind != "":
		_wind_t -= delta
		if _wind_t <= 0.0:
			var w := _wind
			_wind = ""
			_kit_fire(w)
	if _q_left > 0:
		_q_cd -= delta
		if _q_cd <= 0.0:
			_q_cd = _q_gap
			_q_left -= 1
			var aim := target + Vector2(randf_range(-_q_spread, _q_spread), randf_range(-_q_spread, _q_spread))
			launch.emit(_q_kind, position, aim, damage * _q_dmg)
			Sfx.play("bolt", -4.0)
	_kit_cd -= delta
	if _kit_cd > 0.0 or _wind != "" or _q_left > 0 or _beam_charge > 0.0:
		return
	var names: Array = KITS[ability]
	var pick: String = names[randi() % names.size()]
	if pick == _kit_last:
		pick = names[(names.find(pick) + 1) % names.size()]
	_kit_last = pick
	_kit_cd = (6.0 if ability == "regen" else (7.0 - 0.7 * float(phase) if ability == "titan" else 8.0)) * randf_range(0.85, 1.15)
	_kit_start(pick)

func _haz(style: String, pos: Vector2, rad: float, delay: float, dmg: float, opts: Dictionary = {}) -> void:
	hazard.emit(style, pos, rad, delay, dmg, opts)

func _around_base(minr: float, maxr: float) -> Vector2:
	return target + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(minr, maxr)

func _kit_start(pick: String) -> void:
	Sfx.play("boss_warn", -2.0)
	match pick:
		"geysers":
			announce.emit(Loc.t("Mud Geysers!  Keep moving!"), "skull")
			_haz("mud", target, 95.0, 1.4, damage * 1.4, {"linger": 3.5, "slow_factor": 0.55, "slow_time": 3.0})
			for i in 5:
				_haz("mud", _around_base(70.0, 280.0), 95.0, 1.4 + 0.15 * i, damage * 1.4, {"linger": 3.5, "slow_factor": 0.55, "slow_time": 3.0})
		"barrage":
			announce.emit(Loc.t("Boulder Barrage!  Shoot the boulders down!"), "skull")
			_q_kind = "boulder"
			_q_left = 6
			_q_cd = 0.4
			_q_gap = 0.45
			_q_spread = 90.0
			_q_dmg = 1.2
		"quake":
			announce.emit(Loc.t("Quake Slam!  Brace yourself!"), "skull")
			_wind = "quake"
			_wind_max = 1.0
			_wind_t = 1.0
		"meteors":
			announce.emit(Loc.t("Meteor Shower!  Leave the red circles!"), "skull")
			_haz("meteor", target, 85.0, 1.7, damage * 1.6)
			for i in 3 + phase * 2:
				_haz("meteor", _around_base(40.0, 320.0), 85.0, 1.4 + 0.22 * i, damage * 1.6)
		"spikes":
			announce.emit(Loc.t("Stone Spikes erupt!"), "skull")
			var n := 8
			for i in n:
				var p := position.lerp(target, float(i + 1) / float(n))
				_haz("spike", p, 70.0, 0.8 + 0.14 * i, damage * 1.3)
			_haz("spike", target, 110.0, 0.8 + 0.14 * n, damage * 1.8)
		"hurl":
			announce.emit(Loc.t("Titan Hurl!  A huge boulder is coming!"), "skull")
			_q_kind = "boulder"
			_q_left = phase
			_q_cd = 0.5
			_q_gap = 0.35
			_q_spread = 40.0
			_q_dmg = 2.4
			_add_shake(14.0)
		"singularity":
			announce.emit(Loc.t("Singularity!  The void pulls you in!"), "skull")
			_haz("void", target + Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0)), 170.0, 1.6, damage * 2.0, {"linger": 4.0, "pull": 60.0})
		"blink":
			announce.emit(Loc.t("Phase Blink!  A void nova follows!"), "skull")
			_wind = "blink"
			_wind_max = 0.8
			_wind_t = 0.8
		"orbs":
			announce.emit(Loc.t("Seeking Void Orbs!  Shoot them down!"), "skull")
			_q_kind = "voidorb"
			_q_left = 3
			_q_cd = 0.3
			_q_gap = 0.5
			_q_spread = 60.0
			_q_dmg = 1.1

func _add_shake(a: float) -> void:
	shake.emit(a)

func _kit_fire(w: String) -> void:
	match w:
		"quake":
			shake.emit(30.0)
			Sfx.play("boss_phase", -2.0)
			var reach := position.distance_to(target) + 260.0
			_haz("ring", position, reach, 0.0, damage * 2.0, {"ring_speed": 420.0, "slow_factor": 0.5, "slow_time": 3.0})
		"blink":
			Fx.spawn(get_parent(), "explosion", position, Color(0.7, 0.4, 1.0), "", 1.4, 0.6)
			position = _around_base(430.0, 600.0)
			_wander_target = position
			Fx.spawn(get_parent(), "explosion", position, Color(0.7, 0.4, 1.0), "", 1.8, 0.7)
			Sfx.play("beam", -6.0)
			var reach := position.distance_to(target) + 260.0
			_haz("ring", position, reach, 0.0, damage * 1.6, {"ring_speed": 520.0})

# Hell Lord attack cycle: Fire Breath (charge, then 3.5 s of continuous flame), then a volley of
# Hell Arrows, and so on. Below 30% health it ENRAGES: 1.5x size, everything doubled.
func _process_hell(delta: float) -> void:
	var to_base := (target - position).angle()
	match _hell_mode:
		"":
			_hell_cd -= delta
			if _hell_cd <= 0.0:
				if _hell_next == "breath":
					_hell_mode = "charge"
					_hell_t = 1.0 / (2.0 if enraged else 1.0)
					_breath_angle = to_base
					announce.emit(Loc.t("Hell Lord takes a deep breath..."), "skull")
					Sfx.play("boss_warn", -2.0)
				else:
					_hell_mode = "volley"
					_volley_left = 9 if enraged else 6
					_volley_cd = 0.0
					announce.emit(Loc.t("Hell Arrows!"), "skull")
					Sfx.play("boss_warn", -2.0)
		"charge":
			_breath_angle = lerp_angle(_breath_angle, to_base, 1.0 - exp(-6.0 * delta))
			_hell_t -= delta
			if _hell_t <= 0.0:
				_hell_mode = "breath"
				_hell_t = 3.5
				_breath_tick = 0.0
				announce.emit(Loc.t("Hell Lord breathes FIRE!"), "skull")
				Sfx.play("boss_summon", -2.0)
		"breath":
			_hell_t -= delta
			_breath_angle = lerp_angle(_breath_angle, to_base, 1.0 - exp(-(2.4 if enraged else 1.3) * delta))
			_breath_tick -= delta
			if _breath_tick <= 0.0:
				_breath_tick = 0.25
				var f := Vector2.RIGHT.rotated(_breath_angle)
				breath.emit(position + f * radius * 0.9, _breath_angle, _breath_reach(), BREATH_HALF, damage * 0.35)
				Sfx.play("mg", -14.0)
			if _hell_t <= 0.0:
				_end_hell_attack("arrows")
		"volley":
			_volley_cd -= delta
			if _volley_cd <= 0.0:
				_volley_cd = 0.25 if enraged else 0.45
				_volley_left -= 1
				var n := 5 if enraged else 3
				var aim_dir := (target - position).normalized()
				for i in n:
					var a := (float(i) - float(n - 1) * 0.5) * 0.2
					hell_arrow.emit(position + aim_dir * radius, position + aim_dir.rotated(a) * 1000.0, damage * 1.2)
				Sfx.play("bolt", -4.0)
				if _volley_left <= 0:
					_end_hell_attack("breath")

func _end_hell_attack(next: String) -> void:
	_hell_mode = ""
	_hell_next = next
	_hell_cd = 1.5 if enraged else 3.0

func _breath_reach() -> float:
	return radius * 4.2

func _enrage() -> void:
	enraged = true
	radius *= 1.5
	damage *= 2.0
	speed *= 2.0
	_summon_interval *= 0.5
	_summon_count *= 2
	_bolt_interval *= 0.5
	_scale_pop = 0.3
	_flash = 0.5
	Fx.spawn(get_parent(), "explosion", position, Color.WHITE, "", 2.4, 1.0)
	Sfx.play("boss_phase", -2.0)
	announce.emit(Loc.t("ENRAGE!  The Hell Lord grows and doubles its power!"), "skull")
	raged.emit()

# Void Overlord: split in two, then punish the player if the copies survive.
func _process_void(delta: float) -> void:
	_lesser_timer -= delta
	if _lesser_timer <= 0.0:
		_lesser_timer = 10.0
		_check_timer = 5.0
		for off: float in [-1.0, 1.0]:
			summon_lesser.emit(position + Vector2(off * 80.0, 30.0), _lesser_hp, damage * 0.5, speed * 0.5)
		announce.emit(Loc.t("Void Overlord split in two! Destroy the copies within 5 seconds!"), "skull")
		Sfx.play("boss_split", -2.0)
	if _check_timer > 0.0:
		_check_timer -= delta
		if _check_timer <= 0.0 and _lessers_alive() and _beam_charge <= 0.0:
			_start_beam()
	if _beam_charge > 0.0:
		_beam_charge -= delta
		if _beam_charge <= 0.0:
			_beam_charge = 0.0
			_beam_flash = BEAM_FLASH_TIME
			beam.emit(damage * 3.0, position, _beam_aim)   # fires at the LOCKED spot; only moving away stops it
			Sfx.play("beam")
	if _beam_flash > 0.0:
		_beam_flash = maxf(_beam_flash - delta, 0.0)
	# Attack cycle: Void Fire (a burst of fast void bullets) -> Void Beam -> ...
	_attack_timer -= delta
	if _attack_timer <= 0.0 and _beam_charge <= 0.0 and _burst_left <= 0:
		if _next_attack == "fire":
			_burst_left = 24
			_burst_cd = 0.0
			_attack_timer = 7.0
			_next_attack = "beam"
			announce.emit(Loc.t("Void Fire!"), "skull")
			Sfx.play("boss_warn", -2.0)
		else:
			_start_beam()
			_attack_timer = 10.0
			_next_attack = "fire"
	if _burst_left > 0:
		_burst_cd -= delta
		if _burst_cd <= 0.0:
			_burst_cd = 0.07
			_burst_left -= 1
			var aim := target + Vector2(randf_range(-60.0, 60.0), randf_range(-60.0, 60.0))
			void_fire.emit(position, aim, damage * 0.25)
			Sfx.play("mg", -10.0)

# Locks the beam onto where the castle is right now, then charges.
func _start_beam() -> void:
	_beam_charge = BEAM_CHARGE_TIME
	_beam_aim = target
	announce.emit(Loc.t("Void beam charging!  Move!"), "shield")
	Sfx.play("beam_charge")

func _lessers_alive() -> bool:
	for node in get_tree().get_nodes_in_group("void_lessers"):
		var e := node as Enemy
		if e != null and not e.dead:
			return true
	return false

func take_damage(amount: float, pen: float = 0.0) -> void:
	if dead:
		return
	var par := get_parent()
	var dealt := amount * Weapons.armor_mult(armor, pen) * dmg_taken_mult
	var hp_before := hp
	hp -= dealt
	var crit := _is_crit(dealt)
	_record_chunk(hp_before, crit)
	_flash = 0.1
	_scale_pop = 0.05
	_slow_time = 0.2   # bosses only stagger slightly
	_push = -Vector2.RIGHT.rotated(_heading) * 40.0
	Fx.spawn(par, "spark", position + Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0)), Color(0.85, 0.5, 1.0), "", 1.2, 0.4)
	if crit:
		_crit_effects(par, 2.4)
	Fx.spawn(par, "number", position + Vector2(randf_range(-30.0, 30.0), -radius), Color(1.0, 0.35, 0.12) if crit else Color.WHITE, str(int(ceil(dealt))) + ("!" if crit else ""), 2.0 if crit else 1.0, 1.0 if crit else 0.7)
	Sfx.play("boss_hit")
	if ability == "hell" and not enraged and hp > 0.0 and hp <= max_hp * ENRAGE_HP:
		_enrage()
	if hp <= 0.0:
		if ability == "titan" and phase < 3:
			_grow_phase()
			return
		dead = true
		Fx.spawn(par, "explosion", position, Color.WHITE, "", 2.6, 1.0)
		Sfx.play("boss_die")
		died.emit(self)
		queue_free()

# Stone Titan: +50% size, health, speed and power after each phase.
func _grow_phase() -> void:
	phase += 1
	_grow *= 1.5
	max_hp = _phase_hp * _grow
	hp = max_hp
	speed *= 1.5
	damage *= 1.5
	radius *= 1.5
	_scale_pop = 0.3
	_flash = 0.4
	Fx.spawn(get_parent(), "explosion", position, Color.WHITE, "", 1.8, 0.9)
	Sfx.play("boss_phase", -2.0)
	announce.emit(Loc.t("%s grows stronger!  Phase %d / 3") % [boss_name, phase], "skull")

# ---------- drawing ----------

func _draw() -> void:
	var s := 1.0 + _scale_pop * 2.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s * MobArt.GROUND_SQUASH))       # circles on the ground look squashed in the tilted view
	PixelFx.disc(self, Vector2(6, 8), radius + 3.0, Color(0, 0, 0, 0.35))
	PixelFx.ring(self, Vector2.ZERO, radius + 10.0, Color(0.75, 0.35, 1.0, 0.9), 4.0)      # purple boss ring
	_draw_under(radius)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# parts that sit behind the pixel-art body
func _draw_under(r: float) -> void:
	var f := Vector2.RIGHT.rotated(_heading)
	var side := f.orthogonal()
	match ability:
		"speed":
			for i in 4:
				var off := side * (float(i) - 1.5) * r * 0.45
				PixelFx.line(self, off - f * r * 0.9, off - f * r * (1.8 + 0.25 * i), Color(0.6, 1.0, 0.6, 0.35), 4.0)
		"regen":
			pass
		"titan":
			pass
		"void":
			PixelFx.disc(self, Vector2.ZERO, r * 1.38, Color(0.5, 0.2, 0.9, 0.14))
			for i in 8:
				var d := Vector2.RIGHT.rotated(TAU * i / 8.0 + _t * 0.8)
				PixelFx.line(self, d * r * 0.9, d * r * (1.3 + 0.15 * sin(_t * 3.0 + i)), Color(0.55, 0.25, 0.95, 0.8), 5.0)
		_:
			var dark := Color(0.45, 0.05, 0.05)
			var tail := PackedVector2Array()
			for i in 8:
				var k := float(i) / 7.0
				tail.append(-f * (r * 0.8 + r * 0.9 * k) + side * sin(_t * 3.0 + k * 3.0) * r * 0.3 * k)
			draw_polyline(tail, _c(dark), 6.0)
			PixelFx.disc(self, tail[7], r * 0.12, Color(1.0, 0.4, 0.1))

# parts on top of the body: moving glows, the void eye, flames, the beam and the health bar
func _draw_over() -> void:
	var r := radius
	if _wind != "":
		var k := 1.0 - clampf(_wind_t / _wind_max, 0.0, 1.0)
		var wc := Color(1.0, 0.4, 0.2, 0.6) if _wind == "quake" else Color(0.75, 0.4, 1.0, 0.7)
		PixelFx.ring(_ov, Vector2.ZERO, r * (1.9 - 0.8 * k), wc, 4.0)
		PixelFx.ring(_ov, Vector2.ZERO, r * (1.2 + 0.6 * k), wc, 3.0)
	var s := 1.0 + _scale_pop * 2.0
	_ov.draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	_ov.draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s * MobArt.GROUND_SQUASH))
	match ability:
		"regen":
			var pulse := 0.5 + 0.5 * sin(_t * 4.0)
			PixelFx.ring(_ov, Vector2.ZERO, r * 1.12 + pulse * 5.0, Color(0.4, 1.0, 0.4, 0.2 + 0.3 * pulse), 4.0)
			for i in 5:
				var x := (float(i) - 2.0) * r * 0.3
				var drip := 4.0 + 6.0 * absf(sin(_t * 2.0 + i))
				PixelFx.line(_ov, Vector2(x, r * 0.86), Vector2(x, r * 0.86 + drip), Color(0.45, 0.30, 0.15).darkened(0.3), 5.0)
			var cross := Color(0.4, 1.0, 0.4, 0.5 + 0.4 * pulse)
			PixelFx.line(_ov, Vector2(-r * 0.12, r * 0.45), Vector2(r * 0.12, r * 0.45), cross, 5.0)
			PixelFx.line(_ov, Vector2(0, r * 0.33), Vector2(0, r * 0.57), cross, 5.0)
		"titan":
			PixelFx.disc(_ov, Vector2.ZERO, r * 0.2, Color(1.0, 0.6, 0.15, 0.25 + 0.3 * sin(_t * 3.0 + phase)))
		"void":
			PixelFx.arc(_ov, Vector2.ZERO, r * 0.86, _t, _t + 3.6, Color(0.7, 0.4, 1.0, 0.85), 3.0)
			PixelFx.arc(_ov, Vector2.ZERO, r * 0.62, -_t * 1.3, -_t * 1.3 + 3.0, Color(0.5, 0.3, 0.95, 0.8), 3.0)
		"hell":
			for i in 6:
				var fl := Vector2.RIGHT.rotated(TAU * i / 6.0 + _t * 1.2)
				PixelFx.disc(_ov, fl * r * 1.05, 5.0 + 3.0 * sin(_t * 8.0 + i), Color(1.0, 0.6, 0.1, 0.7))
	_ov.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ability == "hell":
		_draw_hell()
	if ability == "void":
		_draw_beam()
	_draw_boss_bar()

# Hell Lord extras: the devilish bow, the flame cone and the enrage aura.
func _draw_hell() -> void:
	var r := radius
	if enraged:
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		PixelFx.ring(_ov, Vector2.ZERO, r * 1.2 + pulse * 8.0, Color(1.0, 0.15, 0.05, 0.35 + 0.35 * pulse), 6.0)
		for i in 10:
			var ph := fmod(_t * 1.6 + float(i) * 0.31, 1.0)
			var ax := sin(float(i) * 2.3) * r * 0.9
			PixelFx.disc(_ov, Vector2(ax, r * 0.3 - ph * r * 1.6), 5.0 + 9.0 * (1.0 - ph), Color(1.0, 0.4, 0.05, 0.6 * (1.0 - ph)))
	# the bow always points at the castle
	var aim := (target - position).angle()
	var f := Vector2.RIGHT.rotated(aim)
	var pulling := _hell_mode == "volley"
	var c := f * r * 0.55
	var br := r * 0.62
	var dark := Color(0.35, 0.02, 0.05)
	var red := Color(0.8, 0.1, 0.12)
	PixelFx.arc(_ov, c, br, aim - 1.15, aim + 1.15, Color(0.05, 0.0, 0.02), 14.0)
	PixelFx.arc(_ov, c, br, aim - 1.15, aim + 1.15, dark, 10.0)
	PixelFx.arc(_ov, c, br, aim - 1.1, aim + 1.1, red, 5.0)
	for sg in [-1.0, 1.0]:
		var tip := c + Vector2.RIGHT.rotated(aim + sg * 1.15) * br
		var horn := tip + Vector2.RIGHT.rotated(aim + sg * 1.15 + sg * 1.5) * br * 0.34       # devil horns curling back
		PixelFx.line(_ov, tip, horn, Color(0.05, 0.0, 0.02), 9.0)
		PixelFx.line(_ov, tip, horn, Color(1.0, 0.45, 0.1), 4.0)
		PixelFx.disc(_ov, horn, 5.0, Color(1.0, 0.8, 0.3))
	var t_a := c + Vector2.RIGHT.rotated(aim - 1.15) * br
	var t_b := c + Vector2.RIGHT.rotated(aim + 1.15) * br
	var nock := c - f * (br * (0.55 if pulling else 0.0)) + f * br * 0.0
	PixelFx.line(_ov, t_a, nock, Color(1.0, 0.8, 0.5, 0.9), 3.0)
	PixelFx.line(_ov, nock, t_b, Color(1.0, 0.8, 0.5, 0.9), 3.0)
	if pulling:
		PixelFx.line(_ov, nock, nock + f * br * 1.1, Color(0.7, 0.1, 0.1), 5.0)
		PixelFx.disc(_ov, nock + f * br * 1.1, 6.0, Color(1.0, 0.6, 0.2))
	# fire breath: charge warning, then a roaring cone of flame
	if _hell_mode == "charge" or _hell_mode == "breath":
		var ba := _breath_angle
		var reach := _breath_reach()
		var mouth := Vector2.RIGHT.rotated(ba) * r * 0.9
		if _hell_mode == "charge":
			var k := 1.0 - _hell_t / (1.0 / (2.0 if enraged else 1.0))
			for sg in [-1.0, 1.0]:
				PixelFx.line(_ov, mouth, mouth + Vector2.RIGHT.rotated(ba + sg * BREATH_HALF) * reach, Color(1.0, 0.25, 0.1, 0.25 + 0.4 * k), 3.0)
			PixelFx.disc(_ov, mouth, r * (0.2 + 0.35 * k), Color(1.0, 0.55, 0.1, 0.3 + 0.4 * k))
		else:
			var poly := PackedVector2Array([mouth])
			for i in 9:
				poly.append(mouth + Vector2.RIGHT.rotated(ba - BREATH_HALF + BREATH_HALF * 2.0 * float(i) / 8.0) * reach)
			_ov.draw_colored_polygon(poly, Color(1.0, 0.35, 0.05, 0.12))
			for i in 46:
				var h := float(i) * 0.6180339
				var tt := fmod(_t * 1.7 + h, 1.0)
				var jitter := (fmod(h * 7.13, 1.0) - 0.5) * 2.0
				var a := ba + jitter * BREATH_HALF * (0.25 + 0.75 * tt)
				var p := mouth + Vector2.RIGHT.rotated(a) * reach * tt
				var sz := (7.0 + 30.0 * tt) * (1.0 if not enraged else 1.2)
				var col := Color(1.0, 0.95, 0.6, 0.9).lerp(Color(1.0, 0.45, 0.05, 0.75), minf(tt * 2.0, 1.0))
				col = col.lerp(Color(0.5, 0.05, 0.02, 0.0), maxf(tt - 0.5, 0.0) * 2.0)
				PixelFx.disc(_ov, p, sz, col)

func _draw_beam() -> void:
	var to_base := (_beam_aim - position).normalized() * 1900.0
	if _beam_charge > 0.0:
		var k := 1.0 - _beam_charge / BEAM_CHARGE_TIME
		PixelFx.line(_ov, Vector2.ZERO, to_base, Color(1.0, 0.2, 0.3, 0.2 + 0.5 * k), 2.0 + 6.0 * k)
		PixelFx.disc(_ov, Vector2.ZERO, radius * (0.4 + 0.6 * k), Color(1.0, 0.3, 0.6, 0.25 + 0.3 * k))
	if _beam_flash > 0.0:
		var a := _beam_flash / BEAM_FLASH_TIME
		PixelFx.line(_ov, Vector2.ZERO, to_base, Color(0.8, 0.3, 1.0, 0.35 * a), 56.0 * a + 6.0)
		PixelFx.line(_ov, Vector2.ZERO, to_base, Color(1.0, 0.8, 1.0, 0.9 * a), 22.0 * a + 3.0)

func _draw_boss_bar() -> void:
	var w := maxf(240.0, radius * 2.4)
	var h := 20.0
	var top := -radius * 1.4 - 36.0
	var pos := Vector2(-w * 0.5, top)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_ov.draw_rect(Rect2(pos, Vector2(w, h)), Color(0.08, 0.0, 0.12, 0.85))
	_ov.draw_rect(Rect2(pos, Vector2(w * frac, h)), Color(0.62, 0.2, 0.92))
	_draw_chunk(pos.x, pos.y, w, h, 1.0, _ov)
	_ov.draw_rect(Rect2(pos, Vector2(w, h)), Color(0.85, 0.6, 1.0), false, 2.0)
	_draw_armor_tag(pos + Vector2(-34.0, 3.0), _ov)
	var font := ThemeDB.fallback_font
	var value := "%d/%d" % [ceili(hp), ceili(max_hp)]
	var title := boss_name
	if ability == "titan":
		title = Loc.t("%s  -  Phase %d/3") % [boss_name, phase]
	elif enraged:
		title = "%s  -  %s" % [boss_name, Loc.t("ENRAGED")]
	_ov.draw_string_outline(font, pos + Vector2(0, 15), value, HORIZONTAL_ALIGNMENT_CENTER, w, PixelUI.fs(15), 4, Color.BLACK)
	_ov.draw_string(font, pos + Vector2(0, 15), value, HORIZONTAL_ALIGNMENT_CENTER, w, PixelUI.fs(15), Color.WHITE)
	_ov.draw_string_outline(font, pos + Vector2(0, -6), title, HORIZONTAL_ALIGNMENT_CENTER, w, PixelUI.fs(16), 4, Color.BLACK)
	_ov.draw_string(font, pos + Vector2(0, -6), title, HORIZONTAL_ALIGNMENT_CENTER, w, PixelUI.fs(16), Color(0.9, 0.75, 1.0))
