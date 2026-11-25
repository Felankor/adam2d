class_name TextFit
extends RefCounted

# Keeps texts inside their boxes (translations are often longer than the English text).
# Every Label or Button that has a fixed width (custom_minimum_size.x) is watched: when its text is too wide,
#  - a Label wraps onto more lines (or, with meta "fit" = "shrink", gets a smaller font),
#  - a Button gets a smaller font (on the pixel grid) and, as a last resort, "..." at the end.
# It hooks the scene tree once, so every window is covered without touching its code.

static var _hooked: bool = false

static func hook(tree: SceneTree) -> void:
	if _hooked:
		return
	_hooked = true
	tree.node_added.connect(_on_added)

static func _on_added(n: Node) -> void:
	if n is Label or n is Button:
		TextFit.fit_node.bind(n).call_deferred()

# The biggest font size (starting at `base`, going down the pixel grid) at which the widest line fits in `avail`.
static func best_size(font: Font, text: String, base: int, avail: float) -> int:
	var last := base
	var k := base
	while k >= 10:
		var s := mini(PixelUI.mfs(k), base)
		if s < last or k == base:
			last = s
			if _width(font, text, s) <= avail:
				return s
		k -= 1
	return maxi(last, 10)

static func _width(font: Font, text: String, size: int) -> float:
	var w := 0.0
	for line in text.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return w

static func fit_node(n: Node) -> void:
	if not is_instance_valid(n):
		return
	var c := n as Control
	if c.custom_minimum_size.x <= 0.0:
		return
	if not c.has_meta("fit_hooked"):
		c.set_meta("fit_hooked", true)
		c.minimum_size_changed.connect(TextFit.fit_node.bind(c), CONNECT_DEFERRED)
	if c is Label:
		_fit_label(c as Label)
	elif c is Button:
		_fit_button(c as Button)

static func _base_size(c: Control) -> int:
	if not c.has_meta("fit_base"):
		c.set_meta("fit_base", c.get_theme_font_size("font_size"))
	return int(c.get_meta("fit_base"))

static func _fit_label(l: Label) -> void:
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF and not l.has_meta("fit_wrapped"):
		return                                  # wraps by itself already
	var base := _base_size(l)
	var font := l.get_theme_font("font")
	var avail := l.custom_minimum_size.x - 2.0
	var shrink := str(l.get_meta("fit", "")) == "shrink"
	var need := _width(font, l.text, base)
	if need <= avail:
		if l.has_meta("fit_wrapped"):
			l.remove_meta("fit_wrapped")
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
		if l.has_theme_font_size_override("font_size") and l.get_theme_font_size("font_size") != base:
			l.add_theme_font_size_override("font_size", base)
		return
	if shrink:
		var s := best_size(font, l.text, base, avail)
		if s != l.get_theme_font_size("font_size"):
			l.add_theme_font_size_override("font_size", s)
		if not l.clip_text:
			l.clip_text = true
		if l.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS:
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	elif not l.has_meta("fit_wrapped"):
		l.set_meta("fit_wrapped", true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func _fit_button(b: Button) -> void:
	var base := _base_size(b)
	var font := b.get_theme_font("font")
	var sb := b.get_theme_stylebox("normal")
	var pad := sb.get_minimum_size().x if sb != null else 28.0
	var avail := b.custom_minimum_size.x - pad - 4.0
	if b.icon != null:
		avail -= float(b.icon.get_width()) + float(b.get_theme_constant("h_separation"))
	var s := best_size(font, b.text, base, avail)
	var wrap := false
	var mid := mini(PixelUI.mfs(20), base)
	if s < mid and _width(font, b.text, mid) <= avail * 1.9:
		s = mid                                   # two lines at a readable size beat tiny letters
		wrap = true
	if s != b.get_theme_font_size("font_size"):
		b.add_theme_font_size_override("font_size", s)
	var over := not wrap and _width(font, b.text, s) > avail
	if b.clip_text != over:
		b.clip_text = over
	var ov := TextServer.OVERRUN_TRIM_ELLIPSIS if over else TextServer.OVERRUN_NO_TRIMMING
	if b.text_overrun_behavior != ov:
		b.text_overrun_behavior = ov
	var aw := TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if int(b.get("autowrap_mode")) != int(aw):
		b.set("autowrap_mode", aw)
