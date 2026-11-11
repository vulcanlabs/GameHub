extends Node3D

const MapGen = preload("res://scripts/map_gen.gd")
const PlayerScript = preload("res://scripts/player.gd")

var settings := {"lives": 3, "levels": 5, "platforms": 8}
var pending: Dictionary = {}
var hub: Node
var playtest := false

var level_index := 0
var lives_left := 3
var phase := "play"
var course: Node3D
var plats: Array = []
var player
var goal_area: Area3D
var lava_area: Area3D
var hurt_lock := false
var hurt_flash: ColorRect
var recovering := false
var recover_from := Vector3.ZERO
var recover_to := Vector3.ZERO
var recover_t := 0.0
var death_flash := 0.0
var playtest_done := false

var hud: Label
var pause_layer: CanvasLayer
var end_layer: CanvasLayer
var end_label: Label
var lives_spin: SpinBox
var levels_spin: SpinBox
var platforms_spin: SpinBox
var click_layer: CanvasLayer


func start(next_settings: Dictionary, hub_node: Node, is_playtest := false) -> void:
	settings = next_settings.duplicate()
	pending = settings.duplicate()
	hub = hub_node
	playtest = is_playtest
	lives_left = int(settings.lives)
	_world()
	_player()
	_lava()
	_hud()
	_pause_ui()
	_end_ui()
	_click_ui()
	_build_level()
	if playtest:
		return
	phase = "play"
	player.active = false
	_set_pause(false)
	_set_end(false)
	click_layer.visible = true


func _world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a100c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a4030")
	env.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_color = Color("ffd0a8")
	sun.light_energy = 1.1
	add_child(sun)


func _player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.fell.connect(_on_fell)


func _lava() -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	mesh.mesh = plane
	mesh.material_override = _lava_material()
	mesh.position.y = -2.2
	add_child(mesh)
	lava_area = Area3D.new()
	lava_area.collision_layer = 4
	lava_area.collision_mask = 1
	lava_area.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2.0, 400)
	shape.shape = box
	lava_area.position = Vector3(0, -3.2, 0)
	lava_area.add_child(shape)
	add_child(lava_area)
	lava_area.body_entered.connect(_on_lava_body)


func _lava_material() -> ShaderMaterial:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/lava.gdshader")
	mat.set_shader_parameter("noise_texture", tex)
	mat.set_shader_parameter("noise_scale", 8.0)
	mat.set_shader_parameter("scroll_x", 0.02)
	mat.set_shader_parameter("scroll_y", 0.01)
	mat.set_shader_parameter("wave_speed", 0.12)
	mat.set_shader_parameter("noise_wave_speed", 0.08)
	mat.set_shader_parameter("oscillation_speed", 0.15)
	return mat


func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 16)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color("f4efe6"))
	layer.add_child(hud)
	_refresh_hud()
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 30
	add_child(flash_layer)
	hurt_flash = ColorRect.new()
	hurt_flash.color = Color(0.75, 0.02, 0.02, 0.0)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_layer.add_child(hurt_flash)


func _refresh_hud() -> void:
	if hud == null:
		return
	hud.text = "Lives %d    Level %d / %d" % [
		lives_left,
		level_index + 1,
		int(settings.levels),
	]


func _pause_ui() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 10
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -180
	box.offset_top = -160
	box.offset_right = 180
	box.offset_bottom = 180
	box.add_theme_constant_override("separation", 10)
	pause_layer.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f4efe6"))
	box.add_child(title)
	var note := Label.new()
	note.text = "Applies on the next level, or when you restart."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(360, 40)
	note.add_theme_color_override("font_color", Color("f4efe6"))
	box.add_child(note)
	lives_spin = _spin(1, 20)
	levels_spin = _spin(1, 20)
	platforms_spin = _spin(4, 40)
	box.add_child(_row("Lives", lives_spin))
	box.add_child(_row("Levels to beat", levels_spin))
	box.add_child(_row("Platforms per level", platforms_spin))
	var apply := Button.new()
	apply.text = "Save"
	apply.pressed.connect(_save_pending)
	box.add_child(apply)
	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(_restart)
	box.add_child(restart)
	var fullscreen := Button.new()
	fullscreen.text = "Fullscreen"
	fullscreen.pressed.connect(_toggle_fullscreen)
	box.add_child(fullscreen)
	pause_layer.visible = false


func _spin(min_value: float, max_value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.rounded = true
	spin.custom_minimum_size = Vector2(120, 32)
	return spin


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(200, 0)
	label.add_theme_color_override("font_color", Color("f4efe6"))
	row.add_child(label)
	row.add_child(control)
	return row


func _end_ui() -> void:
	end_layer = CanvasLayer.new()
	end_layer.layer = 12
	add_child(end_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -160
	box.offset_top = -80
	box.offset_right = 160
	box.offset_bottom = 80
	box.add_theme_constant_override("separation", 12)
	end_layer.add_child(box)
	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 32)
	end_label.add_theme_color_override("font_color", Color("f4efe6"))
	box.add_child(end_label)
	var again := Button.new()
	again.text = "Play again"
	again.pressed.connect(_restart)
	box.add_child(again)
	end_layer.visible = false


func _click_ui() -> void:
	click_layer = CanvasLayer.new()
	click_layer.layer = 8
	add_child(click_layer)
	var label := Label.new()
	label.text = "Click to look"
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -80
	label.offset_top = -20
	label.offset_right = 80
	label.offset_bottom = 20
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("f4efe6"))
	click_layer.add_child(label)
	click_layer.visible = false


func _sync_spins() -> void:
	var shown: Dictionary = pending if not pending.is_empty() else settings
	lives_spin.value = float(shown.lives)
	levels_spin.value = float(shown.levels)
	platforms_spin.value = float(shown.platforms)


func _read_spins() -> Dictionary:
	return {
		"lives": int(lives_spin.value),
		"levels": int(levels_spin.value),
		"platforms": int(platforms_spin.value),
	}


func _save_pending() -> void:
	pending = _read_spins()
	if hub and hub.has_method("save_settings"):
		hub.save_settings(pending)


func _set_pause(show: bool) -> void:
	pause_layer.visible = show
	if player:
		player.can_look = not show and phase == "play"
		player.active = not show and phase == "play" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if show:
		_sync_spins()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if hub and hub.has_method("post_state"):
			hub.post_state("paused")
	elif phase == "play" and not click_layer.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if player:
			player.active = true
		if hub and hub.has_method("post_state"):
			hub.post_state("ready")


func _set_end(show: bool) -> void:
	end_layer.visible = show


func _build_level() -> void:
	if course:
		course.queue_free()
		course = null
		goal_area = null
	var built: Dictionary = MapGen.build(self, level_index, int(settings.platforms))
	course = built.root
	plats = built.platforms
	goal_area = built.goal
	if goal_area:
		goal_area.body_entered.connect(_on_goal_body)
	_spawn()
	_refresh_hud()


func _spawn() -> void:
	if plats.is_empty() or player == null:
		return
	var start: Vector3 = plats[0].position
	var top: float = float(plats[0].top)
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(start.x, top + 0.05, start.z)
	if plats.size() > 1:
		player.face_toward(plats[1].position)
	player.active = phase == "play" and not pause_layer.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _apply_pending() -> void:
	if pending.is_empty():
		return
	settings = pending.duplicate()


func _toggle_fullscreen() -> void:
	var parent := get_parent()
	if parent and parent.has_method("toggle_fullscreen"):
		parent.toggle_fullscreen()


func _restart() -> void:
	if pause_layer.visible:
		pending = _read_spins()
		if hub and hub.has_method("save_settings"):
			hub.save_settings(pending)
	_apply_pending()
	lives_left = int(settings.lives)
	level_index = 0
	phase = "play"
	hurt_lock = false
	recovering = false
	death_flash = 0.0
	if hurt_flash:
		hurt_flash.color.a = 0.0
	_set_end(false)
	pause_layer.visible = false
	click_layer.visible = true
	player.can_look = false
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_level()


func _on_fell() -> void:
	_lose_life()


func _on_lava_body(body: Node) -> void:
	if body == player:
		_lose_life()


func _lose_life() -> void:
	if phase != "play" or playtest or hurt_lock:
		return
	hurt_lock = true
	player.active = false
	lives_left -= 1
	_refresh_hud()
	if lives_left <= 0:
		phase = "over"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		end_label.text = "Out of lives"
		death_flash = 0.55
		return
	phase = "recover"
	recover_from = player.global_position
	recover_to = _start_pos()
	recover_t = 0.0
	recovering = true


func _start_pos() -> Vector3:
	var start: Vector3 = plats[0].position
	return Vector3(start.x, float(plats[0].top) + 0.05, start.z)


func _step_recover(delta: float) -> void:
	recover_t += delta / 0.85
	var t := clampf(recover_t, 0.0, 1.0)
	var p := recover_from.lerp(recover_to, t)
	p.y += sin(t * PI) * 3.4
	player.velocity = Vector3.ZERO
	player.global_position = p
	if plats.size() > 1:
		player.face_toward(plats[1].position)
	if hurt_flash:
		hurt_flash.color.a = abs(sin(t * PI * 2.0)) * 0.72
	if t < 1.0:
		return
	recovering = false
	if hurt_flash:
		hurt_flash.color.a = 0.0
	phase = "play"
	_spawn()
	_clear_hurt.call_deferred()


func _clear_hurt() -> void:
	hurt_lock = false


func _on_goal_body(body: Node) -> void:
	if body != player or phase != "play" or playtest:
		return
	phase = "clear"
	if level_index + 1 >= int(settings.levels):
		phase = "win"
		player.active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		end_label.text = "You made it"
		_set_end(true)
		_refresh_hud()
		return
	level_index += 1
	_apply_pending()
	phase = "play"
	_build_level()


func _unhandled_input(event: InputEvent) -> void:
	if playtest or phase == "win" or phase == "over" or phase == "recover":
		return
	if event is InputEventMouseButton and event.pressed and click_layer.visible and not pause_layer.visible:
		click_layer.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if player:
			player.can_look = true
			player.active = true
		if hub and hub.has_method("post_state"):
			hub.post_state("ready")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if pause_layer.visible:
			_set_pause(false)
		elif phase == "play":
			_set_pause(true)


func _process(delta: float) -> void:
	if recovering:
		_step_recover(delta)
		return
	if death_flash > 0.0:
		death_flash -= delta
		if hurt_flash:
			hurt_flash.color.a = sin(clampf(death_flash / 0.55, 0.0, 1.0) * PI) * 0.75
		if death_flash <= 0.0:
			if hurt_flash:
				hurt_flash.color.a = 0.0
			_set_end(true)
		return
	if not playtest or playtest_done:
		return
	playtest_done = true
	if plats.size() == int(settings.platforms):
		print("playtest ok")
	else:
		print("playtest fail plats=%d want=%d" % [plats.size(), int(settings.platforms)])
	get_tree().quit()
