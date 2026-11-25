extends Node2D

const BASE_POS := Vector2(960, 500)
const ALLY_CHANCE := 0.10
const LEVELS_PER_TIER := 7        # the base evolves every 7 levels (Eye of End at level 64)
const SPACE_BIOME := 8            # the last biome: no refugees, 3x hostiles, space ships
const LEVELS_PER_BIOME := 10      # a new biome every 10 levels; level 10, 20, 30... are boss levels
const SPAWN_RATE_BASE := 3.0       # every biome spawns at least 3x as fast as before
const SPAWN_RATE_PER_LEVEL := 0.20 # ...and +0.20 more (of the base rate) with every level
const MAX_ALIVE := 180            # safety cap so huge summons never overload the game

# Chapter order (wave 10, 20, ... 90): Greenland, Mudland, High Mountains, Deep Ocean, Cursed Garden, Dark Continent, Hell, Forgotten Realm, Space.
# `biome` is the chapter's position in that order. CONTENT turns a position into the id of its look and mobs
# (backdrop, weather, music, boss): 0 Greenland 1 Mudland 2 Mountains 3 Dark Continent 4 Forgotten Realm 5 Cursed Garden 6 Deep Ocean 7 Hell 8 Space.
const CONTENT := [0, 1, 2, 6, 5, 3, 7, 4, 8]
const BIOME_NAMES := ["Chapter I: Greenland", "Chapter II: Mudland", "Chapter III: High Mountains", "Chapter IV: Deep Ocean", "Chapter V: Cursed Garden", "Chapter VI: Dark Continent", "Chapter VII: Hell", "Chapter VIII: Forgotten Realm", "Chapter IX: Space"]
const CHAPTER_TITLES := ["Greenland", "Mudland", "High Mountains", "Deep Ocean", "Cursed Garden", "Dark Continent", "Hell", "Forgotten Realm", "Outer Space"]      # without the "Chapter III:" in front
const CHAPTER_TAGS := [
	"The garden is waking up",
	"The mud swallows the weak",
	"The peaks hide ancient stone",
	"The deep keeps what it takes",
	"Even the flowers have teeth",
	"Something hunts in the dark",
	"The fire never sleeps",
	"The old gods stopped listening",
	"Beyond the sky, only the void",
]
const BOSS_NAMES := ["Garden Warden", "Mud Colossus", "Stone Titan", "Leviathan", "Thorn Queen", "Elite Titan", "Hell Lord", "Fallen Seraph", "Void Overlord"]

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
# Rogue Castle spawning. Never on boss waves. The first one waits MINI_FIRST_DELAY so the wave gets going.
const MINI_CAPS := [1, 2, 3, 3, 4, 4, 4, 5, 5]        # most Rogue Castles alive at once, per biome
const MINI_FIRST_LEVEL := 5               # Beginner: from level 5 (a chance per level, never two levels in a row)
const MINI_SEASONED_LEVEL := 5            # I Hate Myself: from level 5, two per level (+1 every 2 levels)
const MINI_CAPS_SEASONED := [2, 3, 4, 4, 5, 5, 5, 6, 6]   # most alive at once on I Hate Myself
const MINI_MAX_PER_LEVEL := 8
const SEASONED_COIN_MULT := 2             # I Hate Myself pays double gold
const MINI_FIRST_DELAY := 15.0
const MINI_INTERVAL_SLOW := 30.0          # seconds between castles of one wave: 30 s early ...
const MINI_INTERVAL_FAST := 14.0          # ... down to 14 s at level 30+
var _mini_budget: int = 0                 # castles still to come on this level
var _mini_last_level: int = -10           # last level that had one (Beginner gets a breather after it)
const XP_MULT := 1.5              # every mob gives this much more XP than its gold reward
const COIN_MULT := 10              # every gold reward is multiplied by this
var _mini_timer: float = 0.0
var _power_timer: float = 0.0
var _cam_prev: Vector2 = Vector2.ZERO
const SPAWN_DIST_MIN := 1650.0     # enemies appear this far (min..max) from the castle (just outside the wider view)
const SPAWN_DIST_MAX := 1900.0
var camera: Camera2D
var hud: Hud
var vignette: DamageVignette
var _show_details: bool = false
var banner: Label
var pause_panel: PanelContainer
var castle_menu: CastleMenu
var levelup_menu: LevelUpMenu
var pause_menu: PauseMenu
var hud_editor: HudEditor
var notifier: Notifier
var gameover_menu: GameOverMenu
var _level_snapshot: Dictionary = {}
var boss_label: Label
var _banner_t: float = 0.0

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
var dungeon_best: int = 0          # best wave reached in the Dungeon (kept in the hub profile)
var stat_time: float = 0.0
var _zoom_target: float = Settings.VIEW_ZOOM
var _clear_timer: float = -1.0
var _boss_level: bool = false
# Statistics of the running chapter (shown in the chapter summary, saved with the game)
var ch_dealt: float = 0.0
var ch_taken: float = 0.0
var ch_kills: int = 0
var ch_gold: int = 0
var ch_time: float = 0.0
var _dealt_seen: float = 0.0
var chapter_scene: ChapterScene
var _chapter_flow: bool = false          # true while the next chapter is built behind the clouds
# Map mode (Phase 1 of the Hub & Maps overhaul): one handmade map instead of the endless waves
var map_run: MapRun
var _map_status: String = ""
var _map_done: bool = false
# Hub mode (Phase 2): the safe hub, the profile with the inventory and stash
var hub_field: HubField
var hub_panel: HubPanel
var inv: Dictionary = {}
var stash: Dictionary = {}
var cleared: Array = []
const BOSS_RESPAWN := 300.0          # seconds; counts in the hub too (it is real time)
var boss_dead: Dictionary = {}       # map id -> unix time the boss was killed
const MINI_NAMES := ["Pirate Castle", "Sky Raider", "Rogue One"]
const DEATH_XP_LOSS := 0.10

func _ready() -> void:
	PixelUI.setup(get_tree())
	# Main keeps running while the tree is paused so it can handle the pause keys.
	# Gameplay nodes (base, enemies, projectiles) are set to pause themselves.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.load_and_apply()

	backdrop = BackdropGrid.new()
	base = Base.new()
	base.position = BASE_POS
	var data := GameState.pending_load
	GameState.pending_load = {}
	if GameState.hub_mode or GameState.map_mode or GameState.dungeon_mode:
		data = Profile.get_data()
		dungeon_best = int(data.get("dungeon_best", 0))
		inv = Profile.int_dict(data.get("inv", {}))
		stash = Profile.int_dict(data.get("stash", {}))
		cleared = (data.get("cleared", []) as Array).duplicate()
		boss_dead = Profile.int_dict(data.get("boss_dead", {}))
	if not data.is_empty():
		_apply_save(data)
	if GameState.dungeon_mode:
		level = 1
		biome = 0
	elif GameState.map_mode:
		biome = MapRun.region_of(GameState.map_id)
	backdrop.setup(CONTENT[biome])
	add_child(backdrop)
	add_child(base)
	base.destroyed.connect(_on_base_destroyed)
	base.critical.connect(_on_player_crit)
	base.damaged.connect(_on_base_damaged)
	base.blocked.connect(_on_base_blocked)
	base.shield_broken.connect(_on_base_shield_broken)
	base.poisoned.connect(_on_base_poisoned)
	base.burning.connect(_on_base_burning)
	base.status.connect(func(t: String, _k: String) -> void: _notify(t, "hit", Color(0.85, 0.65, 0.3), "status"))

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
	weather.set_biome(CONTENT[biome])
	weather_layer.add_child(weather)

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	hud = Hud.new()
	hud.base = base
	layer.add_child(hud)

	vignette = DamageVignette.new()
	layer.add_child(vignette)

	notifier = Notifier.new()
	layer.add_child(notifier)

	boss_label = Label.new()
	boss_label.position = Vector2(0, 124)
	boss_label.custom_minimum_size = Vector2(Settings.WORLD_SIZE.x, 40)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", PixelUI.fs(30))
	boss_label.add_theme_constant_override("outline_size", 8)
	boss_label.add_theme_color_override("font_outline_color", Color.BLACK)
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	boss_label.visible = false
	layer.add_child(boss_label)

	banner = Label.new()
	banner.position = Vector2(0, 150)
	banner.custom_minimum_size = Vector2(Settings.WORLD_SIZE.x, 70)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", PixelUI.fs(52))
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.modulate.a = 0.0
	layer.add_child(banner)

	hud.attach("notifier", [notifier])
	hud.attach("bosswarn", [boss_label])
	hud.attach("banner", [banner])

	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2(Settings.WORLD_SIZE.x * 0.5 - 130.0, 24)
	pause_panel.custom_minimum_size = Vector2(260, 52)
	var sb := PixelUI.box(PixelUI.WIN_BG, PixelUI.BRONZE)
	sb.set_content_margin_all(24)
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	pause_panel.add_theme_stylebox_override("panel", sb)
	var pause_text := Label.new()
	pause_text.text = "GAME PAUSED"
	pause_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_text.add_theme_font_size_override("font_size", PixelUI.fs(26))
	pause_panel.add_child(pause_text)
	pause_panel.visible = false
	layer.add_child(pause_panel)

	castle_menu = CastleMenu.new()
	castle_menu.base = base
	castle_menu.class_chosen.connect(_on_class_chosen)
	castle_menu.picks_requested.connect(_open_levelup)
	castle_menu.hire_requested.connect(_on_hire)
	castle_menu.weapon_upgrade.connect(_on_castle_weapon)
	castle_menu.reset_pressed.connect(_on_castle_reset)
	castle_menu.laser_toggled.connect(_on_castle_laser)
	castle_menu.continue_pressed.connect(_close_castle)
	layer.add_child(castle_menu)

	levelup_menu = LevelUpMenu.new()
	levelup_menu.picked.connect(_on_buff_picked)
	levelup_menu.reroll_requested.connect(_on_reroll)
	layer.add_child(levelup_menu)

	pause_menu = PauseMenu.new()
	pause_menu.resume_requested.connect(_close_pause_menu)
	pause_menu.save_requested.connect(_save_game)
	pause_menu.quit_requested.connect(_on_pause_quit)
	layer.add_child(pause_menu)

	hud_editor = HudEditor.new()
	hud_editor.closed.connect(_on_hud_editor_closed)
	layer.add_child(hud_editor)
	pause_menu.edit_hud_requested.connect(_open_hud_editor)

	gameover_menu = GameOverMenu.new()
	gameover_menu.retry_requested.connect(_on_retry_pressed)
	gameover_menu.quit_requested.connect(_quit_to_menu)
	layer.add_child(gameover_menu)

	chapter_scene = ChapterScene.new()
	if GameState.map_mode:
		chapter_scene.continue_pressed.connect(_return_to_hub)      # leaving the finished map goes back to the hub
	else:
		chapter_scene.continue_pressed.connect(chapter_scene.start_transition)
	chapter_scene.covered.connect(_on_chapter_covered)
	chapter_scene.clouds_cleared.connect(_update_pause)
	layer.add_child(chapter_scene)

	hub_panel = HubPanel.new()
	hub_panel.fly_out.connect(_on_fly_out)
	hub_panel.sell.connect(_on_hub_sell)
	hub_panel.move_item.connect(_on_hub_move)
	hub_panel.reset_requested.connect(_on_hub_reset)
	hub_panel.buy_tier.connect(_on_buy_tier)
	hub_panel.closed.connect(_update_pause)
	layer.add_child(hub_panel)

	Enemy.dealt_total = 0.0
	_dealt_seen = 0.0
	if GameState.map_mode:
		_start_map()
	elif GameState.hub_mode:
		_start_hub()
	else:
		_start_level()
		if GameState.dungeon_mode:
			pause_menu.configure_quit("Return to the Hub", "Click again to leave the dungeon (items are kept)")
			_notify(Loc.t("The Dungeon: endless waves. Your castle, gold and loot are kept."), "skull", Color(1.0, 0.6, 0.3))
		if (level - 1) % LEVELS_PER_BIOME == 0:      # a new game (or a save that begins a chapter) opens with the chapter card
			chapter_scene.show_card(_chapter_info(biome))

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
	ch_dealt = maxf(float(st.get("ch_dealt", 0.0)), 0.0)
	ch_taken = maxf(float(st.get("ch_taken", 0.0)), 0.0)
	ch_kills = maxi(int(st.get("ch_kills", 0)), 0)
	ch_gold = maxi(int(st.get("ch_gold", 0)), 0)
	ch_time = maxf(float(st.get("ch_time", 0.0)), 0.0)
	biome = _biome_for(level)
	if d.get("hud") is Dictionary:           # the HUD layout belongs to the saved game
		HudLayout.load_dict(d["hud"] as Dictionary)
		Settings.save()

func _make_save_data() -> Dictionary:
	return {
		"version": GameState.SAVE_VERSION,
		"difficulty": GameState.difficulty,
		"level": level,
		"coins": coins,
		"base": base.to_dict(),
		"hud": HudLayout.snapshot(),
		"stats": {"kills": stat_kills, "gold": stat_gold, "bosses": stat_bosses, "best_wave": stat_best_wave, "time": stat_time,
			"ch_dealt": ch_dealt, "ch_taken": ch_taken, "ch_kills": ch_kills, "ch_gold": ch_gold, "ch_time": ch_time},
	}

func _fmt_time(sec: float) -> String:
	var t := int(sec)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

func _save_game() -> void:
	if map_run != null or hub_field != null or GameState.dungeon_mode:
		_commit_profile()
		Sfx.play("powerup")
		pause_menu.set_status(Loc.t("Saved: castle, gold and items."))
		return
	var data := _make_save_data()
	if GameState.write_save(data):
		Sfx.play("powerup")
		pause_menu.set_status(Loc.t("Game saved. You will resume at the start of Wave %d.") % level)
		_notify(Loc.t("Game saved"), "star", Color(1.0, 0.85, 0.3), "save")
	else:
		pause_menu.set_status(Loc.t("Could not save the game."))

func _open_hud_editor() -> void:
	pause_menu.close()
	hud_editor.open(hud)
	_update_pause()

func _on_hud_editor_closed() -> void:
	_store_hud_in_save()
	pause_menu.open()
	_update_pause()

# After the HUD editor closes the new layout goes into the running level's snapshot and the current save slot,
# so it is not lost if the game is closed before the next autosave.
func _store_hud_in_save() -> void:
	var h := HudLayout.snapshot()
	if not _level_snapshot.is_empty():
		_level_snapshot["hud"] = h
	var i := GameState.current_slot
	if i >= 0:
		var d := GameState.read_slot(i)
		if not d.is_empty():
			d["hud"] = h
			GameState.write_save(d)

func _close_pause_menu() -> void:
	pause_menu.close()
	_update_pause()

# Retry restarts the level you died on, with the base fully repaired.
func _retry_level() -> void:
	GameState.pending_load = _level_snapshot
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_retry_pressed() -> void:
	if map_run != null or GameState.dungeon_mode:
		_return_to_hub()
	else:
		_retry_level()

func _on_pause_quit() -> void:
	if map_run != null or GameState.dungeon_mode:
		_return_to_hub()
	else:
		_quit_to_menu()

func _quit_to_menu() -> void:
	_commit_profile()
	get_tree().paused = false
	Cursors.set_mode(Cursors.Mode.ARROW)
	get_tree().change_scene_to_file("res://menu.tscn")

# ---------- Levels, biomes, banner ----------

func _biome_for(lv: int) -> int:
	return mini(int((lv - 1) / float(LEVELS_PER_BIOME)), BIOME_NAMES.size() - 1)

func _start_level() -> void:
	var new_tier := mini(int((level - 1) / float(LEVELS_PER_TIER)), Base.TIER_NAMES.size() - 1)
	if new_tier != base.tier and not GameState.dungeon_mode:       # the Dungeon keeps the castle you bought in the Shipyard
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
	Enemy.terrain_biome = CONTENT[biome]
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
	_banner_t = 3.0
	Music.play(CONTENT[biome], _boss_level)
	if level % LEVELS_PER_BIOME == LEVELS_PER_BIOME - 2:
		Backdrop.request(CONTENT[mini(biome + 1, BIOME_NAMES.size() - 1)])      # build the next biome's terrain in the background
	_mini_budget = _mini_count(level)
	_mini_pending = _mini_budget > 0
	if _mini_budget > 0:
		_mini_last_level = level
	_mini_timer = MINI_FIRST_DELAY
	to_spawn = count
	spawn_timer = 1.5
	_clear_timer = -1.0
	if not _chapter_flow:
		_show_banner(title, _boss_level)
	_update_label()
	# Remember the state at the start of this level so Retry can restart it.
	_level_snapshot = _make_save_data()
	(_level_snapshot["base"] as Dictionary)["hp"] = base.max_hp
	stat_best_wave = maxi(stat_best_wave, level)
	_level_snapshot["stats"] = (_make_save_data()["stats"] as Dictionary)
	if GameState.dungeon_mode:
		dungeon_best = maxi(dungeon_best, level)
		_commit_profile()
	elif Settings.autosave and GameState.write_save(_level_snapshot):
		_notify(Loc.t("Autosaved"), "star", Color(1.0, 0.85, 0.3), "save")

# ---------- Hub mode ----------

func _start_hub() -> void:
	biome = 0
	Enemy.space_mode = false
	Enemy.terrain_biome = 0
	boss_pending = false
	to_spawn = 0
	_boss_level = false
	_mini_pending = false
	_mini_budget = 0
	Music.play(0, false)
	base.can_fire = false
	base.hp = base.max_hp
	hub_field = HubField.new()
	hub_field.setup(BASE_POS)
	add_child(hub_field)
	move_child(hub_field, backdrop.get_index() + 1)
	backdrop.visible = false            # the hub draws its own sky
	weather.visible = false
	pause_menu.configure_quit("Quit to Main Menu", "Click again to confirm")
	_map_status = Loc.t("Safe harbour: no enemies here")
	_show_banner(Loc.t("The Hub"), false)
	_notify(Loc.t("Click a building to use it. Fly closer if it is far away."), "star", Color(1.0, 0.85, 0.3))
	_update_label()

# Writes the castle, gold and items to the hub profile (the castle is repaired, items are never lost).
func _commit_profile() -> void:
	if not (GameState.hub_mode or GameState.map_mode or GameState.dungeon_mode) or base == null:
		return
	var bd := base.to_dict()
	bd["hp"] = base.max_hp
	Profile.data = {"base": bd, "coins": coins, "inv": inv.duplicate(), "stash": stash.duplicate(), "cleared": cleared.duplicate(), "boss_dead": boss_dead.duplicate(), "dungeon_best": dungeon_best}
	Profile.save()

# Seconds until the boss of a map is back (0 = ready). Real time, so it keeps counting while you are in the hub.
func _boss_left(map_id: String) -> int:
	if not boss_dead.has(map_id):
		return 0
	var passed := Time.get_unix_time_from_system() - float(boss_dead[map_id])
	if passed < 0.0:
		return int(BOSS_RESPAWN)          # the clock went backwards: never lock the boss for longer than the cooldown
	return maxi(int(ceil(BOSS_RESPAWN - passed)), 0)

func _boss_times() -> Dictionary:
	var d := {}
	for id: String in MapRun.IDS:
		d[id] = _boss_left(id)
	return d

func _clock(sec: int) -> String:
	return "%d:%02d" % [sec / 60, sec % 60]

func _return_to_hub() -> void:
	_commit_profile()
	GameState.dungeon_mode = false
	GameState.hub_mode = true
	GameState.map_mode = false
	GameState.pending_load = {}
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_fly_out(id: String) -> void:
	if id == "dungeon":
		if int(inv.get("sigil", 0)) + int(stash.get("sigil", 0)) < 1:
			return
		_take_material("sigil", 1)          # the pass is used up when you enter
		_commit_profile()
		GameState.hub_mode = false
		GameState.map_mode = false
		GameState.dungeon_mode = true
		GameState.pending_load = {}
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	_commit_profile()
	if not MapRun.IDS.has(id):
		id = "greenland"
	var need := MapRun.needs(id)
	if need != "" and not cleared.has(need):
		return                               # locked until the previous region's boss is down
	GameState.map_id = id
	GameState.hub_mode = false
	GameState.dungeon_mode = false
	GameState.map_mode = true
	GameState.pending_load = {}
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_hub_reset() -> void:
	Profile.reset()
	GameState.pending_load = {}
	get_tree().paused = false
	get_tree().reload_current_scene()

func _refresh_hub() -> void:
	hub_panel.inv = inv
	hub_panel.stash = stash
	hub_panel.coins = coins
	hub_panel.cleared = cleared
	hub_panel.dungeon_best = dungeon_best
	hub_panel.tier = base.tier
	hub_panel.boss_left = _boss_times()
	hub_panel.rebuild()

func _click_station() -> void:
	var st := hub_field.station_at(get_global_mouse_position())
	if st.is_empty():
		return
	if base.position.distance_to(st["pos"] as Vector2) > HubField.USE_DIST:
		_notify(Loc.t("Fly closer to the %s") % Loc.t(str(st["name"])), "hit", Color(1.0, 0.6, 0.3), "far")
		return
	Sfx.play("click")
	if str(st["id"]) == "workshop":
		_open_castle("")
		return
	hub_panel.inv = inv
	hub_panel.stash = stash
	hub_panel.coins = coins
	hub_panel.cleared = cleared
	hub_panel.dungeon_best = dungeon_best
	hub_panel.tier = base.tier
	hub_panel.boss_left = _boss_times()
	hub_panel.open(str(st["id"]))
	_update_pause()

func _on_hub_sell(id: String, count: int) -> void:
	var n := mini(count, int(inv.get(id, 0)))
	if n <= 0:
		return
	coins += n * Items.price_of(id)
	inv[id] = int(inv[id]) - n
	if int(inv[id]) <= 0:
		inv.erase(id)
	Sfx.play("powerup", -4.0)
	_commit_profile()
	_update_label()
	_refresh_hub()

# Takes a material from the bag first, then from the stash.
func _take_material(id: String, n: int) -> void:
	var from_bag := mini(n, int(inv.get(id, 0)))
	if from_bag > 0:
		inv[id] = int(inv[id]) - from_bag
		if int(inv[id]) <= 0:
			inv.erase(id)
	var rest := n - from_bag
	if rest > 0:
		stash[id] = int(stash.get(id, 0)) - rest
		if int(stash[id]) <= 0:
			stash.erase(id)

func _on_buy_tier() -> void:
	var t := base.tier
	if t >= Base.TIER_NAMES.size() - 1:
		return
	var cost := Items.tier_cost(t)
	if coins < int(cost["gold"]):
		return
	for id: String in ["shard", "resin", "heart"]:
		if int(inv.get(id, 0)) + int(stash.get(id, 0)) < int(cost[id]):
			return
	coins -= int(cost["gold"])
	for id: String in ["shard", "resin", "heart"]:
		if int(cost[id]) > 0:
			_take_material(id, int(cost[id]))
	base.set_tier(t + 1)
	Sfx.play("weapon_up")
	_add_shake(8.0)
	_notify(Loc.t("Your settlement grew into a %s!") % Loc.t(Base.TIER_NAMES[t + 1]), "star", Color(1.0, 0.85, 0.3))
	_commit_profile()
	_update_label()
	_refresh_hub()

func _on_hub_move(id: String, to_stash: bool, count: int) -> void:
	var src: Dictionary = inv if to_stash else stash
	var dst: Dictionary = stash if to_stash else inv
	var n := mini(int(src.get(id, 0)), maxi(count, 1))
	if n <= 0:
		return
	src[id] = int(src[id]) - n
	if int(src[id]) <= 0:
		src.erase(id)
	dst[id] = int(dst.get(id, 0)) + n
	Sfx.play("click")
	_commit_profile()
	_refresh_hub()

# Loot goes straight into the bag (never lost on death).
func _roll_loot(e: Enemy) -> void:
	for d: Array in Items.roll_drops(e.kind, e.is_small, not cleared.has(GameState.map_id)):
		var id := str(d[0])
		var n := int(d[1])
		if id == "sigil" and GameState.dungeon_mode:
			continue                  # the Dungeon never pays for its own entry pass
		inv[id] = int(inv.get(id, 0)) + n
		_notify("+%d %s" % [n, Items.name_of(id)], id, Items.color_of(id), "loot_" + id)

# ---------- Map mode ----------

func _start_map() -> void:
	map_run = MapRun.make(GameState.map_id, BASE_POS)
	biome = map_run.biome
	Enemy.space_mode = false
	Enemy.terrain_biome = CONTENT[biome]
	boss_pending = false
	to_spawn = 0
	_boss_level = false
	_mini_pending = false
	_mini_budget = 0
	Music.play(CONTENT[biome], false)
	pause_menu.configure_quit("Return to the Hub", "Click again to leave the map (items are kept)")
	map_run.zone_woke.connect(_on_zone_woke)
	map_run.zone_cleared.connect(_on_zone_cleared)
	map_run.danger_near.connect(_on_zone_danger)
	if _boss_left(map_run.map_id) > 0:
		map_run.boss["done"] = true          # the boss is still down: its arena stays quiet until it respawns
	add_child(map_run)
	move_child(map_run, backdrop.get_index() + 1)       # drawn on the ground, under the castle and the mobs
	_show_banner(Loc.t(map_run.map_name), false)
	_notify(Loc.t("Follow the arrow. Clear the zones, then defeat the boss."), "skull", Color(1.0, 0.85, 0.3))
	_level_snapshot = _make_save_data()
	(_level_snapshot["base"] as Dictionary)["hp"] = base.max_hp
	_update_map_status()
	_update_label()

func _update_map_status() -> void:
	if map_run == null:
		return
	if _map_done:
		_map_status = Loc.t("Map cleared!")
	elif bool(map_run.boss["done"]):
		_map_status = Loc.t("Zones cleared: %d / %d") % [map_run.zones_cleared(), map_run.zones_total()] + "   " + Loc.t("Boss returns in %s") % _clock(_boss_left(map_run.map_id))
	elif bool(map_run.boss["awake"]):
		_map_status = Loc.t("Defeat the %s!") % Loc.t(BOSS_NAMES[biome])
	else:
		_map_status = Loc.t("Zones cleared: %d / %d") % [map_run.zones_cleared(), map_run.zones_total()]

# A zone wakes: its pack appears around the zone centre and charges the castle.
func _on_zone_woke(z: Dictionary) -> void:
	var mobs: Array = z["mobs"]
	var lvl := int(z["lvl"])
	var mult := float(z["mult"])
	var centre: Vector2 = z["pos"]
	for entry: Array in z["pack"]:
		for i in int(entry[1]):
			if alive >= MAX_ALIVE:
				break
			var e := Enemy.make(str(entry[0]), lvl)
			e.hp *= mult
			e.max_hp = e.hp
			e.reward = int(ceil(float(e.reward) * mult))
			var p := centre + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 300.0)
			for k in 8:
				if not Backdrop.liquid_at(CONTENT[biome], p):
					break
				p = centre + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 300.0)
			e.position = p
			e.target = base.position
			e.reach = base.hit_radius()
			alive += 1
			_register_mob(e)
			mobs.append(e)
	Sfx.play("boss_spawn", -10.0)
	_notify(Loc.t("Pack spotted!"), "skull", Color(1.0, 0.6, 0.3), "zone")
	_update_map_status()
	_update_label()

func _on_zone_cleared(_z: Dictionary) -> void:
	Sfx.play("win", -6.0)
	_notify(Loc.t("Zone cleared!"), "star", Color(0.5, 1.0, 0.6), "zone")
	_update_map_status()
	_update_label()

func _on_zone_danger(_z: Dictionary) -> void:
	Sfx.play("boss_spawn", -8.0)
	_show_banner(Loc.t("Warning: dangerous area!"), true)
	_notify(Loc.t("Warning: dangerous area!"), "skull", Color(1.0, 0.3, 0.25), "danger")

func _wake_map_boss() -> void:
	map_run.boss["awake"] = true
	_show_banner(Loc.t("Warning: dangerous area!"), true)
	_spawn_boss(int(map_run.boss["lvl"]), map_run.boss["pos"] as Vector2)
	_update_map_status()
	_update_label()

func _map_complete() -> void:
	if _map_done:
		return
	_map_done = true
	map_run.boss["done"] = true
	if not cleared.has(map_run.map_id):
		cleared.append(map_run.map_id)
	boss_dead[map_run.map_id] = int(Time.get_unix_time_from_system())
	_commit_profile()
	_update_map_status()
	_update_label()
	get_tree().create_timer(3.0).timeout.connect(_show_map_summary)

func _show_map_summary() -> void:
	var info := {"title": Loc.t("MAP COMPLETE"), "sub": map_run.map_name, "button": "Return to the Hub"}
	info["rows"] = [
		{"label": "Damage dealt", "num": ch_dealt},
		{"label": "Damage taken", "num": ch_taken},
		{"label": "Mobs defeated", "num": float(ch_kills)},
		{"label": "Gold earned", "num": float(ch_gold)},
		{"label": "Time", "text": _fmt_time(ch_time)},
		{"label": "Boss defeated", "text": Loc.t(BOSS_NAMES[biome])},
	]
	chapter_scene.show_summary(info)
	_update_pause()

func _change_biome(new_biome: int) -> void:
	biome = new_biome
	var old := backdrop
	var fresh := BackdropGrid.new()
	fresh.setup(CONTENT[new_biome])
	fresh.follow(camera.position)
	weather.set_biome(CONTENT[new_biome])
	fresh.modulate.a = 0.0
	add_child(fresh)
	move_child(fresh, old.get_index() + 1)
	backdrop = fresh
	if _chapter_flow:                    # behind the clouds: no slow fade needed
		fresh.modulate.a = 1.0
		old.queue_free()
		return
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
	if base != null and base.picks > 0 and not game_over and not levelup_menu.visible and not castle_menu.visible and not pause_menu.visible and not hud_editor.visible and not hub_panel.visible and not _manual_paused and (chapter_scene == null or not chapter_scene.blocking()):
		_open_levelup()
	_update_camera(delta)
	if _manual_paused:
		# Blink the "game paused" popup until the game resumes
		pause_panel.visible = int(Time.get_ticks_msec() / 500.0) % 2 == 0
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			boss_label.visible = false
	if _boss_level and boss_label.visible:
		boss_label.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0))
	if get_tree().paused:
		return
	_update_shake(delta)
	if not game_over:
		stat_time += delta
		ch_time += delta
		ch_dealt += Enemy.dealt_total - _dealt_seen
	_dealt_seen = Enemy.dealt_total
	if map_run != null and not game_over:
		base.position = map_run.clamp_pos(base.position)
		map_run.tick(base.position, delta)
		if map_run.boss_ready():
			_wake_map_boss()
	if hub_field != null:
		base.position = hub_field.clamp_pos(base.position)
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
				if _minis_alive() < _mini_cap():
					_spawn_mini_boss()
					_mini_budget -= 1
					if _mini_budget <= 0:
						_mini_pending = false
				_mini_timer = lerpf(MINI_INTERVAL_SLOW, MINI_INTERVAL_FAST, Power.level_t(level))
			else:
				_mini_pending = false      # no normal mobs standing: no more Rogue Castles this level
	_power_timer -= delta
	if _power_timer <= 0.0:
		_power_timer = 0.5
		if hub_panel.visible and hub_panel.page == "map":
			hub_panel.set_boss_left(_boss_times())
		if map_run != null and not _map_done and bool(map_run.boss["done"]):
			if _boss_left(map_run.map_id) <= 0:
				map_run.boss["done"] = false           # the boss respawned while you were in the map
				_notify(Loc.t("The boss has returned!"), "skull", Color(1.0, 0.4, 0.3), "bossback")
			_update_map_status()
		alive = _count_hostiles()        # the running counter can drift; the real count is the truth
		_update_label()
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and alive < MAX_ALIVE:
			_spawn_mob()
			to_spawn -= 1
			spawn_timer = maxf(0.08, maxf(0.35, 2.0 - level * 0.1) / _spawn_rate()) * GameState.interval_mult()
	elif map_run == null and hub_field == null and not boss_pending and _count_hostiles() == 0:
		if _clear_timer < 0.0:
			_clear_timer = 0.8
		_clear_timer -= delta
		if _clear_timer <= 0.0:
			_clear_timer = -1.0
			_level_cleared()
	else:
		_clear_timer = -1.0

# The real number of hostile mobs standing right now (bosses and Rogue Castles included).
# The wave is cleared and spawning is capped from this, never from a counter that can drift.
func _count_hostiles() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.dead and not e.is_queued_for_deletion():
			n += 1
	return n

func _update_pause() -> void:
	get_tree().paused = _manual_paused or levelup_menu.visible or castle_menu.visible or pause_menu.visible or hud_editor.visible or hub_panel.visible or chapter_scene.blocking()
	if not _manual_paused:
		pause_panel.visible = false

# ---------- Cursor and screen shake ----------

func _update_cursor() -> void:
	if get_tree().paused or game_over or hub_field != null:
		Cursors.set_mode(Cursors.Mode.ARROW)
		return
	var mouse := get_global_mouse_position()
	var over := false
	for e in Field.near(mouse, 12.0):
		if not e.is_ally and not e.dead and mouse.distance_to(e.global_position) <= e.radius + 12.0:
			over = true
			break
	Cursors.set_mode(Cursors.Mode.AGGRESSIVE if over else Cursors.Mode.CROSSHAIR)
	Cursors.tick()

# The castle stays in the centre of the screen; the world (backdrop, enemies, weather)
# scrolls past it. Mouse-wheel zoom is smooth.
func _update_camera(delta: float) -> void:
	_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-10.0 * delta))
	camera.zoom = Vector2(_zoom, _zoom)
	camera.position = base.position
	var vs := get_viewport_rect().size / maxf(_zoom, 0.05)
	Enemy.view_rect = Rect2(camera.position - vs * 0.5, vs).grow(800.0)
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
	ch_taken += amount
	_add_shake(minf(7.0 + amount * 3.0, 24.0))
	vignette.flash(minf(0.55 + amount * 0.12, 1.0))
	Sfx.play("base_hit")
	_notify(Loc.t("Taken Damage!  -%d") % int(ceil(amount)), "hit", Color(1.0, 0.3, 0.3), "dmg")
	_update_label()

func _on_base_blocked() -> void:
	Sfx.play("block")
	_notify(Loc.t("Absorbed by the Energy Shield!"), "eshield", Color(0.4, 0.85, 1.0), "block")

func _on_base_shield_broken() -> void:
	Sfx.play("boss_phase", -6.0)
	_add_shake(10.0)
	_notify(Loc.t("Energy Shield down!"), "eshield", Color(1.0, 0.55, 0.3), "eshield")

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
		_begin_chapter_end(_biome_for(cleared))
		return
	_start_level()
	spawn_timer = 3.5            # a short breather before the next wave

# ---------- Chapter end: summary window, clouds, title card ----------

func _chapter_info(idx: int) -> Dictionary:
	idx = clampi(idx, 0, CHAPTER_TITLES.size() - 1)
	return {"roman": ChapterScene.ROMAN[idx], "name": CHAPTER_TITLES[idx], "tag": CHAPTER_TAGS[idx]}

func _begin_chapter_end(idx: int) -> void:
	var info := _chapter_info(idx)
	info["rows"] = [
		{"label": "Damage dealt", "num": ch_dealt},
		{"label": "Damage taken", "num": ch_taken},
		{"label": "Mobs defeated", "num": float(ch_kills)},
		{"label": "Gold earned", "num": float(ch_gold)},
		{"label": "Time", "text": _fmt_time(ch_time)},
		{"label": "Boss defeated", "text": Loc.t(BOSS_NAMES[clampi(idx, 0, BOSS_NAMES.size() - 1)])},
	]
	ch_dealt = 0.0
	ch_taken = 0.0
	ch_kills = 0
	ch_gold = 0
	ch_time = 0.0
	# Save now, with the new wave number: quitting from the summary must not make the player fight the boss again.
	var snap := _make_save_data()
	(snap["base"] as Dictionary)["hp"] = base.max_hp
	if GameState.dungeon_mode:
		_commit_profile()
	elif Settings.autosave:
		GameState.write_save(snap)
	chapter_scene.show_summary(info)
	_update_pause()

# The clouds cover the screen: build the next chapter now.
func _on_chapter_covered() -> void:
	_chapter_flow = true
	_start_level()
	_chapter_flow = false
	spawn_timer = 4.5
	chapter_scene.show_card(_chapter_info(biome))
	chapter_scene.release()

# Kills give XP equal to their reward (summoned fodder gives none). Every new level = 5 stat points.
func _gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	var gained := base.add_xp(amount)
	if gained > 0:
		base.play_level_up()
		Sfx.play("weapon_up", -2.0)
		_notify(Loc.t("Level up!  Level %d") % base.xp_level, "star", Color(0.5, 1.0, 0.6), "levelup")
		if castle_menu.visible:
			_refresh_castle()

# ---------- Mobs ----------

# A point at a fixed distance (min..max) from the castle, in a random direction.
func _edge_spawn_pos() -> Vector2:
	return base.position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX)

# A spawn point that is not in water or lava (walking units start on dry land).
func _ground_spawn_pos() -> Vector2:
	var p := _edge_spawn_pos()
	for i in 12:
		if not Backdrop.liquid_at(CONTENT[biome], p):
			break
		p = _edge_spawn_pos()
	return p

const BIOME_ENEMY_NOTES := [
	"",
	"Bloodworms swarm in - tiny, very fast and fragile!",
	"Golems approach - they split into a smaller golem when destroyed!",
	"Anglers crawl up from the trench and a naval fleet closes in - destroyers, cruisers, missile cruisers and carriers!",
	"Thornlings creep out of the hedges - they spit thorns from a distance!",
	"Stalkers prowl the dark - fast, and they pounce from a distance!",
	"Demons rise from the lava - tough, fast and brutal!",
	"Heralds descend - flying angels that shoot bolts of light!",
	"Hunter packs incoming - they dodge a lot and shoot from far away!",
]

# Spawn-rate multiplier: x3 in every biome, +0.20 per level on top (level 11 = x9).
func _spawn_rate() -> float:
	return SPAWN_RATE_BASE * (1.0 + SPAWN_RATE_PER_LEVEL * float(level - 1))

# Biome-unique rosters (from the Deep Ocean on): [kind, weight, minimum chapter-local level] - they replace the traditional mobs.
const ROSTERS := {
	5: [["cursed", 36.0, 0], ["thornling", 18.0, 0], ["cgren", 16.0, 1], ["crpg", 18.0, 1], ["cmini", 14.0, 2], ["aatruck", 12.0, 2]],
	3: [["ant", 44.0, 0], ["antwarden", 20.0, 0], ["antspitter", 18.0, 1], ["antflyer", 16.0, 1], ["stalker", 12.0, 0], ["antking", 5.0, 3], ["antqueen", 5.0, 3],
		["troll", 26.0, 2], ["trollwarrior", 16.0, 3], ["trollcaptain", 12.0, 4], ["trollking", 4.0, 6], ["titan", 5.0, 7]],
	4: [["soul", 40.0, 0], ["herald", 22.0, 0], ["wisp", 20.0, 1], ["fallen", 8.0, 2]],
	6: [["destroyer", 30.0, 0], ["cruiser", 22.0, 0], ["missilecruiser", 16.0, 2], ["carrier", 2.0, 5], ["angler", 14.0, 0],
		["phantom", 24.0, 0], ["falcon", 18.0, 1], ["warthog", 14.0, 3], ["stealth", 8.0, 5]],
}

func _roster_ok(it: Array, local: int, counts: Dictionary) -> bool:
	if local < int(it[2]):
		return false
	if it[0] == "carrier" and int(counts.get("carrier", 0)) >= 1:
		return false
	if it[0] == "stealth" and int(counts.get("stealth", 0)) >= 3:
		return false
	if it[0] == "fallen" and int(counts.get("fallen", 0)) >= 4:
		return false
	if (it[0] == "antking" or it[0] == "antqueen" or it[0] == "trollking") and int(counts.get(it[0], 0)) >= 1:
		return false
	if it[0] == "titan" and int(counts.get("titan", 0)) >= 2:
		return false
	return true

func _roster_pick(list: Array) -> String:
	var local := level - biome * 10
	var counts := {}
	for node in get_tree().get_nodes_in_group("enemies"):
		var ce := node as Enemy
		if ce != null and not ce.dead:
			counts[ce.kind] = int(counts.get(ce.kind, 0)) + 1
	var total := 0.0
	for it: Array in list:
		if _roster_ok(it, local, counts):
			total += float(it[1])
	var r := randf() * total
	for it: Array in list:
		if _roster_ok(it, local, counts):
			r -= float(it[1])
			if r <= 0.0:
				return str(it[0])
	return ""

func _pick_kind() -> String:
	var special := ""
	var w_special := 0.0
	match CONTENT[biome]:
		1:
			special = "worm"
			w_special = 40.0
		2:
			special = "golem"
			w_special = 22.0
		3:
			special = "stalker"
			w_special = 34.0
		4:
			special = "herald"
			w_special = 24.0
		5:
			special = "thornling"
			w_special = 26.0
		6:
			special = "angler"
			w_special = 24.0
		7:
			special = "demon"
			w_special = 16.0
		8:
			special = "hunter"
			w_special = 14.0
	var w_mech := 0.0 if level < 2 else minf(18.0 + level * 1.5, 40.0)
	var w_tank := 0.0 if level < 3 else minf(10.0 + level * 1.5, 30.0)
	var w_medic := 0.0 if level < 6 else minf(4.0 + level * 0.5, 12.0)
	var w_aegis := 0.0 if level < 9 else minf(3.0 + level * 0.4, 12.0)
	var w_heavy := 0.0 if level < 8 else minf(3.0 + level * 0.4, 14.0)
	var w_apoc := 0.0 if level < 14 else minf(1.5 + level * 0.2, 8.0)
	var w_soldier := 100.0
	if ROSTERS.has(CONTENT[biome]):
		var rk := _roster_pick(ROSTERS[CONTENT[biome]])
		if rk != "":
			return rk
	if CONTENT[biome] == 7:
		# Hell: Apocalypse Tanks instead of Medics and Aegis, Devils instead of Mechs, half as many Soldiers, 50% more Devils
		w_apoc += w_medic + w_aegis
		w_medic = 0.0
		w_aegis = 0.0
		w_soldier = 50.0
		w_special = (w_special + w_mech) * 1.5
		w_mech = 0.0
	var total := w_soldier + w_mech + w_tank + w_special + w_medic + w_aegis + w_heavy + w_apoc
	var r := randf() * total
	if r < w_special:
		return special
	r -= w_special
	if r < w_tank:
		return "tank"
	r -= w_tank
	if r < w_heavy:
		return "heavytank"
	r -= w_heavy
	if r < w_apoc:
		return "apoctank"
	r -= w_apoc
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
	e.launch.connect(_on_enemy_launch)
	e.request.connect(_on_enemy_request)
	e.shake.connect(_add_shake)
	if e.shoots:
		e.shoot.connect(_on_tank_shoot)
	if deferred:
		add_child.call_deferred(e)
	else:
		add_child(e)

func _spawn_mob() -> void:
	var e: Enemy
	if Base.HELPERS_ON and biome != SPACE_BIOME and randf() < ALLY_CHANCE:   # no refugees in space (and none while helpers are switched off)
		e = Enemy.make_ally()
	else:
		var k := _pick_kind()
		if k == "hunter":
			_spawn_hunters()
			return
		e = Enemy.make(k, level)
		alive += 1
		if k == "carrier":
			_notify(Loc.t("An Aircraft Carrier approaches!  Shoot down its jets!"), "skull", Color(0.6, 0.85, 1.0))
	e.position = _ground_spawn_pos()
	e.target = base.position
	e.reach = base.hit_radius()
	_register_mob(e)

# Hunters arrive as a pack of five.
func _spawn_hunters() -> void:
	var center := _edge_spawn_pos()
	for i in 5:
		var h := Enemy.make("hunter", level)
		h.position = center + Vector2.RIGHT.rotated(TAU * float(i) / 5.0) * 50.0
		h.target = base.position
		h.reach = base.hit_radius()
		alive += 1
		_register_mob(h)

func _spawn_soldier_at(pos: Vector2) -> void:
	var s := Enemy.make("soldier", level)
	s.position = pos
	s.target = base.position
	s.reach = base.hit_radius()
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
		m.reach = base.hit_radius()
		alive += 1
		_register_mob(m, true)

# Mud Golems called by the Mud Colossus in a ring around the castle (no gold, vanish with the boss, at most 12 alive).
func _spawn_mud_golems(center: Vector2, count: int) -> void:
	var live := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var ex := node as Enemy
		if ex != null and ex.mud and not ex.dead:
			live += 1
	var a0 := randf() * TAU
	for i in mini(count, 12 - live):
		if alive >= MAX_ALIVE:
			break
		var m := Enemy.make_mud_golem(level)
		m.position = center + Vector2.RIGHT.rotated(a0 + TAU * float(i) / float(count)) * randf_range(280.0, 360.0)
		m.target = base.position
		m.reach = base.hit_radius()
		m._scale_pop = 0.25
		alive += 1
		_register_mob(m, true)
	Sfx.play("boss_summon", -3.0)

# Bees summoned by the Garden Warden (no gold, vanish with the boss).
func _spawn_bees(pos: Vector2, count: int) -> void:
	for i in count:
		if alive >= MAX_ALIVE:
			break
		var m := Enemy.make_bee(level)
		m.position = pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 110.0)
		m.target = base.position
		m.reach = base.hit_radius()
		alive += 1
		_register_mob(m, true)

# Trolls and Titans called by the Elite Titan (no gold, vanish with the boss; at most 2 Titans at a time).
func _spawn_boss_trolls(pos: Vector2, count: int) -> void:
	var kinds := ["troll", "troll", "trollwarrior", "trollcaptain", "titan"]
	for i in count:
		if alive >= MAX_ALIVE:
			break
		var kd: String = kinds[randi() % kinds.size()]
		if kd == "titan":
			var tn := 0
			for node in get_tree().get_nodes_in_group("minions"):
				if node is Enemy and node.kind == "titan":
					tn += 1
			if tn >= 2:
				kd = "trollwarrior"
		var m := Enemy.make(kd, level)
		m.hp *= 0.3 if kd == "titan" else 0.5
		m.max_hp = m.hp
		m.reward = 0
		m.is_minion = true
		m.position = pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 170.0)
		m.target = base.position
		m.reach = base.hit_radius()
		alive += 1
		_register_mob(m, true)

# Pillars raised around the castle by the Elite Titan: they pin it down until they are shot to pieces.
func _spawn_pillars(center: Vector2, count: int) -> void:
	var have := 0
	for node in get_tree().get_nodes_in_group("minions"):
		if node is Enemy and node.kind == "pillar":
			have += 1
	for i in count:
		if have >= 5:
			break
		have += 1
		var m := Enemy.make("pillar", level)
		m.is_minion = true
		var a := TAU * (float(i) + randf() * 0.5) / float(maxi(count, 1))
		m.position = center + Vector2.RIGHT.rotated(a) * randf_range(140.0, 210.0)
		m.target = base.position
		m.reach = 0.0
		Fx.spawn(self, "explosion", m.position, Color(0.7, 0.7, 0.7), "", 1.2, 0.5)
		alive += 1
		_register_mob(m, true)

# Stalkers called by the Savage Behemoth (no gold, vanish with the boss).
func _spawn_stalkers(pos: Vector2, count: int) -> void:
	for i in count:
		if alive >= MAX_ALIVE:
			break
		var m := Enemy.make_stalker_minion(level)
		m.position = pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 140.0)
		m.target = base.position
		m.reach = base.hit_radius()
		alive += 1
		_register_mob(m, true)

# Heralds called by the Fallen Seraph (no gold, vanish with the boss).
func _spawn_heralds(pos: Vector2, count: int) -> void:
	for i in count:
		if alive >= MAX_ALIVE:
			break
		var m := Enemy.make_herald_minion(level)
		m.position = pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 140.0)
		m.target = base.position
		m.reach = base.hit_radius()
		alive += 1
		_register_mob(m, true)

# Thornlings called by the Thorn Queen (no gold, vanish with the boss).
func _spawn_thornlings(pos: Vector2, count: int) -> void:
	for i in count:
		if alive >= MAX_ALIVE:
			break
		var m := Enemy.make_thornling_minion(level)
		m.position = pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 140.0)
		m.target = base.position
		m.reach = base.hit_radius()
		alive += 1
		_register_mob(m, true)

# Anglers called by the Leviathan (no gold, vanish with the boss).
func _spawn_anglers(pos: Vector2, count: int) -> void:
	for i in count:
		if alive >= MAX_ALIVE:
			break
		var m := Enemy.make_angler_minion(level)
		m.position = pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 140.0)
		m.target = base.position
		m.reach = base.hit_radius()
		alive += 1
		_register_mob(m, true)

func _on_boss_bomb(origin: Vector2, dest: Vector2) -> void:
	var b := PetekBomb.new()
	b.start = origin
	b.dest = dest
	b.base_ref = base
	add_child(b)

func _spawn_boss(boss_lvl: int = -1, at: Vector2 = Vector2.INF) -> void:
	var b := Boss.make_boss(level if boss_lvl < 0 else boss_lvl, CONTENT[biome])
	b.boss_name = Loc.t(BOSS_NAMES[biome])
	b.position = _edge_spawn_pos() if at == Vector2.INF else at
	b.target = base.position
	b.died.connect(_on_enemy_died)
	b.summon.connect(_spawn_minions)
	b.summon_lesser.connect(_on_boss_lesser)
	b.bolt.connect(_on_boss_bolt)
	b.beam.connect(_on_boss_beam)
	b.void_fire.connect(_on_void_fire)
	b.summon_bees.connect(_spawn_bees)
	b.summon_golems.connect(_spawn_mud_golems)
	b.summon_stalkers.connect(_spawn_stalkers)
	b.summon_trolls.connect(_spawn_boss_trolls)
	b.summon_pillars.connect(_spawn_pillars)
	b.summon_heralds.connect(_spawn_heralds)
	b.summon_thornlings.connect(_spawn_thornlings)
	b.summon_anglers.connect(_spawn_anglers)
	b.bomb.connect(_on_boss_bomb)
	b.announce.connect(_on_boss_announce)
	b.breath.connect(_on_boss_breath)
	b.hell_arrow.connect(_on_hell_arrow)
	b.hazard.connect(_on_boss_hazard)
	b.launch.connect(_on_enemy_launch)
	b.shake.connect(_add_shake)
	b.raged.connect(func() -> void: _add_shake(26.0))
	add_child(b)
	alive += 1
	Sfx.play("boss_spawn")
	_notify(Loc.t("%s approaches!") % Loc.t(BOSS_NAMES[biome]), "skull", Color(0.8, 0.4, 1.0))

func _on_boss_lesser(pos: Vector2, hp: float, dmg: float, spd: float) -> void:
	var e := Enemy.make_void_lesser(hp, dmg, spd)
	e.position = pos
	e.target = base.position
	e.reach = base.hit_radius()
	alive += 1
	_register_mob(e, true)

func _on_boss_hazard(style: String, pos: Vector2, rad: float, delay: float, dmg: float, opts: Dictionary) -> void:
	var h := Hazard.new()
	h.style = style
	h.position = pos
	h.radius = rad
	h.delay = delay
	h.damage = dmg
	h.base_ref = base
	h.linger = float(opts.get("linger", 0.0))
	h.pull = float(opts.get("pull", 0.0))
	h.slow_factor = float(opts.get("slow_factor", 1.0))
	h.slow_time = float(opts.get("slow_time", 0.0))
	h.true_damage = bool(opts.get("true_damage", false))
	h.ring_speed = float(opts.get("ring_speed", 700.0))
	h.tint = opts.get("tint", Color.WHITE)
	add_child(h)

func _on_boss_announce(text: String, icon: String) -> void:
	_notify(text, icon, Color(0.85, 0.5, 1.0))

# A straight, unguided shot: it flies toward where the target WAS when fired.
const BOLT_PEN := {"rock": 15.0, "boulder": 25.0, "fireball": 20.0, "missile": 22.0, "voidorb": 35.0, "holy": 18.0, "thorn": 14.0, "bubble": 12.0, "tracer": 2.0, "cannon": 25.0, "laser": 30.0, "lightblade": Weapons.TRUE_PEN, "hellarrow": 25.0, "bullet": 0.0, "shell": 10.0, "rocket": 12.0, "grenade": 8.0, "acid": 6.0, "flak": 6.0, "orb": 20.0, "void": Weapons.TRUE_PEN}   # armor penetration of enemy shots by style

func _spawn_bolt(origin: Vector2, aim: Vector2, dmg: float, style: String, spd: float, opts: Dictionary = {}) -> void:
	var pen := float(BOLT_PEN.get(style, 0.0))
	var b := EnemyBolt.new()
	b.style = style
	b.speed = spd
	b.position = origin
	b.direction = (aim - origin).normalized()
	b.base_ref = base
	b.damage = dmg
	b.reach = base.hit_radius()
	b.homing = float(opts.get("homing", 0.0))
	if bool(opts.get("dest", false)):
		b.dest_mode = true
		b.dest = aim
		b.blast_radius = float(opts.get("blast", 90.0))
	if style == "hellarrow":
		b.pierce = true
		b.hit_base.connect(func(d: float) -> void:
			base.take_damage(d, pen)
			base.apply_burn(maxf(1.0, d * 0.35), 5.0))
	else:
		b.hit_base.connect(func(d: float) -> void: base.take_damage(d, pen))
	add_child(b)

# Beam weapons hit everything on the line from origin toward the locked aim point.
func _beam_hit_check(origin: Vector2, aim: Vector2, dmg: float, width: float, pen: float = 30.0) -> void:
	var dir := (aim - origin).normalized()
	var rel := base.position - origin
	if rel.dot(dir) > -base.hit_radius() and absf(rel.cross(dir)) <= base.hit_radius() + width:
		base.take_damage(dmg, pen)

func _on_boss_beam(dmg: float, origin: Vector2, aim: Vector2) -> void:
	_add_shake(16.0)
	_beam_hit_check(origin, aim, dmg, 30.0, Weapons.TRUE_PEN)    # TRUE DAMAGE: ignores armor and Energy Shield; cannot be shot down - only moving away stops it

# Hell Lord fire breath: a cone of flame. Anything of ours inside it burns.
func _on_boss_breath(origin: Vector2, angle: float, reach: float, half: float, dmg: float) -> void:
	var rel := base.position - origin
	var dist := rel.length()
	var hr := base.hit_radius()
	if dist > reach + hr:
		return
	var spread := half + asin(clampf(hr / maxf(dist, hr + 1.0), 0.0, 1.0))
	if absf(angle_difference(angle, rel.angle())) <= spread:
		_add_shake(5.0)
		base.take_damage(dmg, 20.0)
		base.apply_burn(maxf(1.0, dmg * 0.8), 5.0)

func _on_hell_arrow(origin: Vector2, aim: Vector2, dmg: float) -> void:
	_spawn_bolt(origin, aim, dmg, "hellarrow", 900.0)

func _on_void_fire(origin: Vector2, aim: Vector2, dmg: float) -> void:
	_spawn_bolt(origin, aim, dmg, "void", 560.0)

func _on_boss_bolt(from_pos: Vector2, dmg: float) -> void:
	_spawn_bolt(from_pos, base.position, dmg, "orb", 260.0)

# Rocks, boulders, fireballs, missiles and void orbs thrown by mobs and bosses.
func _on_enemy_launch(kind: String, origin: Vector2, aim: Vector2, dmg: float) -> void:
	match kind:
		"rock":
			_spawn_bolt(origin, aim, dmg, "rock", 430.0)
		"boulder":
			_spawn_bolt(origin, aim, dmg, "boulder", 360.0, {"dest": true, "blast": 150.0})
		"fireball":
			_spawn_bolt(origin, aim, dmg, "fireball", 520.0, {"dest": true, "blast": 100.0})
		"missile":
			_spawn_bolt(origin, aim, dmg, "missile", 600.0, {"homing": 1.7})
		"apocshell":
			_spawn_bolt(origin, aim, dmg, "shell", 680.0)
		"voidorb":
			_spawn_bolt(origin, aim, dmg, "voidorb", 250.0, {"homing": 1.1})
		"holy":
			_spawn_bolt(origin, aim, dmg, "holy", 560.0)
		"thorn":
			_spawn_bolt(origin, aim, dmg, "thorn", 470.0)
		"bubble":
			_spawn_bolt(origin, aim, dmg, "bubble", 380.0)
		"tracer":
			_spawn_bolt(origin, aim, dmg, "tracer", 900.0)
		"cannon":
			_spawn_bolt(origin, aim, dmg, "cannon", 820.0)
		"laser":
			_spawn_bolt(origin, aim, dmg, "laser", 1250.0)
		"lightblade":
			_spawn_bolt(origin, aim, dmg, "lightblade", 520.0)
		"rocket":
			_spawn_bolt(origin, aim, dmg, "rocket", 480.0)
		"bullet":
			_spawn_bolt(origin, aim, dmg, "bullet", 700.0)
		"grenade":
			_spawn_bolt(origin, aim, dmg, "grenade", 330.0, {"dest": true, "blast": 85.0})
		"flak":
			_spawn_bolt(origin, aim, dmg, "flak", 900.0)
		"acid":
			_spawn_bolt(origin, aim, dmg, "acid", 430.0)
		"acidglob":
			_spawn_bolt(origin, aim, dmg, "acid", 340.0, {"dest": true, "blast": 85.0})

# Earthworms burst out under the castle; Sinners crowd around their Demon.
func _on_enemy_request(what: String, src: Enemy, count: int) -> void:
	if what == "pin":                    # a Titan Pillar holds the castle in place
		base.apply_slow(0.22, 0.6)
		return
	for i in count:
		var e: Enemy
		var pos := Vector2.ZERO
		match what:
			"worms":
				e = Enemy.make("earthworm", level)
				pos = base.position + Vector2.RIGHT.rotated(randf() * TAU) * (base.hit_radius() + randf_range(18.0, 40.0))
				Fx.spawn(self, "spark", pos, Color(0.55, 0.45, 0.32), "", 1.4, 0.45)
			"jets":
				if src == null or not is_instance_valid(src) or alive >= MAX_ALIVE or src._sinners_alive >= Enemy.JET_CAP:
					return
				var jkinds := ["phantom", "phantom", "falcon", "falcon", "warthog", "warthog", "stealth"]
				e = Enemy.make(jkinds[randi() % jkinds.size()], level)
				e.hp *= 0.6
				e.max_hp = e.hp
				e.reward = maxi(int(float(e.reward) * 0.3), 1)
				e.master = src
				src._sinners_alive += 1
				pos = src.position + Vector2.RIGHT.rotated(randf() * TAU) * (src.radius * 0.5)
				Fx.spawn(self, "spark", pos, Color(0.8, 0.9, 1.0), "", 1.0, 0.35)
			"fighters":
				if src == null or not is_instance_valid(src) or alive >= MAX_ALIVE:
					return
				e = Enemy.make("fighter", level)
				pos = src.position + Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(count, 1))) * (src.radius + 20.0)
				Fx.spawn(self, "spark", pos, Color(0.8, 0.9, 1.0), "", 1.0, 0.35)
			"sinners":
				if src == null or not is_instance_valid(src):
					return
				e = Enemy.make("sinner", level)
				e.master = src
				pos = src.position + Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(count, 1))) * (src.radius + 40.0)
				Fx.spawn(self, "spark", pos, Color(0.9, 0.2, 0.1), "", 1.2, 0.4)
			"ants":
				if src == null or not is_instance_valid(src) or alive >= MAX_ALIVE:
					return
				e = Enemy.make("ant", level)
				e.master = src
				e.reward = 0
				pos = src.position + Vector2.RIGHT.rotated(randf() * TAU) * (src.radius + 14.0)
				Fx.spawn(self, "spark", pos, Color(0.9, 0.8, 0.5), "", 0.8, 0.3)
			"kingtrolls":
				if src == null or not is_instance_valid(src) or alive >= MAX_ALIVE:
					return
				e = Enemy.make(["troll", "trollwarrior", "trollcaptain"][i % 3], level)
				e.master = src
				pos = src.position + Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(count, 1))) * (src.radius + 40.0)
				Fx.spawn(self, "spark", pos, Color(1.0, 0.7, 0.3), "", 1.4, 0.45)
			"kingguards":
				if src == null or not is_instance_valid(src) or alive >= MAX_ALIVE:
					return
				e = Enemy.make(["antwarden", "antspitter", "antflyer"][i % 3], level)
				e.master = src
				pos = src.position + Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(count, 1))) * (src.radius + 30.0)
				Fx.spawn(self, "spark", pos, Color(1.0, 0.8, 0.3), "", 1.2, 0.4)
			"souls":
				if src == null or not is_instance_valid(src) or alive >= MAX_ALIVE:
					return
				e = Enemy.make("soul", level)
				e.master = src
				pos = src.position + Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(count, 1))) * (src.radius + 36.0)
				Fx.spawn(self, "spark", pos, Color(0.85, 0.9, 1.0), "", 1.2, 0.4)
			"clones":
				if src == null or not is_instance_valid(src) or alive >= MAX_ALIVE:
					if src != null and is_instance_valid(src):
						src._clones_alive = 0
					return
				e = Enemy.make("fallen", level)
				e.is_clone = true
				e.is_minion = true
				e.master = src
				e.hp = src.hp * 0.3
				e.max_hp = e.hp
				e.reward = 0
				e._life_t = 9.0
				e._clone_cd = 999.0
				pos = src.position + Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(count, 1)) + 0.5) * (src.radius + 50.0)
				Fx.spawn(self, "spark", pos, Color(0.85, 0.9, 1.0), "", 1.6, 0.5)
			_:
				return
		e.position = pos
		e.target = base.position
		e.reach = base.hit_radius()
		alive += 1
		_register_mob(e, true)

func _on_tank_shoot(origin: Vector2, dmg: float) -> void:
	_spawn_bolt(origin, base.position, dmg, "shell", 340.0)

# ---------- Mini boss (a rival castle) ----------

# How many Rogue Castles this level gets.
#  Beginner: from level 5, a 25% chance (+5% per level, at most 60%) of ONE castle, and never on
#            two levels in a row, so there is always a breather.
#  I Hate Myself: from level 5, two castles, plus one more every 2 levels (at most MINI_MAX_PER_LEVEL).
#  Boss waves have none: the boss is the fight.
func _mini_count(lv: int) -> int:
	if _boss_level:
		return 0
	if GameState.difficulty == 0:
		if lv < MINI_FIRST_LEVEL or lv - _mini_last_level <= 1:
			return 0
		var chance := clampf(0.25 + 0.05 * float(lv - MINI_FIRST_LEVEL), 0.0, 0.6)
		return 1 if randf() < chance else 0
	if lv < MINI_SEASONED_LEVEL:
		return 0
	return mini(2 + floori(float(lv - MINI_SEASONED_LEVEL) / 2.0), MINI_MAX_PER_LEVEL)

func _mini_cap() -> int:
	var caps: Array = MINI_CAPS if GameState.difficulty == 0 else MINI_CAPS_SEASONED
	return int(caps[clampi(biome, 0, caps.size() - 1)])

# Gold multiplier for every kill reward (I Hate Myself pays double).
func _coin_mult() -> int:
	return COIN_MULT * (SEASONED_COIN_MULT if GameState.difficulty == 1 else 1)

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
	var m := MiniBoss.make_from(base, level, GameState.difficulty == 1)
	m.boss_name = str(MINI_NAMES.pick_random())
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
	_notify(Loc.t("A %s approaches!") % Loc.t(m.boss_name), "skull", Color(1.0, 0.5, 0.35))

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
	_beam_hit_check(origin, aim, dmg, 6.0, float(Weapons.PEN[4]))

func _on_enemy_died(e: Enemy) -> void:
	if e.is_ally:
		_notify(Loc.t("Refugee Hit!"), "ally", Color(1.0, 0.2, 0.2), "allyhit")
		return
	Fx.spawn(self, "coin", e.position, Color(1.0, 0.85, 0.3), "", clampf(1.0 + float(e.reward * _coin_mult()) / 8.0, 1.0, 6.0), 1.1)
	coins += e.reward * _coin_mult()
	stat_gold += e.reward * _coin_mult()
	stat_kills += 1
	ch_gold += e.reward * _coin_mult()
	ch_kills += 1
	if e.kind == "boss":
		stat_bosses += 1
	_gain_xp(ceili(float(e.reward) * XP_MULT))
	if map_run != null or GameState.dungeon_mode:
		_roll_loot(e)
	alive -= 1
	if e.kind == "mech":
		# The vehicle explodes and leaves 3 soldiers spread to its sides.
		_add_shake(7.0)
		var side := (base.position - e.position).normalized().orthogonal()
		for off in [-55.0, 0.0, 55.0]:
			_spawn_soldier_at(e.position + side * off)
	elif e.kind == "golem" and not e.is_small and not e.mud:
		# The golem crumbles and leaves two smaller golems behind.
		_add_shake(9.0)
		for off in [-34.0, 34.0]:
			var sg := Enemy.make_small_golem(e)
			sg.position = e.position + Vector2(off, 0.0)
			sg.target = base.position
			sg.reach = base.hit_radius()
			alive += 1
			_register_mob(sg, true)
	elif e.kind == "minicastle":
		_add_shake(14.0)
		_notify(Loc.t("%s defeated!  +%d") % [Loc.t((e as MiniBoss).boss_name), e.reward * _coin_mult()], "coin", Color(1.0, 0.85, 0.3))
	elif e.kind == "boss":
		_add_shake(22.0)
		_notify(Loc.t("%s defeated!  +%d") % [Loc.t(BOSS_NAMES[biome]), e.reward * _coin_mult()], "coin", Color(1.0, 0.85, 0.3))
		if map_run != null:
			_map_complete()
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
	var pick := randi() % 4
	if randf() < 0.2:
		pick = 5                                  # a refugee: bigger mana pool
	if pick == 0 and base.auto_cannons >= base.max_auto():
		pick = 4                                  # all weapon slots are full
	if pick == 4 and base.auto_interval <= Base.AUTO_INTERVAL_MIN + 0.001:
		pick = 1 + randi() % 3                    # auto fire rate is maxed: another profession instead
	_apply_refugee(pick)

# One refugee joins: 0/4 gunner (new turret, or +1% auto fire rate when slots are full), 1 scientist, 2 engineer, 3 mechanic, 5 mana keeper.
func _apply_refugee(pick: int) -> void:
	var jr := base.body_radius() * 1.25
	var jn := {0: "Gunner", 4: "Gunner", 1: "Scientist", 2: "Engineer", 3: "Mechanic", 5: "Mana Keeper"}.get(pick, "Helper") as String
	var jc := {0: Color(0.5, 0.9, 0.4), 4: Color(0.5, 0.9, 0.4), 1: Color(0.4, 0.95, 0.8), 2: Color(1.0, 0.85, 0.25), 3: Color(1.0, 0.55, 0.35), 5: Color(0.4, 0.65, 1.0)}.get(pick, Color(0.5, 1.0, 0.55)) as Color
	Fx.spawn(base, "join", Vector2(0.0, -jr), jc, "+1 " + Loc.t(jn), jr, 1.6, true)
	match pick:
		0:
			base.gunners += 1
			base.add_auto_cannon()
			_notify(Loc.t("+1 auto-weapon"), "gunner", Color(0.5, 0.85, 0.4))
		4:
			base.gunners += 1
			base.auto_interval = maxf(base.auto_interval * 0.99, Base.AUTO_INTERVAL_MIN)
			base.auto_range = minf(base.auto_range + 4.0, Base.MAX_RANGE)
			_notify(Loc.t("Weapon slots full: auto fire rate +1%"), "gunner", Color(0.5, 0.85, 0.4))
		1:
			base.scientists += 1
			base.damage_mult *= 1.01
			_notify(Loc.t("Weapon damage +1%"), "scientist", Color(0.4, 0.95, 0.8))
		2:
			base.engineers += 1
			base.energy_regen *= 1.01
			_notify(Loc.t("Mana regen +1%"), "engineer", Color(1.0, 0.85, 0.25))
		5:
			base.mana_helpers += 1
			var old_mana := base.max_energy
			base.max_energy *= 1.01
			base.energy = minf(base.energy + (base.max_energy - old_mana), base.max_energy)
			_notify(Loc.t("Base Mana +1%"), "energy", Color(0.4, 0.65, 1.0))
		3:
			base.mechanics += 1
			_notify(Loc.t("Base repairs itself slowly"), "mechanic", Color(1.0, 0.55, 0.35))

# Hiring with gold: you choose the kind. Gunners only count while turrets or fire rate can still grow.
func _on_hire(kind: String) -> void:
	if not Base.HELPERS_ON or not base.can_hire(kind):
		return
	var price := base.hire_price(kind)
	if coins < price:
		return
	coins -= price
	base.hired[kind] = int(base.hired.get(kind, 0)) + 1
	var pick := {"gunner": 0, "scientist": 1, "engineer": 2, "mechanic": 3, "energy": 5}.get(kind, 1) as int
	if pick == 0 and base.auto_cannons >= base.max_auto():
		pick = 4
	Sfx.play("powerup")
	_apply_refugee(pick)
	_update_label()
	_refresh_castle()

# ---------- Input: Esc menu, pause, shop, skills ----------

# --- Debug switches for finding what costs frame time (watch the window title and the FPS counter) ---
#  F6 weather  F7 backdrop  F8 hide enemies  F9 freeze enemies  F10 HUD  F4 ship wakes+markers
var _dbg: Dictionary = {}

func _debug_key(k: int) -> bool:
	var name := ""
	match k:
		KEY_F4:
			Enemy.dbg_no_extras = not Enemy.dbg_no_extras
			name = "extras"
			_dbg[name] = Enemy.dbg_no_extras
		KEY_F6:
			var wl := weather.get_parent() as CanvasLayer
			wl.visible = not wl.visible
			name = "weather"
			_dbg[name] = not wl.visible
		KEY_F7:
			backdrop.visible = not backdrop.visible
			name = "backdrop"
			_dbg[name] = not backdrop.visible
		KEY_F8:
			var hide := not bool(_dbg.get("hidden", false))
			for n in get_tree().get_nodes_in_group("enemies"):
				(n as CanvasItem).visible = not hide
			_dbg["hidden"] = hide
			name = "hidden"
		KEY_F9:
			var frz := not bool(_dbg.get("frozen", false))
			for n in get_tree().get_nodes_in_group("enemies"):
				(n as Node).set_process(not frz)
			_dbg["frozen"] = frz
			name = "frozen"
		KEY_F10:
			var hl := hud.get_parent() as CanvasLayer
			hl.visible = not hl.visible
			name = "hud"
			_dbg[name] = not hl.visible
		_:
			return false
	var t := "Castle in the Sky  OFF:"
	for key in _dbg:
		if bool(_dbg[key]):
			t += " " + str(key)
	DisplayServer.window_set_title(t)
	return true

func _input(event: InputEvent) -> void:
	var dk := event as InputEventKey
	if dk != null and dk.pressed and not dk.echo and OS.is_debug_build() and _debug_key(int(dk.keycode)):
		return
	if chapter_scene != null and chapter_scene.blocking():
		return
	if levelup_menu != null and levelup_menu.visible:
		var lk := event as InputEventKey
		if lk != null and lk.pressed and not lk.echo:
			var li := int(lk.keycode) - int(KEY_1)
			if li >= 0 and li < 3:
				get_viewport().set_input_as_handled()
				levelup_menu.choose(li)
			elif lk.keycode == KEY_R:
				get_viewport().set_input_as_handled()
				levelup_menu.request_reroll()
		return                       # the level-up window owns the keyboard until a buff is chosen                       # the chapter window and the clouds own the keyboard (Enter / Space continues)
	# Trackpads (MacBook): pinch or two-finger scroll zooms like the mouse wheel.
	var pinch := event as InputEventMagnifyGesture
	var pan := event as InputEventPanGesture
	if pinch != null or pan != null:
		if not (castle_menu.visible or pause_menu.visible or hud_editor.visible):
			var f := pinch.factor if pinch != null else pow(1.1, -clampf(pan.delta.y, -3.0, 3.0) * 0.5)
			_zoom_target = clampf(_zoom_target * f, Settings.ZOOM_MIN, Settings.ZOOM_MAX)
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if not (castle_menu.visible or pause_menu.visible or hud_editor.visible):
			var step := 1.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			_zoom_target = clampf(_zoom_target * step, Settings.ZOOM_MIN, Settings.ZOOM_MAX)
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and hub_field != null and not get_tree().paused and not game_over:
		_click_station()
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
		if game_over or castle_menu.visible or pause_menu.visible or hud_editor.visible:
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
		if game_over or _manual_paused or pause_menu.visible or hud_editor.visible or hub_panel.visible:
			return
		_toggle_castle()
		return
	for i in 4:
		if castle_menu.visible:
			break                   # the number keys spend stat points while the Castle window is open
		if event.is_action_pressed("skill_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			if not get_tree().paused and not game_over:
				var used := base.skill_slots[i]
				if used == "repair":
					_use_repair(i)
				elif used == "push":
					_use_push(i)
				elif base.use_skill(i):
					if used == "dash":
						Sfx.play("powerup", -4.0)
					elif used == "overcharge":
						Sfx.play("weapon_up")
						_notify(Loc.t("Overcharge!  Damage +30%% for %d s") % int(Base.BOOST_DURATION), "damage", Color(1.0, 0.6, 0.2), "boost")
			return

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
	if hub_panel.visible:
		hub_panel.close()
		return
	if hud_editor.visible:
		hud_editor.finish(true)
		return
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

# ---------- Level-up buffs and castle classes ----------

func _open_levelup() -> void:
	if base.picks <= 0 or game_over:
		return
	if castle_menu.visible:
		_close_castle()
	levelup_menu.coins = coins
	levelup_menu.open(base)
	_update_pause()

func _on_reroll() -> void:
	var cost := levelup_menu.reroll_cost()
	if coins < cost:
		return
	coins -= cost
	levelup_menu.coins = coins
	levelup_menu.reroll()
	_update_label()

func _on_buff_picked(stat: String, pts: int) -> void:
	if base.picks <= 0:
		return
	base.grant_buff(stat, pts)
	base.picks -= 1
	Sfx.play("powerup", -4.0)
	_notify("%s  %s" % [Loc.t(Buffs.name_of(stat)), Buffs.amount_text({"stat": stat, "pts": pts})], Buffs.icon_of(stat), Color(0.5, 1.0, 0.6), "buff")
	if base.picks > 0:
		levelup_menu.coins = coins
		levelup_menu.open(base)
	else:
		levelup_menu.visible = false
		_update_pause()
	_update_label()
	_refresh_castle()

func _on_class_chosen(id: String) -> void:
	if game_over or base.can_fire:
		_refresh_castle()
		return                              # the class can only be changed in the hub
	base.set_class(id)
	Sfx.play("weapon_up", -2.0)
	_notify(Loc.t("Castle class: %s") % Loc.t(CastleClass.cname(id)), "walls", Color(0.5, 1.0, 0.6), "class")
	_update_label()
	_refresh_castle()

# Bulwark skill: a shockwave that throws the mobs around the castle back.
func _use_push(slot: int) -> void:
	if base.skill_cd[slot] > 0.0:
		return
	var reach := Base.PUSH_RADIUS + base.hit_radius()
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or not is_instance_valid(e) or e is Boss or e.kind == "apoctank":
			continue
		var off := e.position - base.position
		var d := off.length()
		if d > reach + e.radius:
			continue
		var heavy := e.kind in ["tank", "heavytank", "golem", "demon"]
		var f := 1.0 - 0.5 * clampf(d / (reach + e.radius), 0.0, 1.0)
		var s := Base.PUSH_FORCE * f * (0.4 if heavy else 1.0) * (0.3 if e is MiniBoss else 1.0)
		e._hit_reaction(off.normalized() if d > 1.0 else Vector2.RIGHT, s)
	base.push_fx = 1.0
	base.skill_cd[slot] = Base.PUSH_COOLDOWN
	base.skill_cd_max[slot] = Base.PUSH_COOLDOWN
	Sfx.play("weapon_up", -2.0)

func _refresh_castle() -> void:
	var diff_name: String = GameState.DIFFICULTY_NAMES[GameState.difficulty]
	castle_menu.refresh(coins, {
		"wave": level,
		"region": Loc.t(BIOME_NAMES[biome]),
		"difficulty": Loc.t(diff_name),
		"power": Power.of_base(base),
		"stats": "%s: %d   %s: %s" % [Loc.t("Kills"), stat_kills, Loc.t("Time"), _fmt_time(stat_time)],
	})

func _on_castle_reset() -> void:
	if game_over:
		return
	var n := base.reset_stat_points()
	if n <= 0:
		return
	Sfx.play("weapon_up", -4.0)
	_notify(Loc.t("Stat points reset: %d refunded") % n, "star", Color(1.0, 0.9, 0.4))
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

func _on_castle_laser(on: bool) -> void:
	base.laser = on

# ---------- Game over and HUD text ----------

func _on_base_burning(dps: float) -> void:
	_notify(Loc.t("Burning!  -%d HP per second for 5 s") % int(ceil(dps)), "hit", Color(1.0, 0.5, 0.15), "burn")

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
	var blast := CastleBlast.new()
	blast.position = base.position
	blast.base_ref = base
	blast.radius = base.hit_radius()
	blast.shake.connect(_add_shake)
	add_child(blast)
	for group in ["enemies", "allies", "bolts", "bombs", "shots", "hazards"]:
		for node in get_tree().get_nodes_in_group(group):
			node.set_process(false)
	boss_label.visible = false
	var xp_lost := 0
	var in_dungeon := GameState.dungeon_mode
	if map_run != null or in_dungeon:
		xp_lost = int(ceil(float(base.xp) * DEATH_XP_LOSS))
		base.xp = maxi(base.xp - xp_lost, 0)
		_commit_profile()
	var info := Loc.t("Your %s fell on Wave %d  (%s)") % [Loc.t(Base.TIER_NAMES[base.tier]), level, Loc.t(BIOME_NAMES[biome])]
	if in_dungeon:
		info = Loc.t("Your %s fell in the Dungeon on Wave %d") % [Loc.t(Base.TIER_NAMES[base.tier]), level]
		info += "\n" + Loc.t("You lost 10%% of your XP (-%d). Items and gold are kept.") % xp_lost
	elif map_run != null:
		info = Loc.t("Your %s fell on the %s") % [Loc.t(Base.TIER_NAMES[base.tier]), Loc.t(map_run.map_name)]
		info += "\n" + Loc.t("You lost 10%% of your XP (-%d). Items and gold are kept.") % xp_lost
	info += "\n" + Loc.t("Kills: %d   Gold earned: %d   Play time: %s") % [stat_kills, stat_gold, _fmt_time(stat_time)]
	get_tree().create_timer(4.0).timeout.connect(gameover_menu.open.bind(info, Loc.t("Return to the Hub") if (map_run != null or in_dungeon) else Loc.t("Retry Wave %d") % level))

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
	# always visible: the level, the region and the castle stage (the HUD draws them as a plaque)
	hud.info_wave = level
	hud.info_biome = Loc.t(BIOME_NAMES[biome])
	hud.info_castle = Loc.t(Base.TIER_NAMES[base.tier])
	hud.info_msg = _msg if _msg != "" else _map_status
	if map_run != null:
		hud.info_biome = Loc.t(map_run.map_name)
	if hub_field != null:
		hud.info_biome = Loc.t("The Hub")
	# on demand (details key): the numbers behind the level
	hud.info_detail = ""
	if _show_details:
		var diff_name: String = GameState.DIFFICULTY_NAMES[GameState.difficulty]
		var d := "%s   |   %s x%.2f   |   %s x%.1f" % [Loc.t(diff_name), Loc.t("Enemy damage"), 1.0 + 0.25 * (level - 1), Loc.t("Spawn rate"), _spawn_rate()]
		d += "\n%s: %s %d   |   %s %d" % [Loc.t("Power"), Loc.t("you"), int(Power.of_base(base)), Loc.t("enemies"), int(Power.field_power(get_tree(), base.armor_points()))]
		hud.info_detail = d
