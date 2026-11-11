extends Node2D

const BASE_POS := Vector2(960, 500)
const ALLY_CHANCE := 0.10
const LEVELS_PER_TIER := 7        # the base evolves every 7 levels (Death Star at level 64)
const SPACE_BIOME := 4            # the last biome: no refugees, 3x hostiles, space ships
const LEVELS_PER_BIOME := 10      # a new biome every 10 levels; level 10, 20, 30... are boss levels
const SPAWN_RATE_BASE := 3.0       # every biome spawns at least 3x as fast as before
const SPAWN_RATE_PER_LEVEL := 0.20 # ...and +0.20 more (of the base rate) with every level
const MAX_ALIVE := 180            # safety cap so huge summons never overload the game

const BIOME_NAMES := ["Greenland Biome", "Mudland Biome", "Rocky Mountain Biome", "Hell Biome", "Space Biome"]
const BOSS_NAMES := ["Garden Warden", "Mud Colossus", "Stone Titan", "Hell Lord", "Void Overlord"]

# Shop rows, in order (the number keys 1-6 buy them). Weapon upgrade and repair are special.
const ITEMS := [
	{"id": "damage", "name": "Weapon damage", "desc": "+5% damage for all weapons", "icon": "damage", "cost": 10, "growth": 1.16},
	{"id": "weapon", "name": "Weapon upgrade", "desc": "", "icon": "cannon", "cost": 0, "growth": 1.0},
	{"id": "regen", "name": "Energy regen", "desc": "+4 energy per second", "icon": "regen", "cost": 10, "growth": 1.5},
	{"id": "autorate", "name": "Auto fire rate", "desc": "Auto-weapons fire 15% faster and reach further", "icon": "autorate", "cost": 20, "growth": 1.5},
	{"id": "energy", "name": "Max energy", "desc": "+20 maximum energy", "icon": "energy", "cost": 10, "growth": 1.5},
	{"id": "repair", "name": "Repair base", "desc": "Heal 50% of max health", "icon": "repair", "cost": 15, "growth": 1.0},
	{"id": "armor", "name": "Armor plating", "desc": "+10 max health and heal 10", "icon": "walls", "cost": 25, "growth": 1.45},
]

# Reward cards offered after each level (3 random ones). Auto-weapons only come from Gunner allies.
const UPGRADES := [
	{"id": "regen", "name": "Fast loading", "icon": "regen", "desc": "Energy regen +4 per second"},
	{"id": "energy", "name": "Bigger magazine", "icon": "energy", "desc": "Max energy +20"},
	{"id": "autorate", "name": "Gun oil", "icon": "autorate", "desc": "Auto-weapons fire 15% faster\nand reach further"},
	{"id": "walls", "name": "Thicker walls", "icon": "walls", "desc": "Max health +10 and heal 10"},
	{"id": "repair", "name": "Field repairs", "icon": "repair", "desc": "Heal 50% of max health"},
	{"id": "coins", "name": "Tax collection", "icon": "coin", "desc": "Gain bonus gold\n(more in later levels)"},
	{"id": "speed", "name": "Thrusters", "icon": "speed", "desc": "Castle move speed +5%"},
	{"id": "laser", "name": "Laser sight", "icon": "sight", "desc": "A red laser shows exactly\nwhere your weapon will hit"},
]

var level: int = 1
var coins: int = 0
var to_spawn: int = 0
var alive: int = 0
var spawn_timer: float = 0.0
var game_over: bool = false
var levels: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var biome: int = 0
var boss_pending: bool = false
var boss_timer: float = 0.0

var base: Base
var backdrop: BackdropGrid
var weather: Weather
var _mini_pending: bool = false
var _mini_timer: float = 0.0
var _power_timer: float = 0.0
var _cam_prev: Vector2 = Vector2.ZERO
const SPAWN_DIST_MIN := 1300.0     # enemies appear this far (min..max) from the castle
const SPAWN_DIST_MAX := 1550.0
var camera: Camera2D
var hud: Hud
var vignette: DamageVignette
var info_label: Label
var banner: Label
var pause_panel: PanelContainer
var upgrade_menu: UpgradeMenu
var shop_menu: ShopMenu
var pause_menu: PauseMenu
var notifier: Notifier
var gameover_menu: GameOverMenu
var _level_snapshot: Dictionary = {}
var boss_label: Label

var _manual_paused: bool = false
var _msg: String = ""
var _msg_time: float = 0.0
var _banner_tween: Tween
var _shake: float = 0.0
var _zoom: float = Settings.VIEW_ZOOM
var _zoom_target: float = Settings.VIEW_ZOOM
var _clear_timer: float = -1.0
var _boss_level: bool = false

func _ready() -> void:
	# Main keeps running while the tree is paused so it can handle the pause keys.
	# Gameplay nodes (base, enemies, projectiles) are set to pause themselves.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.load_and_apply()

	backdrop = BackdropGrid.new()
	base = Base.new()
	base.position = BASE_POS
	var data := GameState.pending_load
	GameState.pending_load = {}
	if not data.is_empty():
		_apply_save(data)
	backdrop.setup(biome)
	add_child(backdrop)
	add_child(base)
	base.destroyed.connect(_on_base_destroyed)
	base.damaged.connect(_on_base_damaged)
	base.blocked.connect(_on_base_blocked)

	camera = Camera2D.new()
	camera.position = base.position
	_cam_prev = camera.position
	add_child(camera)
	camera.zoom = Vector2(Settings.VIEW_ZOOM, Settings.VIEW_ZOOM)
	camera.make_current()

	var weather_layer := CanvasLayer.new()
	weather_layer.layer = 1
	add_child(weather_layer)
	weather = Weather.new()
	weather.set_biome(biome)
	weather_layer.add_child(weather)

	var layer := CanvasLayer.new()
	layer.layer = 2
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

	notifier = Notifier.new()
	layer.add_child(notifier)

	boss_label = Label.new()
	boss_label.position = Vector2(0, 92)
	boss_label.custom_minimum_size = Vector2(Settings.WORLD_SIZE.x, 40)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 30)
	boss_label.add_theme_constant_override("outline_size", 8)
	boss_label.add_theme_color_override("font_outline_color", Color.BLACK)
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	boss_label.visible = false
	layer.add_child(boss_label)

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
	shop_menu.setup(ITEMS.size())

	pause_menu = PauseMenu.new()
	pause_menu.resume_requested.connect(_close_pause_menu)
	pause_menu.save_requested.connect(_save_game)
	pause_menu.quit_requested.connect(_quit_to_menu)
	layer.add_child(pause_menu)

	gameover_menu = GameOverMenu.new()
	gameover_menu.retry_requested.connect(_retry_level)
	gameover_menu.quit_requested.connect(_quit_to_menu)
	layer.add_child(gameover_menu)

	_start_level()

func _exit_tree() -> void:
	Cursors.set_mode(Cursors.Mode.ARROW)

# ---------- Save / load ----------

func _apply_save(d: Dictionary) -> void:
	level = maxi(int(d.get("level", 1)), 1)
	coins = int(d.get("coins", 0))
	if int(d.get("version", 1)) >= 2:   # older saves used a different shop order
		var saved_levels: Array = d.get("shop_levels", [])
		for i in mini(saved_levels.size(), levels.size()):
			levels[i] = int(saved_levels[i])
	base.from_dict(d.get("base", {}) as Dictionary)
	biome = _biome_for(level)

func _make_save_data() -> Dictionary:
	return {
		"version": 2,
		"difficulty": GameState.difficulty,
		"level": level,
		"coins": coins,
		"shop_levels": levels.duplicate(),
		"base": base.to_dict(),
	}

func _save_game() -> void:
	var data := _make_save_data()
	if GameState.write_save(data):
		Sfx.play("powerup")
		pause_menu.set_status(Loc.t("Game saved. You will resume at the start of Level %d.") % level)
		_notify(Loc.t("Game saved"), "star", Color(1.0, 0.85, 0.3), "save")
	else:
		pause_menu.set_status(Loc.t("Could not save the game."))

func _close_pause_menu() -> void:
	pause_menu.close()
	_update_pause()

# Retry restarts the level you died on, with the base fully repaired.
func _retry_level() -> void:
	GameState.pending_load = _level_snapshot
	get_tree().paused = false
	get_tree().reload_current_scene()

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
		_notify(Loc.t("Your settlement grew into a %s!") % Loc.t(Base.TIER_NAMES[new_tier]), "star", Color(1.0, 0.85, 0.3))
	var new_biome := _biome_for(level)
	if new_biome != biome:
		_change_biome(new_biome)
		if new_biome < BIOME_ENEMY_NOTES.size() and BIOME_ENEMY_NOTES[new_biome] != "":
			_notify(Loc.t(str(BIOME_ENEMY_NOTES[new_biome])), "skull", Color(1.0, 0.6, 0.3))
	var title := Loc.t("Level %d  -  %s") % [level, Loc.t(BIOME_NAMES[biome])]
	_boss_level = level % LEVELS_PER_BIOME == 0
	Enemy.space_mode = biome == SPACE_BIOME
	var count := int((3 + level * 2) * GameState.count_mult() * 3.0)
	if biome == SPACE_BIOME:
		count *= 3                      # the space biome throws 3x as many hostiles at you
	boss_pending = _boss_level
	if boss_pending:
		count = int(count * 0.6)
		boss_timer = 2.5
		title = Loc.t("Level %d  -  %s Boss Level") % [level, Loc.t(BIOME_NAMES[biome])]
		boss_label.text = Loc.t("!!  %s BOSS LEVEL  !!") % Loc.t(BIOME_NAMES[biome]).to_upper()
	boss_label.visible = _boss_level
	_mini_pending = level % LEVELS_PER_BIOME == 5      # a rival castle shows up mid-biome
	if _mini_pending:
		count = int(count * 0.7)
		_mini_timer = 6.0
	to_spawn = count
	spawn_timer = 1.5
	_clear_timer = -1.0
	_show_banner(title, _boss_level)
	_update_label()
	# Remember the state at the start of this level so Retry can restart it.
	_level_snapshot = _make_save_data()
	(_level_snapshot["base"] as Dictionary)["hp"] = base.max_hp

func _change_biome(new_biome: int) -> void:
	biome = new_biome
	var old := backdrop
	var fresh := BackdropGrid.new()
	fresh.setup(new_biome)
	fresh.follow(camera.position)
	weather.set_biome(new_biome)
	fresh.modulate.a = 0.0
	add_child(fresh)
	move_child(fresh, old.get_index() + 1)
	backdrop = fresh
	var tw := create_tween()
	tw.tween_property(fresh, "modulate:a", 1.0, 3.0)
	tw.tween_callback(old.queue_free)

func _show_banner(text: String, important: bool = false) -> void:
	banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	banner.modulate.a = 0.0
	_banner_tween = create_tween()
	if important:
		# Boss level: blink red so the player knows this phase matters.
		banner.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
		for i in 6:
			_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
			_banner_tween.tween_interval(0.35)
			_banner_tween.tween_property(banner, "modulate:a", 0.1, 0.2)
		_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
		_banner_tween.tween_interval(1.0)
		_banner_tween.tween_property(banner, "modulate:a", 0.0, 1.0)
	else:
		banner.add_theme_color_override("font_color", Color.WHITE)
		_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.6)
		_banner_tween.tween_interval(1.8)
		_banner_tween.tween_property(banner, "modulate:a", 0.0, 1.0)

func _process(delta: float) -> void:
	_update_cursor()
	_update_camera(delta)
	if _manual_paused:
		# Blink the "game paused" popup until the game resumes
		pause_panel.visible = int(Time.get_ticks_msec() / 500.0) % 2 == 0
	if _boss_level and boss_label.visible:
		boss_label.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0))
	if get_tree().paused:
		return
	_update_shake(delta)
	for group in ["enemies", "allies"]:
		for node in get_tree().get_nodes_in_group(group):
			node.set("target", base.position)
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_msg = ""
			_update_label()
	if game_over:
		return
	if boss_pending:
		boss_timer -= delta
		if boss_timer <= 0.0:
			boss_pending = false
			_spawn_boss()
	if _mini_pending:
		_mini_timer -= delta
		if _mini_timer <= 0.0:
			_mini_pending = false
			_spawn_mini_boss()
	_power_timer -= delta
	if _power_timer <= 0.0:
		_power_timer = 0.5
		_update_label()
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and alive < MAX_ALIVE:
			_spawn_mob()
			to_spawn -= 1
			spawn_timer = maxf(0.08, maxf(0.35, 2.0 - level * 0.1) / _spawn_rate()) * GameState.interval_mult()
	elif alive == 0 and not boss_pending and not _mini_pending:
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

# The castle stays in the centre of the screen; the world (backdrop, enemies, weather)
# scrolls past it. Mouse-wheel zoom is smooth.
func _update_camera(delta: float) -> void:
	_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-10.0 * delta))
	camera.zoom = Vector2(_zoom, _zoom)
	camera.position = base.position
	var moved := camera.position - _cam_prev
	_cam_prev = camera.position
	weather.feed(moved, _zoom)
	for node in get_tree().get_nodes_in_group("backdrops"):
		(node as BackdropGrid).follow(camera.position)

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
	_notify(Loc.t("Taken Damage!  -%d") % int(ceil(amount)), "hit", Color(1.0, 0.3, 0.3), "dmg")
	_update_label()

func _on_base_blocked() -> void:
	Sfx.play("block")
	_notify(Loc.t("Blocked by the Barrier!"), "shield", Color(0.4, 0.85, 1.0), "block")

# ---------- Level reward menu ----------

func _level_cleared() -> void:
	var cleared := level
	var biome_done := cleared % LEVELS_PER_BIOME == 0
	level += 1
	Sfx.play("biome_win" if biome_done else "win")
	var title := Loc.t("Level %d cleared!  Choose a reward") % cleared
	_boss_level = false
	boss_label.visible = false
	_notify(Loc.t("Level %d cleared!") % cleared, "star", Color(1.0, 0.85, 0.3))
	if biome_done:
		title = Loc.t("%s conquered!  Choose a reward") % Loc.t(BIOME_NAMES[_biome_for(cleared)])
	_open_upgrade_menu(title)

func _is_available(u: Dictionary) -> bool:
	match u["id"]:
		"repair":
			return base.hp < base.max_hp
		"laser":
			return not base.laser
		"autorate":
			return base.auto_cannons > 0
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
	var picked: Dictionary = {}
	for u in UPGRADES:
		if str(u["id"]) == id:
			picked = u
	_notify(Loc.t(text), str(picked.get("icon", "star")), Color(0.5, 1.0, 0.6))

func _apply_upgrade(id: String) -> String:
	match id:
		"regen":
			base.energy_regen += 4.0
			return "Energy regen +4 per second"
		"energy":
			base.max_energy += 20.0
			return "Max energy +20"
		"autorate":
			base.upgrade_auto_rate()
			return "Auto-weapons fire faster and reach further"
		"walls":
			base.hp_bonus += 10
			base.max_hp += 10.0
			base.heal(10.0)
			return "Max health +10"
		"repair":
			base.heal(base.max_hp * 0.5)
			return "Base repaired"
		"coins":
			var gain := 5 + level * 3
			coins += gain
			return Loc.t("Collected %d gold") % gain
		"speed":
			base.move_mult += 0.05
			return "Move speed +5%"
		"laser":
			base.laser = true
			return "Laser sight installed"
	return ""

# ---------- Mobs ----------

# A point at a fixed distance (min..max) from the castle, in a random direction.
func _edge_spawn_pos() -> Vector2:
	return base.position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX)

const BIOME_ENEMY_NOTES := [
	"",
	"Bloodworms swarm in - tiny, very fast and fragile!",
	"Golems approach - they split into a smaller golem when destroyed!",
	"Demons rise from the lava - tough, fast and brutal!",
	"Hunter packs incoming - they dodge a lot and shoot from far away!",
]

# Spawn-rate multiplier: x3 in every biome, +0.20 per level on top (level 11 = x9).
func _spawn_rate() -> float:
	return SPAWN_RATE_BASE * (1.0 + SPAWN_RATE_PER_LEVEL * float(level - 1))

func _pick_kind() -> String:
	var special := ""
	var w_special := 0.0
	match biome:
		1:
			special = "worm"
			w_special = 40.0
		2:
			special = "golem"
			w_special = 22.0
		3:
			special = "demon"
			w_special = 16.0
		4:
			special = "hunter"
			w_special = 14.0
	var w_mech := 0.0 if level < 2 else minf(18.0 + level * 1.5, 40.0)
	var w_tank := 0.0 if level < 3 else minf(10.0 + level * 1.5, 30.0)
	var total := 100.0 + w_mech + w_tank + w_special
	var r := randf() * total
	if r < w_special:
		return special
	r -= w_special
	if r < w_tank:
		return "tank"
	if r < w_tank + w_mech:
		return "mech"
	return "soldier"

func _register_mob(e: Enemy, deferred: bool = false) -> void:
	e.died.connect(_on_enemy_died)
	e.arrived.connect(_on_mob_arrived)
	if e.shoots:
		e.shoot.connect(_on_tank_shoot)
	if deferred:
		add_child.call_deferred(e)
	else:
		add_child(e)

func _spawn_mob() -> void:
	var e: Enemy
	if biome != SPACE_BIOME and randf() < ALLY_CHANCE:   # no refugees in space
		e = Enemy.make_ally()
	else:
		var k := _pick_kind()
		if k == "hunter":
			_spawn_hunters()
			return
		e = Enemy.make(k, level)
		alive += 1
	e.position = _edge_spawn_pos()
	e.target = base.position
	e.reach = base.body_radius()
	_register_mob(e)

# Hunters arrive as a pack of five.
func _spawn_hunters() -> void:
	var center := _edge_spawn_pos()
	for i in 5:
		var h := Enemy.make("hunter", level)
		h.position = center + Vector2.RIGHT.rotated(TAU * float(i) / 5.0) * 50.0
		h.target = base.position
		h.reach = base.body_radius()
		alive += 1
		_register_mob(h)

func _spawn_soldier_at(pos: Vector2) -> void:
	var s := Enemy.make("soldier", level)
	s.position = pos
	s.target = base.position
	s.reach = base.body_radius()
	alive += 1
	_register_mob(s, true)

# Weaker soldiers summoned by a boss (no gold; they vanish when the boss dies).
func _spawn_minions(pos: Vector2, count: int) -> void:
	for i in count:
		if alive >= MAX_ALIVE:
			break
		var m := Enemy.make_minion(level)
		var a := randf() * TAU
		m.position = pos + Vector2.RIGHT.rotated(a) * randf_range(50.0, 120.0)
		m.target = base.position
		m.reach = base.body_radius()
		alive += 1
		_register_mob(m, true)

func _spawn_boss() -> void:
	var b := Boss.make_boss(level, biome)
	b.boss_name = Loc.t(BOSS_NAMES[biome])
	b.position = _edge_spawn_pos()
	b.target = base.position
	b.died.connect(_on_enemy_died)
	b.summon.connect(_spawn_minions)
	b.summon_lesser.connect(_on_boss_lesser)
	b.bolt.connect(_on_boss_bolt)
	b.beam.connect(_on_boss_beam)
	b.void_fire.connect(_on_void_fire)
	b.announce.connect(_on_boss_announce)
	add_child(b)
	alive += 1
	Sfx.play("boss_spawn")
	_notify(Loc.t("%s approaches!") % Loc.t(BOSS_NAMES[biome]), "skull", Color(0.8, 0.4, 1.0))

func _on_boss_lesser(pos: Vector2, hp: float, dmg: float, spd: float) -> void:
	var e := Enemy.make_void_lesser(hp, dmg, spd)
	e.position = pos
	e.target = base.position
	e.reach = base.body_radius()
	alive += 1
	_register_mob(e, true)

func _on_boss_announce(text: String, icon: String) -> void:
	_notify(text, icon, Color(0.85, 0.5, 1.0))

# A straight, unguided shot: it flies toward where the target WAS when fired.
func _spawn_bolt(origin: Vector2, aim: Vector2, dmg: float, style: String, spd: float) -> void:
	var b := EnemyBolt.new()
	b.style = style
	b.speed = spd
	b.position = origin
	b.direction = (aim - origin).normalized()
	b.base_ref = base
	b.damage = dmg
	b.reach = base.body_radius()
	b.hit_base.connect(base.take_damage)
	add_child(b)

# Beam weapons hit everything on the line from origin toward the locked aim point.
func _beam_hit_check(origin: Vector2, aim: Vector2, dmg: float, width: float) -> void:
	var dir := (aim - origin).normalized()
	var rel := base.position - origin
	if rel.dot(dir) > -base.body_radius() and absf(rel.cross(dir)) <= base.body_radius() + width:
		base.take_damage(dmg)

func _on_boss_beam(dmg: float, origin: Vector2, aim: Vector2) -> void:
	_add_shake(16.0)
	_beam_hit_check(origin, aim, dmg, 30.0)    # cannot be shot down - only the Barrier or moving away stops it

func _on_void_fire(origin: Vector2, aim: Vector2, dmg: float) -> void:
	_spawn_bolt(origin, aim, dmg, "void", 560.0)

func _on_boss_bolt(from_pos: Vector2, dmg: float) -> void:
	_spawn_bolt(from_pos, base.position, dmg, "orb", 260.0)

func _on_tank_shoot(origin: Vector2, dmg: float) -> void:
	_spawn_bolt(origin, base.position, dmg, "shell", 340.0)

# ---------- Mini boss (a rival castle) ----------

func _spawn_mini_boss() -> void:
	var m := MiniBoss.make_from(base)
	m.reward = 25 + level * 5
	m.position = _edge_spawn_pos()
	m.target = base.position
	m.died.connect(_on_enemy_died)
	m.fire.connect(_on_mini_fire)
	m.beam_fire.connect(_on_mini_beam)
	m.announce.connect(_on_boss_announce)
	add_child(m)
	alive += 1
	Sfx.play("boss_spawn", -4.0)
	_notify(Loc.t("A Rogue Castle approaches!"), "skull", Color(1.0, 0.5, 0.35))

func _on_mini_fire(origin: Vector2, aim: Vector2, dmg: float, style: String) -> void:
	var spd := 560.0
	match style:
		"bullet":
			spd = 700.0
		"shell":
			spd = 340.0
		"rocket":
			spd = 380.0
	_spawn_bolt(origin, aim, dmg, style, spd)

func _on_mini_beam(origin: Vector2, aim: Vector2, dmg: float) -> void:
	var fx := BeamFx.new()
	fx.start = origin
	fx.finish = origin + (aim - origin).normalized() * 1700.0
	fx.thick = 1.4
	add_child(fx)
	_add_shake(6.0)
	_beam_hit_check(origin, aim, dmg, 6.0)

func _on_enemy_died(e: Enemy) -> void:
	if e.is_ally:
		_notify(Loc.t("Refugee Hit!"), "ally", Color(1.0, 0.2, 0.2), "allyhit")
		return
	coins += e.reward
	alive -= 1
	if e.kind == "mech":
		# The vehicle explodes and leaves 3 soldiers spread to its sides.
		_add_shake(7.0)
		var side := (base.position - e.position).normalized().orthogonal()
		for off in [-55.0, 0.0, 55.0]:
			_spawn_soldier_at(e.position + side * off)
	elif e.kind == "golem" and not e.is_small:
		# The golem crumbles and leaves one smaller golem behind.
		_add_shake(9.0)
		var sg := Enemy.make_small_golem(e)
		sg.position = e.position
		sg.target = base.position
		sg.reach = base.body_radius()
		alive += 1
		_register_mob(sg, true)
	elif e.kind == "minicastle":
		_add_shake(14.0)
		_notify(Loc.t("Rogue Castle defeated!  +%d") % e.reward, "coin", Color(1.0, 0.85, 0.3))
	elif e.kind == "boss":
		_add_shake(22.0)
		_notify(Loc.t("%s defeated!  +%d") % [Loc.t(BOSS_NAMES[biome]), e.reward], "coin", Color(1.0, 0.85, 0.3))
		# Everything the boss summoned disappears with it.
		for node in get_tree().get_nodes_in_group("minions"):
			var m := node as Enemy
			if m == null or m.dead:
				continue
			m.dead = true
			alive -= 1
			Fx.spawn(self, "spark", m.position, Color(0.8, 0.4, 1.0), "", 1.3, 0.4)
			m.queue_free()
	_update_label()

func _on_mob_arrived(e: Enemy) -> void:
	if e.is_ally:
		_recruit()
	else:
		alive -= 1
		base.take_damage(e.damage)
		_update_label()

# An ally that reaches the base becomes a helper. The toast shows only the
# profession ICON, the same way the gold coin icon replaces the word "coin".
func _recruit() -> void:
	Sfx.play("powerup")
	match randi() % 4:
		0:
			base.gunners += 1
			base.add_auto_cannon()
			_notify(Loc.t("+1 auto-weapon"), "gunner", Color(0.5, 0.85, 0.4))
		1:
			base.scientists += 1
			base.damage_mult += 0.15
			_notify(Loc.t("Weapon damage +15%"), "scientist", Color(0.4, 0.95, 0.8))
		2:
			base.engineers += 1
			base.energy_regen += 5.0
			_notify(Loc.t("Energy regen +5 per second"), "engineer", Color(1.0, 0.85, 0.25))
		3:
			base.mechanics += 1
			_notify(Loc.t("Base repairs itself slowly"), "mechanic", Color(1.0, 0.55, 0.35))

# ---------- Input: Esc menu, pause, shop, skills ----------

func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if not (shop_menu.visible or upgrade_menu.visible or pause_menu.visible):
			var step := 1.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			_zoom_target = clampf(_zoom_target * step, Settings.ZOOM_MIN, Settings.ZOOM_MAX)
		return
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
			if not get_tree().paused and not game_over:
				var used := base.skill_slots[i]
				if base.use_skill(i):
					if used == "overcharge":
						Sfx.play("weapon_up")
						_notify(Loc.t("Overcharge!  Weapon damage +30%% for %d s") % int(Base.BOOST_DURATION), "damage", Color(1.0, 0.6, 0.2), "boost")
					else:
						Sfx.play("barrier")
						_notify(Loc.t("Barrier up!  Invincible for %d s") % int(Base.BARRIER_DURATION), "shield", Color(0.4, 0.85, 1.0), "barrier")
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
	var rows: Array = []
	for i in ITEMS.size():
		rows.append(_shop_row(i))
	shop_menu.refresh(coins, rows)

func _shop_row(i: int) -> Dictionary:
	var item: Dictionary = ITEMS[i]
	var id := str(item["id"])
	var row := {
		"name": Loc.t(str(item["name"])),
		"desc": Loc.t(str(item["desc"])),
		"icon": str(item["icon"]),
		"cost": _cost(i),
		"level": "%s %d" % [Loc.t("Lv"), levels[i]],
		"maxed": false,
	}
	if id == "repair":
		row["level"] = ""
	elif id == "weapon":
		var tier := base.weapon_tier
		row["level"] = "%d / %d" % [tier + 1, Weapons.MAX_TIER + 1]
		if tier >= Weapons.MAX_TIER:
			row["desc"] = Loc.t("%s - maximum weapon reached") % Loc.t(Weapons.name_of(tier))
			row["icon"] = Weapons.id_of(tier)
			row["maxed"] = true
		else:
			row["desc"] = Loc.t("%s -> %s\nAuto-weapons are upgraded too") % [Loc.t(Weapons.name_of(tier)), Loc.t(Weapons.name_of(tier + 1))]
			row["icon"] = Weapons.id_of(tier + 1)
	return row

func _cost(i: int) -> int:
	var item: Dictionary = ITEMS[i]
	var id := str(item["id"])
	if id == "weapon":
		if base.weapon_tier >= Weapons.MAX_TIER:
			return 0
		return int(Weapons.UPGRADE_PRICE[base.weapon_tier])
	if id == "repair":
		return int(item["cost"]) + base.tier * 5
	return int(float(item["cost"]) * pow(float(item["growth"]), levels[i]))

func _buy(i: int) -> void:
	if game_over or i < 0 or i >= ITEMS.size():
		return
	var item: Dictionary = ITEMS[i]
	var id := str(item["id"])
	var cost := _cost(i)
	if coins < cost:
		return
	var text := ""
	var icon := str(item["icon"])
	match id:
		"damage":
			base.damage_mult += 0.05
			text = "Weapon damage +5%"
		"weapon":
			if not base.upgrade_weapon():
				return
			Sfx.play("weapon_up")
			text = Loc.t("Weapon upgraded: %s") % Loc.t(Weapons.name_of(base.weapon_tier))
			icon = Weapons.id_of(base.weapon_tier)
		"regen":
			base.energy_regen += 4.0
			text = "Energy regen +4 per second"
		"autorate":
			if base.auto_cannons == 0:
				_notify(Loc.t("No auto-weapons yet - a Gunner ally builds one"), "gunner", Color(1.0, 0.6, 0.3), "noauto")
				return
			base.upgrade_auto_rate()
			text = "Auto-weapons fire faster"
		"energy":
			base.max_energy += 20.0
			text = "Max energy +20"
		"armor":
			base.hp_bonus += 10
			base.max_hp += 10.0
			base.heal(10.0)
			text = "Max health +10"
		"repair":
			if base.hp >= base.max_hp:
				_notify(Loc.t("Base is already at full health"), "repair", Color(1.0, 0.6, 0.3), "full")
				return
			base.heal(base.max_hp * 0.5)
			text = "Base repaired"
	coins -= cost
	if id != "repair":
		levels[i] += 1
	Sfx.play("coin")
	_notify(Loc.t(text), icon, Color(0.5, 1.0, 0.6))
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
	boss_label.visible = false
	var info := Loc.t("Your %s fell on Level %d  (%s)") % [Loc.t(Base.TIER_NAMES[base.tier]), level, Loc.t(BIOME_NAMES[biome])]
	get_tree().create_timer(1.3).timeout.connect(gameover_menu.open.bind(info, Loc.t("Retry Level %d") % level))

# Game-over text stays on the info label; everything else is a pop-up notification.
func _say(text: String, seconds: float) -> void:
	_msg = text
	_msg_time = seconds
	_update_label()

func _notify(text: String, icon: String = "", color: Color = Color.WHITE, key: String = "") -> void:
	if notifier != null:
		notifier.push(text, icon, color, key)

func _update_label() -> void:
	hud.coins = coins
	var diff_name: String = GameState.DIFFICULTY_NAMES[GameState.difficulty]
	var t := "%s   |   %s %d   |   %s   |   %s   |   %s x%.2f   |   %s x%.1f" % [Loc.t(Base.TIER_NAMES[base.tier]), Loc.t("Level"), level, Loc.t(BIOME_NAMES[biome]), Loc.t(diff_name), Loc.t("Enemy damage"), 1.0 + 0.25 * (level - 1), Loc.t("Spawn rate"), _spawn_rate()]
	t += "\n%s: %s %d   |   %s %d" % [Loc.t("Power"), Loc.t("you"), int(Power.of_base(base)), Loc.t("enemies"), int(Power.field_power(get_tree()))]
	if _msg != "":
		t += "\n" + _msg
	info_label.text = t
