class_name GameState
extends RefCounted

# Data that must survive a scene change (menu -> game) lives here.
const DIFFICULTY_NAMES := ["Beginner", "I Hate Myself"]
const SAVE_VERSION := 6

# Every save lives in its own slot file under user://saves/, so starting a new game can never
# overwrite another slot. Each slot keeps a rolling backup (.bak) of its previous save.
const SLOT_COUNT := 3
const SAVE_DIR := "user://saves"
const LEGACY_PATH := "user://savegame.json"
const LEGACY_BAK := "user://savegame.bak"

static var difficulty: int = 0               # 0 = Beginner, 1 = Seasoned
static var pending_load: Dictionary = {}     # filled by the menu when a save is loaded
static var current_slot: int = -1            # the slot that autosave and Save write to
static var _ready_done: bool = false
static var reopen_slots: bool = false        # after deleting a slot the menu reopens the slot list

static func slot_path(i: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, i + 1]

static func _bak(i: int) -> String:
	return slot_path(i) + ".bak"

static func _tmp(i: int) -> String:
	return slot_path(i) + ".tmp"

# Creates the folder and moves a save from the old single-file system into slot 1 (the old file is kept).
static func init_saves() -> void:
	if _ready_done:
		return
	_ready_done = true
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if not FileAccess.file_exists(slot_path(0)) and not FileAccess.file_exists(_bak(0)):
		var src := LEGACY_PATH if FileAccess.file_exists(LEGACY_PATH) else (LEGACY_BAK if FileAccess.file_exists(LEGACY_BAK) else "")
		if src != "":
			DirAccess.copy_absolute(src, slot_path(0))

static func has_save() -> bool:
	init_saves()
	for i in SLOT_COUNT:
		if not slot_info(i).is_empty():
			return true
	return false

# Writes to a temporary file first and keeps the previous save as a backup, so a crash or a full
# disk in the middle of saving can never destroy the only copy. Writes only to the current slot.
static func write_save(data: Dictionary) -> bool:
	init_saves()
	var i := current_slot
	if i < 0 or i >= SLOT_COUNT:
		return false
	var f := FileAccess.open(_tmp(i), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		return false
	if FileAccess.file_exists(slot_path(i)):
		DirAccess.copy_absolute(slot_path(i), _bak(i))
	return DirAccess.rename_absolute(_tmp(i), slot_path(i)) == OK

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

# Loads a slot; if it is missing or damaged, falls back to its backup copy.
static func read_slot(i: int) -> Dictionary:
	init_saves()
	var d := _read_file(slot_path(i))
	if d.is_empty():
		d = _read_file(_bak(i))
	return d

# Short description of a slot for the menus ({} when the slot is empty).
static func slot_info(i: int) -> Dictionary:
	var d := read_slot(i)
	if d.is_empty():
		return {}
	var p := slot_path(i)
	if not FileAccess.file_exists(p):
		p = _bak(i)
	var t := int(FileAccess.get_modified_time(p))
	return {"level": int(d.get("level", 1)), "difficulty": clampi(int(d.get("difficulty", 0)), 0, 1), "time": t}

static func time_text(unix: int) -> String:
	if unix <= 0:
		return ""
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(local, true).substr(0, 16)

# The most recently saved slot, or -1.
static func newest_slot() -> int:
	var best := -1
	var best_t := -1
	for i in SLOT_COUNT:
		var info := slot_info(i)
		if not info.is_empty() and int(info["time"]) > best_t:
			best_t = int(info["time"])
			best = i
	return best

static func delete_slot(i: int) -> void:
	for p in [slot_path(i), _bak(i), _tmp(i)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	if i == 0:
		for p in [LEGACY_PATH, LEGACY_BAK]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)         # else it would be copied into slot 1 again
	if current_slot == i:
		current_slot = -1

# Brings an older save up to the current format with safe defaults (so old saves keep working).
static func migrate(d: Dictionary) -> Dictionary:
	if not (d.get("stats") is Dictionary):
		d["stats"] = {}
	if int(d.get("version", 0)) < 6 and d.get("base") is Dictionary:
		# v6 added the Gatling Gun at tier 2: older Rocket / Laser / Void tiers moved up by one
		var bd := d["base"] as Dictionary
		var wt := int(bd.get("weapon_tier", 0))
		if wt >= 2:
			bd["weapon_tier"] = wt + 1
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
