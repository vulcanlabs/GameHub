class_name PlayroomsEnvironmentDecor
extends Node3D
## Visual-only Playroom dressing: climbing frames, furniture, murals, ceiling fittings, and quiet air.
## Does not move rooms, doors, slides, the collection hole, or any gameplay node.

const BALL_COLORS := [
	Color(0.78, 0.18, 0.18),
	Color(0.86, 0.72, 0.14),
	Color(0.18, 0.42, 0.78),
	Color(0.22, 0.58, 0.28),
	Color(0.82, 0.42, 0.12),
	Color(0.52, 0.28, 0.62),
]

var _yellow: StandardMaterial3D
var _red: StandardMaterial3D
var _green: StandardMaterial3D
var _blue: StandardMaterial3D
var _cream: StandardMaterial3D
var _teal: StandardMaterial3D
var _foam_b: StandardMaterial3D
var _foam_r: StandardMaterial3D
var _foam_y: StandardMaterial3D
var _foam_g: StandardMaterial3D
var _metal_y: StandardMaterial3D
var _metal_r: StandardMaterial3D
var _metal_g: StandardMaterial3D
var _metal_b: StandardMaterial3D
var _net_mat: StandardMaterial3D
var _wood: StandardMaterial3D
var _dark: StandardMaterial3D
var _plastic_cache := {}
var _time := 0.0
var _next_creak := 7.0
var _next_bounce := 11.0
var _next_metal := 16.0
var _creak: AudioStreamPlayer3D
var _bounce: AudioStreamPlayer3D
var _metal: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _playground: Node3D
var _props: Node3D
var _slide_details: Node3D
var _foam: Node3D
var _furniture: Node3D
var _walls: Node3D
var _ceiling: Node3D
var _audio: Node3D


func build() -> void:
	name = "Playrooms_Environment_Decor"
	_rng.seed = 20261112
	_make_materials()
	_playground = _group("Playground_Structures")
	_slide_details = _group("Slide_Details")
	_foam = _group("Foam_Obstacles")
	_furniture = _group("Furniture")
	_walls = _group("Wall_Decorations")
	_ceiling = _group("Ceiling_Details")
	_props = _group("Environmental_Props")
	_audio = _group("Ambient_Audio")
	_build_climbing_frame()
	_build_yellow_tower_dressing()
	_build_slide_surrounds()
	_build_pit_ring()
	_build_foam_clusters()
	_build_furniture()
	_build_wall_art()
	_build_ceiling_kit()
	_build_story_props()
	_build_ambient_audio()


func _process(delta: float) -> void:
	_time += delta
	if _creak != null and _time >= _next_creak:
		_creak.position = Vector3(_rng.randf_range(-16.0, 16.0), 2.2, _rng.randf_range(-12.0, 12.0))
		_creak.pitch_scale = _rng.randf_range(0.86, 1.12)
		_creak.play()
		_next_creak = _time + _rng.randf_range(9.0, 18.0)
	if _bounce != null and _time >= _next_bounce:
		_bounce.position = Vector3(_rng.randf_range(-8.0, 8.0), 0.2, _rng.randf_range(-8.0, 8.0))
		_bounce.pitch_scale = _rng.randf_range(0.9, 1.15)
		_bounce.play()
		_next_bounce = _time + _rng.randf_range(14.0, 28.0)
	if _metal != null and _time >= _next_metal:
		_metal.position = Vector3(_rng.randf_range(-18.0, 18.0), 5.4, _rng.randf_range(-13.0, 13.0))
		_metal.pitch_scale = _rng.randf_range(0.8, 1.05)
		_metal.play()
		_next_metal = _time + _rng.randf_range(18.0, 34.0)


func _group(group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	add_child(node)
	return node


func _make_materials() -> void:
	_yellow = _slide_plastic(Color(0.88, 0.7, 0.1))
	_red = _slide_plastic(Color(0.72, 0.18, 0.16))
	_green = _slide_plastic(Color(0.2, 0.52, 0.26))
	_blue = _slide_plastic(Color(0.2, 0.38, 0.72))
	_cream = _slide_plastic(Color(0.86, 0.74, 0.5))
	_teal = _slide_plastic(Color(0.2, 0.44, 0.36))
	_foam_b = _foam_mat(Color(0.22, 0.38, 0.7))
	_foam_r = _foam_mat(Color(0.68, 0.22, 0.2))
	_foam_y = _foam_mat(Color(0.8, 0.66, 0.16))
	_foam_g = _foam_mat(Color(0.28, 0.56, 0.3))
	_metal_y = _powder(Color(0.9, 0.74, 0.12))
	_metal_r = _powder(Color(0.74, 0.16, 0.14))
	_metal_g = _powder(Color(0.2, 0.58, 0.28))
	_metal_b = _powder(Color(0.16, 0.36, 0.76))
	_wood = _paint(Color(0.46, 0.3, 0.16), 0.72)
	_dark = _paint(Color(0.12, 0.12, 0.13), 0.55)
	_net_mat = StandardMaterial3D.new()
	_net_mat.albedo_texture = _net_texture()
	_net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_net_mat.roughness = 0.7
	_net_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_net_mat.albedo_color = Color(0.82, 0.84, 0.78, 0.85)


func _paint(color: Color, roughness := 0.82) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _foam_mat(color: Color) -> StandardMaterial3D:
	var material := _paint(color, 0.9)
	material.roughness_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_Roughness.jpg")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_scale = Vector3(1.6, 1.6, 1.6)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	return material


func _slide_plastic(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.3
	material.metallic = 0.04
	material.clearcoat_enabled = true
	material.clearcoat = 0.48
	material.clearcoat_roughness = 0.38
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_NormalGL.jpg")
	material.roughness_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_Roughness.jpg")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_scale = Vector3(2.2, 2.2, 2.2)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	return material


func _powder(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.22
	material.roughness = 0.46
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/Metal012/Metal012_2K-JPG_NormalGL.jpg")
	material.roughness_texture = load("res://assets/textures/Metal012/Metal012_2K-JPG_Roughness.jpg")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_scale = Vector3(1.4, 1.4, 1.4)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	return material


func _gloss_ball(color: Color) -> StandardMaterial3D:
	if _plastic_cache.has(color):
		return _plastic_cache[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.22
	material.metallic = 0.02
	material.clearcoat_enabled = true
	material.clearcoat = 0.4
	_plastic_cache[color] = material
	return material


# ---------------------------------------------------------------- climbing / playground

func _build_climbing_frame() -> void:
	var root := Node3D.new()
	root.name = "WestClimbingFrame"
	root.position = Vector3(-17.1, 0.0, 5.1)
	root.rotation.y = PI * 0.5
	_playground.add_child(root)
	var metals: Array[StandardMaterial3D] = [_metal_y, _metal_b, _metal_g, _metal_r]
	var foams: Array[StandardMaterial3D] = [_foam_y, _foam_b, _foam_g, _foam_r]
	var xs: Array[float] = [-0.95, 0.0, 0.95]
	var zs: Array[float] = [-0.85, 0.15, 1.15]
	for ix in xs.size():
		for iz in zs.size():
			var mat: StandardMaterial3D = metals[(ix + iz) % 4]
			var foam: StandardMaterial3D = foams[(ix + iz) % 4]
			var at := Vector3(xs[ix], 1.55, zs[iz])
			_pole(root, at, 3.1, 0.055, mat)
			_cyl(root, Vector3(xs[ix], 0.55, zs[iz]), 0.08, 1.1, foam)
			_joint(root, Vector3(xs[ix], 1.18, zs[iz]), 0.09, mat)
			_joint(root, Vector3(xs[ix], 2.28, zs[iz]), 0.09, mat)
	_padded_deck(root, Vector3(0.0, 1.18, 0.15), Vector3(2.05, 0.1, 2.15), _foam_y)
	_padded_deck(root, Vector3(0.0, 2.28, 0.05), Vector3(1.85, 0.1, 1.85), _foam_b)
	LevelKit.box(root, Vector3(1.7, 0.62, 0.08), Vector3(0.0, 2.62, -0.82), _blue, false)
	LevelKit.box(root, Vector3(0.08, 0.62, 1.5), Vector3(-0.95, 2.62, 0.05), _green, false)
	_hole_frame(root, Vector3(0.0, 2.22, -0.72), 0.92, 0.7, 0.07, _yellow)
	_ladder(root, Vector3(-1.15, 0.0, 0.15), _metal_y)
	_ladder(root, Vector3(1.15, 0.0, 0.85), _metal_b)
	_tunnel_section(root, Vector3(0.95, 0.42, 0.15), 0.4, 1.45, _red)
	_tunnel_section(root, Vector3(-0.2, 1.55, 1.05), 0.36, 1.2, _yellow)
	_net_panel(root, Vector3(1.08, 1.55, 0.15), Vector3(0.04, 2.2, 2.0))
	_net_panel(root, Vector3(-1.08, 1.55, 0.15), Vector3(0.04, 2.2, 2.0))
	for i in 4:
		var pad := Vector3(-0.95 + float(i) * 0.55, 0.16, 1.55)
		LevelKit.box(root, Vector3(0.48, 0.32, 0.22), pad, _foam_b if i % 2 == 0 else _foam_g, false)
	_barrier(root, Vector3(0.0, 0.28, -1.15), Vector3(2.1, 0.55, 0.08), _foam_r)
	LevelKit.collider(root, Vector3(2.6, 0.5, 2.9), Vector3(0.0, 0.4, 0.2))
	LevelKit.collider(root, Vector3(1.4, 1.2, 1.8), Vector3(0.0, 1.3, 0.1))


func _build_yellow_tower_dressing() -> void:
	var root := Node3D.new()
	root.name = "YellowTowerDressing"
	root.position = Vector3(-16.8, 0.0, -12.4)
	root.rotation.y = 0.7
	_playground.add_child(root)
	_joint(root, Vector3(0.0, 2.55, 0.05), 0.1, _metal_y)
	_net_panel(root, Vector3(0.72, 1.3, 0.1), Vector3(0.04, 1.8, 1.4))
	_tunnel_section(root, Vector3(-0.15, 0.36, 0.95), 0.34, 1.15, _blue)
	_barrier(root, Vector3(-0.9, 0.22, -0.2), Vector3(0.12, 0.44, 1.1), _foam_r)


func _build_slide_surrounds() -> void:
	var beige := Node3D.new()
	beige.name = "BeigeSlideDetails"
	beige.position = Vector3(12.4, 0.0, 14.35)
	beige.rotation.y = PI
	_slide_details.add_child(beige)
	_landing_kit(beige, Vector3(0.0, 0.0, -4.55), _cream)
	_sign_plate(beige, Vector3(1.15, 1.15, -1.4), Vector3(1, 0, 0), "SLIDE")
	_barrier(beige, Vector3(-0.85, 0.2, -2.2), Vector3(0.1, 0.4, 1.6), _foam_b)

	var green := Node3D.new()
	green.name = "GreenSlideDetails"
	green.position = Vector3(-12.8, 0.0, 12.6)
	green.rotation.y = 0.2
	_slide_details.add_child(green)
	_landing_kit(green, Vector3(0.0, 0.0, -3.25), _teal)
	_sign_plate(green, Vector3(0.95, 1.05, -1.1), Vector3(1, 0, 0), "WAIT HERE")
	_barrier(green, Vector3(0.7, 0.2, -1.6), Vector3(0.1, 0.4, 1.2), _foam_g)


func _landing_kit(parent: Node3D, at: Vector3, _slide_mat: Material) -> void:
	LevelKit.box(parent, Vector3(1.35, 0.06, 1.15), at + Vector3(0.0, 0.03, 0.1), _foam_b, false)
	LevelKit.box(parent, Vector3(0.55, 0.08, 0.4), at + Vector3(0.55, 0.04, 0.35), _foam_y, false)


func _build_pit_ring() -> void:
	var root := Node3D.new()
	root.name = "PitSurround"
	_props.add_child(root)
	LevelKit.box(root, Vector3(0.72, 0.08, 0.52), Vector3(5.2, 0.04, 1.4), _foam_b, false)
	LevelKit.box(root, Vector3(0.5, 0.16, 0.42), Vector3(5.65, 0.08, 1.35), _foam_y, false)
	LevelKit.box(root, Vector3(0.4, 0.22, 0.36), Vector3(6.0, 0.11, 1.32), _foam_g, false)
	_bucket(root, Vector3(4.9, 0.02, -2.55), 0.85)
	_bucket(root, Vector3(5.4, 0.02, -2.1), 1.35)
	_ride_on(root, Vector3(6.25, 0.0, 2.45))


func _build_foam_clusters() -> void:
	_foam_stack(Vector3(-6.5, 0.0, 10.3), [_foam_r, _foam_y, _foam_b])
	_foam_stack(Vector3(8.7, 0.0, 5.2), [_foam_b, _foam_r, _foam_g])
	_foam_stack(Vector3(15.8, 0.0, -6.4), [_foam_y, _foam_b, _foam_r])
	_cyl(_foam, Vector3(-6.95, 0.28, 9.75), 0.22, 0.56, _foam_b)
	_cyl(_foam, Vector3(9.2, 0.22, 4.75), 0.2, 0.44, _foam_y)
	_tunnel_section(_foam, Vector3(8.15, 0.34, -4.55), 0.34, 1.45, _yellow)
	_tunnel_section(_foam, Vector3(8.15, 0.34, -5.85), 0.34, 1.45, _red)
	_tunnel_section(_foam, Vector3(16.4, 0.36, -7.4), 0.38, 1.6, _blue)
	LevelKit.box(_foam, Vector3(1.1, 0.28, 0.7), Vector3(16.9, 0.14, -8.6), _foam_g, false)
	LevelKit.box(_foam, Vector3(0.7, 0.5, 0.7), Vector3(17.6, 0.25, -8.2), _foam_y, false)
	LevelKit.collider(_foam, Vector3(2.2, 0.4, 2.4), Vector3(16.8, 0.3, -7.4))


func _build_furniture() -> void:
	_kid_table(Vector3(-8.4, 0.0, -3.2))
	_kid_table(Vector3(7.6, 0.0, -11.6))
	_tipped_chair(Vector3(-7.55, 0.0, -2.55))
	_arcade(Vector3(19.35, 0.0, 4.6), PI * 0.5)
	_arcade(Vector3(19.35, 0.0, 5.75), PI * 0.5)
	_vending(Vector3(19.32, 0.0, 7.15), PI * 0.5)
	_shelf(Vector3(0.0, 0.0, 14.55), 0.0)
	_bench_pad(Vector3(4.2, 0.0, -14.45), _foam_b)
	_bench_pad(Vector3(-4.2, 0.0, -14.45), _foam_y)
	_ride_on(_furniture, Vector3(7.4, 0.0, 8.6))
	_ride_on(_furniture, Vector3(-15.2, 0.0, 8.8))
	_small_climb(Vector3(-8.8, 0.0, 5.6))
	_party_table(Vector3(15.4, 0.0, 11.6))


func _build_wall_art() -> void:
	_mural(Vector3(0.0, 2.55, -14.58), Vector3(0, 0, 1), Vector2(6.2, 2.4), 0)
	_mural(Vector3(19.58, 2.7, 9.2), Vector3(-1, 0, 0), Vector2(5.0, 2.15), 1)
	_mural(Vector3(-19.58, 2.55, -10.6), Vector3(1, 0, 0), Vector2(4.6, 2.0), 2)
	_mural(Vector3(-19.58, 2.7, 10.4), Vector3(1, 0, 0), Vector2(4.0, 1.8), 3)
	_sign_plate(_walls, Vector3(-19.5, 1.7, 8.4), Vector3(1, 0, 0), "PLAY SAFE")
	_sign_plate(_walls, Vector3(19.5, 1.65, -3.2), Vector3(-1, 0, 0), "NO RUNNING")
	_sign_plate(_walls, Vector3(19.5, 1.7, 11.4), Vector3(-1, 0, 0), "SOCKS ONLY")
	_poster(Vector3(10.5, 2.1, 14.58), Vector3(0, 0, -1), "HAPPY\nBIRTHDAY", Color(0.7, 0.22, 0.28), 0.08)
	_poster(Vector3(-3.5, 2.15, 14.58), Vector3(0, 0, -1), "PARTY\nROOM", Color(0.22, 0.4, 0.7), 0.0)
	_poster(Vector3(6.2, 2.35, -14.58), Vector3(0, 0, 1), "TOKEN\nGAMES", Color(0.72, 0.5, 0.16), -0.06)
	_poster(Vector3(-12.4, 2.2, -14.58), Vector3(0, 0, 1), "LOST &\nFOUND", Color(0.28, 0.5, 0.32), 0.05)
	_height_chart(Vector3(-19.52, 0.2, 3.4), Vector3(1, 0, 0))
	_clock(Vector3(0.0, 4.55, -14.55))
	_banner(Vector3(0.0, 4.85, 14.35), "BIRTHDAY STAR")
	LevelKit.box(_walls, Vector3(0.08, 1.8, 1.4), Vector3(-19.52, 0.95, 5.2), _paint(Color(0.74, 0.2, 0.18), 0.7), false)
	LevelKit.box(_walls, Vector3(0.08, 1.8, 1.4), Vector3(-19.52, 0.95, 6.7), _paint(Color(0.2, 0.4, 0.7), 0.7), false)


func _build_ceiling_kit() -> void:
	var steel := load("res://assets/materials/steel_painted_dark.tres") as Material
	var galv := load("res://assets/materials/steel_galvanized.tres") as Material
	for z: float in [-11.0, -3.7, 3.7, 11.0]:
		for x: float in [-16.0, -8.0, 0.0, 8.0, 16.0]:
			LevelKit.box(_ceiling, Vector3(1.15, 0.06, 0.28), Vector3(x, 6.78, z), steel, false)
			var tube := _paint(Color(0.94, 0.95, 0.9), 0.18)
			tube.emission_enabled = true
			tube.emission = Color(0.92, 0.94, 0.88)
			tube.emission_energy_multiplier = 0.45
			LevelKit.box(_ceiling, Vector3(1.02, 0.04, 0.12), Vector3(x, 6.74, z), tube, false)
	var vents: Array[Vector3] = [Vector3(-10.0, 6.2, -14.55), Vector3(10.0, 6.2, 14.55), Vector3(0.0, 6.25, 0.0)]
	for at: Vector3 in vents:
		LevelKit.box(_ceiling, Vector3(1.15, 0.55, 0.06), at, steel, false)
		for slat in 5:
			LevelKit.box(_ceiling, Vector3(1.05, 0.03, 0.03), at + Vector3(0.0, -0.18 + float(slat) * 0.08, 0.04), galv, false)
	_camera(Vector3(-18.5, 6.35, -13.5))
	_camera(Vector3(18.5, 6.35, 13.5))
	_camera(Vector3(0.0, 6.4, -13.8))
	_exit_sign(Vector3(18.6, 5.85, 0.9), Vector3(-1, 0, 0))
	_exit_sign(Vector3(-18.6, 5.85, -0.9), Vector3(1, 0, 0))
	var stain := _paint(Color(0.72, 0.7, 0.64, 0.35), 0.95)
	stain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var stains: Array[Vector3] = [Vector3(-6.5, 6.84, 4.2), Vector3(9.2, 6.84, -5.5), Vector3(-11.0, 6.84, -8.0)]
	for at: Vector3 in stains:
		LevelKit.box(_ceiling, Vector3(1.8, 0.01, 1.1), at, stain, false)


func _build_story_props() -> void:
	_shoe(Vector3(5.85, 0.02, 8.15))
	_banner(Vector3(-8.8, 3.6, 5.6), "JAMIE 7 TODAY")


func _build_ambient_audio() -> void:
	for at: Vector3 in [Vector3(-10.0, 5.6, 0.0), Vector3(10.0, 5.6, 0.0), Vector3(0.0, 5.8, -8.0)]:
		var hum := AudioStreamPlayer3D.new()
		hum.stream = Sfx.stream("vent_hum")
		hum.bus = "Environment"
		hum.position = at
		hum.unit_size = 16.0
		hum.volume_db = -22.0
		hum.autoplay = true
		_audio.add_child(hum)
	_creak = AudioStreamPlayer3D.new()
	_creak.stream = Sfx.stream("plastic_creak")
	_creak.bus = "Environment"
	_creak.unit_size = 10.0
	_creak.volume_db = -18.0
	_audio.add_child(_creak)
	_bounce = AudioStreamPlayer3D.new()
	_bounce.stream = Sfx.stream("ball_bounce_far")
	_bounce.bus = "Environment"
	_bounce.unit_size = 8.0
	_bounce.volume_db = -20.0
	_audio.add_child(_bounce)
	_metal = AudioStreamPlayer3D.new()
	_metal.stream = Sfx.stream("distant_metal")
	_metal.bus = "Environment"
	_metal.unit_size = 18.0
	_metal.volume_db = -24.0
	_audio.add_child(_metal)


# ---------------------------------------------------------------- pieces

func _pole(parent: Node3D, at: Vector3, height: float, radius: float, material: Material) -> void:
	_cyl(parent, at, radius, height, material)


func _cyl(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


func _joint(parent: Node3D, at: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)


func _padded_deck(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	LevelKit.box(parent, size, at, material, false)
	var lip := _paint(Color(0.78, 0.78, 0.74), 0.55)
	LevelKit.box(parent, Vector3(size.x + 0.06, 0.04, size.z + 0.06), at + Vector3(0.0, -size.y * 0.5 - 0.02, 0.0), lip, false)


func _ladder(parent: Node3D, at: Vector3, material: Material) -> void:
	var ladder := Node3D.new()
	ladder.position = at
	parent.add_child(ladder)
	_pole(ladder, Vector3(0.0, 1.25, -0.16), 2.5, 0.03, material)
	_pole(ladder, Vector3(0.0, 1.25, 0.16), 2.5, 0.03, material)
	for n in 7:
		LevelKit.box(ladder, Vector3(0.05, 0.035, 0.36), Vector3(0.0, 0.28 + float(n) * 0.32, 0.0), material, false)


func _tunnel_section(parent: Node3D, at: Vector3, radius: float, length: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 18
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.rotation.z = PI * 0.5
	parent.add_child(node)
	var ring := _paint(Color(0.86, 0.86, 0.82), 0.4)
	for side: float in [-1.0, 1.0]:
		var lip := TorusMesh.new()
		lip.inner_radius = radius * 0.08
		lip.outer_radius = radius * 0.16
		lip.rings = 10
		lip.ring_segments = 16
		var band := MeshInstance3D.new()
		band.mesh = lip
		band.material_override = ring
		band.position = at + Vector3(side * length * 0.48, 0.0, 0.0)
		band.rotation.z = PI * 0.5
		parent.add_child(band)
	LevelKit.collider(parent, Vector3(length, radius * 1.15, radius * 1.15), at)


func _net_panel(parent: Node3D, at: Vector3, size: Vector3) -> void:
	LevelKit.box(parent, size, at, _net_mat, false)


func _barrier(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	LevelKit.box(parent, size, at, material, false)


func _hole_frame(parent: Node3D, at: Vector3, width: float, height: float, thick: float, material: Material) -> void:
	LevelKit.box(parent, Vector3(width, thick, thick), at + Vector3(0.0, height * 0.5, 0.0), material, false)
	LevelKit.box(parent, Vector3(width, thick, thick), at + Vector3(0.0, -height * 0.5, 0.0), material, false)
	LevelKit.box(parent, Vector3(thick, height, thick), at + Vector3(-width * 0.5, 0.0, 0.0), material, false)
	LevelKit.box(parent, Vector3(thick, height, thick), at + Vector3(width * 0.5, 0.0, 0.0), material, false)


func _foam_stack(at: Vector3, mats: Array) -> void:
	var sizes: Array[Vector3] = [Vector3(0.55, 0.55, 0.55), Vector3(0.4, 0.4, 0.4), Vector3(0.38, 0.7, 0.38)]
	var offs: Array[Vector3] = [Vector3(0.0, 0.28, 0.0), Vector3(0.42, 0.2, 0.28), Vector3(0.18, 0.35, -0.38)]
	for n in sizes.size():
		var mat: Material = mats[n % mats.size()]
		LevelKit.box(_foam, sizes[n], at + offs[n], mat, false)


func _bucket(parent: Node3D, at: Vector3, tilt: float) -> void:
	var pail := _slide_plastic(Color(0.78, 0.24, 0.18))
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.13
	mesh.height = 0.22
	mesh.radial_segments = 14
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = pail
	node.position = at + Vector3(0.0, 0.12, 0.0)
	node.rotation.z = tilt
	parent.add_child(node)


func _ride_on(parent: Node3D, at: Vector3) -> void:
	var body := _slide_plastic(Color(0.74, 0.16, 0.16))
	var wheel := _paint(Color(0.1, 0.1, 0.11), 0.7)
	LevelKit.box(parent, Vector3(0.55, 0.16, 0.28), at + Vector3(0.0, 0.18, 0.0), body, false)
	LevelKit.box(parent, Vector3(0.18, 0.16, 0.26), at + Vector3(-0.16, 0.32, 0.0), body, false)
	var wheel_x: Array[float] = [-0.18, 0.18]
	var wheel_z: Array[float] = [-0.14, 0.14]
	for x: float in wheel_x:
		for z: float in wheel_z:
			_cyl(parent, at + Vector3(x, 0.08, z), 0.07, 0.05, wheel)


func _kid_table(at: Vector3) -> void:
	LevelKit.box(_furniture, Vector3(0.9, 0.05, 0.9), at + Vector3(0.0, 0.42, 0.0), _yellow, false)
	var legs: Array[Vector3] = [Vector3(-0.35, 0.21, -0.35), Vector3(0.35, 0.21, -0.35), Vector3(-0.35, 0.21, 0.35), Vector3(0.35, 0.21, 0.35)]
	for p: Vector3 in legs:
		_cyl(_furniture, at + p, 0.035, 0.42, _yellow)
	var seats: Array[StandardMaterial3D] = [_red, _green, _blue, _yellow]
	var spots: Array[Vector3] = [Vector3(-0.85, 0.0, 0.0), Vector3(0.85, 0.0, 0.0), Vector3(0.0, 0.0, -0.85), Vector3(0.0, 0.0, 0.85)]
	for n in 4:
		if n == 1:
			continue
		_cyl(_furniture, at + spots[n] + Vector3(0.0, 0.18, 0.0), 0.16, 0.06, seats[n])
		_cyl(_furniture, at + spots[n] + Vector3(0.0, 0.1, 0.0), 0.04, 0.2, seats[n])
	LevelKit.collider(_furniture, Vector3(2.0, 0.5, 2.0), at + Vector3(0.0, 0.25, 0.0))


func _tipped_chair(at: Vector3) -> void:
	var chair := Node3D.new()
	chair.position = at
	chair.rotation.z = 0.85
	chair.rotation.y = 0.4
	_furniture.add_child(chair)
	_cyl(chair, Vector3(0.0, 0.18, 0.0), 0.16, 0.06, _red)
	_cyl(chair, Vector3(0.0, 0.1, 0.0), 0.04, 0.2, _red)


func _arcade(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	_furniture.add_child(root)
	LevelKit.box(root, Vector3(0.72, 1.48, 0.64), Vector3(0.0, 0.74, 0.0), _dark)
	LevelKit.box(root, Vector3(0.54, 0.42, 0.04), Vector3(0.0, 1.08, 0.33), LevelKit.glow(Color(0.1, 0.32, 0.14), 0.7), false)
	LevelKit.box(root, Vector3(0.5, 0.08, 0.28), Vector3(0.0, 0.72, 0.18), _paint(Color(0.18, 0.18, 0.2), 0.4), false)
	_cyl(root, Vector3(-0.12, 0.78, 0.22), 0.03, 0.06, _red)
	_cyl(root, Vector3(0.12, 0.78, 0.22), 0.03, 0.06, _yellow)


func _vending(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	_furniture.add_child(root)
	var body := _paint(Color(0.72, 0.14, 0.16), 0.48)
	LevelKit.box(root, Vector3(0.78, 1.85, 0.7), Vector3(0.0, 0.93, 0.0), body)
	LevelKit.box(root, Vector3(0.5, 1.15, 0.04), Vector3(0.0, 1.05, 0.36), _paint(Color(0.15, 0.18, 0.2), 0.2), false)
	LevelKit.box(root, Vector3(0.18, 0.12, 0.04), Vector3(0.22, 0.35, 0.36), LevelKit.glow(Color(0.2, 0.7, 0.25), 0.4), false)


func _shelf(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	_furniture.add_child(root)
	LevelKit.box(root, Vector3(1.65, 1.22, 0.34), Vector3(0.0, 0.61, 0.0), _wood)
	for y in [0.25, 0.6, 0.95]:
		LevelKit.box(root, Vector3(1.52, 0.04, 0.3), Vector3(0.0, y, 0.02), _wood, false)
	LevelKit.box(root, Vector3(0.18, 0.18, 0.18), Vector3(-0.45, 0.72, 0.05), _blue, false)
	LevelKit.box(root, Vector3(0.16, 0.22, 0.16), Vector3(0.15, 1.08, 0.05), _red, false)
	LevelKit.box(root, Vector3(0.2, 0.12, 0.14), Vector3(0.48, 0.34, 0.05), _yellow, false)
	_cyl(root, Vector3(-0.2, 0.38, 0.04), 0.07, 0.16, _green)


func _bench_pad(at: Vector3, foam: Material) -> void:
	LevelKit.box(_furniture, Vector3(1.8, 0.38, 0.5), at + Vector3(0.0, 0.19, 0.0), foam)


func _small_climb(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	_playground.add_child(root)
	_pole(root, Vector3(-0.45, 0.7, -0.35), 1.4, 0.045, _metal_y)
	_pole(root, Vector3(0.45, 0.7, -0.35), 1.4, 0.045, _metal_y)
	_pole(root, Vector3(-0.45, 0.7, 0.35), 1.4, 0.045, _metal_b)
	_pole(root, Vector3(0.45, 0.7, 0.35), 1.4, 0.045, _metal_b)
	LevelKit.box(root, Vector3(1.05, 0.08, 0.85), Vector3(0.0, 1.35, 0.0), _foam_y, false)
	LevelKit.collider(root, Vector3(1.2, 1.4, 1.0), Vector3(0.0, 0.7, 0.0))


func _party_table(at: Vector3) -> void:
	LevelKit.box(_furniture, Vector3(1.2, 0.06, 0.7), at + Vector3(0.0, 0.72, 0.0), _paint(Color(0.86, 0.86, 0.8), 0.6), false)
	var table_legs: Array[Vector3] = [Vector3(-0.5, 0.36, -0.28), Vector3(0.5, 0.36, -0.28), Vector3(-0.5, 0.36, 0.28), Vector3(0.5, 0.36, 0.28)]
	for p: Vector3 in table_legs:
		_cyl(_furniture, at + p, 0.03, 0.72, _paint(Color(0.55, 0.55, 0.52), 0.4))
	LevelKit.box(_furniture, Vector3(0.22, 0.08, 0.16), at + Vector3(-0.25, 0.8, 0.1), _red, false)
	LevelKit.box(_furniture, Vector3(0.18, 0.12, 0.18), at + Vector3(0.28, 0.82, -0.08), _yellow, false)
	_cyl(_furniture, at + Vector3(0.0, 0.9, 0.05), 0.05, 0.22, _paint(Color(0.9, 0.9, 0.88), 0.3))
	LevelKit.collider(_furniture, Vector3(1.3, 0.8, 0.8), at + Vector3(0.0, 0.4, 0.0))


func _shoe(at: Vector3) -> void:
	var rubber := _paint(Color(0.72, 0.18, 0.2), 0.65)
	LevelKit.box(_props, Vector3(0.18, 0.07, 0.08), at + Vector3(0.0, 0.04, 0.0), rubber, false)
	LevelKit.box(_props, Vector3(0.08, 0.08, 0.08), at + Vector3(-0.06, 0.08, 0.0), rubber, false)


func _scatter_balls(parent: Node3D, at: Vector3, count: int, radius: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.085
	mesh.height = 0.17
	mesh.radial_segments = 10
	mesh.rings = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	for n in count:
		var angle := float(n) * 2.3
		var r := radius * (0.25 + fmod(float(n) * 0.37, 0.75))
		var xf := Transform3D(Basis.IDENTITY, at + Vector3(cos(angle) * r, 0.0, sin(angle) * r))
		mm.set_instance_transform(n, xf)
		var color: Color = BALL_COLORS[n % BALL_COLORS.size()]
		mm.set_instance_color(n, color)
	var node := MultiMeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.22
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.35
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func _loose_ball(parent: Node3D, at: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.085
	mesh.height = 0.17
	mesh.radial_segments = 10
	mesh.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _gloss_ball(BALL_COLORS[wrapi(int(absf(at.x * 7.0 + at.z * 5.0)), 0, BALL_COLORS.size())])
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func _mural(at: Vector3, facing: Vector3, size: Vector2, kind: int) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _mural_tex(kind)
	mat.roughness = 0.94
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.position = at
	node.rotation.y = atan2(facing.x, facing.z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_walls.add_child(node)


func _mural_tex(kind: int) -> ImageTexture:
	var image := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	match kind:
		0:
			image.fill(Color(0.62, 0.78, 0.9, 0.92))
			_blob(image, Vector2(40, 90), 28, Color(0.28, 0.58, 0.28, 0.9))
			_blob(image, Vector2(90, 85), 34, Color(0.24, 0.52, 0.24, 0.9))
			_blob(image, Vector2(160, 88), 30, Color(0.3, 0.6, 0.28, 0.9))
			_blob(image, Vector2(70, 36), 22, Color(0.92, 0.92, 0.9, 0.85))
			_blob(image, Vector2(200, 32), 18, Color(0.9, 0.9, 0.88, 0.8))
		1:
			image.fill(Color(0.78, 0.62, 0.32, 0.88))
			for n in 7:
				var c := Color.from_hsv(float(n) / 7.0, 0.55, 0.82, 0.9)
				_blob(image, Vector2(28.0 + float(n) * 32.0, 64.0), 16, c)
		2:
			image.fill(Color(0.55, 0.7, 0.48, 0.9))
			_blob(image, Vector2(70, 70), 26, Color(0.9, 0.78, 0.28, 0.9))
			_blob(image, Vector2(70, 48), 14, Color(0.92, 0.55, 0.22, 0.9))
			_blob(image, Vector2(180, 72), 22, Color(0.86, 0.86, 0.84, 0.9))
			_blob(image, Vector2(168, 58), 10, Color(0.2, 0.2, 0.22, 0.9))
			_blob(image, Vector2(192, 58), 10, Color(0.2, 0.2, 0.22, 0.9))
		_:
			image.fill(Color(0.7, 0.74, 0.62, 0.88))
			for n in 6:
				_blob(image, Vector2(30.0 + float(n) * 38.0, 40.0 + float(n % 2) * 30.0), 14, Color(0.82, 0.32, 0.28, 0.85) if n % 2 == 0 else Color(0.28, 0.42, 0.72, 0.85))
	return ImageTexture.create_from_image(image)


func _blob(image: Image, centre: Vector2, radius: float, tone: Color) -> void:
	var r := int(radius)
	var x0 := maxi(int(centre.x) - r, 0)
	var y0 := maxi(int(centre.y) - r, 0)
	var x1 := mini(int(centre.x) + r, image.get_width() - 1)
	var y1 := mini(int(centre.y) + r, image.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if Vector2(x, y).distance_to(centre) <= radius:
				image.set_pixel(x, y, tone)


func _sign_plate(parent: Node3D, at: Vector3, facing: Vector3, text: String) -> void:
	var yellow := _paint(Color(0.78, 0.68, 0.16), 0.55)
	LevelKit.box(parent, Vector3(0.02, 0.34, 0.72) if absf(facing.x) > 0.5 else Vector3(0.72, 0.34, 0.02), at, yellow, false)
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.modulate = Color(0.16, 0.12, 0.08)
	label.position = at + facing * 0.03
	label.rotation.y = atan2(facing.x, facing.z)
	label.pixel_size = 0.004
	parent.add_child(label)


func _poster(at: Vector3, facing: Vector3, text: String, color: Color, tilt: float) -> void:
	var size := Vector3(0.02, 0.72, 0.52) if absf(facing.x) > 0.5 else Vector3(0.52, 0.72, 0.02)
	LevelKit.box(_walls, size, at, _paint(color, 0.7), false)
	var label := Label3D.new()
	label.text = text
	label.font_size = 34
	label.modulate = Color(0.95, 0.9, 0.72)
	label.position = at + facing * 0.03
	label.rotation.y = atan2(facing.x, facing.z) + tilt
	label.pixel_size = 0.0035
	_walls.add_child(label)


func _height_chart(at: Vector3, facing: Vector3) -> void:
	LevelKit.box(_walls, Vector3(0.03, 1.6, 0.22), at + Vector3(0.0, 0.8, 0.0), _paint(Color(0.9, 0.9, 0.86), 0.65), false)
	for n in 8:
		var y := 0.25 + float(n) * 0.18
		LevelKit.box(_walls, Vector3(0.02, 0.015, 0.16), at + Vector3(0.02, y, 0.0), _paint(Color(0.2, 0.2, 0.22), 0.5), false)
	var label := Label3D.new()
	label.text = "HOW TALL?"
	label.font_size = 28
	label.position = at + facing * 0.04 + Vector3(0.0, 1.55, 0.0)
	label.rotation.y = atan2(facing.x, facing.z)
	label.pixel_size = 0.003
	label.modulate = Color(0.2, 0.35, 0.7)
	_walls.add_child(label)


func _clock(at: Vector3) -> void:
	_cyl(_walls, at, 0.24, 0.05, _paint(Color(0.88, 0.88, 0.84), 0.4))
	LevelKit.box(_walls, Vector3(0.02, 0.14, 0.02), at + Vector3(0.0, 0.04, 0.03), _paint(Color(0.1, 0.1, 0.1), 0.4), false)
	LevelKit.box(_walls, Vector3(0.1, 0.02, 0.02), at + Vector3(0.04, 0.0, 0.03), _paint(Color(0.1, 0.1, 0.1), 0.4), false)


func _camera(at: Vector3) -> void:
	LevelKit.box(_ceiling, Vector3(0.16, 0.1, 0.22), at, _dark, false)
	_cyl(_ceiling, at + Vector3(0.0, -0.02, 0.14), 0.05, 0.08, _dark)


func _banner(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.modulate = Color(0.78, 0.22, 0.28, 0.8)
	label.outline_size = 8
	label.position = at
	label.pixel_size = 0.0045
	_walls.add_child(label)


func _exit_sign(at: Vector3, facing: Vector3) -> void:
	LevelKit.box(_ceiling, Vector3(0.04, 0.18, 0.42) if absf(facing.x) > 0.5 else Vector3(0.42, 0.18, 0.04), at, LevelKit.glow(Color(0.15, 0.55, 0.22), 0.8), false)
	var label := Label3D.new()
	label.text = "EXIT"
	label.font_size = 42
	label.modulate = Color(0.85, 0.95, 0.8)
	label.position = at + facing * 0.04
	label.rotation.y = atan2(facing.x, facing.z)
	label.pixel_size = 0.0035
	_ceiling.add_child(label)


func _net_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var line := Color(0.75, 0.75, 0.7, 0.7)
	for i in 64:
		if i % 8 == 0:
			for j in 64:
				image.set_pixel(i, j, line)
				image.set_pixel(j, i, line)
	return ImageTexture.create_from_image(image)
