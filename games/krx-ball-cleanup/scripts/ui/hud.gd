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
var _held_count: Label
var _tool_vacuum: PanelContainer
var _tool_hand: PanelContainer
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
	_build_tools(root)
	_build_centre(root)
	GameState.counts_changed.connect(func() -> void: _dirty = true)
	GameState.level_unlocked.connect(_on_level_unlocked)
	GameState.sweep_started.connect(_on_sweep)


func _process(delta: float) -> void:
	_clock += delta
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
		if pit != null and pit.can_unload() and pit.looking_at():
			return true
	return false


func _refresh_counts() -> void:
	var level := GameState.current_level
	_balls_left.text = number(GameState.total_remaining())
	_level_name.text = "LEVEL %d / %d   %s" % [level + 1, GameState.LEVELS.size(), GameState.level_name(level).to_upper()]

	var stored := GameState.vacuum_stored
	_tank_text.text = "%s / %s" % [number(stored), number(GameState.VACUUM_CAPACITY)]
	_held_count.text = str(stored)
	_mark_tool(_tool_vacuum, GameState.tool == GameState.TOOL_VACUUM)
	_mark_tool(_tool_hand, GameState.tool == GameState.TOOL_HAND)


func _on_level_unlocked(level: int) -> void:
	Sfx.play("unlock", "Alerts", -3.0)
	announce("LEVEL %d COMPLETED" % level, GOOD, 4.5)


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
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	_pin(row, Control.PRESET_BOTTOM_LEFT, Vector2(22.0, -96.0))
	var jar := _jar()
	row.add_child(jar)
	_held_count = _label(row, "0", _bold, 36, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_held_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tank_text = _label(row, "0 / 50,000", _bold, 8, Color(0, 0, 0, 0))
	_tank_text.visible = false


func _jar() -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(72.0, 118.0)
	holder.clip_contents = true
	var picture := TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = _jar_picture()
	picture.modulate = Color(1, 1, 1, 0.45)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(picture)
	var capacity := _label(holder, "50000", _bold, 20, Color.WHITE)
	capacity.add_theme_color_override("font_outline_color", Color.BLACK)
	capacity.add_theme_constant_override("outline_size", 8)
	capacity.set_anchors_preset(Control.PRESET_FULL_RECT)
	capacity.offset_top = 18.0
	capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capacity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return holder


func _build_tools(root: Control) -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	root.add_child(column)
	_pin(column, Control.PRESET_BOTTOM_RIGHT, Vector2(-36.0, -150.0))
	_tool_vacuum = _tool_slot(column, "2", _vacuum_picture())
	_tool_hand = _tool_slot(column, "1", _fist_picture())


func _build_centre(root: Control) -> void:
	_dot = CentreDot.new()
	root.add_child(_dot)

	_prompt = _label(root, "PRESS E TO EMPTY VACUUM", _bold, 22, Color.WHITE)
	_pin(_prompt, Control.PRESET_CENTER, Vector2.ZERO)
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


func _mark_tool(slot: PanelContainer, selected: bool) -> void:
	var style := slot.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	style.bg_color = Color(0.96, 0.96, 0.97, 0.96) if selected else Color(0.22, 0.22, 0.25, 0.78)
	slot.custom_minimum_size = Vector2(78.0, 78.0) if selected else Vector2(58.0, 58.0)
	slot.rotation = 0.0
	for child in slot.get_children():
		if child is TextureRect:
			child.modulate = Color(0.12, 0.12, 0.14) if selected else Color.WHITE


func _tool_slot(parent: Control, key_text: String, icon: Texture2D) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(58.0, 58.0)
	slot.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.22, 0.25, 0.78)
	style.set_corner_radius_all(14)
	slot.add_theme_stylebox_override("panel", style)
	parent.add_child(slot)
	var picture := TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = icon
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(40.0, 40.0)
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 8.0
	picture.offset_top = 6.0
	picture.offset_right = -8.0
	picture.offset_bottom = -8.0
	slot.add_child(picture)
	var key := _label(slot, key_text, _bold, 14, Color(0.9, 0.9, 0.92))
	key.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	key.offset_left = -18.0
	key.offset_top = -18.0
	return slot


func _jar_picture() -> Texture2D:
	var image := Image.new()
	image.load("res://assets/ui/jar.png")
	return ImageTexture.create_from_image(image)


func _vacuum_picture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink := Color.WHITE
	_disc(image, Vector2(24, 40), Vector2(16, 14), ink)
	_disc(image, Vector2(24, 40), Vector2(8, 8), Color(0, 0, 0, 0))
	_box_px(image, Rect2i(30, 22, 22, 6), ink)
	_box_px(image, Rect2i(48, 16, 8, 8), ink)
	_box_px(image, Rect2i(14, 18, 5, 16), ink)
	_disc(image, Vector2(16, 16), Vector2(6, 5), ink)
	return ImageTexture.create_from_image(image)


func _fist_picture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink := Color.WHITE
	_disc(image, Vector2(34, 36), Vector2(16, 14), ink)
	_disc(image, Vector2(22, 24), Vector2(6, 8), ink)
	_disc(image, Vector2(30, 20), Vector2(6, 8), ink)
	_disc(image, Vector2(38, 20), Vector2(6, 8), ink)
	_disc(image, Vector2(46, 24), Vector2(6, 7), ink)
	_disc(image, Vector2(18, 34), Vector2(7, 6), ink)
	return ImageTexture.create_from_image(image)


func _disc(image: Image, centre: Vector2, radius: Vector2, color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var point := Vector2(float(x) - centre.x, float(y) - centre.y)
			if (point.x * point.x) / (radius.x * radius.x) + (point.y * point.y) / (radius.y * radius.y) <= 1.0:
				image.set_pixel(x, y, color)


func _box_px(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)


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
