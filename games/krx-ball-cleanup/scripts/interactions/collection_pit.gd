class_name CollectionPit
extends Node3D
## The only place in the game where the vacuum can be emptied: a tiled pit sunk into the floor of Level 1.
##
## Stand within `reach` of the kerb and press `unload` (E). The vacuum keeps pouring until it is empty.
##
## WHAT THE BALLS IN THE PIT SHOW: the pit is a gauge, not a container. 250,000 real 17 cm balls need about
## 1,000 cubic metres and the pit holds 96. So the surface of balls rises in proportion to how much of the
## whole run has been deposited, and reaches the rim when every ball in the run is in the pit. The first
## few thousand deposits appear one by one on the pit floor. The deposited count on the HUD is the exact figure.

const KERB_WIDTH := 0.55
const KERB_HEIGHT := 0.92
const WALL_THICKNESS := 0.2
const RIM_GAP := 0.15                       # how far below the floor a full pit's surface stops (m)
const POUR_PER_TICK := 4                    # balls drawn in the pouring stream per physics tick

## Opening of the pit: x by z, in metres.
@export var size := Vector2(8.0, 6.0)
@export var depth := 2.0
## Balls leaving the vacuum per second while unloading. 8,000 empties a full 50,000 tank in about 6 seconds.
@export var unload_rate := 8000.0
## How far from the kerb the player can stand and still unload (m).
@export var reach := 2.6

## Draws the stream of balls. Set by the main scene.
var flyers: BallFlyers
var player_in_range := false
var unloading := false

var _player: Player
var _fill: MultiMeshInstance3D
var _shell_balls := 0                       # balls in the drawn surface: two layers across the whole pit
var _pour: AudioStreamPlayer3D
var _carry := 0.0
var _rng := RandomNumberGenerator.new()
var _pouring := false


func _ready() -> void:
	_build()
	_build_fill()
	_pour = AudioStreamPlayer3D.new()
	_pour.stream = Sfx.stream("ball_pour")
	_pour.bus = "Balls"
	_pour.unit_size = 9.0
	_pour.position = Vector3(0.0, -depth * 0.5, 0.0)
	add_child(_pour)
	GameState.counts_changed.connect(_update_fill)
	_update_fill()


## True when holding E would do something: the player is close enough and the tank is not empty.
func can_unload() -> bool:
	return player_in_range and GameState.vacuum_stored > 0


## True when the crosshair is aimed down into the hole, not merely standing nearby.
func looking_at() -> bool:
	if _player == null or _player.camera == null:
		return false
	var origin: Vector3 = _player.camera.global_position
	var direction: Vector3 = -_player.camera.global_transform.basis.z
	if direction.y >= -0.12:
		return false
	var t := (global_position.y - origin.y) / direction.y
	if t < 0.3 or t > 10.0:
		return false
	var hit := origin + direction * t
	var hole := minf(size.x, size.y) * 0.38
	var offset := Vector2(hit.x - global_position.x, hit.z - global_position.z)
	return offset.length() < hole


## 0 when nothing has been deposited, 1 when every ball in the run is in the pit.
func fill_fraction() -> float:
	return float(GameState.deposited) / maxf(GameState.balls_in_run(), 1.0)


## World height of the top of the balls in the pit.
func surface_height() -> float:
	return _fill.global_position.y + BallManager.BALL_RADIUS + BallManager.LAYER_HEIGHT


func _physics_process(delta: float) -> void:
	_fall_back_to_start()
	unloading = false
	var ready := can_unload() and _player != null and _player.has_control()
	if ready and Input.is_action_just_pressed("unload"):
		_pouring = true
	if GameState.vacuum_stored <= 0 or not player_in_range:
		_pouring = false
	if _pouring and ready:
		_carry += unload_rate * delta
		var batch := int(_carry)
		_carry -= batch
		unloading = GameState.deposit(batch) > 0
		if unloading and flyers != null:
			_draw_stream()
	else:
		_carry = 0.0
	if unloading and not _pour.playing:
		_pour.play()
	elif not unloading and _pour.playing:
		_pour.stop()


# A few balls arcing from the nozzle to the part of the pit nearest the player.
func _draw_stream() -> void:
	var from := _player.vacuum.suction_point()
	var hole := minf(size.x, size.y) * 0.28
	var local := to_local(from)
	var near := Vector2(local.x, local.z)
	if near.length() > hole:
		near = near.normalized() * hole
	for n in POUR_PER_TICK:
		var spread := Vector2(_rng.randfn(0.0, 0.35), _rng.randfn(0.0, 0.35))
		var land := near + spread
		if land.length() > hole:
			land = land.normalized() * hole
		var jitter := Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5) * 0.12
		var color: Color = BallManager.PALETTE[_rng.randi() % BallManager.PALETTE.size()]
		flyers.add_poured(from + jitter, to_global(Vector3(land.x, 0.0, land.y)) + Vector3(0.0, surface_height() - global_position.y, 0.0), color)


func _update_fill() -> void:
	var deposited := GameState.deposited
	# The blue mat is at floor level. A full pit stops just under the top course of foam.
	var floor_y := -1.7
	var top := -0.25
	if deposited <= _shell_balls:
		_fill.multimesh.visible_instance_count = deposited
		_fill.position.y = floor_y
		return
	_fill.multimesh.visible_instance_count = _shell_balls
	var beyond := float(deposited - _shell_balls) / maxf(GameState.balls_in_run() - _shell_balls, 1.0)
	_fill.position.y = lerpf(floor_y, top, clampf(beyond, 0.0, 1.0))


# ---------------------------------------------------------------- construction

func _build() -> void:
	var radius := minf(size.x, size.y) * 0.38
	var shaft := CylinderMesh.new()
	shaft.top_radius = radius * 0.98
	shaft.bottom_radius = radius * 0.72
	shaft.height = 14.0
	shaft.radial_segments = 48
	var darkness := StandardMaterial3D.new()
	darkness.albedo_color = Color(0.0, 0.0, 0.0)
	darkness.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	darkness.cull_mode = BaseMaterial3D.CULL_DISABLED
	var void_mesh := MeshInstance3D.new()
	void_mesh.mesh = shaft
	void_mesh.material_override = darkness
	void_mesh.position = Vector3(0.0, -7.0, 0.0)
	void_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(void_mesh)
	var lip := TorusMesh.new()
	lip.inner_radius = radius - 0.22
	lip.outer_radius = radius + 0.28
	lip.rings = 16
	lip.ring_segments = 40
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.05, 0.05, 0.06)
	rim_mat.roughness = 0.35
	var rim := MeshInstance3D.new()
	rim.mesh = lip
	rim.material_override = rim_mat
	rim.position = Vector3(0.0, 0.06, 0.0)
	add_child(rim)
	# A low ring. Walking stops at the lip. A jump clears it and drops into the hole.
	var segments := 24
	for n in segments:
		var angle := TAU * float(n) / float(segments)
		var at := Vector3(cos(angle), 0.22, sin(angle)) * radius
		var block := LevelKit.collider(self, Vector3(0.5, 0.44, 0.95), at)
		block.rotation.y = angle

	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 1                 # physics layer "Player"
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x + (KERB_WIDTH + reach) * 2.0, 3.0, size.y + (KERB_WIDTH + reach) * 2.0)
	var hit := CollisionShape3D.new()
	hit.shape = shape
	hit.position.y = 1.5
	zone.add_child(hit)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	add_child(zone)


# The surface of the deposited balls: two close-packed layers across the pit, slightly uneven.
# The draw order is shuffled, bottom layer first, so the first deposits appear scattered over the pit floor.
func _fall_back_to_start() -> void:
	if _player == null or _player.global_position.y > -0.9:
		return
	var flat := _player.global_position - global_position
	flat.y = 0.0
	if flat.length() > minf(size.x, size.y) * 0.55:
		return
	_player.respawn()


func _build_fill() -> void:
	_rng.seed = 77
	var spacing := BallManager.SPACING
	var row := BallManager.ROW
	var margin := BallManager.BALL_RADIUS + 0.02
	var hole := minf(size.x, size.y) * 0.32
	var columns := int((hole * 2.0 - margin * 2.0) / spacing) - 1
	var rows := int((hole * 2.0 - margin * 2.0) / row) - 1
	var order: Array[Vector3] = []
	for layer in 2:
		var first := order.size()
		for j in rows:
			for i in columns:
				var x := -hole + margin + (i + 0.5 + 0.5 * (j & 1) + 0.5 * layer) * spacing
				var z := -hole + margin + (j + 0.5) * row + layer * spacing * 0.2886751
				if Vector2(x, z).length() > hole - margin:
					continue
				var swell := 0.035 * sin(x * 1.9 + 0.6) * cos(z * 2.3) + 0.02 * sin(x * 5.1 + z * 4.3)
				var jitter := Vector3(_rng.randf() - 0.5, 0.0, _rng.randf() - 0.5) * BallManager.JITTER
				order.append(Vector3(x, layer * BallManager.LAYER_HEIGHT + swell, z) + jitter)
		# Shuffle this layer only, so the whole bottom layer is still drawn before any of the top one.
		for n in range(order.size() - 1, first, -1):
			var other := _rng.randi_range(first, n)
			var held := order[n]
			order[n] = order[other]
			order[other] = held
	_shell_balls = order.size()

	var mesh := SphereMesh.new()
	mesh.radius = BallManager.BALL_RADIUS
	mesh.height = BallManager.BALL_RADIUS * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = preload("res://assets/materials/ball_plastic.tres")
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = _shell_balls
	for n in _shell_balls:
		multimesh.set_instance_transform(n, Transform3D(Basis.IDENTITY, order[n]))
		var color: Color = BallManager.PALETTE[_rng.randi() % BallManager.PALETTE.size()]
		multimesh.set_instance_color(n, color.lightened(_rng.randf() * 0.04))
	multimesh.visible_instance_count = 0
	_fill = MultiMeshInstance3D.new()
	_fill.multimesh = multimesh
	_fill.layers = 2                        # render layer "Balls"
	add_child(_fill)


## Raised pit from the photo: blue vinyl rim, green and brown padded base, steps on the east side.
func _padded_pit(half: Vector2) -> void:
	var blue := _vinyl(Color(0.08, 0.28, 0.82))
	var green := _pad(Color(0.55, 0.72, 0.28))
	var brown := _pad(Color(0.28, 0.16, 0.1))
	var thick := KERB_WIDTH
	var height := KERB_HEIGHT
	var skirt := height * 0.52
	var rim := height - skirt
	# North and south walls own the corners.
	_band(Vector3(size.x + thick * 2.0, skirt, thick), Vector3(0.0, skirt * 0.5, -(half.y + thick * 0.5)), green)
	_band(Vector3(size.x + thick * 2.0, skirt, thick), Vector3(0.0, skirt * 0.5, half.y + thick * 0.5), green)
	_band(Vector3(thick, skirt, size.y), Vector3(-(half.x + thick * 0.5), skirt * 0.5, 0.0), green)
	_band(Vector3(thick, skirt, size.y), Vector3(half.x + thick * 0.5, skirt * 0.5, 0.0), brown)
	var rim_y := skirt + rim * 0.45
	_band(Vector3(size.x + thick * 2.0, rim, thick), Vector3(0.0, rim_y, -(half.y + thick * 0.5)), blue)
	_band(Vector3(size.x + thick * 2.0, rim, thick), Vector3(0.0, rim_y, half.y + thick * 0.5), blue)
	_band(Vector3(thick, rim, size.y), Vector3(-(half.x + thick * 0.5), rim_y, 0.0), blue)
	_band(Vector3(thick, rim, size.y), Vector3(half.x + thick * 0.5, rim_y, 0.0), blue)
	_puffy_rim(half, skirt + rim * 0.72, thick, blue)
	# Two brown steps along the east side.
	var step_x := half.x + thick + 0.55
	_band(Vector3(1.15, skirt * 0.55, size.y + thick * 2.0), Vector3(step_x, skirt * 0.28, 0.0), brown)
	_band(Vector3(0.62, skirt, size.y + 0.4), Vector3(half.x + thick + 0.28, skirt * 0.5, 0.0), brown)
	var liner := 0.04
	_band(Vector3(size.x, height - 0.08, liner), Vector3(0.0, height * 0.5, -(half.y - liner)), blue)
	_band(Vector3(size.x, height - 0.08, liner), Vector3(0.0, height * 0.5, half.y - liner), blue)
	_band(Vector3(liner, height - 0.08, size.y - liner * 2.0), Vector3(-(half.x - liner), height * 0.5, 0.0), blue)
	_band(Vector3(liner, height - 0.08, size.y - liner * 2.0), Vector3(half.x - liner, height * 0.5, 0.0), blue)


func _band(block: Vector3, at: Vector3, material: Material) -> void:
	LevelKit.box(self, block, at, material)


## Rounded vinyl bolsters along the top edge so the rim reads as stuffed padding.
func _puffy_rim(half: Vector2, y: float, thick: float, material: Material) -> void:
	var radius := thick * 0.55
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.2
	mesh.radial_segments = 14
	mesh.rings = 8
	_bolsters(mesh, material, -size.x * 0.5 - thick, size.x * 0.5 + thick, true, -(half.y + thick * 0.5), y)
	_bolsters(mesh, material, -size.x * 0.5 - thick, size.x * 0.5 + thick, true, half.y + thick * 0.5, y)
	_bolsters(mesh, material, -size.y * 0.5, size.y * 0.5, false, -(half.x + thick * 0.5), y)
	_bolsters(mesh, material, -size.y * 0.5, size.y * 0.5, false, half.x + thick * 0.5, y)


func _bolsters(mesh: SphereMesh, material: Material, start: float, end_at: float, along_x: bool, fixed: float, y: float) -> void:
	var step := mesh.radius * 1.35
	var cursor := start
	while cursor <= end_at:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		node.scale = Vector3(1.15, 0.72, 1.05)
		node.position = Vector3(cursor, y, fixed) if along_x else Vector3(fixed, y, cursor)
		add_child(node)
		cursor += step


func _vinyl(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.18
	material.metallic = 0.04
	material.clearcoat_enabled = true
	material.clearcoat = 0.65
	material.clearcoat_roughness = 0.2
	return material


func _pad(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.42
	material.metallic = 0.0
	material.clearcoat_enabled = true
	material.clearcoat = 0.35
	material.clearcoat_roughness = 0.35
	return material


func _pit_plastic(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_Color.jpg")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_NormalGL.jpg")
	material.roughness_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_Roughness.jpg")
	material.uv1_scale = Vector3(1.6, 1.6, 1.6)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	return material


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		player_in_range = false
