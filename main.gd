extends Node2D

const BASE_POS := Vector2(960, 500)
const ALLY_CHANCE := 0.10
const PHASES_PER_TIER := 3
const PHASES_PER_BIOME := 5

const BIOME_NAMES := ["Garden", "Mudlands", "Rocky Mountains", "Deep Space", "Hell"]

const ITEMS := [
	{"id": "damage", "name": "Cannon damage", "desc": "+20% damage for all cannons", "cost": 10},
	{"id": "regen", "name": "Energy regen", "desc": "+4 energy per second", "cost": 10},
	{"id": "auto", "name": "Auto-cannon", "desc": "Adds an automatic cannon and extends auto range", "cost": 25},
	{"id": "autorate", "name": "Auto fire rate", "desc": "Auto-cannons fire 15% faster and reach further", "cost": 20},
	{"id": "energy", "name": "Max energy", "desc": "+20 maximum energy", "cost": 10},
	{"id": "repair", "name": "Repair base", "desc": "Heal 50% of max health", "cost": 15, "leveled": false},
]

const UPGRADES := [
	{"id": "damage", "name": "Heavy shells", "desc": "Cannon damage +20%"},
	{"id": "regen", "name": "Fast loading", "desc": "Energy regen +4 per second"},
	{"id": "energy", "name": "Bigger magazine", "desc": "Max energy +20"},
	{"id": "autorate", "name": "Gun oil", "desc": "Auto-cannons fire 15% faster\nand reach further"},
	{"id": "autocannon", "name": "New auto-cannon", "desc": "Adds one automatic cannon\nand extends auto range"},
	{"id": "walls", "name": "Thicker walls", "desc": "Max health +10 and heal 10"},
	{"id": "repair", "name": "Field repairs", "desc": "Heal 50% of max health"},
	{"id": "coins", "name": "Tax collection", "desc": "Gain bonus coins\n(more in later phases)"},
]

var phase: int = 1
var coins: int = 0
var to_spawn: int = 0
var alive: int = 0
var spawn_timer: float = 0.0
var game_over: bool = false
var levels: Array[int] = [0, 0, 0, 0, 0, 0]
var biome: int = 0

var base: Base
var backdrop: Backdrop
var info_label: Label
var banner: Label
var pause_panel: PanelContainer
var upgrade_menu: UpgradeMenu
var shop_menu: ShopMenu

var _manual_paused: bool = false
var _msg: String = ""
var _msg_time: float = 0.0
var _banner_tween: Tween

func _ready() -> void:
	# Main keeps running while the tree is paused so it can handle the pause keys.
	# Gameplay nodes (base, enemies, projectiles) are set to pause themselves.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.load_and_apply()

	backdrop = Backdrop.new()
	add_child(backdrop)

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
	info_label.position = Vector2(28, 20)
	info_label.add_theme_font_size_override("font_size", 22)
	info_label.add_theme_constant_override("outline_size", 6)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(info_label)

	banner = Label.new()
	banner.position = Vector2(0, 150)
	banner.custom_minimum_size = Vector2(Settings.WORLD_SIZE.x, 70)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 56)
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.modulate.a = 0.0
	layer.add_child(banner)

	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2(Settings.WORLD_SIZE.x * 0.5 - 130.0, 24)
	pause_panel.custom_minimum_size = Vector2(260, 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.75)
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	pause_panel.add_theme_stylebox_override("panel", sb)
	var pause_text := Label.new()
	pause_text.text = "GAME PAUSED"
	pause_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_text.add_theme_font_size_override("font_size", 26)
	pause_panel.add_child(pause_text)
	pause_panel.visible = false
	layer.add_child(pause_panel)

	upgrade_menu = UpgradeMenu.new()
	upgrade_menu.chosen.connect(_on_upgrade_chosen)
	layer.add_child(upgrade_menu)

	shop_menu = ShopMenu.new()
	shop_menu.buy_requested.connect(_buy)
	layer.add_child(shop_menu)
	shop_menu.setup(ITEMS)

	_start_phase()

# ---------- Phases, biomes, banner ----------

func _start_phase() -> void:
	var new_tier := mini(int((phase - 1) / float(PHASES_PER_TIER)), Base.TIER_NAMES.size() - 1)
	if new_tier != base.tier:
		base.set_tier(new_tier)
		_say("Your settlement grew into a %s!" % Base.TIER_NAMES[new_tier], 5.0)
	var title := "Phase %d" % phase
	var new_biome := mini(int((phase - 1) / float(PHASES_PER_BIOME)), BIOME_NAMES.size() - 1)
	if new_biome != biome:
		_change_biome(new_biome)
		title += "  -  " + BIOME_NAMES[new_biome]
	_show_banner(title)
	to_spawn = 3 + phase * 2
	spawn_timer = 1.5
	_update_label()

func _change_biome(new_biome: int) -> void:
	biome = new_biome
	var old := backdrop
	var fresh := Backdrop.new()
	fresh.biome = new_biome
	fresh.modulate.a = 0.0
	add_child(fresh)
	move_child(fresh, old.get_index() + 1)
	backdrop = fresh
	var tw := create_tween()
	tw.tween_property(fresh, "modulate:a", 1.0, 3.0)
	tw.tween_callback(old.queue_free)

func _show_banner(text: String) -> void:
	banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.6)
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 1.0)

func _process(delta: float) -> void:
	if _manual_paused:
		# Blink the "game paused" popup until the game resumes
		pause_panel.visible = int(Time.get_ticks_msec() / 500.0) % 2 == 0
	if get_tree().paused:
		return
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

func _update_pause() -> void:
	get_tree().paused = _manual_paused or shop_menu.visible or upgrade_menu.visible
	if not _manual_paused:
		pause_panel.visible = false

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
	_update_pause()

func _on_upgrade_chosen(id: String) -> void:
	var text := _apply_upgrade(id)
	_update_pause()
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
			base.upgrade_auto_rate()
			return "Auto-cannons fire faster and reach further."
		"autocannon":
			base.add_auto_cannon()
			return "A new auto-cannon was built. Auto range extended."
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

# A point just outside the screen, in a random direction from the base.
func _edge_spawn_pos() -> Vector2:
	var d := Vector2.RIGHT.rotated(randf() * TAU)
	var rect := Rect2(Vector2.ZERO, Settings.WORLD_SIZE).grow(60.0)
	var tx := INF
	var ty := INF
	if absf(d.x) > 0.0001:
		tx = ((rect.end.x if d.x > 0.0 else rect.position.x) - BASE_POS.x) / d.x
	if absf(d.y) > 0.0001:
		ty = ((rect.end.y if d.y > 0.0 else rect.position.y) - BASE_POS.y) / d.y
	return BASE_POS + d * minf(tx, ty)

func _spawn_mob() -> void:
	var e := Enemy.new()
	e.is_ally = randf() < ALLY_CHANCE
	e.position = _edge_spawn_pos()
	e.target = BASE_POS
	e.reach = base.body_radius()
	if e.is_ally:
		e.speed = 50.0
	else:
		e.hp = 10.0 + (phase - 1) * 4.0
		e.speed = minf(70.0 + (phase - 1) * 5.0, 180.0)
		e.reward = 1 + int(phase * 0.5)
		e.damage = 1 + int(phase / 4.0)
		alive += 1
	e.died.connect(_on_enemy_died)
	e.arrived.connect(_on_mob_arrived)
	add_child(e)

func _on_enemy_died(e: Enemy) -> void:
	if e.is_ally:
		_say("An ally was hit by friendly fire!", 3.0)
		return
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
			base.add_auto_cannon()
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

# ---------- Input: pause, shop, menu ----------

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			get_viewport().set_input_as_handled()
			if game_over or shop_menu.visible or upgrade_menu.visible:
				return
			_manual_paused = not _manual_paused
			_update_pause()
		KEY_TAB:
			get_viewport().set_input_as_handled()
			if game_over or _manual_paused or upgrade_menu.visible:
				return
			_toggle_shop()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if shop_menu.visible:
				_toggle_shop()
			else:
				get_tree().paused = false
				get_tree().change_scene_to_file("res://menu.tscn")
		_:
			if shop_menu.visible:
				var idx := int(key.keycode) - int(KEY_1)
				if idx >= 0 and idx < ITEMS.size():
					_buy(idx)

func _toggle_shop() -> void:
	shop_menu.visible = not shop_menu.visible
	if shop_menu.visible:
		_refresh_shop()
	_update_pause()

func _refresh_shop() -> void:
	var costs: Array = []
	for i in ITEMS.size():
		costs.append(_cost(i))
	shop_menu.refresh(coins, costs, levels)

func _cost(i: int) -> int:
	if i == 5:
		return ITEMS[5]["cost"] + base.tier * 5
	return int(ITEMS[i]["cost"] * pow(1.5, levels[i]))

func _buy(i: int) -> void:
	if game_over:
		return
	var cost := _cost(i)
	if coins < cost:
		return
	match i:
		0:
			base.damage_mult += 0.2
		1:
			base.energy_regen += 4.0
		2:
			if not base.add_auto_cannon():
				_say("Auto-cannon limit reached.", 2.0)
				return
		3:
			base.upgrade_auto_rate()
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
	_refresh_shop()

# ---------- Game over and HUD text ----------

func _on_base_destroyed() -> void:
	game_over = true
	for group in ["enemies", "allies"]:
		for node in get_tree().get_nodes_in_group(group):
			node.set_process(false)
	_say("Your %s fell on phase %d.  Enter: restart   Esc: main menu" % [Base.TIER_NAMES[base.tier], phase], 9999.0)

func _say(text: String, seconds: float) -> void:
	_msg = text
	_msg_time = seconds
	_update_label()

func _update_label() -> void:
	var t := "%s   |   Phase %d   |   Coins %d" % [Base.TIER_NAMES[base.tier], phase, coins]
	t += "\nAuto-cannons %d   Blacksmiths %d   Engineers %d   Medics %d" % [base.auto_cannons, base.smiths, base.engineers, base.medics]
	t += "\nLeft mouse: fire   Tab: shop   Space: pause   Esc: menu"
	if _msg != "":
		t += "\n" + _msg
	info_label.text = t
