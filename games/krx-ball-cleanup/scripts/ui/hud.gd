class_name Hud
extends CanvasLayer
## The in-game interface. Laid out for 1920 x 1080 and scaled with the window.
##
##   top centre     balls left in the whole game, current level
##   top right      run timer
##   bottom left    vacuum tank
##   bottom right   controls
##   centre         aiming dot, the unload prompt, the VACUUM FULL warning, short announcements
##
## Text is large on purpose: this is watched on a phone through TikTok LIVE. There is no money counter.

const PANEL_COLOR := Color(0.035, 0.05, 0.075, 0.62)
const DIM := Color(0.72, 0.79, 0.87)
const ACCENT := Color(0.97, 0.82, 0.2)
const GOOD := Color(0.3, 0.92, 0.48)
const BAD := Color(1.0, 0.27, 0.2)

## Tells the HUD when the unload prompt applies. Set by the main scene.
var pits: Array[CollectionPit] = []

var _bold: Font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
var _semi: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")

var _balls_left: Label
var _level_name: Label
var _timer: Label
var _tank_text: Label
var _tank_bar: ProgressBar
var _tank_fill: StyleBoxFlat
var _prompt: Control
var _full: Control
var _toast: Label
var _click_hint: Label
var _dot: CentreDot
var _dirty := true
var _shown_second := -1
var _toast_time := 0.0
var _clock := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_centre(root)
	_build_top_right(root)
	_build_tank(root)
	_build_controls(root)
	_build_centre(root)
	GameState.counts_changed.connect(func() -> void: _dirty = true)
	GameState.level_unlocked.connect(_on_level_unlocked)
	GameState.sweep_started.connect(_on_sweep)


func _process(delta: float) -> void:
	_clock += delta
	if _dirty:
		_dirty = false
		_refresh_counts()
	var second := int(GameState.run_time)
	if second != _shown_second:
		_shown_second = second
		_timer.text = clock_text(second)

	_prompt.visible = _any_pit_ready()
	_full.visible = GameState.vacuum_full()
	if _full.visible:
		_full.modulate.a = 0.55 + 0.45 * absf(sin(_clock * 5.0))
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)
		_toast.visible = _toast_time > 0.0


## A short announcement under the ball counter. Fades after `seconds`.
func announce(text: String, color: Color, seconds := 4.0) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast_time = seconds
	_toast.modulate.a = 1.0
	_toast.visible = true


func show_click_hint(on: bool) -> void:
	_click_hint.visible = on


func balls_left_text() -> String:
	return _balls_left.text


func level_text() -> String:
	return _level_name.text


func tank_text() -> String:
	return _tank_text.text


func deposited_text() -> String:
	return number(GameState.deposited)


func prompt_visible() -> bool:
	return _prompt.visible


func full_warning_visible() -> bool:
	return _full.visible


func toast_text() -> String:
	return _toast.text if _toast.visible else ""


func dot() -> CentreDot:
	return _dot


## 12345 -> "12,345"
static func number(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## 3725 -> "1:02:05", 125 -> "02:05"
static func clock_text(seconds: int) -> String:
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func _any_pit_ready() -> bool:
	for pit in pits:
		if pit != null and pit.can_unload():
			return true
	return false


func _refresh_counts() -> void:
	var level := GameState.current_level
	_balls_left.text = number(GameState.total_remaining())
	_level_name.text = "LEVEL %d / %d   %s" % [level + 1, GameState.LEVELS.size(), GameState.level_name(level).to_upper()]

	var stored := GameState.vacuum_stored
	var fill := float(stored) / GameState.VACUUM_CAPACITY
	_tank_text.text = "%s / %s" % [number(stored), number(GameState.VACUUM_CAPACITY)]
	_tank_bar.value = fill * 100.0
	_tank_fill.bg_color = BAD if fill >= 1.0 else (ACCENT if fill >= 0.8 else GOOD)


func _on_level_unlocked(level: int) -> void:
	Sfx.play("unlock", "Alerts", -3.0)
	if level == 1:
		announce("LEVEL 2 UNLOCKED   POOLROOM", GOOD, 5.0)
	else:
		announce("LEVEL %d UNLOCKED   %s   (NOT BUILT YET)" % [level + 1, GameState.level_name(level).to_upper()], GOOD, 6.0)


func _on_sweep() -> void:
	Sfx.play("unlock", "Alerts", -3.0)
	announce("FIND THE LAST BALLS", ACCENT, 7.0)


# ---------------------------------------------------------------- layout

func _build_top_centre(root: Control) -> void:
	var box := _stack(root, Control.PRESET_CENTER_TOP, Vector2(0.0, 18.0))
	_label(box, "BALLS LEFT", _semi, 28, Color(1.0, 0.92, 0.78, 0.85))
	_balls_left = _label(box, "0", _bold, 108, Color(1.0, 0.97, 0.9))
	_level_name = _label(box, "", _semi, 32, ACCENT)


func _build_top_right(root: Control) -> void:
	var box := _stack(root, Control.PRESET_TOP_RIGHT, Vector2(-26.0, 22.0))
	_label(box, "RUN TIME", _semi, 22, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_timer = _label(box, "00:00", _bold, 44, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)


func _build_tank(root: Control) -> void:
	var box := _stack(root, Control.PRESET_BOTTOM_LEFT, Vector2(26.0, -26.0))
	_label(box, "VACUUM", _semi, 18, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_tank_text = _label(box, "0 / 50,000", _bold, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_tank_bar = _bar(box, GOOD, 14.0)
	_tank_bar.custom_minimum_size = Vector2(220.0, 14.0)
	_tank_fill = _tank_bar.get_theme_stylebox("fill") as StyleBoxFlat


func _build_controls(root: Control) -> void:
	var box := _panel(root, Control.PRESET_BOTTOM_RIGHT, Vector2(-26.0, -26.0))
	for line: String in [
		"WASD  MOVE     SHIFT  SPRINT     SPACE  JUMP",
		"HOLD LEFT MOUSE  VACUUM",
		"HOLD E AT A BALL PIT  EMPTY VACUUM",
		"ESC  PAUSE AND SETTINGS",
	]:
		_label(box, line, _semi, 25, DIM, HORIZONTAL_ALIGNMENT_RIGHT)


func _build_centre(root: Control) -> void:
	_dot = CentreDot.new()
	root.add_child(_dot)

	var prompt_box := _panel(root, Control.PRESET_CENTER, Vector2(0.0, 150.0))
	_label(prompt_box, "HOLD E TO EMPTY VACUUM", _bold, 50, Color.WHITE)
	_prompt = prompt_box.get_parent()
	_prompt.visible = false

	var full_box := VBoxContainer.new()
	full_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(full_box)
	_pin(full_box, Control.PRESET_CENTER, Vector2(0.0, -230.0))
	_label(full_box, "VACUUM FULL!", _bold, 96, BAD)
	_label(full_box, "TAKE IT BACK TO THE PLAYROOM PITS", _semi, 34, Color.WHITE)
	_full = full_box
	_full.visible = false

	_toast = _label(root, "", _bold, 54, GOOD)
	_pin(_toast, Control.PRESET_CENTER_TOP, Vector2(0.0, 250.0))
	_toast.visible = false

	_click_hint = _label(root, "CLICK TO START", _bold, 64, Color.WHITE)
	_pin(_click_hint, Control.PRESET_CENTER, Vector2(0.0, 80.0))
	_click_hint.visible = false


# Labels only, no dark plate. Returns the column.
func _stack(root: Control, preset: Control.LayoutPreset, offset: Vector2) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", -2)
	root.add_child(column)
	_pin(column, preset, offset)
	return column


# A rounded dark panel pinned to one corner or edge. Returns the column inside it.
func _panel(root: Control, preset: Control.LayoutPreset, offset: Vector2) -> VBoxContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(16)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 14.0
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	_pin(panel, preset, offset)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", -2)
	panel.add_child(column)
	return column


# Pins a control to a corner, edge or the centre of the screen, `offset` pixels from there.
func _pin(control: Control, preset: Control.LayoutPreset, offset: Vector2) -> void:
	control.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	control.grow_horizontal = _grow(preset, true)
	control.grow_vertical = _grow(preset, false)
	control.offset_left += offset.x
	control.offset_right += offset.x
	control.offset_top += offset.y
	control.offset_bottom += offset.y


# Which way a pinned panel grows as its text gets longer, so it stays pinned.
func _grow(preset: Control.LayoutPreset, horizontal: bool) -> Control.GrowDirection:
	if horizontal:
		match preset:
			Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT:
				return Control.GROW_DIRECTION_BEGIN
			Control.PRESET_CENTER_TOP, Control.PRESET_CENTER:
				return Control.GROW_DIRECTION_BOTH
		return Control.GROW_DIRECTION_END
	match preset:
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT:
			return Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_LEFT, Control.PRESET_CENTER:
			return Control.GROW_DIRECTION_BOTH
	return Control.GROW_DIRECTION_END


func _label(parent: Control, text: String, font: Font, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("outline_size", maxi(size / 9, 3))
	parent.add_child(label)
	return label


func _bar(parent: Control, color: Color, height: float) -> ProgressBar:
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1.0, 1.0, 1.0, 0.14)
	back.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(8)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar
