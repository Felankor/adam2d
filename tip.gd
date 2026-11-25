class_name Tip
extends CanvasLayer

# One hover pop-up for the whole game. Hover anything that has a tip (inventory items, castle stats, HUD parts,
# hub buildings, buttons) and a small bronze card tells what it is. Controls use Tip.attach; things that are
# drawn by hand (the HUD, the hub buildings) call Tip.show_text every frame while the mouse is over them.

static var _inst: Tip = null

var _panel: PanelContainer
var _row: HBoxContainer
var _icon: IconRect
var _title: Label
var _body: Label
var _foot: Label
var _owner: Object = null

static func ensure(tree: SceneTree) -> void:
	if _inst != null and is_instance_valid(_inst):
		return
	_inst = Tip.new()
	tree.root.add_child.call_deferred(_inst)

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.theme = PixelUI.theme()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := PixelUI.box(Color(0.06, 0.04, 0.03, 0.97), PixelUI.BRONZE)
	sb.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	add_child(_panel)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_row)
	_icon = IconRect.new()
	_icon.custom_minimum_size = Vector2(52, 52)
	_icon.with_bg = false
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_row.add_child(_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", PixelUI.mfs(24))
	PixelUI.style_title(_title)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", PixelUI.mfs(18))
	_body.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_body)
	_foot = Label.new()
	_foot.add_theme_font_size_override("font_size", PixelUI.mfs(18))
	_foot.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_foot)

func _process(_delta: float) -> void:
	if _panel == null or not _panel.visible:
		return
	if _owner != null:
		if not is_instance_valid(_owner):
			_hide()
			return
		if _owner is Control and not (_owner as Control).is_visible_in_tree():
			_hide()
			return
	var vp := get_viewport()
	var m := vp.get_mouse_position()
	var sz := _panel.get_combined_minimum_size()
	_panel.size = sz
	var lim := vp.get_visible_rect().size
	var p := m + Vector2(26.0, 30.0)
	if p.x + sz.x > lim.x - 8.0:
		p.x = m.x - sz.x - 18.0
	if p.y + sz.y > lim.y - 8.0:
		p.y = m.y - sz.y - 18.0
	_panel.position = Vector2(maxf(p.x, 8.0), maxf(p.y, 8.0))

func _show(owner: Object, title: String, body: String, icon: String, foot: String) -> void:
	_owner = owner
	_title.text = title
	_body.text = body
	_body.visible = body != ""
	# wrap width follows the text: short texts stay on one line, long ones wrap at 460 (never one word per line)
	_body.custom_minimum_size = Vector2(clampf(float(body.length()) * 11.0, 200.0, 460.0), 0.0)
	_foot.text = foot
	_foot.visible = foot != ""
	_foot.custom_minimum_size = Vector2(clampf(float(foot.length()) * 11.0, 0.0, 460.0), 0.0)
	_title.custom_minimum_size = Vector2(float(title.length()) * 17.0, 0.0)
	_icon.visible = icon != ""
	if icon != "":
		_icon.set_kind(icon)
	_panel.visible = true
	_panel.reset_size()

func _hide() -> void:
	_owner = null
	if _panel != null:
		_panel.visible = false

# ---------- API ----------

# Shows (or refreshes) the card. Texts are English keys: they are translated here.
static func show_text(owner: Object, title: String, body: String = "", icon: String = "", foot: String = "") -> void:
	if _inst == null or not is_instance_valid(_inst) or _inst._panel == null:
		return
	var t := Loc.t(title)
	var b := Loc.t(body)
	var f := Loc.t(foot)
	if _inst._owner == owner and _inst._title.text == t and _inst._body.text == b and _inst._foot.text == f:
		return
	_inst._show(owner, t, b, icon, f)

static func hide_for(owner: Object) -> void:
	if _inst != null and is_instance_valid(_inst) and _inst._owner == owner:
		_inst._hide()

# Hover tip for a Control. Call it again to change the text. Attach to leaf controls (a label, an icon, a button),
# not to containers: a child that takes the mouse would hide the tip of its parent.
static func attach(c: Control, title: String, body: String = "", icon: String = "", foot: String = "") -> void:
	if c == null:
		return
	c.set_meta("tip", [title, body, icon, foot])
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	if c.has_meta("tip_on"):
		if _inst != null and is_instance_valid(_inst) and _inst._owner == c:
			_enter(c)               # the text changed while it is showing
		return
	c.set_meta("tip_on", true)
	c.mouse_entered.connect(Tip._enter.bind(c))
	c.mouse_exited.connect(Tip.hide_for.bind(c))
	c.tree_exiting.connect(Tip.hide_for.bind(c))

# The same tip on a control and every control inside it.
static func attach_all(c: Control, title: String, body: String = "", icon: String = "", foot: String = "") -> void:
	attach(c, title, body, icon, foot)
	for ch in c.get_children():
		if ch is Control:
			attach_all(ch as Control, title, body, icon, foot)

static func _enter(c: Control) -> void:
	if not c.has_meta("tip"):
		return
	var d: Array = c.get_meta("tip")
	show_text(c, str(d[0]), str(d[1]), str(d[2]), str(d[3]))
