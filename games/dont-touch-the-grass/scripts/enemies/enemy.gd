# Base for every monster: three states, path-finding on the grass, and the catch test.
# A monster kind (ant.gd, later spider.gd) extends this, sets the numbers in _init(), and supplies the body and its animation.
#
#   ROAMING    wanders. Harmless.
#   CHASING    the player touched the grass. Runs at the player and kills on contact.
#   SEARCHING  the player got onto a platform. Keeps following from below. Cannot attack.
#
# This script never decides when to change state. chase_manager.gd does, so one timer rules every monster.
extends CharacterBody3D

signal caught_player(enemy: CharacterBody3D)
signal state_changed(enemy: CharacterBody3D, new_state: State)

enum State { ROAMING, CHASING, SEARCHING }

const SoundBank = preload("res://scripts/systems/sound_bank.gd")

# --- Numbers a monster kind may change in _init() ---
var kind := "enemy"
var roam_speed := 1.5
var chase_speed := 6.0          # player walks 4.5, sprints 7.0
var detect_radius := 30.0       # "nearby": how far away it notices a player on the grass
var catch_radius := 1.1         # how close its head or body must get
var reach_height := 0.9         # it cannot grab feet higher than this above the floor
var head_distance := 1.0        # body centre to head, along its forward direction
var mouth_offset := Vector3(0.0, 0.45, -1.3)   # the point that ends up in front of the camera in a jumpscare
var jumpscare_distance := 0.45
var body_height := 0.75
var body_radius := 0.35

var state: State = State.ROAMING
var frozen := false             # true during a jumpscare: no thinking, no moving
var player: CharacterBody3D
var chase: Node
var home := Vector3.ZERO
var nav: NavigationAgent3D
var _speed := 0.0
var _repath := 0.0
var _roam_wait := 0.0
var _roam_time := 0.0
var _voice: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8        # Enemies
	collision_mask = 2         # World only: it passes under platforms and does not push the player
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = body_radius
	shape.shape = sphere
	shape.position.y = body_radius
	add_child(shape)

	nav = NavigationAgent3D.new()
	nav.path_desired_distance = 0.6
	nav.target_desired_distance = 0.4
	nav.radius = 0.5
	nav.height = body_height
	add_child(nav)

	_voice = AudioStreamPlayer3D.new()
	_voice.stream = SoundBank.chitter()
	_voice.unit_size = 4.0
	_voice.max_distance = 45.0
	_voice.position.y = 0.5
	add_child(_voice)
	_voice.play()

	_build_model()


func setup(p_player: CharacterBody3D, p_chase: Node, p_home: Vector3) -> void:
	player = p_player
	chase = p_chase
	home = p_home
	global_position = home
	rotation.y = randf() * TAU


func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_repath = 0.0
	if state == State.ROAMING:
		_pick_roam_target()
	state_changed.emit(self, state)


func can_detect(target: Vector3) -> bool:
	return _flat_distance(global_position, target) <= detect_radius


# Back to where it started, calm. Called after the player dies or the level restarts.
func reset_to_home() -> void:
	end_attack()
	frozen = false
	velocity = Vector3.ZERO
	global_transform = Transform3D(Basis.IDENTITY, home)
	_speed = 0.0
	state = State.ROAMING
	_roam_wait = 1.0
	state_changed.emit(self, state)


func scare_stream() -> AudioStream:
	return SoundBank.screech()


# World position of the face. The jumpscare puts this point in front of the camera.
func mouth_position() -> Vector3:
	return global_transform * mouth_offset


func _physics_process(delta: float) -> void:
	if frozen or player == null:
		return
	# The navigation map needs one physics frame after the level is built before it answers.
	if NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) == 0:
		return
	match state:
		State.ROAMING:
			_roam(delta)
		State.CHASING, State.SEARCHING:
			_pursue(delta)
	_move(delta)
	if state == State.CHASING and chase.player_in_danger and _can_reach_player():
		frozen = true
		velocity = Vector3.ZERO
		caught_player.emit(self)


func _process(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	var excited := state != State.ROAMING
	_voice.pitch_scale = lerpf(_voice.pitch_scale, 1.35 if excited else 0.8, minf(delta * 4.0, 1.0))
	_voice.volume_db = lerpf(_voice.volume_db, -4.0 if excited else -20.0, minf(delta * 4.0, 1.0))
	_animate(delta, moving)


func _roam(delta: float) -> void:
	_roam_time += delta
	if _roam_wait > 0.0:
		_roam_wait -= delta
		_speed = 0.0
		if _roam_wait <= 0.0:
			_pick_roam_target()
		return
	_speed = roam_speed
	# Arrived, or took far too long (blocked): stand a moment, then pick somewhere else.
	if nav.is_navigation_finished() or _roam_time > 25.0:
		_roam_wait = randf_range(0.6, 2.5)


func _pick_roam_target() -> void:
	_roam_time = 0.0
	_roam_wait = 0.0
	nav.target_position = NavigationServer3D.map_get_random_point(nav.get_navigation_map(), 1, false)


# Chasing and searching move the same way: go to the spot on the grass right under the player.
func _pursue(delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.15
		nav.target_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
	_speed = chase_speed


func _move(delta: float) -> void:
	var direction := Vector3.ZERO
	if _speed > 0.0 and not nav.is_navigation_finished():
		direction = nav.get_next_path_position() - global_position
		direction.y = 0.0
		direction = direction.normalized() if direction.length() > 0.01 else Vector3.ZERO
	velocity = velocity.move_toward(direction * _speed, 20.0 * delta)
	velocity.y = 0.0
	var face := velocity
	if face.length() < 0.3 and state != State.ROAMING:
		# Standing under the player: turn to stare at them.
		face = player.global_position - global_position
		face.y = 0.0
	if face.length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), minf(delta * 7.0, 1.0))
	move_and_slide()
	global_position.y = 0.0


func _can_reach_player() -> bool:
	var target := player.global_position
	if target.y > reach_height:
		return false
	var head := global_position - global_basis.z * head_distance
	return _flat_distance(head, target) <= catch_radius or _flat_distance(global_position, target) <= catch_radius


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- For the monster kind to fill in ---

func _build_model() -> void:
	pass


# Called every frame. `moving` is the speed over the ground in m/s.
func _animate(_delta: float, _moving: float) -> void:
	pass


# Jumpscare steps: rear up, then bite, then back to normal.
func begin_attack() -> void:
	pass


func bite() -> void:
	pass


func end_attack() -> void:
	pass
