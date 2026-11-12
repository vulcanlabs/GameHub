class_name Vacuum
extends Node3D
## The industrial vacuum the player carries: the model in the lower right of the view, the suction, the tank.
##
## Hold the `vacuum` action (left mouse) to run the motor. At full power it lifts COLLECT_RATE balls a second
## from wherever the centre dot points, up to REACH metres away, until the tank holds
## GameState.VACUUM_CAPACITY. Then it stops collecting and warns.
##
## MODEL: Blender was not available when this was built, so the model is assembled here from Godot's own
## primitive meshes with the downloaded PBR materials. It is original to this project. A sculpted .glb can
## replace `_build_model()` later; only `tip` (the nozzle opening) is used by the rest of the game.
##
## The model is built at real size and drawn at VIEW_SCALE, close to the camera, so the nozzle never pokes
## through a wall the player is standing against. Anything in the world that has to meet the nozzle (balls
## flying in, balls pouring out) uses `suction_point()`, which is where a full-size nozzle would be.

const VIEW_SCALE := 0.3
const REST_POSITION := Vector3(0.078, -0.062, -0.128)
const REST_ROTATION := Vector3(0.07, 0.085, 0.0)

## Balls collected per second at full power.
@export var collect_rate := 1200.0
## How far the suction reaches from the camera (m).
@export var reach := 4.5
## Seconds for the motor to reach full power, and to stop.
@export var spin_up := 0.35
@export var spin_down := 0.6

var balls: BallManager
var rooms: Array[BallManager] = []
var flyers: BallFlyers
var camera: Camera3D
## False while the player has no control (paused, mouse not captured).
var enabled := true
## Horizontal speed of the player, for the walking sway (m/s).
var carrier_speed := 0.0

var power := 0.0                             # 0 off, 1 full speed
var sucking := false                         # true while balls are actually arriving

var tip: Marker3D
var _model: Node3D
var _lamps: Array[MeshInstance3D] = []
var _dust: GPUParticles3D
var _motor: AudioStreamPlayer
var _air: AudioStreamPlayer
var _carry := 0.0
var _suck_hold := 0.0
var _warn_wait := 0.0
var _pop_wait := 0.0
var _time := 0.0
var _positions := PackedVector3Array()
var _colors := PackedColorArray()


func _ready() -> void:
	position = REST_POSITION
	rotation = REST_ROTATION
	scale = Vector3.ONE * VIEW_SCALE
	_build_model()
	_motor = _loop("vacuum_motor")
	_air = _loop("vacuum_air")
	GameState.vacuum_filled.connect(_on_filled)
	GameState.counts_changed.connect(_update_lamps)
	_update_lamps()


## Where a full-size nozzle would be in the world. Collected balls fly here; unloaded balls leave from here.
func suction_point() -> Vector3:
	var eye := camera.global_position if camera != null else global_position
	return eye + (tip.global_position - eye) / VIEW_SCALE


func _physics_process(delta: float) -> void:
	var held := enabled and Input.is_action_pressed("vacuum")
	power = move_toward(power, 1.0 if held else 0.0, delta / (spin_up if held else spin_down))
	_suck_hold = maxf(_suck_hold - delta, 0.0)
	_warn_wait = maxf(_warn_wait - delta, 0.0)
	_pop_wait = maxf(_pop_wait - delta, 0.0)
	if held and power > 0.5:
		if GameState.vacuum_full():
			if _warn_wait <= 0.0:
				_warn()
		elif balls != null and camera != null:
			_collect(delta)
	sucking = _suck_hold > 0.0


func _collect(delta: float) -> void:
	_carry += collect_rate * power * delta
	var wanted := mini(int(_carry), GameState.vacuum_space())
	if wanted <= 0:
		return
	_positions.clear()
	_colors.clear()
	var taken := 0
	var room := balls
	if not rooms.is_empty():
		var index := clampi(GameState.current_level, 0, rooms.size() - 1)
		room = rooms[index]
	if room != null:
		taken = room.suck(camera.global_position, -camera.global_basis.z, reach, wanted, _positions, _colors)
	# Unused suction does not bank up: at most one ball carries over to the next tick.
	_carry = minf(_carry - taken, 1.0)
	if taken == 0:
		return
	GameState.store_in_vacuum(taken)
	_suck_hold = 0.12
	if flyers != null:
		for n in taken:
			flyers.add_sucked(_positions[n], _colors[n])
	if _pop_wait <= 0.0:
		_pop_wait = randf_range(0.032, 0.058)
		Sfx.play("ball_pop", "Balls", randf_range(-8.5, -4.5), randf_range(0.78, 1.12))
		if taken >= 8:
			Sfx.play("ball_pop", "Balls", randf_range(-12.0, -8.0), randf_range(0.95, 1.28))


func _process(delta: float) -> void:
	_time += delta
	# Walking sway, plus a tremble from the motor.
	var stride := clampf(carrier_speed / 5.0, 0.0, 1.6)
	var sway := Vector3(cos(_time * 5.2) * 0.0028, absf(sin(_time * 5.2)) * -0.0034, 0.0) * stride
	var tremble := Vector3(randf() - 0.5, randf() - 0.5, 0.0) * 0.0009 * power
	var pull := Vector3(0.0, -0.002, -0.006) * (1.0 if sucking else 0.0)
	position = position.lerp(REST_POSITION + sway + pull, minf(delta * 14.0, 1.0)) + tremble
	_dust.emitting = sucking

	var full := GameState.vacuum_full()
	_set_loop(_motor, power, -11.0, (0.68 + 0.22 * power) * (0.9 if full else 1.0) + (0.03 if sucking else 0.0))
	_set_loop(_air, power * (0.45 if full else 1.0), -13.0, 0.78 + 0.18 * power)
	if full and not _lamps.is_empty():
		_lamps[2].visible = fmod(_time, 0.5) < 0.3


func _set_loop(player: AudioStreamPlayer, level: float, loudest_db: float, pitch: float) -> void:
	if level <= 0.01:
		if player.playing:
			player.stop()
		return
	player.volume_db = loudest_db + linear_to_db(level)
	player.pitch_scale = pitch
	if not player.playing:
		player.play()


func _loop(sound: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = Sfx.stream(sound)
	player.bus = "Vacuum"
	add_child(player)
	return player


func _on_filled() -> void:
	_warn()


func _warn() -> void:
	_warn_wait = 1.4
	Sfx.play("warn_full", "Alerts", -4.0)


# Green while there is room, amber from 80 %, red (blinking) when full.
func _update_lamps() -> void:
	if _lamps.is_empty():
		return
	var fill := float(GameState.vacuum_stored) / GameState.VACUUM_CAPACITY
	_lamps[0].visible = fill < 0.8
	_lamps[1].visible = fill >= 0.8 and fill < 1.0
	_lamps[2].visible = fill >= 1.0


# ---------------------------------------------------------------- model

func _build_model() -> void:
	var body: Material = preload("res://assets/materials/vacuum_body.tres")
	var yellow: Material = preload("res://assets/materials/vacuum_yellow.tres")
	var steel: Material = preload("res://assets/materials/vacuum_metal.tres")
	var rubber: Material = preload("res://assets/materials/rubber_black.tres")
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)

	# Motor housing, with a yellow band, a yellow end cap and three cooling grooves.
	_tube(0.075, 0.075, 0.34, 0.0, body, true)
	_tube(0.0775, 0.0775, 0.05, -0.065, yellow)
	_tube(0.064, 0.064, 0.03, 0.172, yellow)
	for groove in 3:
		_tube(0.0765, 0.0765, 0.007, 0.035 + groove * 0.024, rubber)

	# Reducer, steel wand with two yellow collars, flared nozzle with a rubber lip.
	_tube(0.07, 0.04, 0.1, -0.2, body)
	_tube(0.036, 0.036, 0.36, -0.41, steel)
	_tube(0.043, 0.043, 0.034, -0.29, yellow)
	_tube(0.043, 0.043, 0.034, -0.52, yellow)
	_tube(0.037, 0.064, 0.085, -0.625, steel)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.056
	lip.outer_radius = 0.072
	lip.rings = 24
	lip.ring_segments = 10
	_part(lip, Vector3(0.0, 0.0, -0.668), Vector3(PI * 0.5, 0.0, 0.0), rubber)
	var throat := StandardMaterial3D.new()
	throat.albedo_color = Color(0.01, 0.01, 0.012)
	throat.roughness = 1.0
	_tube(0.057, 0.057, 0.004, -0.655, throat)

	# Carry handle on top, pistol grip underneath.
	_box(Vector3(0.016, 0.05, 0.018), Vector3(0.0, 0.095, -0.07), yellow)
	_box(Vector3(0.016, 0.05, 0.018), Vector3(0.0, 0.095, 0.09), yellow)
	var bar := _tube(0.0115, 0.0115, 0.205, 0.01, rubber, true)
	bar.position.y = 0.121
	var grip := _box(Vector3(0.036, 0.12, 0.05), Vector3(0.0, -0.12, 0.06), rubber)
	grip.rotation.x = -0.26

	# Ribbed hose leaving the back of the housing and dropping out of view.
	var points := [Vector3(0.0, 0.0, 0.18), Vector3(0.0, 0.0, 0.4), Vector3(0.06, -0.3, 0.5), Vector3(0.12, -0.75, 0.36)]
	var ribs := 40
	for n in ribs:
		var t := (n + 0.5) / ribs
		var at := _bezier(points, t)
		var ahead := _bezier(points, t + 0.01) - at
		var rib := CylinderMesh.new()
		rib.top_radius = 0.047 if n % 2 == 0 else 0.039
		rib.bottom_radius = rib.top_radius
		rib.height = 0.021
		rib.radial_segments = 14
		rib.rings = 1
		var node := _part(rib, at, Vector3.ZERO, rubber)
		# A cylinder's axis is its local Y. Point it along the hose.
		node.quaternion = Quaternion(Vector3.UP, ahead.normalized())

	# Three status lamps along the top left of the housing, where the player can see them.
	var lamp_colors := [Color(0.2, 1.0, 0.35), Color(1.0, 0.62, 0.08), Color(1.0, 0.12, 0.08)]
	for n in 3:
		var socket := CylinderMesh.new()
		socket.top_radius = 0.011
		socket.bottom_radius = 0.011
		socket.height = 0.006
		socket.radial_segments = 12
		var at := Vector3(-0.034, 0.0665, -0.02 + n * 0.032)
		_part(socket, at, Vector3(0.0, 0.0, 0.47), rubber)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = lamp_colors[n]
		glow.emission_enabled = true
		glow.emission = lamp_colors[n]
		glow.emission_energy_multiplier = 3.0
		var bulb := SphereMesh.new()
		bulb.radius = 0.008
		bulb.height = 0.016
		bulb.radial_segments = 10
		bulb.rings = 5
		_lamps.append(_part(bulb, at + Vector3(-0.0015, 0.003, 0.0), Vector3.ZERO, glow))

	tip = Marker3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0.0, 0.0, -0.67)
	_model.add_child(tip)

	# Dust drawn into the nozzle while balls are arriving.
	var motes := ParticleProcessMaterial.new()
	motes.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 0.16
	motes.direction = Vector3(0.0, 0.0, 1.0)
	motes.spread = 12.0
	motes.initial_velocity_min = 1.6
	motes.initial_velocity_max = 2.6
	motes.gravity = Vector3.ZERO
	motes.radial_accel_min = -6.0
	motes.radial_accel_max = -3.0
	motes.scale_min = 0.5
	motes.scale_max = 1.2
	var fleck := QuadMesh.new()
	fleck.size = Vector2(0.006, 0.006)
	# A soft round speck: white in the middle, clear at the edge.
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var speck := GradientTexture2D.new()
	speck.gradient = fade
	speck.width = 32
	speck.height = 32
	speck.fill = GradientTexture2D.FILL_RADIAL
	speck.fill_from = Vector2(0.5, 0.5)
	speck.fill_to = Vector2(1.0, 0.5)
	var fleck_material := StandardMaterial3D.new()
	fleck_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fleck_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fleck_material.albedo_color = Color(0.9, 0.92, 0.95, 0.22)
	fleck_material.albedo_texture = speck
	fleck_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fleck.material = fleck_material
	_dust = GPUParticles3D.new()
	_dust.amount = 40
	_dust.lifetime = 0.2
	_dust.local_coords = true               # the dust belongs to the view model and turns with it
	_dust.process_material = motes
	_dust.draw_pass_1 = fleck
	_dust.position = Vector3(0.0, 0.0, -1.12)
	_dust.emitting = false
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(_dust)


# A round section along the model's length. `front_radius` faces away from the player.
func _tube(back_radius: float, front_radius: float, length: float, z: float, material: Material, rounded := false) -> MeshInstance3D:
	var mesh: PrimitiveMesh
	if rounded:
		var capsule := CapsuleMesh.new()
		capsule.radius = back_radius
		capsule.height = length
		capsule.radial_segments = 32
		capsule.rings = 8
		mesh = capsule
	else:
		var cylinder := CylinderMesh.new()
		cylinder.bottom_radius = back_radius
		cylinder.top_radius = front_radius
		cylinder.height = length
		cylinder.radial_segments = 32
		cylinder.rings = 1
		mesh = cylinder
	return _part(mesh, Vector3(0.0, 0.0, z), Vector3(-PI * 0.5, 0.0, 0.0), material)


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(mesh, at, Vector3.ZERO, material)


func _part(mesh: Mesh, at: Vector3, turn: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.rotation = turn
	# The model is a miniature next to the camera. Its shadow on the room would be the wrong size.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(node)
	return node


func _bezier(points: Array, t: float) -> Vector3:
	var a: Vector3 = points[0]
	var b: Vector3 = points[1]
	var c: Vector3 = points[2]
	var d: Vector3 = points[3]
	return a.bezier_interpolate(b, c, d, t)
