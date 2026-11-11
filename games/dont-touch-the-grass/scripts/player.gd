# First-person player: look, walk, sprint, jump.
# There is no health. A monster that catches the player on the grass kills at once (see systems/jumpscare.gd).
extends CharacterBody3D

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.0
const JUMP_VELOCITY := 7.0     # with GRAVITY 20 the jump peaks 1.22 m up and lasts 0.7 s
const GRAVITY := 20.0
const GROUND_ACCEL := 60.0
const GROUND_BRAKE := 70.0     # high, so the player stops on the spot instead of sliding off a platform
const AIR_ACCEL := 22.0
const COYOTE_TIME := 0.1       # jump still works this long after walking off an edge
const JUMP_BUFFER := 0.12      # a jump pressed this long before landing still counts
const MOUSE_SENS := 0.0022
const EYE_HEIGHT := 1.62
const BASE_FOV := 80.0
const SPRINT_FOV := 86.0

var require_mouse_capture := true
var locked := false            # true during a jumpscare or level change: no input, no physics
var sprinting := false
var yaw := 0.0
var pitch := 0.0
var cam: Camera3D
var _coyote := 0.0
var _buffer := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2 | 4     # world + safe platforms
	floor_snap_length = 0.15
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	cap.shape = shape
	cap.position.y = 0.9
	add_child(cap)
	cam = Camera3D.new()
	cam.fov = BASE_FOV
	cam.near = 0.05
	cam.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(cam)
	cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not _has_control():
		return
	if event is InputEventMouseMotion:
		# screen_relative is the raw mouse movement. `relative` is scaled with the window, which would make
		# the camera turn slower on a big monitor.
		var moved := (event as InputEventMouseMotion).screen_relative
		set_look(yaw - moved.x * MOUSE_SENS, pitch - moved.y * MOUSE_SENS)


func _process(delta: float) -> void:
	if locked:
		return
	var target := SPRINT_FOV if sprinting else BASE_FOV
	cam.fov = lerpf(cam.fov, target, minf(delta * 8.0, 1.0))


func _physics_process(delta: float) -> void:
	if locked:
		return
	var control := _has_control()
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		velocity.y -= GRAVITY * delta
	_buffer = maxf(_buffer - delta, 0.0)
	if control and Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0

	var input := Vector2.ZERO
	if control:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	sprinting = control and Input.is_action_pressed("sprint") and input.length() > 0.1
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var target := transform.basis * Vector3(input.x, 0.0, input.y) * speed
	var rate := AIR_ACCEL
	if is_on_floor():
		rate = GROUND_ACCEL if input.length() > 0.01 else GROUND_BRAKE
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()


func set_look(new_yaw: float, new_pitch: float) -> void:
	yaw = new_yaw
	pitch = clampf(new_pitch, -1.35, 1.35)
	rotation.y = yaw
	cam.rotation.x = pitch


# Put the player somewhere and stop all motion. `at` is where the feet go.
func teleport(at: Vector3, facing_yaw: float) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_coyote = 0.0
	_buffer = 0.0
	set_look(facing_yaw, 0.0)


func lock() -> void:
	locked = true
	sprinting = false
	velocity = Vector3.ZERO


func unlock() -> void:
	locked = false
	cam.fov = BASE_FOV


func _has_control() -> bool:
	if locked:
		return false
	return not require_mouse_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
