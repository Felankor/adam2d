class_name Notifier
extends VBoxContainer

# Small pop-up messages in the bottom-left corner ("Taken Damage!", "Refugee Hit!").
# Repeats of the same message are merged into one toast with a counter.
const MAX_TOASTS := 5
const LIFE := 3.2
const FADE_IN := 0.15
const FADE_OUT := 0.5

var _toasts: Array[Dictionary] = []
var _fid: String = "game"          # HUD editor: font and text size of the pop-ups
var _fmult: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 28.0
	offset_right = 28.0 + 480.0
	offset_top = -28.0
	offset_bottom = -28.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", 8)

# HUD editor: shift, size and opacity of the whole pop-up stack.
func set_shift(off: Vector2, sc: float, a: float) -> void:
	offset_left = 28.0 + off.x
	offset_right = 28.0 + 480.0 + off.x
	offset_top = -28.0 + off.y
	offset_bottom = -28.0 + off.y
	scale = Vector2(sc, sc)
	modulate.a = a

func _style_label(l: Label) -> void:
	l.add_theme_font_override("font", HudFonts.get_font(_fid))
	l.add_theme_font_size_override("font_size", HudFonts.size_for(_fid, 22.0, _fmult))

func set_text_style(fid: String, mult: float) -> void:
	if fid == _fid and is_equal_approx(mult, _fmult):
		return
	_fid = fid
	_fmult = mult
	for t in _toasts:
		_style_label(t["label"] as Label)

# icon: an Icons kind ("" = none). key merges repeated messages.
func push(text: String, icon: String = "", color: Color = Color.WHITE, key: String = "") -> void:
	if key != "":
		for t in _toasts:
			if str(t["key"]) == key and float(t["age"]) < LIFE - FADE_OUT:
				t["count"] = int(t["count"]) + 1
				t["age"] = FADE_IN
				var lbl := t["label"] as Label
				lbl.text = "%s  x%d" % [text, int(t["count"])]
				return
	while _toasts.size() >= MAX_TOASTS:
		_remove(0)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := PixelUI.plate(Color(0.07, 0.05, 0.04, 0.92), color, 2)
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	if icon != "":
		var ic := IconRect.new()
		ic.custom_minimum_size = Vector2(38, 38)
		ic.kind = icon
		row.add_child(ic)
	var label := Label.new()
	label.text = text
	_style_label(label)
	label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.55))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	panel.modulate.a = 0.0
	add_child(panel)
	_toasts.append({"node": panel, "label": label, "age": 0.0, "key": key, "count": 1})

func _process(delta: float) -> void:
	pivot_offset = Vector2(0.0, size.y)      # scale from the bottom-left corner (HUD editor)
	var i := 0
	while i < _toasts.size():
		var t := _toasts[i]
		t["age"] = float(t["age"]) + delta
		var age := float(t["age"])
		if age >= LIFE:
			_remove(i)
			continue
		var node := t["node"] as Control
		node.modulate.a = clampf(age / FADE_IN, 0.0, 1.0) * clampf((LIFE - age) / FADE_OUT, 0.0, 1.0)
		i += 1

func _remove(index: int) -> void:
	var node := _toasts[index]["node"] as Control
	_toasts.remove_at(index)
	if is_instance_valid(node):
		node.queue_free()
