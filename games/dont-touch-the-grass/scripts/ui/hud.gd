# Everything drawn over the 3D view: the level counter, the start hint, and the full-screen effects
# (camcorder finish, black fade, red flash).
extends CanvasLayer

var _level_label: Label
var _hint: Label
var _countdown: Label
var _saved: Label
var _black: ColorRect
var _red: ColorRect
var _screen: ShaderMaterial
var _danger := 0.0
var _fade: Tween
var _flash: Tween


func _ready() -> void:
	layer = 10
	var finish := ColorRect.new()
	finish.set_anchors_preset(Control.PRESET_FULL_RECT)
	finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var finish_mat := ShaderMaterial.new()
	finish_mat.shader = load("res://shaders/screen.gdshader")
	finish.material = finish_mat
	_screen = finish_mat
	add_child(finish)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Consolas", "monospace"])
	font.font_weight = 700

	_level_label = Label.new()
	_level_label.position = Vector2(28, 20)
	_level_label.add_theme_font_override("font", font)
	_level_label.add_theme_font_size_override("font_size", 22)
	_level_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.66, 0.92))
	_level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_level_label.add_theme_constant_override("shadow_offset_x", 2)
	_level_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_level_label)

	_hint = Label.new()
	_hint.text = "CLICK TO PLAY\n\nWASD move    SHIFT sprint    SPACE jump    ESC pause    F11 fullscreen"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -48
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.93, 0.88, 0.66, 0.92))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(_hint)

	_countdown = Label.new()
	_countdown.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_countdown.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown.offset_top = 18
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.add_theme_font_override("font", font)
	_countdown.add_theme_font_size_override("font_size", 28)
	_countdown.add_theme_color_override("font_color", Color(0.95, 0.25, 0.18))
	_countdown.visible = false
	add_child(_countdown)

	_saved = Label.new()
	_saved.text = "RUN SAVED"
	_saved.set_anchors_preset(Control.PRESET_CENTER)
	_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_saved.add_theme_font_override("font", font)
	_saved.add_theme_font_size_override("font_size", 36)
	_saved.add_theme_color_override("font_color", Color(0.93, 0.88, 0.66))
	_saved.visible = false
	add_child(_saved)

	_red = _overlay(Color(0.7, 0.0, 0.0, 0.0))
	_black = _overlay(Color(0, 0, 0, 0))


func set_level(number: int, total: int) -> void:
	_level_label.text = "LEVEL %d/%d" % [number, total]


func level_text() -> String:
	return _level_label.text


func set_danger(amount: float) -> void:
	_danger = amount
	_screen.set_shader_parameter("danger", amount)


func danger() -> float:
	return _danger


# seconds < 0 hides it.
func set_countdown(seconds: float) -> void:
	_countdown.visible = seconds >= 0.0
	if seconds >= 0.0:
		_countdown.text = "RESET IN %d" % ceili(seconds)


func show_saved() -> void:
	_saved.visible = true
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func() -> void: _saved.visible = false, CONNECT_ONE_SHOT)


func show_hint(visible_now: bool) -> void:
	_hint.visible = visible_now


# Screen goes black at once.
func blackout() -> void:
	if _fade:
		_fade.kill()
	_black.color.a = 1.0


func fade_in(seconds: float) -> void:
	await _fade_to(0.0, seconds)


func fade_out(seconds: float) -> void:
	await _fade_to(1.0, seconds)


# Short red hit across the screen.
func flash() -> void:
	if _flash:
		_flash.kill()
	_red.color.a = 0.4
	_flash = create_tween()
	_flash.tween_property(_red, "color:a", 0.08, 0.25)
	_flash.tween_property(_red, "color:a", 0.0, 0.5)


func _fade_to(alpha: float, seconds: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_black, "color:a", alpha, seconds)
	# Wait on a timer, not on the tween: a tween that gets replaced never reports that it finished.
	await get_tree().create_timer(seconds).timeout


func _overlay(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
