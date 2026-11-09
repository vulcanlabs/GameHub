extends Node3D

const MapGen = preload("res://scripts/map_gen.gd")
const MonsterScript = preload("res://scripts/monster.gd")
const BirdScript = preload("res://scripts/bird.gd")

const SPEED := {
	"land": 6.5,
	"landSprint": 13.0,
	"water": 3.5,
	"waterSprint": 8.0,
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
var level := 0
var pending_level := -1
var dead := 0.0
var time := 0.0
var playing := false

var course: Node3D
var plats: Array = []
var hazards: Array = []
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
var blood := 0.0
var blood_rect: ColorRect
var splats: Array[Polygon2D] = []
var killer: Node3D
var spin_lock := 0.0
var space_held := false


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
	env.background_color = Color("6a7058")
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.02
	env.fog_light_color = Color("7c8460")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6d7358")
	env.ambient_light_energy = 0.42
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70, 20, 0)
	sun.light_color = Color("c5c99a")
	sun.light_energy = 0.22
	add_child(sun)


func _water() -> void:
	water = _plane(Vector2(160, 160), Color(0.05, 0.16, 0.14, 0.9), 0.02)
	water.material_override = _water_shader()
	bed = _plane(Vector2(160, 160), Color("071412"), -4.0)
	ceiling = _plane(Vector2(180, 180), Color("8a8268"), 4.55)
	ceiling.material_override = _ceiling_shader()
	_hang_lights(ceiling)
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


func _water_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode blend_mix, depth_draw_opaque, cull_disabled;\nvoid vertex() {\n\tVERTEX.y += sin(VERTEX.x * 0.35 + TIME * 0.7) * 0.05;\n\tVERTEX.y += cos(VERTEX.z * 0.28 + TIME * 0.55) * 0.04;\n}\nvoid fragment() {\n\tfloat ripple = sin(UV.x * 90.0 + TIME * 0.8) * sin(UV.y * 70.0 - TIME * 0.6);\n\tvec3 deep = vec3(0.04, 0.13, 0.12);\n\tvec3 chem = vec3(0.16, 0.32, 0.24);\n\tALBEDO = mix(deep, chem, 0.22 + ripple * 0.08);\n\tALPHA = 0.9;\n\tROUGHNESS = 0.12;\n\tMETALLIC = 0.08;\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _ceiling_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nvoid fragment() {\n\tvec2 uv = UV * 28.0;\n\tvec2 g = abs(fract(uv) - 0.5);\n\tfloat seam = step(0.47, max(g.x, g.y));\n\tvec3 tile = vec3(0.55, 0.52, 0.38);\n\ttile *= 0.92 + 0.08 * sin(UV.x * 40.0);\n\tALBEDO = mix(tile, tile * 0.5, seam);\n\tROUGHNESS = 0.9;\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _hang_lights(parent: Node3D) -> void:
	var tube_mat := StandardMaterial3D.new()
	tube_mat.albedo_color = Color("e4e7b0")
	tube_mat.emission_enabled = true
	tube_mat.emission = Color("d5dead")
	tube_mat.emission_energy_multiplier = 1.6
	tube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			if (ix + iz) % 2 != 0:
				continue
			var lamp := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(2.6, 0.06, 0.28)
			lamp.mesh = box
			lamp.material_override = tube_mat
			lamp.position = Vector3(ix * 10.0, -0.16, iz * 10.0)
			parent.add_child(lamp)
			var glow := OmniLight3D.new()
			glow.light_color = Color("dfe6b4")
			glow.light_energy = 0.7
			glow.omni_range = 11.0
			glow.position = lamp.position
			parent.add_child(glow)


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
	var blood_layer := CanvasLayer.new()
	blood_layer.layer = 20
	add_child(blood_layer)
	blood_rect = ColorRect.new()
	blood_rect.color = Color(0.55, 0.0, 0.02, 0.0)
	blood_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_rect.visible = false
	blood_layer.add_child(blood_rect)
	for i in 24:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		var n := 6 + (i % 4)
		var rad := 50.0 + float(i % 5) * 28.0
		for k in n:
			var a := TAU * float(k) / float(n)
			var r := rad * (0.35 if k % 2 == 0 else 1.0)
			pts.append(Vector2(cos(a), sin(a)) * r)
		poly.polygon = pts
		poly.color = Color(0.45 + float(i % 3) * 0.12, 0.0, 0.02, 0.94)
		poly.visible = false
		blood_layer.add_child(poly)
		splats.append(poly)


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
	var built: Dictionary = MapGen.build(self, int(settings.diff), level)
	course = built.root
	plats = built.plats
	hazards = built.hazards
	_clear_monsters()
	_spawn_monster()
	if reset_player:
		_place_start()


func go_level(index: int) -> void:
	level = clampi(index, 0, MapGen.LEVEL_COUNT - 1)
	pending_level = -1
	build_course(true)
	_log("Level %d" % (level + 1))


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


func _place_start() -> void:
	if plats.is_empty():
		return
	var p: Dictionary = plats[0]
	pos = Vector3(float(p.x), float(p.top) + 0.01, float(p.z))
	vel = Vector3.ZERO
	kb = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	in_water = false
	on_ground = true
	plat = p
	killer = null
	for m in monsters:
		if is_instance_valid(m):
			m.place_far(pos)
	for poly in splats:
		poly.visible = false


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
			go_level(level + 1)
		"down_1":
			go_level(level - 1)
		"up_5":
			go_level(level + 5)
		"down_5":
			go_level(level - 5)
		"custom":
			go_level(level + int(settings.custom))
		"reset":
			go_level(level)
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
		_step_hazards(dt)
		_move(dt, true, 1.0, 0.0)
		if time > 0.4 and plats.size() > 10 and monsters.size() > 0:
			print("playtest ok plats=%d monsters=%d" % [plats.size(), monsters.size()])
			get_tree().quit()
		return
	if dead > 0.0:
		dead -= dt
		if dead <= 0.0:
			_place_start()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not pause_layer.visible:
		var forward := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		var strafe := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		var space_now := Input.is_key_pressed(KEY_SPACE)
		var sprinting := Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT)
		if space_now and not space_held and in_water:
			var face := _forward()
			kb.x += face.x * 4.0
			kb.z += face.y * 4.0
		_step_hazards(dt)
		_move(dt, sprinting, forward, strafe)
		if space_now and not space_held and on_ground and not in_water and spin_lock <= 0.0:
			vel.y = 8.0
	else:
		_step_hazards(dt)
	if pending_level >= 0 and dead <= 0.0:
		go_level(pending_level)
	_step_actors(dt)
	_step_splashes(dt)
	_step_blood(dt)
	_place_camera()
	_refresh_hud()
	space_held = Input.is_key_pressed(KEY_SPACE)


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
		_stand_if_over_pad()
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
				_note_goal(p)
			elif pos.y < float(p.top) - 0.05:
				var ox := lim - absf(dx)
				var oz := lim - absf(dz)
				if ox < oz:
					pos.x += (-1.0 if dx < 0.0 else 1.0) * ox
				else:
					pos.z += (-1.0 if dz < 0.0 else 1.0) * oz


func _stand_if_over_pad() -> void:
	for p in plats:
		var dx := pos.x - float(p.x)
		var dz := pos.z - float(p.z)
		if absf(dx) <= float(p.h) - 0.05 and absf(dz) <= float(p.h) - 0.05:
			pos.y = float(p.top)
			vel.y = 0.0
			on_ground = true
			plat = p
			_note_goal(p)
			return


func _note_goal(p: Dictionary) -> void:
	if not bool(p.get("goal", false)) or pending_level >= 0:
		return
	if level + 1 >= MapGen.LEVEL_COUNT:
		p["goal"] = false
		_log("All levels clear")
		return
	pending_level = level + 1


func _step_hazards(dt: float) -> void:
	spin_lock = maxf(0.0, spin_lock - dt)
	for p in plats:
		var phase := float(p.phase)
		var wave := sin(time * 0.65 + phase)
		var slide := sin(time * float(p.slide_speed) + phase) * float(p.slide_amp)
		var drift := wave * 0.32
		p.x = float(p.ox) + float(p.axis_x) * (slide + drift)
		p.z = float(p.oz) + float(p.axis_z) * (slide + drift)
		p.top = float(p.top0) + sin(time * 0.85 + phase * 1.7) * 0.06
		var mesh: MeshInstance3D = p.mesh
		if is_instance_valid(mesh):
			mesh.position = Vector3(float(p.x), float(p.top) - 2.5, float(p.z))
	if on_ground and not plat.is_empty():
		pos.y = float(plat.top)
	if dead > 0.0:
		for h in hazards:
			var idle: Node3D = h.node
			if is_instance_valid(idle):
				idle.rotation.y += dt * float(h.speed)
		return
	if spin_lock > 0.0:
		for h in hazards:
			var spinning: Node3D = h.node
			if is_instance_valid(spinning):
				spinning.rotation.y += dt * float(h.speed)
		return
	for h in hazards:
		var node: Node3D = h.node
		if not is_instance_valid(node):
			continue
		node.rotation.y += dt * float(h.speed)
		var dx := pos.x - node.position.x
		var dz := pos.z - node.position.z
		var dist := Vector2(dx, dz).length()
		var bar_y := node.position.y
		if dist >= float(h.reach) or pos.y > bar_y + 0.45 or pos.y < bar_y - 0.85:
			continue
		var ang := atan2(dz, dx)
		var arm := wrapf(ang - node.rotation.y, -PI, PI)
		var arm_back := wrapf(ang - node.rotation.y + PI, -PI, PI)
		if dist > 0.55 and absf(arm) > 0.4 and absf(arm_back) > 0.4:
			continue
		if dist > 0.2:
			kb.x += (dx / dist) * 5.0
			kb.z += (dz / dist) * 5.0
		if vel.y > 1.0:
			vel.y = 1.0
		on_ground = false
		plat = {}
		spin_lock = 0.55
		_log("Spinner hit")
		break


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
	dead = 2.4
	_hurt_flash()
	_show_splatter()
	var nearest: Node3D = null
	var best := 9999.0
	for m in monsters:
		if not is_instance_valid(m):
			continue
		var d := Vector2(m.position.x - pos.x, m.position.z - pos.z).length()
		if d < best:
			best = d
			nearest = m
	if nearest:
		nearest.loom(pos, _forward())
		killer = nearest
	_log("The monster caught you")


func _hurt_flash() -> void:
	blood = 1.0


func _show_splatter() -> void:
	for poly in splats:
		poly.visible = true
		poly.position = Vector2(randf_range(-80.0, 1360.0), randf_range(-80.0, 800.0))
		poly.rotation = randf() * TAU
		poly.scale = Vector2(randf_range(0.7, 1.8), randf_range(0.7, 1.8))


func _step_blood(dt: float) -> void:
	if dead > 0.0:
		blood = 1.0
	else:
		blood = maxf(0.0, blood - dt * 1.4)
		if blood <= 0.02:
			for poly in splats:
				poly.visible = false
	blood_rect.visible = blood > 0.02
	blood_rect.color.a = blood * 0.55
	for poly in splats:
		if poly.visible:
			poly.modulate.a = blood


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
			_hurt_flash()
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
	if dead > 0.0 and killer and is_instance_valid(killer):
		cam.look_at(killer.global_position + Vector3(0, 0.7, 0), Vector3.UP)
	else:
		cam.rotation = Vector3(pitch, yaw, 0)
	water.position.x = pos.x
	water.position.z = pos.z
	bed.position.x = pos.x
	bed.position.z = pos.z
	ceiling.position.x = pos.x
	ceiling.position.z = pos.z
	var eye := pos.y + 1.6
	var under := eye < 0.2 and in_water
	var fog_color := Color("0c1c18") if under else Color("6f775c")
	world_env.environment.background_color = fog_color
	world_env.environment.fog_light_color = fog_color
	world_env.environment.fog_density = 0.055 if under else 0.02


func _refresh_hud() -> void:
	var charging := 0
	for m in monsters:
		if is_instance_valid(m) and m.state == "charge":
			charging += 1
	var where := "In the water" if in_water else "On a pad"
	if Input.is_key_pressed(KEY_SHIFT):
		where += " · sprint"
	hud.text = "Level %d / %d\n%s\n%d monsters · %d charging" % [
		level + 1, MapGen.LEVEL_COUNT, where, monsters.size(), charging
	]


func _log(text: String) -> void:
	logs.push_front(text)
	if logs.size() > 5:
		logs.resize(5)
	log_label.text = "\n".join(logs)
