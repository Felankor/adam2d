class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"

static var fullscreen: bool = false
static var volume: float = 1.0

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		fullscreen = cfg.get_value("display", "fullscreen", false)
		volume = cfg.get_value("audio", "volume", 1.0)
	apply()

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "volume", volume)
	cfg.save(PATH)

static func apply() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
