extends Node

const GameScript = preload("res://scripts/game.gd")
# Set false when linking should show again.
const SKIP_LINK := true

var hub: Node
var game: Node3D
var link_layer: CanvasLayer
var link_panel: Control
var message: Label
var hub_edit: LineEdit
var code_edit: LineEdit
var name_edit: LineEdit


func _ready() -> void:
	hub = preload("res://scripts/hub_client.gd").new()
	hub.name = "HubClient"
	add_child(hub)
	_build_link()
	hub.linked.connect(_on_linked)
	hub.link_failed.connect(_set_message)
	hub.settings_ready.connect(_on_settings)
	hub.actions_received.connect(_on_actions)
	hub.session_ended.connect(_on_ended)
	hub.poll_note.connect(_set_message)
	if "--playtest" in OS.get_cmdline_user_args() or SKIP_LINK:
		_set_link_visible(false)
		_on_settings({"monster": "stalker", "diff": 1, "fov": 90, "push": 12, "custom": 3})
		return
	if hub.has_token():
		hub_edit.text = hub.base_url
		_set_link_visible(false)
		hub.fetch_settings()
	else:
		_set_link_visible(true)


func _build_link() -> void:
	link_layer = CanvasLayer.new()
	add_child(link_layer)
	var bg := ColorRect.new()
	bg.color = Color("163034")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	link_layer.add_child(bg)
	link_panel = VBoxContainer.new()
	link_panel.set_anchors_preset(Control.PRESET_CENTER)
	link_panel.offset_left = -220
	link_panel.offset_top = -180
	link_panel.offset_right = 220
	link_panel.offset_bottom = 180
	link_panel.add_theme_constant_override("separation", 12)
	link_layer.add_child(link_panel)
	var title := Label.new()
	title.text = "Link Don't Touch the Water"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f4efe6"))
	link_panel.add_child(title)
	hub_edit = _field("Hub URL", "http://localhost:3000")
	code_edit = _field("Link code", "")
	name_edit = _field("This PC", "Stream PC")
	link_panel.add_child(hub_edit)
	link_panel.add_child(code_edit)
	link_panel.add_child(name_edit)
	var button := Button.new()
	button.text = "Link"
	button.pressed.connect(_on_link_pressed)
	link_panel.add_child(button)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(420, 60)
	message.add_theme_color_override("font_color", Color("f6c1b4"))
	link_panel.add_child(message)
	var note := Label.new()
	note.text = "Enter a new link code each time you open the game. It works until the account end date."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(420, 48)
	note.add_theme_color_override("font_color", Color("f4efe6"))
	link_panel.add_child(note)


func _field(placeholder: String, value: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = value
	edit.custom_minimum_size = Vector2(420, 40)
	return edit


func _on_link_pressed() -> void:
	message.text = "Linking…"
	hub.start_link(hub_edit.text, code_edit.text, name_edit.text)


func _set_link_visible(show: bool) -> void:
	link_layer.visible = show
	link_panel.visible = show


func _on_linked() -> void:
	message.text = ""
	_set_link_visible(false)
	hub.fetch_settings()


func _on_settings(raw: Dictionary) -> void:
	_set_link_visible(false)
	if game:
		game.queue_free()
	game = GameScript.new()
	add_child(game)
	var playtest := "--playtest" in OS.get_cmdline_user_args()
	game.start(_clean_settings(raw), hub, playtest)
	if playtest or hub == null or not hub.has_token():
		return
	hub.post_state("ready")
	hub.start_poll()


func _clean_settings(raw: Dictionary) -> Dictionary:
	var monsters := ["stalker", "crawler", "beast", "shadow"]
	var monster := str(raw.get("monster", "stalker"))
	if monster not in monsters:
		monster = "stalker"
	return {
		"monster": monster,
		"diff": clampi(int(raw.get("diff", 1)), 0, 3),
		"fov": clampi(int(raw.get("fov", 90)), 60, 120),
		"push": clampi(int(raw.get("push", 12)), 6, 24),
		"custom": int(raw.get("custom", 3)),
	}


func _on_actions(events: Array) -> void:
	if game == null:
		return
	for item in events:
		if typeof(item) != TYPE_DICTIONARY or str(item.get("type", "")) != "action":
			continue
		var count := clampi(int(item.get("repeatCount", 1)), 1, 10)
		for i in count:
			game.run_action(str(item.get("action", "")))


func _on_ended(text: String) -> void:
	message.text = text
	if game:
		game.queue_free()
		game = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_link_visible(true)


func _set_message(text: String) -> void:
	if link_panel.visible:
		message.text = text
