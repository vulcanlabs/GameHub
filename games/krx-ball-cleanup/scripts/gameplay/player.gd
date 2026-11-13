class_name Player
extends CharacterBody3D
## First-person player: look, walk, sprint, jump, footsteps. Carries the vacuum on its camera.
##
## Field of view, mouse sensitivity, head bobbing and camera shake come from Settings and change at once.

## Tuning. Speeds in m/s, accelerations in m/s².
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var ground_acceleration := 42.0
@export var ground_braking := 36.0
@export var air_acceleration := 9.0

const EYE_HEIGHT := 1.65
const LOOK_PER_PIXEL := 0.005               # radians per pixel of mouse travel at sensitivity 1.0
const SPRINT_FOV_BOOST := 4.0
const STEP_LENGTH := 2.3                    # metres walked between two footsteps

## False in the automatic test, which has no mouse to capture.
var require_mouse_capture := true
var yaw := 0.0
var pitch := 0.0
var sprinting := false
var steps_played := 0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var vacuum: Vacuum = $Head/Camera/Vacuum

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _fov := 90.0
var _sensitivity := 0.5
var _head_bob := true
## Where a fall sends the player back. Set when a level is entered. Not a new run.
var checkpoint_position := Vector3(0.0, 0.05, 11.0)
var checkpoint_yaw := 0.0
var _camera_shake := true
var _bob_time := 0.0
var _step_distance := 0.0
var _slide_path: Path3D
var _slide_along := 0.0
var _slide_speed := 0.0


func _ready() -> void:
	add_to_group("player")
	vacuum.camera = camera
	Settings.changed.connect(_on_setting_changed)
	_read_settings()
	camera.fov = _fov


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and has_control():
		# screen_relative is raw mouse travel. `relative` is scaled with the window and would turn slower on a big monitor.
		var moved := (event as InputEventMouseMotion).screen_relative
		var per_pixel := LOOK_PER_PIXEL * _sensitivity
		set_look(yaw - moved.x * per_pixel, pitch - moved.y * per_pixel)


func _physics_process(delta: float) -> void:
	if _slide_path != null:
		vacuum.enabled = false
		_ride_slide(delta)
		return
	var control := has_control()
	vacuum.enabled = control
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif control and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Vector2.ZERO
	if control:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	sprinting = control and Input.is_action_pressed("sprint") and input.length() > 0.1
	var wanted := transform.basis * Vector3(input.x, 0.0, input.y) * (sprint_speed if sprinting else walk_speed)
	var rate := air_acceleration
	if is_on_floor():
		rate = ground_acceleration if input.length() > 0.01 else ground_braking
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wanted, rate * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()

	var speed := Vector2(velocity.x, velocity.z).length()
	vacuum.carrier_speed = speed if is_on_floor() else 0.0
	_footsteps(speed, delta)


func _process(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	camera.fov = lerpf(camera.fov, _fov + (SPRINT_FOV_BOOST if sprinting else 0.0), minf(delta * 8.0, 1.0))

	var bob := Vector3.ZERO
	if _head_bob and is_on_floor() and speed > 0.5:
		_bob_time += delta * speed * 1.35
		bob = Vector3(cos(_bob_time * 0.5) * 0.012, sin(_bob_time) * 0.018, 0.0)
	camera.position = camera.position.lerp(bob, minf(delta * 12.0, 1.0))

	var shake := Vector3.ZERO
	if _camera_shake and vacuum.sucking:
		shake = Vector3(randf() - 0.5, randf() - 0.5, 0.0) * 0.004
	camera.rotation = shake


func has_control() -> bool:
	if get_tree().paused:
		return false
	return not require_mouse_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func set_look(new_yaw: float, new_pitch: float) -> void:
	yaw = new_yaw
	pitch = clampf(new_pitch, -1.45, 1.45)
	rotation.y = yaw
	head.rotation.x = pitch


## Puts the player somewhere and stops all motion. `at` is where the feet go.
func teleport(at: Vector3, facing_yaw: float) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_step_distance = 0.0
	set_look(facing_yaw, 0.0)


func remember_checkpoint(at: Vector3, facing_yaw: float) -> void:
	checkpoint_position = at
	checkpoint_yaw = facing_yaw


## Puts the player back on their feet. Balls, the vacuum, and unlocked doors stay as they are.
func respawn() -> void:
	_slide_path = null
	teleport(checkpoint_position, checkpoint_yaw)


## Ride starts when the player walks into a slide mouth. They can climb back up and do it again.
func start_slide(path: Path3D) -> void:
	if _slide_path != null or path == null or path.curve == null:
		return
	_slide_path = path
	_slide_along = 0.0
	_slide_speed = 2.4


func _ride_slide(delta: float) -> void:
	var curve := _slide_path.curve
	var length := curve.get_baked_length()
	_slide_speed = minf(_slide_speed + 8.0 * delta, 13.0)
	_slide_along += _slide_speed * delta
	if _slide_along >= length - 0.05:
		global_position = _slide_path.to_global(curve.sample_baked(length))
		velocity = Vector3.ZERO
		_slide_path = null
		Sfx.play("water_splash", "Environment", -8.0, randf_range(0.92, 1.08))
		var pool := get_parent().find_child("Pool", true, false)
		if pool != null and pool.has_method("splash"):
			pool.splash(global_position)
		return
	var local_at := curve.sample_baked(_slide_along)
	var ahead := curve.sample_baked(minf(_slide_along + 0.45, length))
	global_position = _slide_path.to_global(local_at)
	var flat := Vector2(ahead.x - local_at.x, ahead.z - local_at.z)
	if flat.length() > 0.02:
		set_look(atan2(-flat.x, -flat.y), 0.15)
	velocity = Vector3.ZERO


# One step every STEP_LENGTH metres on the ground, so sprinting steps faster. Nothing in the air.
func _footsteps(speed: float, delta: float) -> void:
	if not is_on_floor() or speed < 0.6:
		_step_distance = STEP_LENGTH * 0.6
		return
	_step_distance += speed * delta
	if _step_distance < STEP_LENGTH:
		return
	_step_distance = 0.0
	Sfx.play("step_" + _surface(), "Footsteps", -6.0, randf_range(0.88, 1.12))
	steps_played += 1


# What the player is standing on. Every floor in Level 1 is tile.
# Carpet, grass, concrete and metal are added here with the levels that have them.
func _surface() -> String:
	return "tile"


func _read_settings() -> void:
	_fov = Settings.get_value("camera", "fov")
	_sensitivity = Settings.get_value("camera", "mouse_sensitivity")
	_head_bob = Settings.get_value("camera", "head_bob")
	_camera_shake = Settings.get_value("camera", "camera_shake")


func _on_setting_changed(section: String, _key: String) -> void:
	if section == "camera":
		_read_settings()
