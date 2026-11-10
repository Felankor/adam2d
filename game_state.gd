class_name GameState
extends RefCounted

# Data that must survive a scene change (menu -> game) lives here.
const SAVE_PATH := "user://savegame.json"
const DIFFICULTY_NAMES := ["Beginner", "Seasoned"]

static var difficulty: int = 0               # 0 = Beginner, 1 = Seasoned
static var pending_load: Dictionary = {}     # filled by the menu when pressing Continue

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func write_save(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

static func read_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}

# Seasoned: much denser waves, faster and tougher enemies.
static func count_mult() -> float:
	return 1.0 if difficulty == 0 else 1.7

static func hp_mult() -> float:
	return 1.0 if difficulty == 0 else 1.5

static func speed_mult() -> float:
	return 1.0 if difficulty == 0 else 1.25

static func interval_mult() -> float:
	return 1.0 if difficulty == 0 else 0.55
