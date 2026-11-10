extends Node2D

const BASE_POS := Vector2(576, 290)
const SPAWN_RADIUS := 700.0
const ALLY_CHANCE := 0.10

const ITEM_NAMES := ["Cannon damage", "Energy regen", "Auto-cannon", "Auto fire rate", "Max energy", "Repair base"]
const ITEM_COSTS := [10, 10, 25, 20, 10, 15]

const UPGRADES := [
	{"id": "damage", "name": "Heavy shells", "desc": "Cannon damage +20%"},
	{"id": "regen", "name": "Fast loading", "desc": "Energy regen +4 per second"},
	{"id": "energy", "name": "Bigger magazine", "desc": "Max energy +20"},
	{"id": "autorate", "name": "Gun oil", "desc": "Auto-cannons fire 15% faster"},
	{"id": "autocannon", "name": "New auto-cannon", "desc": "Adds one automatic cannon"},
	{"id": "walls", "name": "Thicker walls", "desc": "Max health +10 and heal 10"},
	{"id": "repair", "name": "Field repairs", "desc": "Heal 50% of max health"},
	{"id": "coins", "name": "Tax collection", "desc": "Gain bonus coins (more in later phases)"},
]

var phase: int = 1
var coins: int = 0
var to_spawn: int = 0
var alive: int = 0
var spawn_timer: float = 0.0
var game_over: bool = false
var levels: Array[int] = [0, 0, 0, 0, 0, 0]

var base: Base
var info_label: Label
var shop_label: Label
var upgrade_menu: UpgradeMenu
var _msg: String = ""
var _msg_time: float = 0.0

func _ready() -> void:
	base = Base.new()
	base.position = BASE_POS
	base.destroyed.connect(_on_base_destroyed)
	add_child(base)

	var layer := CanvasLayer.new()
	add_child(layer)

	var hud := Hud.new()
	hud.base = base
	layer.add_child(hud)

	info_label = Label.new()
	info_label.position = Vector2(16, 12)
	layer.add_child(info_label)

	shop_label = Label.new()
	shop_label.position = Vector2(get_viewport_rect().size.x - 310.0, 12)
	layer.add_child(shop_label)

	upgrade_menu = UpgradeMenu.new()
	upgrade_menu.chosen.connect(_on_upgrade_chosen)
	layer.add_child(upgrade_menu)

	_start_phase()

func _start_phase() -> void:
	var new_tier := mini(int((phase - 1) / 3.0), Base.TIER_NAMES.size() - 1)
	if new_tier != base.tier:
		base.set_tier(new_tier)
		_say("Your settlement grew into a %s!" % Base.TIER_NAMES[new_tier], 5.0)
	to_spawn = 3 + phase * 2
	spawn_timer = 1.0
	_update_label()

func _process(delta: float) -> void:
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_msg = ""
			_update_label()
	if game_over:
		if Input.is_action_just_pressed("ui_accept"):
			get_tree().reload_current_scene()
		return
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_mob()
			to_spawn -= 1
			spawn_timer = maxf(0.5, 2.0 - phase * 0.1)
	elif alive == 0:
		phase += 1
		_open_upgrade_menu()

# ---------- Phase reward menu ----------

func _is_available(u: Dictionary) -> bool:
	match u["id"]:
		"autocannon":
			return base.auto_cannons < Base.MAX_AUTO
		"repair":
			return base.hp < base.max_hp
	return true

func _open_upgrade_menu() -> void:
	var pool := UPGRADES.filter(_is_available)
	pool.shuffle()
	var picks := pool.slice(0, 3)
	upgrade_menu.open("Phase %d cleared!  Choose a reward" % (phase - 1), picks)
	get_tree().paused = true

func _on_upgrade_chosen(id: String) -> void:
	var text := _apply_upgrade(id)
	get_tree().paused = false
	_start_phase()
	_say(text, 4.0)

func _apply_upgrade(id: String) -> String:
	match id:
		"damage":
			base.damage_mult += 0.2
			return "Cannon damage +20%."
		"regen":
			base.energy_regen += 4.0
			return "Energy regen +4."
		"energy":
			base.max_energy += 20.0
			return "Max energy +20."
		"autorate":
			base.auto_interval = maxf(base.auto_interval * 0.85, 0.3)
			return "Auto-cannons fire faster."
		"autocannon":
			base.auto_cannons = mini(base.auto_cannons + 1, Base.MAX_AUTO)
			return "A new auto-cannon was built."
		"walls":
			base.hp_bonus += 10
			base.max_hp += 10
			base.heal(10)
			return "Max health +10."
		"repair":
			base.heal(int(base.max_hp * 0.5))
			return "Base repaired."
		"coins":
			var gain := 5 + phase * 3
			coins += gain
			return "Collected %d coins." % gain
	return ""

# ---------- Mobs ----------

func _spawn_mob() -> void:
	var e := Enemy.new()
	e.is_ally = randf() < ALLY_CHANCE
	var angle := randf() * TAU
	e.position = BASE_POS + Vector2.RIGHT.rotated(angle) * SPAWN_RADIUS
	e.target = BASE_POS
	e.reach = base.body_radius()
	if e.is_ally:
		e.speed = 40.0
	else:
		e.hp = 10.0 + (phase - 1) * 4.0
		e.speed = minf(60.0 + (phase - 1) * 5.0, 160.0)
		e.reward = 1 + int(phase * 0.5)
		e.damage = 1 + int(phase / 4.0)
		alive += 1
	e.died.connect(_on_enemy_died)
	e.arrived.connect(_on_mob_arrived)
	add_child(e)

func _on_enemy_died(e: Enemy) -> void:
	coins += e.reward
	alive -= 1
	_update_label()

func _on_mob_arrived(e: Enemy) -> void:
	if e.is_ally:
		_recruit()
	else:
		alive -= 1
		base.take_damage(e.damage)
		_update_label()

func _recruit() -> void:
	match randi() % 4:
		0:
			base.gunners += 1
			base.auto_cannons = mini(base.auto_cannons + 1, Base.MAX_AUTO)
			_say("A gunner joined and crews a new auto-cannon!", 4.0)
		1:
			base.smiths += 1
			base.damage_mult += 0.15
			_say("A blacksmith joined: cannon damage +15%.", 4.0)
		2:
			base.engineers += 1
			base.energy_regen += 5.0
			_say("An engineer joined: energy regen +5.", 4.0)
		3:
			base.medics += 1
			_say("A medic joined: your base slowly heals.", 4.0)

# ---------- Coin shop and input ----------

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://menu.tscn")
		return
	var idx := int(key.keycode) - int(KEY_1)
	if idx >= 0 and idx < ITEM_NAMES.size():
		_buy(idx)

func _cost(i: int) -> int:
	if i == 5:
		return ITEM_COSTS[5] + base.tier * 5
	return int(ITEM_COSTS[i] * pow(1.5, levels[i]))

func _buy(i: int) -> void:
	if game_over:
		return
	var cost := _cost(i)
	if coins < cost:
		_say("Not enough coins.", 2.0)
		return
	match i:
		0:
			base.damage_mult += 0.2
		1:
			base.energy_regen += 4.0
		2:
			if base.auto_cannons >= Base.MAX_AUTO:
				_say("Auto-cannon limit reached.", 2.0)
				return
			base.auto_cannons += 1
		3:
			base.auto_interval = maxf(base.auto_interval * 0.85, 0.3)
		4:
			base.max_energy += 20.0
		5:
			if base.hp >= base.max_hp:
				_say("Base is already at full health.", 2.0)
				return
			base.heal(int(base.max_hp * 0.5))
	coins -= cost
	if i != 5:
		levels[i] += 1
	_update_label()

# ---------- Game over and HUD text ----------

func _on_base_destroyed() -> void:
	game_over = true
	for group in ["enemies", "allies"]:
		for node in get_tree().get_nodes_in_group(group):
			node.set_process(false)
	_say("Your %s fell on phase %d. Enter: restart   Esc: main menu" % [Base.TIER_NAMES[base.tier], phase], 9999.0)

func _say(text: String, seconds: float) -> void:
	_msg = text
	_msg_time = seconds
	_update_label()

func _update_label() -> void:
	var t := "%s   Phase %d   Coins %d" % [Base.TIER_NAMES[base.tier], phase, coins]
	t += "\nAuto-cannons %d   Blacksmiths %d   Engineers %d   Medics %d" % [base.auto_cannons, base.smiths, base.engineers, base.medics]
	t += "\nHold LEFT MOUSE to fire   |   Esc: main menu"
	if _msg != "":
		t += "\n" + _msg
	info_label.text = t

	var s := "SHOP  (press the number key)"
	for i in ITEM_NAMES.size():
		var mark := "*" if coins >= _cost(i) else " "
		var lv := "" if i == 5 else "  Lv%d" % levels[i]
		s += "\n%s[%d] %s%s  -  %d" % [mark, i + 1, ITEM_NAMES[i], lv, _cost(i)]
	shop_label.text = s
