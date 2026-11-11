extends CharacterBody3D

signal fell

const SPEED := 7.0
const JUMP := 8.2
const GRAVITY := 22.0
const MOUSE_SENS := 0.0025

var active := false
var can_look := true
var yaw := 0.0
var pitch := 0.0
var cam: Camera3D
var _jump_held := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	floor_snap_length = 0.25
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.5
	cap.shape = shape
	cap.position.y = 0.85
	add_child(cap)
	cam = Camera3D.new()
	cam.fov = 80
	cam.position = Vector3(0, 1.45, 0)
	add_child(cam)
	cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not can_look:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * MOUSE_SENS
		pitch = clampf(pitch - motion.relative.y * MOUSE_SENS, -1.15, 1.15)
		rotation.y = yaw
		cam.rotation.x = pitch


func face_toward(target: Vector3) -> void:
	var flat := target - global_position
	flat.y = 0.0
	if flat.length() < 0.05:
		return
	yaw = atan2(-flat.x, -flat.z)
	rotation.y = yaw
	pitch = 0.0
	cam.rotation.x = 0.0


func _physics_process(delta: float) -> void:
	if not active:
		return
	var allow := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var jump := false
	if allow:
		var space := Input.is_key_pressed(KEY_SPACE)
		jump = space and not _jump_held and is_on_floor()
		_jump_held = space
	else:
		_jump_held = false
	if is_on_floor():
		if jump:
			velocity.y = JUMP
		elif velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	var wish := Vector3.ZERO
	if allow:
		var forward := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		var strafe := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		wish -= transform.basis.z * forward
		wish += transform.basis.x * strafe
	if wish.length() > 0.01:
		wish = wish.normalized() * SPEED
		velocity.x = wish.x
		velocity.z = wish.z
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)
	move_and_slide()
	# Feet sit about 0.1 above the body origin. The lava plane is at y = -2.2.
	if global_position.y <= -2.3:
		fell.emit()
