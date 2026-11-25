class_name Keybinds
extends RefCounted

# Rebindable actions. Esc (menu), the number keys in the Castle window and the
# mouse button are fixed.
const ORDER := ["move_up", "move_left", "move_down", "move_right", "pause_game", "open_shop", "toggle_info", "skill_1", "skill_2", "skill_3", "skill_4"]
const LABELS := {
	"move_up": "Move up",
	"move_left": "Move left",
	"move_down": "Move down",
	"move_right": "Move right",
	"pause_game": "Pause game",
	"open_shop": "Castle window",
	"toggle_info": "Show details",
	"skill_1": "Skill slot 1",
	"skill_2": "Skill slot 2",
	"skill_3": "Skill slot 3",
	"skill_4": "Skill slot 4",
}
const DEFAULTS := {
	"move_up": KEY_W,
	"move_left": KEY_A,
	"move_down": KEY_S,
	"move_right": KEY_D,
	"pause_game": KEY_P,
	"open_shop": KEY_TAB,
	"toggle_info": KEY_I,
	"skill_1": KEY_SPACE,
	"skill_2": KEY_2,
	"skill_3": KEY_3,
	"skill_4": KEY_4,
}

static var _keys: Dictionary = {}

static func load_from(cfg: ConfigFile) -> void:
	for a in ORDER:
		var def: int = DEFAULTS[a]
		_keys[a] = int(cfg.get_value("keys", a, def))
	if int(cfg.get_value("keys", "ver", 1)) < 2:
		# older saves: Space paused and 1 was skill slot 1 - move them to P and Space (only if still the old defaults)
		if int(_keys["pause_game"]) == KEY_SPACE and int(_keys["skill_1"]) == KEY_1:
			_keys["pause_game"] = KEY_P
			_keys["skill_1"] = KEY_SPACE
	_register()

static func _ensure() -> void:
	if _keys.is_empty():
		load_from(ConfigFile.new())

static func _register() -> void:
	for a in ORDER:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
		InputMap.add_action(a)
		var ev := InputEventKey.new()
		ev.keycode = int(_keys[a]) as Key
		InputMap.action_add_event(a, ev)

static func label_of(action: String) -> String:
	return LABELS[action]

static func get_key(action: String) -> int:
	_ensure()
	return int(_keys[action])

static func key_text(action: String) -> String:
	_ensure()
	return OS.get_keycode_string(int(_keys[action]) as Key)

static func set_key(action: String, keycode: int) -> void:
	_ensure()
	var old: int = int(_keys[action])
	# If another action already uses this key, give it our old key (swap).
	for other in ORDER:
		if other != action and int(_keys[other]) == keycode:
			_keys[other] = old
	_keys[action] = keycode
	_register()

static func reset_defaults() -> void:
	for a in ORDER:
		_keys[a] = int(DEFAULTS[a])
	_register()
