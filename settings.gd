class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"
# The game is designed for a 1920x1080 virtual screen. Godot scales it to
# the real window, so 1080p, 2K (1440p) and 4K monitors all look sharp.
const WORLD_SIZE := Vector2(1920, 1080)
const VIEW_ZOOM := 0.75    # default zoom and the size of the play area (0.75 = 2560x1440)
const ZOOM_MIN := 0.5      # mouse-wheel zoom limits
const ZOOM_MAX := 1.5

# The part of the map the camera actually shows.
static func view_rect() -> Rect2:
	var size := WORLD_SIZE / VIEW_ZOOM
	return Rect2((WORLD_SIZE - size) * 0.5, size)

static var fullscreen: bool = false
static var volume: float = 1.0
static var sfx_volume: float = 1.0
static var muted: bool = false
static var _window_sized: bool = false

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		fullscreen = cfg.get_value("display", "fullscreen", false)
		volume = cfg.get_value("audio", "volume", 1.0)
		sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
		muted = cfg.get_value("audio", "muted", false)
	Keybinds.load_from(cfg)
	DisplayServer.window_set_title("Castle in the Sky")
	apply_scaling()
	apply()

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	for a in Keybinds.ORDER:
		cfg.set_value("keys", a, Keybinds.get_key(a))
	cfg.save(PATH)

static func apply_scaling() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var win := tree.root
	win.content_scale_size = Vector2i(int(WORLD_SIZE.x), int(WORLD_SIZE.y))
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

static func apply() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if not _window_sized:
			_window_sized = true
			var screen := DisplayServer.screen_get_size()
			var w := int(screen.x * 0.8333)
			var h := int(w * 9.0 / 16.0)
			DisplayServer.window_set_size(Vector2i(w, h))
			DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - Vector2i(w, h)) / 2)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, muted)
