class_name HelpPanel
extends VBoxContainer

# "How to play" page of the Esc menu. Rebuilt every time it opens so the key
# names always match the player's current key bindings.
signal back_pressed

var _content: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(380, 52)
	back.add_theme_font_size_override("font_size", 22)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)

func refresh() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	_heading("Goal")
	_text("Defend your castle. Enemies walk in one by one - shoot them to earn gold. Clear every level to grow from a Village into a Death Star. Every 10th level is a boss level.")

	_heading("Controls")
	_key_row("Aim", "Mouse")
	_key_row("Fire (hold)", "Left mouse button")
	_key_row("Move the castle", "%s %s %s %s" % [Keybinds.key_text("move_up"), Keybinds.key_text("move_left"), Keybinds.key_text("move_down"), Keybinds.key_text("move_right")])
	_key_row("Zoom in / out", "Mouse wheel")
	_key_row("Pause game", Keybinds.key_text("pause_game"))
	_key_row("Open shop", Keybinds.key_text("open_shop"))
	_key_row("Skill slot 1 (Barrier)", Keybinds.key_text("skill_1"))
	_key_row("Skill slot 2 (Overcharge)", Keybinds.key_text("skill_2"))
	_key_row("Skill slot 3", Keybinds.key_text("skill_3"))
	_key_row("Skill slot 4", Keybinds.key_text("skill_4"))
	_key_row("Pause menu / go back", "Esc")
	_key_row("Buy in shop / pick a reward card", "Number keys or click")
	_text("You can change these keys in Settings > Controls.")

	_heading("Energy and weapons")
	_text("Every shot costs energy, and energy refills over time. Upgrade your weapon in the shop: Machinegun, Cannon, Rocket Launcher, Laser Gun. Auto-weapons use the same weapon.")

	_heading("Refugees")
	_text("Refugees (red clothes, white flag) are innocent - don't shoot them! Let one reach your castle and it becomes a helper. They stop coming in the Space biome:")
	_ally_row("gunner", "Builds an extra auto-weapon")
	_ally_row("scientist", "Weapon damage +15%")
	_ally_row("engineer", "Energy regen +5 per second")
	_ally_row("mechanic", "Slowly repairs the castle")

	_heading("Enemies")
	_text("Soldier: the standard foe.\nTank: slow and armored; stops at a distance and shells your castle. Shoot the shells down.\nMechanized vehicle: very fast, dodges shots, and explodes into 3 soldiers.")

	_heading("Bosses")
	_text("Each biome ends with a boss that moves, dodges and summons soldiers. Shoot down its energy orbs. If the Void Overlord charges its beam, use your Barrier!")

func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_content.add_child(HSeparator.new())
	_content.add_child(l)

func _text(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(780, 0)
	_content.add_child(l)

func _key_row(action: String, key: String) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var a := Label.new()
	a.text = action
	a.custom_minimum_size = Vector2(430, 0)
	a.add_theme_font_size_override("font_size", 20)
	row.add_child(a)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 20)
	k.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	row.add_child(k)

func _ally_row(icon: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_content.add_child(row)
	var ic := IconRect.new()
	ic.custom_minimum_size = Vector2(40, 40)
	ic.kind = icon
	row.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
