class_name GameState
extends RefCounted

# Data that must survive a scene change (menu -> game) lives here.
const SAVE_PATH := "user://savegame.json"
const DIFFICULTY_NAMES := ["Beginner", "Seasoned"]

static var difficulty: int = 0               # 0 = Beginner, 1 = Seasoned
static var pending_load: Dictionary = {}     # filled by the menu when pressing Continue

const TMP_PATH := "user://savegame.tmp"
const BAK_PATH := "user://savegame.bak"
const SAVE_VERSION := 5

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BAK_PATH)

# Writes to a temporary file first and keeps the previous save as a backup, so a crash or a full
# disk in the middle of saving can never destroy the only copy.
static func write_save(data: Dictionary) -> bool:
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		return false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BAK_PATH)
	return DirAccess.rename_absolute(TMP_PATH, SAVE_PATH) == OK

static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and (parsed as Dictionary).get("base") is Dictionary:
		return migrate(parsed as Dictionary)
	return {}

# Loads the save; if it is missing or damaged, falls back to the backup copy.
static func read_save() -> Dictionary:
	var d := _read_file(SAVE_PATH)
	if d.is_empty():
		d = _read_file(BAK_PATH)
	return d

# Brings an older save up to the current format with safe defaults (so old saves keep working).
static func migrate(d: Dictionary) -> Dictionary:
	if not (d.get("stats") is Dictionary):
		d["stats"] = {}
	d["version"] = SAVE_VERSION
	return d

# Seasoned: much denser waves, faster and tougher enemies.
static func count_mult() -> float:
	return 1.0 if difficulty == 0 else 1.7

static func hp_mult() -> float:
	return 1.0 if difficulty == 0 else 1.5

static func speed_mult() -> float:
	return 1.0 if difficulty == 0 else 1.25

static func interval_mult() -> float:
	return 1.0 if difficulty == 0 else 0.55
