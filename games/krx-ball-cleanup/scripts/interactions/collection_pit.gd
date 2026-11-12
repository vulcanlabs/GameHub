class_name CollectionPit
extends Node3D
## The only place in the game where the vacuum can be emptied: a tiled pit sunk into the floor of Level 1.
##
## Stand within `reach` of the kerb and hold the `unload` action (E). Balls leave the tank at `unload_rate`
## a second and are counted as deposited at once.
##
## WHAT THE BALLS IN THE PIT SHOW: the pit is a gauge, not a container. 250,000 real 17 cm balls need about
## 1,000 cubic metres and the pit holds 96. So the surface of balls rises in proportion to how much of the
## whole run has been deposited, and reaches the rim when every ball in the run is in the pit. The first
## few thousand deposits appear one by one on the pit floor. The deposited count on the HUD is the exact figure.

const KERB_WIDTH := 0.3
const KERB_HEIGHT := 0.2
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


## 0 when nothing has been deposited, 1 when every ball in the run is in the pit.
func fill_fraction() -> float:
	return float(GameState.deposited) / maxf(GameState.balls_in_run(), 1.0)


## World height of the top of the balls in the pit.
func surface_height() -> float:
	return _fill.global_position.y + BallManager.BALL_RADIUS + BallManager.LAYER_HEIGHT


func _physics_process(delta: float) -> void:
	unloading = false
	var held := can_unload() and _player != null and _player.has_control() and Input.is_action_pressed("unload")
	if held:
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
	var half := size * 0.5 - Vector2(0.3, 0.3)
	var local := to_local(from)
	var near := Vector2(clampf(local.x, -half.x, half.x), clampf(local.z, -half.y, half.y))
	for n in POUR_PER_TICK:
		var spread := Vector2(_rng.randfn(0.0, 0.7), _rng.randfn(0.0, 0.7))
		var land := Vector2(clampf(near.x + spread.x, -half.x, half.x), clampf(near.y + spread.y, -half.y, half.y))
		var jitter := Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5) * 0.12
		var color: Color = BallManager.PALETTE[_rng.randi() % BallManager.PALETTE.size()]
		flyers.add_poured(from + jitter, to_global(Vector3(land.x, 0.0, land.y)) + Vector3(0.0, surface_height() - global_position.y, 0.0), color)


func _update_fill() -> void:
	var deposited := GameState.deposited
	var floor_y := -depth + BallManager.BALL_RADIUS
	if deposited <= _shell_balls:
		_fill.multimesh.visible_instance_count = deposited
		_fill.position.y = floor_y
		return
	_fill.multimesh.visible_instance_count = _shell_balls
	var beyond := float(deposited - _shell_balls) / maxf(GameState.balls_in_run() - _shell_balls, 1.0)
	var top := -RIM_GAP - BallManager.BALL_RADIUS - BallManager.LAYER_HEIGHT
	_fill.position.y = lerpf(floor_y, top, clampf(beyond, 0.0, 1.0))


# ---------------------------------------------------------------- construction

func _build() -> void:
	var pad := _pit_plastic(Color(0.86, 0.22, 0.28))
	var well := _pit_plastic(Color(0.55, 0.14, 0.18))
	var half := size * 0.5
	# Lining. Each wall stands 1 cm into the opening so it covers the cut edge of the floor slab.
	var lip := 0.01
	for side: float in [-1.0, 1.0]:
		LevelKit.box(self, Vector3(size.x + WALL_THICKNESS * 2.0, depth, WALL_THICKNESS + lip),
			Vector3(0.0, -depth * 0.5, side * (half.y + (WALL_THICKNESS - lip) * 0.5)), well, false)
		LevelKit.box(self, Vector3(WALL_THICKNESS + lip, depth, size.y),
			Vector3(side * (half.x + (WALL_THICKNESS - lip) * 0.5), -depth * 0.5, 0.0), well, false)
	LevelKit.box(self, Vector3(size.x + WALL_THICKNESS * 2.0, 0.2, size.y + WALL_THICKNESS * 2.0), Vector3(0.0, -depth - 0.1, 0.0), well, false)

	# Soft foam kerb around the opening.
	for side: float in [-1.0, 1.0]:
		LevelKit.box(self, Vector3(size.x + KERB_WIDTH * 2.0, KERB_HEIGHT, KERB_WIDTH),
			Vector3(0.0, KERB_HEIGHT * 0.5, side * (half.y + KERB_WIDTH * 0.5)), pad)
		LevelKit.box(self, Vector3(KERB_WIDTH, KERB_HEIGHT, size.y),
			Vector3(side * (half.x + KERB_WIDTH * 0.5), KERB_HEIGHT * 0.5, 0.0), pad)

	# The player cannot climb out of a 2 m pit, so an unseen barrier fills the opening up to above jump height.
	var barrier_top := 3.2
	LevelKit.collider(self, Vector3(size.x, depth + barrier_top, size.y), Vector3(0.0, (barrier_top - depth) * 0.5, 0.0))

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
func _build_fill() -> void:
	_rng.seed = 77
	var spacing := BallManager.SPACING
	var row := BallManager.ROW
	var margin := BallManager.BALL_RADIUS + 0.02
	var columns := int((size.x - margin * 2.0) / spacing) - 1
	var rows := int((size.y - margin * 2.0) / row) - 1
	var order: Array[Vector3] = []
	for layer in 2:
		var first := order.size()
		for j in rows:
			for i in columns:
				var x := -size.x * 0.5 + margin + (i + 0.5 + 0.5 * (j & 1) + 0.5 * layer) * spacing
				var z := -size.y * 0.5 + margin + (j + 0.5) * row + layer * spacing * 0.2886751
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
		multimesh.set_instance_color(n, color.darkened(_rng.randf() * 0.08))
	multimesh.visible_instance_count = 0
	_fill = MultiMeshInstance3D.new()
	_fill.multimesh = multimesh
	_fill.layers = 2                        # render layer "Balls"
	add_child(_fill)


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
