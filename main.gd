extends Node2D

const BASE_POS := Vector2(960, 500)
const ALLY_CHANCE := 0.10
const LEVELS_PER_TIER := 3
const LEVELS_PER_BIOME := 5

const BIOME_NAMES := ["Greenland Biome", "Mudland Biome", "Rocky Mountain Biome", "Space Biome", "Hell Biome"]
const BOSS_NAMES := ["Garden Warden", "Mud Colossus", "Stone Titan", "Void Overlord", "Hell Lord"]

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
	{"id": "coins", "name": "Tax collection", "desc": "Gain bonus gold\n(more in later levels)"},
	{"id": "laser", "name": "Laser sight", "desc": "A red laser shows exactly\nwhere your cannon will hit"},
]

var level: int = 1
var coins: int = 0
var to_spawn: int = 0
var alive: int = 0
var spawn_timer: float = 0.0
var game_over: bool = false
var levels: Array[int] = [0, 0, 0, 0, 0, 0]
var biome: int = 0
var boss_pending: bool = false
var boss_timer: float = 0.0

var base: Base
var backdrop: Backdrop
var camera: Camera2D
var hud: Hud
var vignette: DamageVignette
var info_label: Label
var banner: Label
var pause_panel: PanelContainer
var upgrade_menu: UpgradeMenu
var shop_menu: ShopMenu
var pause_menu: PauseMenu

var _manual_paused: bool = false
var _msg: String = ""
var _msg_time: float = 0.0
var _banner_tween: Tween
var _shake: float = 0.0
var _clear_timer: float = -1.0

func _ready() -> void:
	# Main keeps running while the tree is paused so it can handle the pause keys.
	# Gameplay nodes (base, enemies, projectiles) are set to pause themselves.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.load_and_apply()

	backdrop = Backdrop.new()
	base = Base.new()
	base.position = BASE_POS
	var data := GameState.pending_load
	GameState.pending_load = {}
	if not data.is_empty():
		_apply_save(data)
	backdrop.biome = biome
	add_child(backdrop)
	add_child(base)
	base.destroyed.connect(_on_base_destroyed)
	base.damaged.connect(_on_base_damaged)
	base.blocked.connect(_on_base_blocked)

	camera = Camera2D.new()
	camera.position = Settings.WORLD_SIZE * 0.5
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)

	hud = Hud.new()
	hud.base = base
	layer.add_child(hud)

	vignette = DamageVignette.new()
	layer.add_child(vignette)

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
	banner.add_theme_font_size_override("font_size", 52)
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

	pause_menu = PauseMenu.new()
	pause_menu.resume_requested.connect(_close_pause_menu)
	pause_menu.save_requested.connect(_save_game)
	pause_menu.quit_requested.connect(_quit_to_menu)
	layer.add_child(pause_menu)

	_start_level()

func _exit_tree() -> void:
	Cursors.set_mode(Cursors.Mode.ARROW)

# ---------- Save / load ----------

func _apply_save(d: Dictionary) -> void:
	level = maxi(int(d.get("level", 1)), 1)
	coins = int(d.get("coins", 0))
	var saved_levels: Array = d.get("shop_levels", [])
	for i in mini(saved_levels.size(), levels.size()):
		levels[i] = int(saved_levels[i])
	base.from_dict(d.get("base", {}) as Dictionary)
	biome = _biome_for(level)

func _save_game() -> void:
	var data := {
		"version": 1,
		"difficulty": GameState.difficulty,
		"level": level,
		"coins": coins,
		"shop_levels": levels.duplicate(),
		"base": base.to_dict(),
	}
	if GameState.write_save(data):
		Sfx.play("powerup")
		pause_menu.set_status("Game saved. You will resume at the start of Level %d." % level)
	else:
		pause_menu.set_status("Could not save the game.")

func _close_pause_menu() -> void:
	pause_menu.close()
	_update_pause()

func _quit_to_menu() -> void:
	get_tree().paused = false
	Cursors.set_mode(Cursors.Mode.ARROW)
	get_tree().change_scene_to_file("res://menu.tscn")

# ---------- Levels, biomes, banner ----------

func _biome_for(lv: int) -> int:
	return mini(int((lv - 1) / float(LEVELS_PER_BIOME)), BIOME_NAMES.size() - 1)

func _start_level() -> void:
	var new_tier := mini(int((level - 1) / float(LEVELS_PER_TIER)), Base.TIER_NAMES.size() - 1)
	if new_tier != base.tier:
		base.set_tier(new_tier)
		_say("Your settlement grew into a %s!" % Base.TIER_NAMES[new_tier], 5.0)
	var new_biome := _biome_for(level)
	if new_biome != biome:
		_change_biome(new_biome)
	var title := "Level %d  -  %s" % [level, BIOME_NAMES[biome]]
	var count := int((3 + level * 2) * GameState.count_mult())
	boss_pending = level % LEVELS_PER_BIOME == 0
	if boss_pending:
		count = int(count * 0.6)
		boss_timer = 2.5
		title = "Level %d  -  BOSS: %s" % [level, BOSS_NAMES[biome]]
	to_spawn = count
	spawn_timer = 1.5
	_clear_timer = -1.0
	_show_banner(title)
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
	_update_cursor()
	if _manual_paused:
		# Blink the "game paused" popup until the game resumes
		pause_panel.visible = int(Time.get_ticks_msec() / 500.0) % 2 == 0
	if get_tree().paused:
		return
	_update_shake(delta)
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_msg = ""
			_update_label()
	if game_over:
		if Input.is_action_just_pressed("ui_accept"):
			get_tree().reload_current_scene()
		return
	if boss_pending:
		boss_timer -= delta
		if boss_timer <= 0.0:
			boss_pending = false
			_spawn_boss()
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_mob()
			to_spawn -= 1
			spawn_timer = maxf(0.35, 2.0 - level * 0.1) * GameState.interval_mult()
	elif alive == 0 and not boss_pending:
		if _clear_timer < 0.0:
			_clear_timer = 0.8
		_clear_timer -= delta
		if _clear_timer <= 0.0:
			_clear_timer = -1.0
			_level_cleared()
	else:
		_clear_timer = -1.0

func _update_pause() -> void:
	get_tree().paused = _manual_paused or shop_menu.visible or upgrade_menu.visible or pause_menu.visible
	if not _manual_paused:
		pause_panel.visible = false

# ---------- Cursor and screen shake ----------

func _update_cursor() -> void:
	if get_tree().paused or game_over:
		Cursors.set_mode(Cursors.Mode.ARROW)
		return
	var mouse := get_global_mouse_position()
	var over := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.dead and mouse.distance_to(e.global_position) <= e.radius + 12.0:
			over = true
			break
	Cursors.set_mode(Cursors.Mode.AGGRESSIVE if over else Cursors.Mode.CROSSHAIR)

func _add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _update_shake(delta: float) -> void:
	if _shake > 0.1:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-8.0 * delta))
	else:
		_shake = 0.0
		camera.offset = Vector2.ZERO

func _on_base_damaged(amount: float) -> void:
	_add_shake(minf(7.0 + amount * 3.0, 24.0))
	vignette.flash(minf(0.55 + amount * 0.12, 1.0))
	Sfx.play("base_hit")
	_update_label()

func _on_base_blocked() -> void:
	Sfx.play("block")

# ---------- Level reward menu ----------

func _level_cleared() -> void:
	var cleared := level
	var biome_done := cleared % LEVELS_PER_BIOME == 0
	level += 1
	Sfx.play("biome_win" if biome_done else "win")
	var title := "Level %d cleared!  Choose a reward" % cleared
	if biome_done:
		title = "%s conquered!  Choose a reward" % BIOME_NAMES[_biome_for(cleared)]
	_open_upgrade_menu(title)

func _is_available(u: Dictionary) -> bool:
	match u["id"]:
		"autocannon":
			return base.auto_cannons < Base.MAX_AUTO
		"repair":
			return base.hp < base.max_hp
		"laser":
			return not base.laser
	return true

func _open_upgrade_menu(title: String) -> void:
	var pool := UPGRADES.filter(_is_available)
	pool.shuffle()
	var picks := pool.slice(0, 3)
	upgrade_menu.open(title, picks)
	_update_pause()

func _on_upgrade_chosen(id: String) -> void:
	var text := _apply_upgrade(id)
	Sfx.play("powerup")
	_update_pause()
	_start_level()
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
			base.max_hp += 10.0
			base.heal(10.0)
			return "Max health +10."
		"repair":
			base.heal(base.max_hp * 0.5)
			return "Base repaired."
		"coins":
			var gain := 5 + level * 3
			coins += gain
			return "Collected %d gold." % gain
		"laser":
			base.laser = true
			return "Laser sight installed."
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

func _pick_kind() -> String:
	var w_mech := 0.0 if level < 2 else minf(18.0 + level * 1.5, 40.0)
	var w_tank := 0.0 if level < 3 else minf(10.0 + level * 1.5, 30.0)
	var total := 100.0 + w_mech + w_tank
	var r := randf() * total
	if r < w_tank:
		return "tank"
	if r < w_tank + w_mech:
		return "mech"
	return "soldier"

func _register_mob(e: Enemy, deferred: bool = false) -> void:
	e.died.connect(_on_enemy_died)
	e.arrived.connect(_on_mob_arrived)
	if deferred:
		add_child.call_deferred(e)
	else:
		add_child(e)

func _spawn_mob() -> void:
	var e: Enemy
	if randf() < ALLY_CHANCE:
		e = Enemy.make_ally()
	else:
		e = Enemy.make(_pick_kind(), level)
		alive += 1
	e.position = _edge_spawn_pos()
	e.target = BASE_POS
	e.reach = base.body_radius()
	_register_mob(e)

func _spawn_soldier_at(pos: Vector2) -> void:
	var s := Enemy.make("soldier", level)
	s.position = pos
	s.target = BASE_POS
	s.reach = base.body_radius()
	alive += 1
	_register_mob(s, true)

func _spawn_boss() -> void:
	var b := Boss.make_boss(level, biome)
	b.boss_name = BOSS_NAMES[biome]
	b.position = _edge_spawn_pos()
	b.target = BASE_POS
	b.died.connect(_on_enemy_died)
	b.summon.connect(_on_boss_summon)
	b.bolt.connect(_on_boss_bolt)
	add_child(b)
	alive += 1
	Sfx.play("boss_spawn")
	_say("%s approaches!" % BOSS_NAMES[biome], 4.0)

func _on_boss_summon(pos: Vector2) -> void:
	for off in [-45.0, 45.0]:
		_spawn_soldier_at(pos + Vector2(off, 20.0))

func _on_boss_bolt(from_pos: Vector2, dmg: float) -> void:
	var b := EnemyBolt.new()
	b.position = from_pos
	b.target = BASE_POS
	b.damage = dmg
	b.reach = base.body_radius()
	b.hit_base.connect(base.take_damage)
	add_child(b)

func _on_enemy_died(e: Enemy) -> void:
	if e.is_ally:
		_say("An ally was hit by friendly fire!", 3.0)
		return
	coins += e.reward
	alive -= 1
	if e.kind == "mech":
		# The vehicle explodes and leaves 3 soldiers spread to its sides.
		_add_shake(7.0)
		var side := (BASE_POS - e.position).normalized().orthogonal()
		for off in [-55.0, 0.0, 55.0]:
			_spawn_soldier_at(e.position + side * off)
	elif e.kind == "boss":
		_add_shake(22.0)
		_say("%s defeated!  +%d gold" % [BOSS_NAMES[biome], e.reward], 4.0)
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

# ---------- Input: Esc menu, pause, shop, skills ----------

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_escape()
		return
	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		if game_over or shop_menu.visible or upgrade_menu.visible or pause_menu.visible:
			return
		_manual_paused = not _manual_paused
		_update_pause()
		return
	if event.is_action_pressed("open_shop"):
		get_viewport().set_input_as_handled()
		if game_over or _manual_paused or upgrade_menu.visible or pause_menu.visible:
			return
		_toggle_shop()
		return
	for i in 4:
		if event.is_action_pressed("skill_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			if not get_tree().paused and not game_over and base.use_skill(i):
				Sfx.play("barrier")
			return
	if shop_menu.visible:
		var idx := int(key.keycode) - int(KEY_1)
		if idx >= 0 and idx < ITEMS.size():
			_buy(idx)

func _on_escape() -> void:
	if upgrade_menu.visible:
		return
	if shop_menu.visible:
		_toggle_shop()
		return
	if pause_menu.visible:
		if pause_menu.go_back():
			Settings.save()
		else:
			_close_pause_menu()
		return
	if game_over:
		_quit_to_menu()
		return
	_manual_paused = false
	pause_menu.open()
	_update_pause()

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
		return int(ITEMS[5]["cost"]) + base.tier * 5
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
			base.heal(base.max_hp * 0.5)
	coins -= cost
	if i != 5:
		levels[i] += 1
	Sfx.play("coin")
	_update_label()
	_refresh_shop()

# ---------- Game over and HUD text ----------

func _on_base_destroyed() -> void:
	if game_over:
		return
	game_over = true
	Sfx.play("fail")
	_add_shake(26.0)
	for group in ["enemies", "allies", "bolts", "shots"]:
		for node in get_tree().get_nodes_in_group(group):
			node.set_process(false)
	_say("Your %s fell on level %d.  Enter: restart   Esc: main menu" % [Base.TIER_NAMES[base.tier], level], 9999.0)

func _say(text: String, seconds: float) -> void:
	_msg = text
	_msg_time = seconds
	_update_label()

func _update_label() -> void:
	hud.coins = coins
	var diff_name: String = GameState.DIFFICULTY_NAMES[GameState.difficulty]
	var t := "%s   |   Level %d   |   %s   |   %s" % [Base.TIER_NAMES[base.tier], level, BIOME_NAMES[biome], diff_name]
	t += "\nAuto-cannons %d   Blacksmiths %d   Engineers %d   Medics %d   Enemy damage x%.2f" % [base.auto_cannons, base.smiths, base.engineers, base.medics, 1.0 + 0.25 * (level - 1)]
	t += "\nLeft mouse: fire   %s: shop   %s: pause   %s / %s / %s / %s: skills   Esc: menu" % [
		Keybinds.key_text("open_shop"), Keybinds.key_text("pause_game"),
		Keybinds.key_text("skill_1"), Keybinds.key_text("skill_2"), Keybinds.key_text("skill_3"), Keybinds.key_text("skill_4"),
	]
	if _msg != "":
		t += "\n" + _msg
	info_label.text = t
