class_name Profile
extends RefCounted

# Phase 2: the Hub profile. One file for the whole hub game (castle, gold, inventory, stash, cleared maps),
# independent from the old wave-mode save slots.
const PATH := "user://hub_profile.json"

static var data: Dictionary = {}
static var _loaded: bool = false

static func fresh() -> Dictionary:
	return {"base": {}, "coins": 0, "inv": {}, "stash": {}, "cleared": [], "boss_dead": {}, "dungeon_best": 0}

static func get_data() -> Dictionary:
	if not _loaded:
		_loaded = true
		data = _read(PATH)
		if data.is_empty():
			data = _read(PATH + ".bak")
		if data.is_empty():
			data = fresh()
	return data.duplicate(true)

static func exists() -> bool:
	return FileAccess.file_exists(PATH) or FileAccess.file_exists(PATH + ".bak")

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and (parsed as Dictionary).get("base") is Dictionary:
		return parsed as Dictionary
	return {}

# Temp file first, previous copy kept as .bak: a crash in the middle of saving cannot destroy the profile.
static func save() -> bool:
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		return false
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, PATH + ".bak")
	return DirAccess.rename_absolute(tmp, PATH) == OK

static func reset() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	data = fresh()
	_loaded = true

# JSON numbers come back as floats: turn {"id": 3.0} into {"id": 3}.
static func int_dict(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in (v as Dictionary):
			var n := maxi(int((v as Dictionary)[k]), 0)
			if n > 0:
				out[str(k)] = n
	return out
