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

var level: int = 1
var coins: int = 0
var to_spawn: int = 0
var alive: int = 0
var spawn_timer: float = 0.0
var game_over: bool = false
var biome: int = 0
var boss_pending: bool = false
var boss_timer: float = 0.0

var base: Base
var backdrop: BackdropGrid
var weather: Weather
var _mini_pending: bool = false
const MINI_CAPS := [2, 4, 10, 20, 50]     # most Rogue Castles alive at once, per biome
var _mini_single: bool = false
const MINI_AFTER_LEVEL := 8          # Rogue Castles start spawning on level 9
const MINI_INTERVAL := 8.0         # one Rogue Castle every 8 seconds while normal mobs are still around
const COIN_MULT := 10              # every gold reward is multiplied by this
var _mini_timer: float = 0.0
var _power_timer: float = 0.0
var _cam_prev: Vector2 = Vector2.ZERO
const SPAWN_DIST_MIN := 1300.0     # enemies appear this far (min..max) from the castle
const SPAWN_DIST_MAX := 1550.0
var camera: Camera2D
var hud: Hud
var vignette: DamageVignette
var info_label: Label
var detail_label: Label
var _show_details: bool = false
var banner: Label
var pause_panel: PanelContainer
var castle_menu: CastleMenu
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
# Progress statistics (saved with the game)
var stat_kills: int = 0
var stat_gold: int = 0
var stat_bosses: int = 0
var stat_best_wave: int = 1
var stat_time: float = 0.0
var exchange_count: int = 0          # gold -> stat points exchanges so far (each one makes the next 10% dearer)
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
	base.critical.connect(_on_player_crit)
	base.damaged.connect(_on_base_damaged)
	base.blocked.connect(_on_base_blocked)
	base.poisoned.connect(_on_base_poisoned)

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

	# difficulty, enemy damage, spawn rate and PowerScore: hidden until the player presses the details key
	detail_label = Label.new()
	detail_label.position = Vector2(28, 168)
	detail_label.add_theme_font_size_override("font_size", 17)
	detail_label.add_theme_constant_override("outline_size", 5)
	detail_label.add_theme_color_override("font_outline_color", Color.BLACK)
	detail_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	detail_label.visible = false
	layer.add_child(detail_label)

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

	castle_menu = CastleMenu.new()
	castle_menu.base = base
	castle_menu.spend.connect(_on_castle_spend)
	castle_menu.weapon_upgrade.connect(_on_castle_weapon)
	castle_menu.laser_toggled.connect(_on_castle_laser)
	castle_menu.exchange_pressed.connect(_on_castle_exchange)
	castle_menu.continue_pressed.connect(_close_castle)
	layer.add_child(castle_menu)

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
	Music.stop()
	Cursors.set_mode(Cursors.Mode.ARROW)

# ---------- Save / load ----------

func _apply_save(d: Dictionary) -> void:
	level = maxi(int(d.get("level", 1)), 1)
	coins = int(d.get("coins", 0))
	base.from_dict(d.get("base", {}) as Dictionary)
	var st := d.get("stats", {}) as Dictionary
	stat_kills = maxi(int(st.get("kills", 0)), 0)
	stat_gold = maxi(int(st.get("gold", 0)), 0)
	stat_bosses = maxi(int(st.get("bosses", 0)), 0)
	stat_best_wave = maxi(int(st.get("best_wave", level)), level)
	stat_time = maxf(float(st.get("time", 0.0)), 0.0)
	exchange_count = clampi(int(d.get("exchange_count", 0)), 0, 400)
	biome = _biome_for(level)

func _make_save_data() -> Dictionary:
	return {
		"version": GameState.SAVE_VERSION,
		"difficulty": GameState.difficulty,
		"level": level,
		"coins": coins,
		"base": base.to_dict(),
		"exchange_count": exchange_count,
		"stats": {"kills": stat_kills, "gold": stat_gold, "bosses": stat_bosses, "best_wave": stat_best_wave, "time": stat_time},
	}

func _fmt_time(sec: float) -> String:
	var t := int(sec)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

func _save_game() -> void:
	var data := _make_save_data()
	if GameState.write_save(data):
		Sfx.play("powerup")
		pause_menu.set_status(Loc.t("Game saved. You will resume at the start of Wave %d.") % level)
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
	var title := Loc.t("Wave %d  -  %s") % [level, Loc.t(BIOME_NAMES[biome])]
	_boss_level = level % LEVELS_PER_BIOME == 0
	Enemy.space_mode = biome == SPACE_BIOME
	var count := int((3 + level * 2) * GameState.count_mult() * 3.0)
	if biome == SPACE_BIOME:
		count *= 3                      # the space biome throws 3x as many hostiles at you
	boss_pending = _boss_level
	if boss_pending:
		count = int(count * 0.6)
		boss_timer = 2.5
		title = Loc.t("Wave %d  -  %s Boss Wave") % [level, Loc.t(BIOME_NAMES[biome])]
		boss_label.text = Loc.t("!!  %s BOSS WAVE  !!") % Loc.t(BIOME_NAMES[biome]).to_upper()
	boss_label.visible = _boss_level
	Music.play(biome, _boss_level)
	_mini_single = GameState.difficulty == 0
	if _mini_single:
		# Beginner: just a chance of ONE Rogue Castle per level (0% before level 5, 20% on level 5, +10% per level)
		_mini_pending = randf() < _mini_chance(level)
	else:
		# Seasoned: the full rules (one every 8 s with biome caps) after level 8
		_mini_pending = level > MINI_AFTER_LEVEL
	_mini_timer = MINI_INTERVAL
	to_spawn = count
	spawn_timer = 1.5
	_clear_timer = -1.0
	_show_banner(title, _boss_level)
	_update_label()
	# Remember the state at the start of this level so Retry can restart it.
	_level_snapshot = _make_save_data()
	(_level_snapshot["base"] as Dictionary)["hp"] = base.max_hp
	stat_best_wave = maxi(stat_best_wave, level)
	_level_snapshot["stats"] = (_make_save_data()["stats"] as Dictionary)
	if Settings.autosave and GameState.write_save(_level_snapshot):
		_notify(Loc.t("Autosaved"), "star", Color(1.0, 0.85, 0.3), "save")

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
	if not game_over:
		stat_time += delta
	var bpos := base.position
	for m in Field.mobs():
		m.target = bpos
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
			if _normal_mobs_left():
				if _minis_alive() < int(MINI_CAPS[clampi(biome, 0, MINI_CAPS.size() - 1)]):
					_spawn_mini_boss()
					if _mini_single:
						_mini_pending = false          # Beginner: only the one castle
				_mini_timer = MINI_INTERVAL
			else:
				_mini_pending = false      # no normal mobs standing: no more Rogue Castles this level
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
	get_tree().paused = _manual_paused or castle_menu.visible or pause_menu.visible
	if not _manual_paused:
		pause_panel.visible = false

# ---------- Cursor and screen shake ----------

func _update_cursor() -> void:
	if get_tree().paused or game_over:
		Cursors.set_mode(Cursors.Mode.ARROW)
		return
	var mouse := get_global_mouse_position()
	var over := false
	for e in Field.near(mouse, 12.0):
		if not e.is_ally and not e.dead and mouse.distance_to(e.global_position) <= e.radius + 12.0:
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
	_shake = maxf(_shake, amount * Settings.shake_scale)

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

# ---------- Wave cleared / XP ----------

func _level_cleared() -> void:
	var cleared := level
	var biome_done := cleared % LEVELS_PER_BIOME == 0
	level += 1
	Sfx.play("biome_win" if biome_done else "win")
	_boss_level = false
	boss_label.visible = false
	_notify(Loc.t("Wave %d cleared!") % cleared, "star", Color(1.0, 0.85, 0.3))
	if biome_done:
		_notify(Loc.t("%s conquered!") % Loc.t(BIOME_NAMES[_biome_for(cleared)]), "star", Color(1.0, 0.85, 0.3))
	_start_level()
	spawn_timer = 3.5            # a short breather before the next wave

# Kills give XP equal to their reward (summoned fodder gives none). Every new level = 5 stat points.
func _gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	var gained := base.add_xp(amount)
	if gained > 0:
		base.play_level_up()
		Sfx.play("weapon_up", -2.0)
		_notify(Loc.t("Level up!  Level %d  (+%d stat points)") % [base.xp_level, gained * 5], "star", Color(0.5, 1.0, 0.6), "levelup")
		if castle_menu.visible:
			_refresh_castle()

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
	var w_medic := 0.0 if level < 6 else minf(4.0 + level * 0.5, 12.0)
	var w_aegis := 0.0 if level < 9 else minf(3.0 + level * 0.4, 12.0)
	var total := 100.0 + w_mech + w_tank + w_special + w_medic + w_aegis
	var r := randf() * total
	if r < w_special:
		return special
	r -= w_special
	if r < w_tank:
		return "tank"
	r -= w_tank
	if r < w_mech:
		return "mech"
	r -= w_mech
	if r < w_medic:
		return "medic"
	r -= w_medic
	if r < w_aegis:
		return "aegis"
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

# Bees summoned by the Garden Warden (no gold, vanish with the boss).
func _spawn_bees(pos: Vector2, count: int) -> void:
	for i in count:
		if alive >= MAX_ALIVE:
			break
		var m := Enemy.make_bee(level)
		m.position = pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 110.0)
		m.target = base.position
		m.reach = base.body_radius()
		alive += 1
		_register_mob(m, true)

func _on_boss_bomb(origin: Vector2, dest: Vector2) -> void:
	var b := PetekBomb.new()
	b.start = origin
	b.dest = dest
	b.base_ref = base
	add_child(b)

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
	b.summon_bees.connect(_spawn_bees)
	b.bomb.connect(_on_boss_bomb)
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
const BOLT_PEN := {"bullet": 0.0, "shell": 10.0, "rocket": 12.0, "orb": 20.0, "void": 30.0}   # armor penetration of enemy shots by style

func _spawn_bolt(origin: Vector2, aim: Vector2, dmg: float, style: String, spd: float) -> void:
	var pen := float(BOLT_PEN.get(style, 0.0))
	var b := EnemyBolt.new()
	b.style = style
	b.speed = spd
	b.position = origin
	b.direction = (aim - origin).normalized()
	b.base_ref = base
	b.damage = dmg
	b.reach = base.body_radius()
	b.hit_base.connect(func(d: float) -> void: base.take_damage(d, pen))
	add_child(b)

# Beam weapons hit everything on the line from origin toward the locked aim point.
func _beam_hit_check(origin: Vector2, aim: Vector2, dmg: float, width: float, pen: float = 30.0) -> void:
	var dir := (aim - origin).normalized()
	var rel := base.position - origin
	if rel.dot(dir) > -base.body_radius() and absf(rel.cross(dir)) <= base.body_radius() + width:
		base.take_damage(dmg, pen)

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

# Beginner difficulty: chance that one Rogue Castle shows up on this level.
func _mini_chance(lv: int) -> float:
	if lv < 5:
		return 0.0
	return clampf(0.2 + 0.1 * float(lv - 5), 0.0, 1.0)

func _minis_alive() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.dead and e.kind == "minicastle":
			n += 1
	return n

# True while ordinary mobs (or the boss) are still alive or still to come.
func _normal_mobs_left() -> bool:
	if to_spawn > 0 or boss_pending:
		return true
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.dead and e.kind != "minicastle":
			return true
	return false

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
		"void":
			spd = 520.0
	_spawn_bolt(origin, aim, dmg, style, spd)

func _on_mini_beam(origin: Vector2, aim: Vector2, dmg: float) -> void:
	var fx := BeamFx.new()
	fx.start = origin
	fx.finish = origin + (aim - origin).normalized() * 1700.0
	fx.thick = 1.4
	add_child(fx)
	_add_shake(6.0)
	_beam_hit_check(origin, aim, dmg, 6.0, float(Weapons.PEN[3]))

func _on_enemy_died(e: Enemy) -> void:
	if e.is_ally:
		_notify(Loc.t("Refugee Hit!"), "ally", Color(1.0, 0.2, 0.2), "allyhit")
		return
	coins += e.reward * COIN_MULT
	stat_gold += e.reward * COIN_MULT
	stat_kills += 1
	if e.kind == "boss":
		stat_bosses += 1
	_gain_xp(e.reward)
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
		_notify(Loc.t("Rogue Castle defeated!  +%d") % (e.reward * COIN_MULT), "coin", Color(1.0, 0.85, 0.3))
	elif e.kind == "boss":
		_add_shake(22.0)
		_notify(Loc.t("%s defeated!  +%d") % [Loc.t(BOSS_NAMES[biome]), e.reward * COIN_MULT], "coin", Color(1.0, 0.85, 0.3))
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
		base.take_damage(e.damage, e.armor_pen)
		if e.kind == "bee":
			base.apply_poison(2.0, 4.0)        # the sting poisons (blocked by the Barrier)
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
			_notify(Loc.t("Mana regen +5 per second"), "engineer", Color(1.0, 0.85, 0.25))
		3:
			base.mechanics += 1
			_notify(Loc.t("Base repairs itself slowly"), "mechanic", Color(1.0, 0.55, 0.35))

# ---------- Input: Esc menu, pause, shop, skills ----------

func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if not (castle_menu.visible or pause_menu.visible):
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
		if game_over or castle_menu.visible or pause_menu.visible:
			return
		_manual_paused = not _manual_paused
		_update_pause()
		return
	if event.is_action_pressed("toggle_info"):
		get_viewport().set_input_as_handled()
		_show_details = not _show_details
		hud.show_debug = _show_details
		_update_label()
		return
	if event.is_action_pressed("open_shop"):
		get_viewport().set_input_as_handled()
		if game_over or _manual_paused or pause_menu.visible:
			return
		_toggle_castle()
		return
	for i in 4:
		if event.is_action_pressed("skill_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			if not get_tree().paused and not game_over:
				var used := base.skill_slots[i]
				if used == "repair":
					_use_repair(i)
				elif base.use_skill(i):
					if used == "overcharge":
						Sfx.play("weapon_up")
						_notify(Loc.t("Overcharge!  Weapon damage +30%% for %d s") % int(Base.BOOST_DURATION), "damage", Color(1.0, 0.6, 0.2), "boost")
					else:
						Sfx.play("barrier")
						_notify(Loc.t("Barrier up!  Invincible for %d s") % int(Base.BARRIER_DURATION), "shield", Color(0.4, 0.85, 1.0), "barrier")
			return
	if castle_menu.visible:
		var idx := int(key.keycode) - int(KEY_1)
		if idx >= 0 and idx < CastleMenu.STATS.size():
			_on_castle_spend(str(CastleMenu.STATS[idx]["id"]))

# Repair skill: pay gold, heal 50% of max health, 1 second cooldown.
func _use_repair(slot: int) -> void:
	if base.skill_cd[slot] > 0.0:
		return
	if base.hp >= base.max_hp:
		_notify(Loc.t("Base is already at full health"), "repair", Color(1.0, 0.6, 0.3), "full")
		return
	var cost := base.repair_cost()
	if coins < cost:
		_notify(Loc.t("Not enough gold to repair"), "coin", Color(1.0, 0.6, 0.3), "norepair")
		return
	coins -= cost
	base.heal(base.max_hp * Base.REPAIR_HEAL)
	base.skill_cd[slot] = Base.REPAIR_COOLDOWN
	base.skill_cd_max[slot] = Base.REPAIR_COOLDOWN
	Sfx.play("powerup")
	_notify(Loc.t("Base repaired  -%d gold") % cost, "repair", Color(0.5, 1.0, 0.6), "repair")
	_update_label()

func _on_escape() -> void:
	if castle_menu.visible:
		_close_castle()
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

# ---------- Castle window (Tab) ----------

func _toggle_castle() -> void:
	if castle_menu.visible:
		_close_castle()
	else:
		_open_castle("")

func _open_castle(title: String) -> void:
	castle_menu.open(title, false)
	_refresh_castle()
	_update_pause()

func _close_castle() -> void:
	castle_menu.visible = false
	_update_pause()

func _refresh_castle() -> void:
	var diff_name: String = GameState.DIFFICULTY_NAMES[GameState.difficulty]
	castle_menu.refresh(coins, {
		"wave": level,
		"region": Loc.t(BIOME_NAMES[biome]),
		"difficulty": Loc.t(diff_name),
		"power": Power.of_base(base),
		"exchange_price": CastleMenu.exchange_price(exchange_count),
		"stats": "%s: %d   %s: %s" % [Loc.t("Kills"), stat_kills, Loc.t("Time"), _fmt_time(stat_time)],
	})

func _on_castle_spend(id: String, count: int = 1) -> void:
	if game_over:
		return
	var spent := 0
	for i in count:
		if not base.spend_point(id):
			break
		spent += 1
	if spent == 0:
		return
	Sfx.play("powerup", -4.0)
	_update_label()
	_refresh_castle()

func _on_castle_weapon() -> void:
	if game_over or base.weapon_tier >= Weapons.MAX_TIER:
		return
	var price := int(Weapons.UPGRADE_PRICE[base.weapon_tier])
	if coins < price or not base.upgrade_weapon():
		return
	coins -= price
	Sfx.play("weapon_up")
	_notify(Loc.t("Weapon upgraded: %s") % Loc.t(Weapons.name_of(base.weapon_tier)), Weapons.id_of(base.weapon_tier), Color(0.5, 1.0, 0.6))
	if base.refunded_damage_pts > 0:
		_notify(Loc.t("Weapon damage points refunded: %d") % base.refunded_damage_pts, "damage", Color(1.0, 0.9, 0.4))
	_update_label()
	_refresh_castle()

func _on_castle_exchange(count: int = 1) -> void:
	if game_over:
		return
	var bought := 0
	var spent := 0
	for i in count:
		var price := CastleMenu.exchange_price(exchange_count)
		if coins < price:
			break
		coins -= price
		spent += price
		exchange_count += 1
		base.free_points += CastleMenu.EXCHANGE_POINTS
		bought += 1
	if bought == 0:
		return
	Sfx.play("powerup", -4.0)
	_notify(Loc.t("Exchanged %d gold for %d stat points") % [spent, bought * CastleMenu.EXCHANGE_POINTS], "coin", Color(0.5, 1.0, 0.6), "exchange")
	_update_label()
	_refresh_castle()

func _on_castle_laser(on: bool) -> void:
	base.laser = on

# ---------- Game over and HUD text ----------

func _on_base_poisoned() -> void:
	_notify(Loc.t("Poisoned!  -2 HP per second"), "skull", Color(0.55, 1.0, 0.3), "poison")

func _on_player_crit(_amount: float) -> void:
	_add_shake(20.0)
	Sfx.play("crit")
	_notify(Loc.t("CRITICAL HIT!"), "hit", Color(1.0, 0.35, 0.2), "crit")

func _on_base_destroyed() -> void:
	if game_over:
		return
	game_over = true
	Sfx.play("fail")
	_add_shake(26.0)
	for group in ["enemies", "allies", "bolts", "bombs", "shots"]:
		for node in get_tree().get_nodes_in_group(group):
			node.set_process(false)
	boss_label.visible = false
	var info := Loc.t("Your %s fell on Wave %d  (%s)") % [Loc.t(Base.TIER_NAMES[base.tier]), level, Loc.t(BIOME_NAMES[biome])]
	info += "\n" + Loc.t("Kills: %d   Gold earned: %d   Play time: %s") % [stat_kills, stat_gold, _fmt_time(stat_time)]
	get_tree().create_timer(1.3).timeout.connect(gameover_menu.open.bind(info, Loc.t("Retry Wave %d") % level))

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
	# always visible: just the level, the region and the castle stage
	var t := "%s %d   -   %s\n%s" % [Loc.t("Wave"), level, Loc.t(BIOME_NAMES[biome]), Loc.t(Base.TIER_NAMES[base.tier])]
	if _msg != "":
		t += "\n" + _msg
	info_label.text = t
	# on demand (details key): the numbers behind the level
	detail_label.visible = _show_details
	if _show_details:
		var diff_name: String = GameState.DIFFICULTY_NAMES[GameState.difficulty]
		var d := "%s   |   %s x%.2f   |   %s x%.1f" % [Loc.t(diff_name), Loc.t("Enemy damage"), 1.0 + 0.25 * (level - 1), Loc.t("Spawn rate"), _spawn_rate()]
		d += "\n%s: %s %d   |   %s %d" % [Loc.t("Power"), Loc.t("you"), int(Power.of_base(base)), Loc.t("enemies"), int(Power.field_power(get_tree()))]
		detail_label.text = d
