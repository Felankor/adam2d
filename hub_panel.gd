class_name HubPanel
extends Control

# Phase 2: the window of a hub building (Map Table, Trader, Stash). Main owns the data (inv, stash, coins);
# this window shows it and reports button presses through signals.
signal fly_out(map_id: String)
signal sell(id: String, count: int)
signal move_item(id: String, to_stash: bool, count: int)
signal reset_requested
signal buy_tier
signal closed

var inv: Dictionary = {}
var stash: Dictionary = {}
var coins: int = 0
var cleared: Array = []
var page: String = ""
var tier: int = 0
var boss_left: Dictionary = {}
var dungeon_best: int = 0
var _cur_view: CastleView = null
var _yard_seen: int = -1            # the castle stage the Shipyard showed last (a higher one plays the grow animation)
var _map_lbls: Dictionary = {}

var _holder: VBoxContainer
var _reset_armed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PixelUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := PixelUI.box(PixelUI.WIN_BG, PixelUI.BRONZE)
	sb.set_content_margin_all(44)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	PixelUI.fit(panel)
	_holder = VBoxContainer.new()
	_holder.add_theme_constant_override("separation", 12)
	panel.add_child(_holder)

func open(p: String) -> void:
	page = p
	_yard_seen = -1
	_reset_armed = false
	visible = true
	rebuild()

func close() -> void:
	visible = false
	closed.emit()

func rebuild() -> void:
	if not visible:
		return
	_holder.add_theme_constant_override("separation", 12)
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()
	match page:
		"map":
			_build_map()
		"trader":
			_build_trader()
		"stash":
			_build_stash()
		"yard":
			_build_yard()
	_holder.add_child(_button("Close", close, 300.0))

func _label(text: String, size: int = 24, col: Color = Color(1, 1, 1), width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", PixelUI.mfs(size))
	l.add_theme_color_override("font_color", col)
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _button(text: String, handler: Callable, width: float = 0.0, size: int = 24) -> Button:
	var b := Button.new()
	b.text = Loc.t(text)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", PixelUI.mfs(size))
	b.custom_minimum_size = Vector2(width, 60)
	if width > 0.0:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		handler.call())
	return b

func _title(text: String) -> void:
	_holder.add_child(PixelTitle.make(text, 44))

func _gold_line() -> void:
	var l := _label(Loc.t("Gold: %d") % coins, 26, Color(1.0, 0.85, 0.3))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tip.attach(l, "Gold", "Dropped by every kill. Spend it on weapon upgrades and the Shipyard.", "coin")
	_holder.add_child(l)

func _map_text(id: String) -> String:
	var txt := Loc.t(str(MapRun.NAMES[id])) + "\n" + Loc.t(str(MapRun.DANGER[id]))
	if cleared.has(id):
		txt += "   " + Loc.t("(cleared)")
	txt += "\n" + _boss_text(id)
	return txt

func _map_card(id: String) -> VBoxContainer:
	var is_dungeon := id == "dungeon"
	var need := "" if is_dungeon else MapRun.needs(id)
	var open: bool = true if is_dungeon else (need == "" or cleared.has(need))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var view := MapView.new()
	view.setup(id, not open, (not is_dungeon) and cleared.has(id))
	col.add_child(view)
	var name_txt := Loc.t("The Dungeon") if is_dungeon else Loc.t(str(MapRun.NAMES[id]))
	var nm := _label(name_txt, 22, Color(1, 1, 1) if open else Color(0.55, 0.5, 0.45), 300.0)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(nm)
	var info: Label
	if is_dungeon:
		var sig := _have("sigil")
		var t3 := Loc.t("Warden Sigils: %d") % sig
		if dungeon_best > 0:
			t3 += "   " + Loc.t("Best wave: %d") % dungeon_best
		info = _label(t3, 18, Color(0.75, 0.6, 1.0) if sig > 0 else Color(1.0, 0.5, 0.4), 300.0)
		Tip.attach(view, "The Dungeon", Loc.t("Endless waves of the old wave mode with your own castle. Each run uses up one Warden Sigil. Your best wave is remembered."), "sigil")
	elif open:
		info = _label(Loc.t(str(MapRun.DANGER[id])) + "\n" + _boss_text(id), 18, Color(0.85, 0.85, 0.8), 300.0)
		_map_lbls[id] = info
		var mobs: Array[String] = []
		for mk: String in MapRun.mobs_of(id):
			mobs.append(Loc.t(mk.capitalize()))
		var zc := MapRun.zones_of(id).size()
		Tip.attach(view, str(MapRun.NAMES[id]), Loc.t("Zones: %d  (red = strong pack)") % zc + "\n" + Loc.t("Boss level: %d") % int(MapRun.BOSS_LVL[id]) + "\n" + Loc.t("Mobs: %s") % ", ".join(mobs) + "\n" + Loc.t("Wake the zones, then defeat the boss. The boss returns 5 minutes after it falls, even while you are in the hub."), "skull")
	else:
		info = _label(Loc.t("Locked: clear the previous region first"), 18, Color(0.55, 0.5, 0.45), 300.0)
		Tip.attach(view, str(MapRun.NAMES[id]), "Defeat the boss of the previous region to open this expedition.", "skull")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	var btn: Button
	if is_dungeon:
		var sig2 := _have("sigil")
		btn = _button("Enter" if sig2 > 0 else "Need a Warden Sigil", func() -> void: fly_out.emit("dungeon"), 300.0, 22)
		btn.disabled = sig2 < 1
		Tip.attach(btn, "Enter" if sig2 > 0 else "Need a Warden Sigil", "Uses up one Warden Sigil from your bag or stash and starts a Dungeon run. If you fall you lose 10% of your XP, but keep your items and gold." if sig2 > 0 else "Bosses drop a Warden Sigil the first time you beat them, and now and then after that.", "sigil")
	else:
		btn = _button("Fly out" if open else "Locked", func() -> void: fly_out.emit(id), 300.0, 22)
		btn.disabled = not open
		Tip.attach(btn, "Fly out" if open else "Locked", "Leaves the hub for this map. If your castle falls you lose 10% of your XP, but keep your gold and items." if open else "Defeat the boss of the previous region first.", "star")
	col.add_child(btn)
	return col

func _build_map() -> void:
	_holder.add_theme_constant_override("separation", 10)
	_title("Map Table")
	_map_lbls.clear()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 14)
	_holder.add_child(grid)
	for id: String in MapRun.IDS:
		grid.add_child(_map_card(id))
	grid.add_child(_map_card("dungeon"))
	_holder.add_child(HSeparator.new())
	var rb := _button("Click again to erase everything" if _reset_armed else "Reset all hub progress", _on_reset_click, 520.0, 20)
	Tip.attach(rb, "Reset all hub progress", "Erases your castle, gold, items, stash and cleared regions and starts over. Click twice to confirm.", "skull")
	_holder.add_child(rb)

const STACK := 99

# The items of a dictionary as slot stacks: [[id, count], ...] (a stack holds at most 99).
func _stacks(d: Dictionary) -> Array:
	var out: Array = []
	for id: String in Items.ORDER:
		var n := int(d.get(id, 0))
		while n > 0:
			var k := mini(n, STACK)
			out.append([id, k])
			n -= k
	return out

# A grid of inventory slots. handler(id, count, mouse_button); foot_fn(id) gives the last line of the item's tip.
func _slot_grid(d: Dictionary, cols: int, min_slots: int, handler: Callable, foot_fn: Callable) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	var stacks := _stacks(d)
	var total := maxi(min_slots, int(ceil(float(stacks.size()) / float(cols))) * cols)
	for i in total:
		var slot := ItemSlot.new()
		g.add_child(slot)
		if i < stacks.size():
			var st: Array = stacks[i]
			var id := str(st[0])
			var n := int(st[1])
			slot.setup(id, n, str(foot_fn.call(id)))
			slot.clicked.connect(func(b: int) -> void: handler.call(id, n, b))
		else:
			slot.setup("", 0)
	return g

func _build_trader() -> void:
	_title("Trader")
	_gold_line()
	_holder.add_child(_label(Loc.t("Hover an item to read about it. Left-click sells the stack, right-click sells one."), 20, Color(0.8, 0.75, 0.65)))
	var heading := _label(Loc.t("Your bag"), 24, Color(0.8, 0.9, 1.0))
	_holder.add_child(heading)
	var foot_fn := func(id: String) -> String:
		return Loc.t("Sells for %d gold each") % Items.price_of(id) + "\n" + Loc.t("Left-click: sell the stack   Right-click: sell one")
	var on_click := func(id: String, n: int, b: int) -> void:
		sell.emit(id, n if b == MOUSE_BUTTON_LEFT else 1)
	var holder := CenterContainer.new()
	holder.add_child(_slot_grid(inv, 8, 24, on_click, foot_fn))
	_holder.add_child(holder)
	if inv.is_empty():
		_holder.add_child(_label(Loc.t("Your bag is empty. Loot from the maps sells here."), 20, Color(0.8, 0.75, 0.65)))
	else:
		var total := 0
		for id in inv:
			total += int(inv[id]) * Items.price_of(str(id))
		var sb := _button(Loc.t("Sell everything  (+%d gold)") % total, _sell_everything, 560.0, 24)
		Tip.attach(sb, "Sell everything", "Sells every item in your bag to the Trader at once. The stash is not touched.", "coin")
		_holder.add_child(sb)

func _sell_everything() -> void:
	for id: String in Items.ORDER:
		if int(inv.get(id, 0)) > 0:
			sell.emit(id, int(inv[id]))

func _on_reset_click() -> void:
	if not _reset_armed:
		_reset_armed = true
		rebuild()
		return
	reset_requested.emit()

func _build_stash() -> void:
	_title("Stash")
	_holder.add_child(_label(Loc.t("Left-click moves a stack, right-click moves one. Hover an item to read about it."), 20, Color(0.8, 0.75, 0.65)))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	_holder.add_child(cols)
	var bag_box := VBoxContainer.new()
	bag_box.add_theme_constant_override("separation", 8)
	cols.add_child(bag_box)
	bag_box.add_child(_label(Loc.t("Your bag"), 24, Color(0.8, 0.9, 1.0)))
	var to_stash_foot := func(_id: String) -> String:
		return Loc.t("Left-click: move the stack to the stash   Right-click: move one")
	var to_bag_foot := func(_id: String) -> String:
		return Loc.t("Left-click: take the stack into your bag   Right-click: take one")
	var to_stash := func(id: String, n: int, b: int) -> void:
		move_item.emit(id, true, n if b == MOUSE_BUTTON_LEFT else 1)
	var to_bag := func(id: String, n: int, b: int) -> void:
		move_item.emit(id, false, n if b == MOUSE_BUTTON_LEFT else 1)
	bag_box.add_child(_slot_grid(inv, 4, 20, to_stash, to_stash_foot))
	var st_box := VBoxContainer.new()
	st_box.add_theme_constant_override("separation", 8)
	cols.add_child(st_box)
	st_box.add_child(_label(Loc.t("Stash"), 24, Color(0.85, 0.7, 1.0)))
	st_box.add_child(_slot_grid(stash, 8, 40, to_bag, to_bag_foot))
	_holder.add_child(_label(Loc.t("Items in the stash are safe: nothing is lost when you fall."), 18, Color(0.7, 0.66, 0.58)))

func set_boss_left(times: Dictionary) -> void:
	boss_left = times
	for id: String in _map_lbls:
		var l: Label = _map_lbls[id]
		if is_instance_valid(l):
			l.text = Loc.t(str(MapRun.DANGER[id])) + "\n" + _boss_text(id)

func _boss_text(id: String) -> String:
	var sec := int(boss_left.get(id, 0))
	if sec <= 0:
		return Loc.t("Boss: ready")
	return Loc.t("Boss returns in %s") % ("%d:%02d" % [sec / 60, sec % 60])

func _have(id: String) -> int:
	return int(inv.get(id, 0)) + int(stash.get(id, 0))

func _castle_stats(t: int, vs: int) -> String:
	var lines: Array[String] = []
	var rows := [
		[Loc.t("Health: %d"), Base.TIER_HP[t], Base.TIER_HP[vs]],
		[Loc.t("Armor: %d"), 3 * t, 3 * vs],
		[Loc.t("Gunner turrets: %d"), Base.AUTO_SLOTS[t], Base.AUTO_SLOTS[vs]],
	]
	for r: Array in rows:
		var line: String = str(r[0]) % int(r[1])
		if vs != t:
			line += "  (%+d)" % (int(r[1]) - int(r[2]))
		lines.append(line)
	return "\n".join(lines)

func _castle_column(t: int, caption: String, is_next: bool, vs: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var cap := _label(caption, 20, Color(1.0, 0.85, 0.3) if is_next else Color(0.8, 0.9, 1.0))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var view := CastleView.new()
	view.set_tip(Loc.t(Base.TIER_NAMES[t]), _castle_stats(t, vs), Loc.t("Next stage") if is_next else Loc.t("Your castle"))
	view.setup(t, is_next)
	col.add_child(view)
	if not is_next:
		_cur_view = view
	var nm := _label(Loc.t(Base.TIER_NAMES[t]), 26, Color(1, 1, 1))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(nm)
	var st := _label(Loc.t("Stage %d of %d") % [t + 1, Base.TIER_NAMES.size()], 18, Color(0.75, 0.7, 0.6))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(st)
	return col

func _build_yard() -> void:
	_title("Shipyard")
	_gold_line()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_holder.add_child(row)
	var last := tier >= Base.TIER_NAMES.size() - 1
	row.add_child(_castle_column(tier, "Your castle", false, tier))
	if not last:
		row.add_child(CastleView.ArrowView.new())
		row.add_child(_castle_column(tier + 1, "Next stage", true, tier))
	if _yard_seen >= 0 and tier > _yard_seen and _cur_view != null:
		_cur_view.pop()
	_yard_seen = tier
	var hint := _label(Loc.t("Hover a castle to see its stats."), 18, Color(0.75, 0.7, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_holder.add_child(hint)
	if last:
		var done := _label(Loc.t("Your castle is as large as it gets."), 24, Color(0.6, 1.0, 0.6))
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_holder.add_child(done)
		return
	var cost := Items.tier_cost(tier)
	var ok := coins >= int(cost["gold"])
	var costs := HBoxContainer.new()
	costs.add_theme_constant_override("separation", 26)
	costs.alignment = BoxContainer.ALIGNMENT_CENTER
	_holder.add_child(costs)
	costs.add_child(_cost_row("coin", Loc.t("Gold"), coins, int(cost["gold"])))
	for id: String in ["shard", "resin", "heart"]:
		var need := int(cost[id])
		if need <= 0:
			continue
		costs.add_child(_cost_row(id, Items.name_of(id), _have(id), need))
		ok = ok and _have(id) >= need
	var b := _button("Grow the castle", func() -> void: buy_tier.emit(), 420.0, 28)
	b.disabled = not ok
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Tip.attach(b, "Grow the castle", "Pays the gold and materials above and grows your castle one stage. Your stat points, weapon and level are kept. Materials come from the bag and the stash.", "walls")
	_holder.add_child(b)

func _cost_row(id: String, item: String, have: int, need: int) -> Control:
	var good := have >= need
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var ic := IconRect.new()
	ic.custom_minimum_size = Vector2(40, 40)
	ic.with_bg = false
	ic.set_kind(id)
	row.add_child(ic)
	var l := _label("%d / %d" % [have, need], 22, Color(0.6, 1.0, 0.6) if good else Color(1.0, 0.5, 0.4))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	if id == "coin":
		Tip.attach(ic, "Gold", "Dropped by every kill. Spend it on weapon upgrades and the Shipyard.", "coin")
		Tip.attach(l, "Gold", "Dropped by every kill. Spend it on weapon upgrades and the Shipyard.", "coin")
	else:
		var body := Items.desc_of(id) + "\n\n" + Items.drop_of(id)
		Tip.attach(ic, item, body, id)
		Tip.attach(l, item, body, id)
	return row
