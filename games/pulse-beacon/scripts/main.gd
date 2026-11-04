extends Control

var hub
var link_panel: Control
var play_panel: Control
var arena: ColorRect
var marker: ColorRect
var status_label: Label
var message: Label
var hub_edit: LineEdit
var code_edit: LineEdit
var name_edit: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hub = preload("res://scripts/hub_client.gd").new()
	hub.name = "HubClient"
	add_child(hub)
	_build()
	hub.linked.connect(_on_linked)
	hub.link_failed.connect(_set_message)
	hub.actions_received.connect(_on_actions)
	hub.session_ended.connect(_on_ended)
	hub.poll_note.connect(_set_message)
	if hub.has_token():
		hub_edit.text = hub.base_url
		_show_play()
		hub.post_state("ready")
		hub.start_poll()
	else:
		_show_link()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("163034")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	link_panel = _center_box()
	add_child(link_panel)
	var title := Label.new()
	title.text = "Link Pulse Beacon"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("f4efe6"))
	link_panel.add_child(title)

	hub_edit = _field("Hub URL", "http://localhost:3000")
	code_edit = _field("Link code", "")
	name_edit = _field("This PC", "Stream PC")
	link_panel.add_child(hub_edit)
	link_panel.add_child(code_edit)
	link_panel.add_child(name_edit)

	var link_btn := Button.new()
	link_btn.text = "Link"
	link_btn.pressed.connect(_on_link_pressed)
	link_panel.add_child(link_btn)

	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(420, 60)
	message.add_theme_color_override("font_color", Color("f6c1b4"))
	link_panel.add_child(message)

	play_panel = Control.new()
	play_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(play_panel)

	arena = ColorRect.new()
	arena.color = Color("0e2428")
	arena.custom_minimum_size = Vector2(960, 520)
	arena.position = Vector2(160, 80)
	arena.size = Vector2(960, 520)
	play_panel.add_child(arena)

	marker = ColorRect.new()
	marker.color = Color("8fdcd4")
	marker.size = Vector2(48, 48)
	arena.add_child(marker)
	_center_marker()

	status_label = Label.new()
	status_label.position = Vector2(160, 24)
	status_label.size = Vector2(700, 40)
	status_label.text = "Waiting for a gift"
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", Color("f4efe6"))
	play_panel.add_child(status_label)

	var unlink := Button.new()
	unlink.text = "Unlink this PC"
	unlink.position = Vector2(1040, 24)
	unlink.pressed.connect(_on_unlink)
	play_panel.add_child(unlink)


func _center_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -220
	box.offset_top = -180
	box.offset_right = 220
	box.offset_bottom = 180
	box.add_theme_constant_override("separation", 12)
	return box


func _field(placeholder: String, value: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = value
	edit.custom_minimum_size = Vector2(420, 44)
	return edit


func _show_link() -> void:
	link_panel.visible = true
	play_panel.visible = false


func _show_play() -> void:
	link_panel.visible = false
	play_panel.visible = true
	status_label.text = "Waiting for a gift"
	_center_marker()


func _on_link_pressed() -> void:
	message.text = "Linking…"
	hub.start_link(hub_edit.text, code_edit.text, name_edit.text)


func _on_linked() -> void:
	message.text = ""
	_show_play()
	hub.post_state("ready")
	hub.start_poll()


func _on_ended(text: String) -> void:
	message.text = text
	_show_link()


func _on_unlink() -> void:
	hub.clear_link()
	message.text = "Unlinked on this PC. Revoke the device in the hub if it should stop."
	_show_link()


func _set_message(text: String) -> void:
	if link_panel.visible:
		message.text = text
	else:
		status_label.text = text


func _on_actions(events: Array) -> void:
	for item in events:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("type", "")) != "action":
			continue
		_apply(str(item.get("action", "")), int(item.get("repeatCount", 1)))


func _apply(action: String, repeat: int) -> void:
	var n := maxi(repeat, 1)
	var step := 48.0
	match action:
		"push_forward":
			marker.position.x += step * n
		"push_back", "crow_attack":
			marker.position.x -= step * n
		"push_water", "down_1":
			marker.position.y += step * n
		"up_1", "custom":
			marker.position.y -= step * n
		"up_5":
			marker.position.y -= step * 5
		"down_5":
			marker.position.y += step * 5
		"spawn_monster":
			marker.color = Color("f6a15c")
		"reset":
			_center_marker()
			marker.color = Color("f6c1b4")
		_:
			marker.position.x += step
	if action != "spawn_monster" and action != "reset":
		marker.color = Color("8fdcd4")
	_clamp_marker()
	status_label.text = "%s × %d" % [action, n]


func _center_marker() -> void:
	marker.position = (arena.size - marker.size) * 0.5


func _clamp_marker() -> void:
	marker.position.x = clampf(marker.position.x, 0, arena.size.x - marker.size.x)
	marker.position.y = clampf(marker.position.y, 0, arena.size.y - marker.size.y)
