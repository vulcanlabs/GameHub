extends Node3D

const MapGen = preload("res://scripts/map_gen.gd")
const MonsterScript = preload("res://scripts/monster.gd")
const BirdScript = preload("res://scripts/bird.gd")

const SPEED := {
	"land": 6.5,
	"landSprint": 10.0,
	"water": 3.5,
	"waterSprint": 5.5,
}

var settings := {
	"monster": "stalker",
	"diff": 1,
	"fov": 90,
	"push": 12,
	"custom": 3,
}
var hub: Node
var playtest := false

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var kb := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var on_ground := false
var in_water := false
var plat: Dictionary = {}
var cp := 0
var dead := 0.0
var time := 0.0
var playing := false

var course: Node3D
var plats: Array = []
var cps: Array = []
var monsters: Array = []
var birds: Array = []
var splashes: Array = []

var cam: Camera3D
var world_env: WorldEnvironment
var water: MeshInstance3D
var bed: MeshInstance3D
var ceiling: MeshInstance3D
var hud: Label
var log_label: Label
var pause_layer: CanvasLayer
var click_layer: CanvasLayer
var monster_pick: OptionButton
var diff_pick: OptionButton
var fov_slider: HSlider
var push_slider: HSlider
var custom_spin: SpinBox
var logs: Array[String] = []


func start(next_settings: Dictionary, hub_node: Node, is_playtest := false) -> void:
	settings = next_settings.duplicate()
	hub = hub_node
	playtest = is_playtest
	_lights()
	_water()
	_hud()
	_pause_ui()
	build_course(true)
	for i in 5:
		_add_bird(false)
	for i in 9:
		_add_bird(true)
	playing = true
	if playtest:
		return
	_show_click()


func _lights() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6a5a30")
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.022
	env.fog_light_color = env.background_color
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.7
	add_child(sun)
	var amb := DirectionalLight3D.new()
	amb.light_energy = 0.35
	amb.rotation_degrees = Vector3(80, 0, 0)
	add_child(amb)


func _water() -> void:
	water = _plane(Vector2(120, 120), Color(0.08, 0.35, 0.42, 0.82), 0.02)
	bed = _plane(Vector2(120, 120), Color("0c2428"), -4.0)
	ceiling = _plane(Vector2(160, 160), Color("2a2418"), 15.0)
	cam = Camera3D.new()
	cam.fov = float(settings.fov)
	add_child(cam)
	cam.make_current()


func _plane(size: Vector2, color: Color, y: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.4
	mesh.material_override = mat
	mesh.position.y = y
	add_child(mesh)
	return mesh


func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 16)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color("f4efe6"))
	layer.add_child(hud)
	log_label = Label.new()
	log_label.position = Vector2(24, 620)
	log_label.add_theme_color_override("font_color", Color("f6c1b4"))
	layer.add_child(log_label)


func _pause_ui() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.visible = false
	add_child(pause_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(390, 80)
	panel.custom_minimum_size = Vector2(500, 520)
	pause_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	box.add_child(_hint("Esc resumes. F1–F12 still fire gift actions."))
	monster_pick = OptionButton.new()
	for name in ["stalker", "crawler", "beast", "shadow"]:
		monster_pick.add_item(name)
	diff_pick = OptionButton.new()
	for name in ["Easy", "Normal", "Hard", "Nightmare"]:
		diff_pick.add_item(name)
	fov_slider = _slider(60, 120)
	push_slider = _slider(6, 24)
	custom_spin = SpinBox.new()
	custom_spin.min_value = -20
	custom_spin.max_value = 20
	custom_spin.rounded = true
	box.add_child(_row("Monster", monster_pick))
	box.add_child(_row("Difficulty", diff_pick))
	box.add_child(_row("FOV", fov_slider))
	box.add_child(_row("Push", push_slider))
	box.add_child(_row("Custom step", custom_spin))
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(_resume)
	box.add_child(resume)
	click_layer = CanvasLayer.new()
	add_child(click_layer)
	var click := Button.new()
	click.text = "Click to look"
	click.position = Vector2(520, 340)
	click.pressed.connect(_resume)
	click_layer.add_child(click)


func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(460, 40)
	return label


func _row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)
	control.custom_minimum_size = Vector2(280, 32)
	row.add_child(control)
	return row


func _slider(min_v: float, max_v: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 1
	return slider


func _show_click() -> void:
	click_layer.visible = true
	pause_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
	_read_pause()
	click_layer.visible = false
	pause_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if hub and hub.has_method("post_state"):
		hub.post_state("ready")
	if hub and hub.has_method("save_settings"):
		hub.save_settings(settings)


func _open_pause() -> void:
	monster_pick.select(["stalker", "crawler", "beast", "shadow"].find(str(settings.monster)))
	diff_pick.select(int(settings.diff))
	fov_slider.value = float(settings.fov)
	push_slider.value = float(settings.push)
	custom_spin.value = float(settings.custom)
	pause_layer.visible = true
	click_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hub and hub.has_method("post_state"):
		hub.post_state("paused")


func _read_pause() -> void:
	var names := ["stalker", "crawler", "beast", "shadow"]
	var next := {
		"monster": names[monster_pick.selected],
		"diff": diff_pick.selected,
		"fov": int(fov_slider.value),
		"push": int(push_slider.value),
		"custom": int(custom_spin.value),
	}
	var diff_changed := int(next.diff) != int(settings.diff)
	var mon_changed := str(next.monster) != str(settings.monster)
	settings = next
	cam.fov = float(settings.fov)
	if diff_changed:
		build_course(true)
	elif mon_changed:
		_clear_monsters()
		_spawn_monster()


func build_course(reset_player: bool) -> void:
	if course:
		course.queue_free()
	var built: Dictionary = MapGen.build(self, int(settings.diff))
	course = built.root
	plats = built.plats
	cps = built.cps
	_clear_monsters()
	_spawn_monster()
	if reset_player:
		respawn(0)


func _clear_monsters() -> void:
	for m in monsters:
		if is_instance_valid(m):
			m.queue_free()
	monsters.clear()


func _spawn_monster() -> void:
	var monster = MonsterScript.new()
	add_child(monster)
	monster.setup(str(settings.monster))
	monster.place_far(pos)
	monsters.append(monster)


func _add_bird(bat: bool, attack_from: Vector3 = Vector3.INF) -> void:
	var bird = BirdScript.new()
	add_child(bird)
	bird.setup(bat)
	if attack_from != Vector3.INF:
		bird.begin_attack(attack_from)
	birds.append(bird)


func respawn(index: int) -> void:
	if cps.is_empty():
		return
	cp = clampi(index, 0, cps.size() - 1)
	var p: Dictionary = plats[int(cps[cp])]
	pos = Vector3(float(p.x), float(p.top) + 0.01, float(p.z))
	vel = Vector3.ZERO
	kb = Vector3.ZERO
	yaw = 0.0
	in_water = false
	on_ground = true
	plat = p
	for m in monsters:
		if is_instance_valid(m):
			m.place_far(pos)
	_log("Checkpoint %d" % cp)


func run_action(action: String) -> void:
	var forward := _forward()
	var push := float(settings.push)
	match action:
		"spawn_monster":
			_spawn_monster()
			_log("Spawn monster")
		"crow_attack":
			_add_bird(false, pos + Vector3(forward.x, 0, forward.y) * 14.0 + Vector3(0, 7, 0))
			_log("Crow attack")
		"up_1":
			respawn(cp + 1)
		"down_1":
			respawn(cp - 1)
		"up_5":
			respawn(cp + 5)
		"down_5":
			respawn(cp - 5)
		"custom":
			respawn(cp + int(settings.custom))
		"reset":
			respawn(0)
		"push_forward":
			kb.x += forward.x * push * 1.2
			kb.z += forward.y * push * 1.2
			_log("Push forward")
		"push_back":
			kb.x -= forward.x * push * 1.2
			kb.z -= forward.y * push * 1.2
			_log("Push back")
		"push_water":
			_push_water(push)
		_:
			_log(action)


func _push_water(push: float) -> void:
	if plat.is_empty():
		_log("Already in the water")
		return
	var dx := pos.x - float(plat.x)
	var dz := pos.z - float(plat.z)
	var dir := Vector2(1, 0)
	if absf(dx) > absf(dz):
		dir = Vector2(1.0 if dx >= 0.0 else -1.0, 0)
	else:
		dir = Vector2(0, 1.0 if dz >= 0.0 else -1.0)
	kb.x += dir.x * push * 2.4
	kb.z += dir.y * push * 2.4
	vel.y = 5.0
	_log("Pushed toward the water")


func _forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.45, 1.45)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if pause_layer.visible:
				_resume()
			else:
				_open_pause()
			return
		var action := _action_for(event.keycode)
		if action != "":
			run_action(action)


func _action_for(code: Key) -> String:
	match code:
		KEY_F1:
			return "spawn_monster"
		KEY_F2:
			return "crow_attack"
		KEY_F3:
			return "up_1"
		KEY_F4:
			return "down_1"
		KEY_F6:
			return "up_5"
		KEY_F7:
			return "down_5"
		KEY_F8:
			return "custom"
		KEY_F9:
			return "reset"
		KEY_F10:
			return "push_forward"
		KEY_F11:
			return "push_back"
		KEY_F12:
			return "push_water"
	return ""


func _process(delta: float) -> void:
	if not playing:
		return
	var dt := minf(delta, 0.05)
	time += dt
	if playtest:
		_move(dt, true, 1.0, 0.0)
		if time > 0.4 and plats.size() > 10 and monsters.size() > 0:
			print("playtest ok plats=%d monsters=%d" % [plats.size(), monsters.size()])
			get_tree().quit()
		return
	if dead > 0.0:
		dead -= dt
		if dead <= 0.0:
			respawn(cp)
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not pause_layer.visible:
		var forward := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		var strafe := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		_move(dt, Input.is_key_pressed(KEY_SHIFT), forward, strafe)
		if Input.is_key_pressed(KEY_SPACE) and on_ground and not in_water:
			vel.y = 8.0
		if Input.is_key_pressed(KEY_SPACE) and in_water:
			_try_climb()
	_step_actors(dt)
	_step_splashes(dt)
	_place_camera()
	_refresh_hud()


func _move(dt: float, sprint: bool, forward_axis: float, strafe_axis: float) -> void:
	var forward := _forward()
	var right := Vector2(cos(yaw), -sin(yaw))
	var wish := forward * forward_axis + right * strafe_axis
	if wish.length() > 0.001:
		wish = wish.normalized()
	var sp := SPEED.land
	if in_water:
		sp = SPEED.waterSprint if sprint else SPEED.water
	else:
		sp = SPEED.landSprint if sprint else SPEED.land
	vel.x = wish.x * sp + kb.x
	vel.z = wish.y * sp + kb.z
	kb *= exp(-3.5 * dt)
	var prev_y := pos.y
	var was_water := in_water
	if in_water:
		pos.y = 0.0
		vel.y = 0.0
		pos.x += vel.x * dt
		pos.z += vel.z * dt
		if forward_axis != 0.0 or strafe_axis != 0.0:
			for p in plats:
				if Vector2(pos.x - float(p.x), pos.z - float(p.z)).length() < float(p.h) + 0.55:
					_try_climb()
					break
	else:
		vel.y -= 22.0 * dt
		pos += vel * dt
		_collide(prev_y)
	in_water = (not on_ground) and pos.y < 0.05
	if in_water:
		pos.y = 0.0
	if in_water and not was_water:
		_splash()


func _collide(prev_y: float) -> void:
	on_ground = false
	plat = {}
	for p in plats:
		if absf(float(p.z) - pos.z) > float(p.h) + 2.0:
			continue
		var dx := pos.x - float(p.x)
		var dz := pos.z - float(p.z)
		var lim := float(p.h) + 0.35
		if absf(dx) < lim and absf(dz) < lim:
			if prev_y >= float(p.top) - 0.15 and pos.y <= float(p.top) and vel.y <= 0.0:
				pos.y = float(p.top)
				vel.y = 0.0
				on_ground = true
				plat = p
				if int(p.cpi) > cp:
					cp = int(p.cpi)
					_log("Checkpoint %d reached" % cp)
					if cp == cps.size() - 1:
						_log("Finish reached")
			elif pos.y < float(p.top) - 0.05:
				var ox := lim - absf(dx)
				var oz := lim - absf(dz)
				if ox < oz:
					pos.x += (-1.0 if dx < 0.0 else 1.0) * ox
				else:
					pos.z += (-1.0 if dz < 0.0 else 1.0) * oz


func _try_climb() -> bool:
	var best: Dictionary = {}
	var best_d := 9999.0
	for p in plats:
		var d := Vector2(pos.x - float(p.x), pos.z - float(p.z)).length()
		if d < float(p.h) + 1.4 and d < best_d:
			best = p
			best_d = d
	if best.is_empty():
		return false
	pos = Vector3(float(best.x), float(best.top) + 0.05, float(best.z))
	vel = Vector3.ZERO
	kb = Vector3.ZERO
	in_water = false
	on_ground = true
	plat = best
	_log("Climbed back onto a platform")
	return true


func _splash() -> void:
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.8
	cyl.height = 0.05
	ring.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 1, 1, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position = Vector3(pos.x, 0.06, pos.z)
	add_child(ring)
	splashes.append({"node": ring, "t": 0.0})
	for m in monsters:
		if is_instance_valid(m):
			m.alert(pos)
	_log("Splash. The monster heard you")


func _scare() -> void:
	if dead > 0.0:
		return
	dead = 1.4
	_log("The monster caught you")


func _step_actors(dt: float) -> void:
	for m in monsters:
		if is_instance_valid(m) and m.step(pos, in_water, dt, time):
			_scare()
	var kept: Array = []
	for b in birds:
		if not is_instance_valid(b):
			continue
		var knock: Vector2 = b.step(pos, float(settings.push), dt, time)
		if knock != Vector2.ZERO:
			kb.x += knock.x
			kb.z += knock.y
			_log("Crow hit you")
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			kept.append(b)
	birds = kept


func _step_splashes(dt: float) -> void:
	var kept: Array = []
	for splash in splashes:
		splash.t += dt
		var node: MeshInstance3D = splash.node
		if not is_instance_valid(node):
			continue
		var s := 1.0 + float(splash.t) * 9.0
		node.scale = Vector3(s, 1, s)
		var mat := node.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = maxf(0.0, 0.9 - float(splash.t) * 1.2)
		if float(splash.t) > 0.8:
			node.queue_free()
		else:
			kept.append(splash)
	splashes = kept


func _place_camera() -> void:
	var shake := 0.12 if dead > 0.0 else 0.0
	cam.position = Vector3(
		pos.x + randf_range(-shake, shake),
		pos.y + 1.6,
		pos.z + randf_range(-shake, shake)
	)
	cam.rotation = Vector3(pitch, yaw, 0)
	water.position.x = pos.x
	water.position.z = pos.z
	bed.position.x = pos.x
	bed.position.z = pos.z
	ceiling.position.x = pos.x
	ceiling.position.z = pos.z
	var eye := pos.y + 1.6
	var under := eye < 0.2 and in_water
	var fog_color := Color("1a4a55") if under else Color("6a5a30")
	world_env.environment.background_color = fog_color
	world_env.environment.fog_light_color = fog_color
	world_env.environment.fog_density = 0.06 if under else 0.022


func _refresh_hud() -> void:
	var charging := 0
	for m in monsters:
		if is_instance_valid(m) and m.state == "charge":
			charging += 1
	var where := "In the water — Space or walk to climb" if in_water else "Safe on platform"
	hud.text = "Checkpoint %d / %d\n%s\n%d monsters · %d charging" % [
		cp, maxi(cps.size() - 1, 0), where, monsters.size(), charging
	]


func _log(text: String) -> void:
	logs.push_front(text)
	if logs.size() > 5:
		logs.resize(5)
	log_label.text = "\n".join(logs)
