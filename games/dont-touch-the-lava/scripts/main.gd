extends Node3D

const GameScript = preload("res://scripts/game.gd")
# Set false when the hub link screen should show again.
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
		_on_settings({"lives": 3, "levels": 5, "platforms": 8})
		return
	_set_link_visible(true)
	hub_edit.text = hub.base_url


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _build_link() -> void:
	link_layer = CanvasLayer.new()
	add_child(link_layer)
	var bg := ColorRect.new()
	bg.color = Color("1a100c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	link_layer.add_child(bg)
	link_panel = VBoxContainer.new()
	link_panel.set_anchors_preset(Control.PRESET_CENTER)
	link_panel.offset_left = -220
	link_panel.offset_top = -180
	link_panel.offset_right = 220
	link_panel.offset_bottom = 200
	link_panel.add_theme_constant_override("separation", 12)
	link_layer.add_child(link_panel)
	var title := Label.new()
	title.text = "Link Don't Touch the Lava"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f4efe6"))
	link_panel.add_child(title)
	hub_edit = _field("Hub URL", hub.base_url if hub else "http://localhost:3000")
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
	message.custom_minimum_size = Vector2(420, 48)
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
	hub.start_poll()


func _clean_settings(raw: Dictionary) -> Dictionary:
	return {
		"lives": clampi(int(raw.get("lives", 3)), 1, 20),
		"levels": clampi(int(raw.get("levels", 5)), 1, 20),
		"platforms": clampi(int(raw.get("platforms", 8)), 4, 40),
	}


func _on_actions(_events: Array) -> void:
	# Gifts are ignored until lava actions exist.
	pass


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
