class_name PauseMenu
extends CanvasLayer
## Pause menu and settings, opened with Esc.
##
## Every control here writes straight to Settings, which applies the change at once and saves it. There is no
## Apply button. Controls are only listed once the thing they change exists: the TikTok interactions page,
## Save Game, and the Music and Monster volume sliders arrive with those features.

signal resume_pressed
signal restart_pressed
signal exit_pressed

const PANEL_COLOR := Color(0.05, 0.065, 0.09, 0.96)
const ACCENT := Color(0.97, 0.82, 0.2)

## Setting path ("camera/fov") -> the control that edits it. The automatic test drives these.
var controls := {}

var _bold: Font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
var _semi: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
var _root: Control
var _main_page: Control
var _settings_page: Control
var _restart: Button
var _restart_armed := 0.0
var _syncs: Array[Callable] = []


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	_main_page = _build_main()
	centre.add_child(_main_page)
	_settings_page = _build_settings()
	centre.add_child(_settings_page)
	Settings.changed.connect(_on_setting_changed)
	visible = false


func _process(delta: float) -> void:
	if _restart_armed > 0.0:
		_restart_armed -= delta
		if _restart_armed <= 0.0:
			_restart.text = "RESTART RUN"


# Esc while the menu is up: leave the settings page first, then the menu.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if _settings_page.visible:
		_show_page(_main_page)
	else:
		resume_pressed.emit()


func open() -> void:
	_show_page(_main_page)
	visible = true


func close() -> void:
	visible = false
	_restart_armed = 0.0
	_restart.text = "RESTART RUN"


func showing_settings() -> bool:
	return visible and _settings_page.visible


func open_settings() -> void:
	_show_page(_settings_page)


func _show_page(page: Control) -> void:
	_main_page.visible = page == _main_page
	_settings_page.visible = page == _settings_page


# ---------------------------------------------------------------- pause page

func _build_main() -> Control:
	var column := _card(520.0)
	_heading(column, "PAUSED", 72)
	_button(column, "RESUME GAME", func() -> void: resume_pressed.emit())
	_button(column, "SETTINGS", func() -> void: _show_page(_settings_page))
	_restart = _button(column, "RESTART RUN", _on_restart)
	_button(column, "EXIT GAME", func() -> void: exit_pressed.emit())
	return column.get_parent()


# Restarting throws the run away, so it takes two presses within three seconds.
func _on_restart() -> void:
	if _restart_armed > 0.0:
		_restart_armed = 0.0
		_restart.text = "RESTART RUN"
		restart_pressed.emit()
		return
	_restart_armed = 3.0
	_restart.text = "PRESS AGAIN TO RESTART"


# ---------------------------------------------------------------- settings page

func _build_settings() -> Control:
	var column := _card(980.0)
	_heading(column, "SETTINGS", 56)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0.0, 640.0)
	column.add_child(tabs)

	var graphics := _tab(tabs, "GRAPHICS")
	_choice(graphics, "graphics", "quality", "Quality preset", ["Low", "Medium", "High", "Ultra"], [0, 1, 2, 3])
	_choice(graphics, "graphics", "resolution", "Resolution (windowed)", Settings.RESOLUTIONS, Settings.RESOLUTIONS)
	_toggle(graphics, "graphics", "fullscreen", "Fullscreen")
	_choice(graphics, "graphics", "shadows", "Shadows", ["Off", "Low", "High"], [0, 1, 2])
	_toggle(graphics, "graphics", "ambient_occlusion", "Ambient occlusion")
	_choice(graphics, "graphics", "anti_aliasing", "Anti-aliasing", ["Off", "FXAA", "MSAA 2x", "MSAA 4x", "TAA"], [0, 1, 2, 3, 4])
	_slider(graphics, "graphics", "render_scale", "Render scale", 0.5, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_toggle(graphics, "graphics", "vsync", "VSync")
	var cap_names: Array = []
	for cap: int in Settings.FPS_CAPS:
		cap_names.append("Unlimited" if cap == 0 else str(cap))
	_choice(graphics, "graphics", "fps_cap", "FPS cap", cap_names, Settings.FPS_CAPS)
	_defaults(graphics, "graphics")

	var camera := _tab(tabs, "CAMERA")
	_slider(camera, "camera", "fov", "Field of view", 60.0, 120.0, 1.0, func(v: float) -> String: return "%d°" % roundi(v))
	_slider(camera, "camera", "mouse_sensitivity", "Mouse sensitivity", 0.05, 2.0, 0.05, func(v: float) -> String: return "%.2f" % v)
	_toggle(camera, "camera", "head_bob", "Head bobbing")
	_toggle(camera, "camera", "camera_shake", "Camera shake")
	_toggle(camera, "camera", "dot_visible", "Centre dot")
	_slider(camera, "camera", "dot_size", "Centre dot size", 1.0, 12.0, 0.5, func(v: float) -> String: return "%.1f px" % v)
	_slider(camera, "camera", "dot_opacity", "Centre dot opacity", 0.05, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_colour(camera, "camera", "dot_color", "Centre dot colour")
	_defaults(camera, "camera")

	var audio := _tab(tabs, "AUDIO")
	var percent := func(v: float) -> String: return "%d%%" % roundi(v * 100.0)
	_slider(audio, "audio", "master", "Master volume", 0.0, 1.0, 0.05, percent)
	_slider(audio, "audio", "footsteps", "Footsteps", 0.0, 1.0, 0.05, percent)
	_slider(audio, "audio", "vacuum", "Vacuum", 0.0, 1.0, 0.05, percent)
	_slider(audio, "audio", "balls", "Ball sounds", 0.0, 1.0, 0.05, percent)
	_slider(audio, "audio", "environment", "Environment", 0.0, 1.0, 0.05, percent)
	_slider(audio, "audio", "alerts", "Alerts", 0.0, 1.0, 0.05, percent)
	_defaults(audio, "audio")

	_button(column, "BACK", func() -> void: _show_page(_main_page))
	return column.get_parent()


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	tabs.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	return column


func _row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 330.0
	row.add_child(label)
	return row


func _slider(parent: Control, section: String, key: String, text: String, low: float, high: float, step: float, format: Callable) -> void:
	var row := _row(parent, text)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.x = 360.0
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size.x = 96.0
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	var sync := func() -> void:
		var value: float = Settings.get_value(section, key)
		slider.set_value_no_signal(value)
		readout.text = format.call(value)
	slider.value_changed.connect(func(value: float) -> void: Settings.set_value(section, key, value))
	_register(section, key, slider, sync)


func _toggle(parent: Control, section: String, key: String, text: String) -> void:
	var row := _row(parent, text)
	var toggle := CheckButton.new()
	row.add_child(toggle)
	var sync := func() -> void: toggle.set_pressed_no_signal(Settings.get_value(section, key))
	toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(section, key, on))
	_register(section, key, toggle, sync)


# `names` are what the player reads, `values` are what is stored. Same order.
func _choice(parent: Control, section: String, key: String, text: String, names: Array, values: Array) -> void:
	var row := _row(parent, text)
	var choice := OptionButton.new()
	choice.custom_minimum_size.x = 300.0
	for item: Variant in names:
		choice.add_item(str(item))
	row.add_child(choice)
	var sync := func() -> void: choice.select(maxi(values.find(Settings.get_value(section, key)), 0))
	choice.item_selected.connect(func(index: int) -> void: Settings.set_value(section, key, values[index]))
	_register(section, key, choice, sync)


func _colour(parent: Control, section: String, key: String, text: String) -> void:
	var row := _row(parent, text)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(140.0, 44.0)
	picker.edit_alpha = false
	row.add_child(picker)
	var sync := func() -> void: picker.color = Settings.get_value(section, key)
	picker.color_changed.connect(func(color: Color) -> void: Settings.set_value(section, key, color))
	_register(section, key, picker, sync)


func _defaults(parent: Control, section: String) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	var button := Button.new()
	button.text = "RESTORE DEFAULTS"
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.pressed.connect(func() -> void:
		Sfx.play("ui_click", "Alerts", -8.0)
		Settings.reset_section(section))
	parent.add_child(button)


func _register(section: String, key: String, control: Control, sync: Callable) -> void:
	controls["%s/%s" % [section, key]] = control
	_syncs.append(sync)
	sync.call()


# A preset or Restore Defaults changes several settings at once. Bring every control back in line.
func _on_setting_changed(_section: String, _key: String) -> void:
	for sync in _syncs:
		sync.call()


# ---------------------------------------------------------------- pieces

func _card(width: float) -> VBoxContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(20)
	style.set_content_margin_all(34.0)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	return column


func _heading(parent: Control, text: String, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _bold)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ACCENT)
	parent.add_child(label)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 68.0
	button.add_theme_font_override("font", _bold)
	button.add_theme_font_size_override("font_size", 38)
	button.pressed.connect(func() -> void:
		Sfx.play("ui_click", "Alerts", -8.0)
		action.call())
	parent.add_child(button)
	return button


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = _semi
	theme.default_font_size = 28
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 0.09)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10.0)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.97, 0.82, 0.2, 0.28)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.97, 0.82, 0.2, 0.45)
	for kind: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, normal)
		theme.set_stylebox("hover", kind, hover)
		theme.set_stylebox("pressed", kind, pressed)
		theme.set_stylebox("focus", kind, StyleBoxEmpty.new())
	return theme
