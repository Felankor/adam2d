class_name ChapterScene
extends Control

# Everything that happens between two chapters:
#   1. show_summary():   a window with the chapter's statistics and a "Continue!" button (the game is paused)
#   2. start_transition(): clouds roll in from both sides of the screen   -> signal covered
#      (the main scene builds the next chapter behind the clouds, then calls release())
#   3. the clouds roll back out the same way, and a title card greets the player: "Chapter III: High Mountains"
# show_card() alone shows the title card (a new game, or a loaded game that starts a chapter).

signal continue_pressed
signal covered              # the clouds hide the whole screen: swap the chapter now
signal clouds_cleared       # the clouds are gone and the game goes on (the title card is still fading)

const COVER_TIME := 1.6
const HOLD_MIN := 1.1
const CARD_IN := 0.8
const CARD_HOLD := 2.8
const CARD_OUT := 1.2
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]

var state: String = ""            # "", "summary", "in", "hold", "out", "card"
var _t: float = 0.0
var _clock: float = 0.0
var _count: float = 0.0           # count-up progress of the numbers, 0..1
var _released: bool = false
var _card_on: bool = false
var _card_t: float = 0.0

var _center: CenterContainer
var _panel: PanelContainer
var _box: VBoxContainer
var _rows_box: VBoxContainer
var _sub: Label
var _continue: Button
var _rows: Array = []             # [{"val": Label, "num": float, "text": String}]

var _card: VBoxContainer
var _card_title: Control
var _card_name: Label
var _card_tag: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PixelUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# ---- the statistics window ----
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.visible = false
	add_child(_center)
	_panel = PanelContainer.new()
	var sb := PixelUI.box(PixelUI.WIN_BG, PixelUI.BRONZE)
	sb.set_content_margin_all(46)
	_panel.add_theme_stylebox_override("panel", sb)
	_center.add_child(_panel)
	PixelUI.fit(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_panel.add_child(_box)

	# ---- the title card ----
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 6)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)

func blocking() -> bool:
	return state == "summary" or state == "in" or state == "hold" or state == "out"

# info: {"roman": "III", "name": "High Mountains", "rows": [{"label": String, "num": float}, {"label": String, "text": String}]}
func show_summary(info: Dictionary) -> void:
	for c in _box.get_children():
		c.queue_free()
	_rows.clear()
	_box.add_child(PixelTitle.make(str(info.get("title", "CHAPTER COMPLETE")), 46))
	_sub = Label.new()
	_sub.text = Loc.t(str(info["sub"])) if info.has("sub") else "%s %s:  %s" % [Loc.t("Chapter"), str(info.get("roman", "I")), Loc.t(str(info.get("name", "")))]
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", PixelUI.mfs(30))
	_sub.add_theme_color_override("font_color", PixelUI.CREAM)
	_box.add_child(_sub)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 8)
	_box.add_child(_rows_box)
	for r: Dictionary in info.get("rows", []):
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", PixelUI.plate(Color(0.05, 0.035, 0.025, 0.9), PixelUI.BRONZE))
		row.custom_minimum_size = Vector2(760, 58)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 20)
		row.add_child(h)
		var lab := Label.new()
		lab.text = Loc.t(str(r["label"]))
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", PixelUI.mfs(26))
		lab.add_theme_color_override("font_color", PixelUI.CREAM)
		h.add_child(lab)
		var val := Label.new()
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", PixelUI.mfs(32))
		val.add_theme_color_override("font_color", PixelUI.GOLD)
		h.add_child(val)
		_rows_box.add_child(row)
		_rows.append({"val": val, "num": float(r.get("num", 0.0)), "text": str(r.get("text", "")), "is_num": r.has("num")})
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_box.add_child(spacer)
	_continue = Button.new()
	_continue.text = Loc.t(str(info.get("button", "Continue!")))
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.custom_minimum_size = Vector2(380, 70)
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.add_theme_font_size_override("font_size", PixelUI.mfs(32))
	_continue.pressed.connect(_on_continue)
	_box.add_child(_continue)
	_count = 0.0
	_apply_numbers()
	state = "summary"
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center.visible = true
	_card.visible = false
	_card_on = false
	Sfx.play("biome_win")

func _on_continue() -> void:
	if state != "summary":
		return
	Sfx.play("click")
	_continue.disabled = true
	continue_pressed.emit()

# The clouds roll in. Emits `covered` when the screen is hidden.
func start_transition() -> void:
	state = "in"
	_t = 0.0
	_released = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center.visible = false
	visible = true

# The main scene has finished building the next chapter behind the clouds.
func release() -> void:
	_released = true

func show_card(info: Dictionary) -> void:
	for c in _card.get_children():
		c.queue_free()
	_card_title = PixelTitle.make("%s %s" % [Loc.t("Chapter"), str(info.get("roman", "I"))], 76)
	_card.add_child(_card_title)
	_card_name = Label.new()
	_card_name.text = Loc.t(str(info.get("name", "")))
	_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_name.add_theme_font_size_override("font_size", PixelUI.mfs(54))
	_card_name.add_theme_color_override("font_color", Color.WHITE)
	_card_name.add_theme_constant_override("outline_size", PixelUI.ol(10))
	_card_name.add_theme_color_override("font_outline_color", PixelUI.OUTLINE)
	_card.add_child(_card_name)
	_card_tag = Label.new()
	_card_tag.text = Loc.t(str(info.get("tag", "")))
	_card_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_tag.add_theme_font_size_override("font_size", PixelUI.mfs(26))
	_card_tag.add_theme_color_override("font_color", PixelUI.DIM.lightened(0.25))
	_card_tag.add_theme_constant_override("outline_size", PixelUI.ol(6))
	_card_tag.add_theme_color_override("font_outline_color", PixelUI.OUTLINE)
	_card.add_child(_card_tag)
	_card.custom_minimum_size = Vector2(1100, 0)
	_card.position = Vector2(size.x * 0.5 - 550.0, size.y * 0.26)
	_card_on = true
	_card_t = 0.0
	_card.visible = true
	_card.modulate.a = 0.0
	visible = true
	if state == "":
		state = "card"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("weapon_up", -4.0)

func _input(event: InputEvent) -> void:
	if state != "summary":
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		_on_continue()

func _process(delta: float) -> void:
	_clock += delta
	match state:
		"summary":
			if _count < 1.0:
				_count = minf(_count + delta / 1.5, 1.0)
				_apply_numbers()
		"in":
			_t += delta
			if _t >= COVER_TIME:
				_t = 0.0
				state = "hold"
				covered.emit()
		"hold":
			_t += delta
			if _t >= HOLD_MIN and _released:
				_t = 0.0
				state = "out"
		"out":
			_t += delta
			if _t >= COVER_TIME:
				_t = 0.0
				state = "card" if _card_on else ""
				mouse_filter = Control.MOUSE_FILTER_IGNORE
				clouds_cleared.emit()
	if _card_on:
		var covering := state == "in" or state == "hold" or state == "out"
		if not covering:
			_card_t += delta                  # the card starts when the clouds are gone
		_card.position = Vector2(size.x * 0.5 - 550.0, size.y * 0.26)
		var a := 1.0
		if _card_t < CARD_IN:
			a = _card_t / CARD_IN
		elif _card_t > CARD_IN + CARD_HOLD:
			a = 1.0 - (_card_t - CARD_IN - CARD_HOLD) / CARD_OUT
		a = clampf(a, 0.0, 1.0)
		_card.modulate.a = 0.0 if covering else a
		if _card_t >= CARD_IN + CARD_HOLD + CARD_OUT:
			_card_on = false
			_card.visible = false
			if state == "card":
				state = ""
	if state == "" and not _card_on:
		visible = false
	else:
		queue_redraw()

func _apply_numbers() -> void:
	var e := 1.0 - pow(1.0 - _count, 3.0)
	for r: Dictionary in _rows:
		var lab := r["val"] as Label
		if lab == null:
			continue
		if bool(r["is_num"]):
			lab.text = _fmt(float(r["num"]) * e)
		else:
			lab.text = Loc.t(str(r["text"]))

static func _fmt(v: float) -> String:
	var s := str(int(roundf(v)))
	var out := ""
	var n := s.length()
	for i in n:
		out += s[i]
		var left := n - 1 - i
		if left > 0 and left % 3 == 0:
			out += ","
	return out

# ---------- drawing ----------

# 0 = clear sky, 1 = covered. Linear in time: every cloud eases itself with its own delay and speed.
func _cover_amount() -> float:
	match state:
		"in":
			return clampf(_t / COVER_TIME, 0.0, 1.0)
		"hold":
			return 1.0
		"out":
			return clampf(1.0 - _t / COVER_TIME, 0.0, 1.0)
	return 0.0

static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _draw() -> void:
	if state == "summary":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.01, 0.72))
	if _card_on and state != "in" and state != "hold" and state != "out":
		var a := _card.modulate.a
		var band_y := size.y * 0.26 - 40.0
		draw_rect(Rect2(0.0, band_y, size.x, 300.0), Color(0.02, 0.015, 0.03, 0.62 * a))
		draw_rect(Rect2(0.0, band_y, size.x, 4.0), Color(0.85, 0.65, 0.2, 0.8 * a))
		draw_rect(Rect2(0.0, band_y + 296.0, size.x, 4.0), Color(0.85, 0.65, 0.2, 0.8 * a))
	var k := _cover_amount()
	if k > 0.0:
		_draw_clouds(k)

# ---------- clouds ----------
# Many separate clouds of different sizes and shapes in three layers (far, middle, near). Each one sails in from the
# side of the screen at its own pace, the near ones overlapping the far ones, and keeps drifting a little while it
# waits. They leave the same way in reverse.

const LAYER_COUNT := [12, 12, 10]                  # far, middle, near
const LAYER_SCALE := [Vector2(0.8, 1.2), Vector2(1.1, 1.6), Vector2(1.5, 2.2)]
const LAYER_DELAY := [Vector2(0.0, 0.30), Vector2(0.05, 0.40), Vector2(0.12, 0.50)]
const LAYER_DRIFT := [0.35, 0.6, 0.9]
const LAYER_COL := [Color(0.50, 0.54, 0.65), Color(0.64, 0.68, 0.77), Color(0.82, 0.85, 0.92)]

var _clouds: Array = []
var _clouds_for: Vector2 = Vector2.ZERO

func _build_clouds() -> void:
	_clouds.clear()
	_clouds_for = size
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for layer in 3:
		var n: int = LAYER_COUNT[layer]
		for i in n:
			var sc: Vector2 = LAYER_SCALE[layer]
			var k := rng.randf_range(sc.x, sc.y)
			var cx := (float(i) + rng.randf_range(0.1, 0.9)) / float(n) * size.x
			var cy := fposmod(float(i) * 0.618 + float(layer) * 0.31 + rng.randf_range(-0.08, 0.08), 1.0) * (size.y + 160.0) - 80.0
			# the cloud's shape: a row of puffs, fat in the middle, with ragged tops
			var puffs: Array = []
			var count := rng.randi_range(4, 8)
			var width := rng.randf_range(260.0, 480.0) * k
			for j in count:
				var u := (float(j) + 0.5) / float(count) * 2.0 - 1.0
				var bump := 1.0 - 0.55 * absf(u)
				var r := rng.randf_range(0.55, 0.85) * width * 0.30 * bump
				puffs.append([Vector2(u * width * 0.5, rng.randf_range(-0.18, 0.12) * width * 0.3), r])
			var from_left := cx < size.x * 0.5
			if absf(cx - size.x * 0.5) < size.x * 0.12:
				from_left = rng.randf() < 0.5
			var dl: Vector2 = LAYER_DELAY[layer]
			_clouds.append({
				"layer": layer, "x": cx, "y": cy, "puffs": puffs, "width": width,
				"side": -1.0 if from_left else 1.0,
				"delay": rng.randf_range(dl.x, dl.y),
				"phase": rng.randf() * TAU,
				"amp": rng.randf_range(14.0, 48.0),
				"rate": float(LAYER_DRIFT[layer]) * rng.randf_range(0.6, 1.4),
			})

func _draw_clouds(p: float) -> void:
	if _clouds.is_empty() or _clouds_for != size:
		_build_clouds()
	var w := size.x
	var h := size.y
	# a haze that closes the gaps between the clouds when they have nearly arrived
	var haze := _ease((p - 0.55) / 0.45)
	if haze > 0.0:
		var hc: Color = LAYER_COL[1]
		draw_rect(Rect2(Vector2.ZERO, size), Color(hc.r, hc.g, hc.b, haze))
	for layer in 3:
		var base: Color = LAYER_COL[layer]
		var dark := base.darkened(0.28)
		var light := base.lightened(0.35)
		for c: Dictionary in _clouds:
			if int(c["layer"]) != layer:
				continue
			var delay: float = c["delay"]
			var local := _ease((p - delay) / maxf(1.0 - delay, 0.2))
			if local <= 0.0:
				continue
			var side: float = c["side"]
			var width: float = c["width"]
			# off-screen start on its own side, so it travels in from the edge
			var rest_x: float = c["x"]
			var start_x := -width * 0.8 if side < 0.0 else w + width * 0.8
			var x := lerpf(start_x, rest_x, local)
			x += sin(_clock * float(c["rate"]) + float(c["phase"])) * float(c["amp"]) * local
			var y: float = float(c["y"]) + cos(_clock * float(c["rate"]) * 0.7 + float(c["phase"])) * 8.0
			var pos := Vector2(x, y)
			for tone in 3:
				for pf: Array in c["puffs"]:
					var off: Vector2 = pf[0]
					var r: float = pf[1]
					if tone == 0:
						PixelFx.disc(self, pos + off + Vector2(6.0, 12.0), r * 1.04, dark)
					elif tone == 1:
						PixelFx.disc(self, pos + off, r, base)
					else:
						PixelFx.disc(self, pos + off + Vector2(-r * 0.12, -r * 0.28), r * 0.62, light)
