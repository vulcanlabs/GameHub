# ESC pause. This node keeps running while the tree is paused, so ESC can also resume.
extends CanvasLayer

var slider: HSlider
var _value: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(360, 220)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_top = -110
	panel.offset_right = 180
	panel.offset_bottom = 110
	add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_top = 20
	box.offset_right = -24
	box.offset_bottom = -20
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_value = Label.new()
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_value)

	slider = HSlider.new()
	slider.min_value = 60
	slider.max_value = 110
	slider.step = 1
	slider.value = 80
	slider.value_changed.connect(_on_fov)
	box.add_child(slider)
	_on_fov(slider.value)

	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(_resume)
	box.add_child(resume)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if (event as InputEventKey).keycode != KEY_ESCAPE:
		return
	var game: Node = get_parent()
	if game.phase != game.Phase.PLAYING:
		return
	game.toggle_pause()
	get_viewport().set_input_as_handled()


func open(current_fov: float) -> void:
	slider.set_value_no_signal(current_fov)
	_on_fov(current_fov)
	visible = true


func close() -> void:
	visible = false


func _on_fov(value: float) -> void:
	_value.text = "Field of view  %d" % int(value)
	var player: CharacterBody3D = get_parent().player
	if player:
		player.set_fov(value)


func _resume() -> void:
	get_parent().toggle_pause()
