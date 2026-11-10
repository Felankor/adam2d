class_name Keybinds
extends RefCounted

# Rebindable actions. Esc (menu), the number keys in the shop and the
# mouse button are fixed.
const ORDER := ["move_up", "move_left", "move_down", "move_right", "pause_game", "open_shop", "skill_1", "skill_2", "skill_3", "skill_4"]
const LABELS := {
	"move_up": "Move up",
	"move_left": "Move left",
	"move_down": "Move down",
	"move_right": "Move right",
	"pause_game": "Pause game",
	"open_shop": "Open shop",
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
	"pause_game": KEY_SPACE,
	"open_shop": KEY_TAB,
	"skill_1": KEY_V,
	"skill_2": KEY_B,
	"skill_3": KEY_N,
	"skill_4": KEY_M,
}

static var _keys: Dictionary = {}

static func load_from(cfg: ConfigFile) -> void:
	for a in ORDER:
		var def: int = DEFAULTS[a]
		_keys[a] = int(cfg.get_value("keys", a, def))
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
