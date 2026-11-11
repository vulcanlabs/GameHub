# The death scene. Works for any monster built on enemy.gd, so the spider can reuse it with its own body.
#
#   1. The player loses control and the camera is wrenched round to face the monster.
#   2. The monster rears and lunges, and the lens punches in, until its face fills the screen.
#   3. It bites: jaws thrash, the camera shakes, the screen flashes red.
#   4. Cut to black. main.gd then puts the player back at the start of the level.
#
# The lunge moves the real monster in the world; it is not a picture pasted on the screen.
extends Node

const SoundBank = preload("res://scripts/systems/sound_bank.gd")

const TURN_TIME := 0.16
const LUNGE_TIME := 0.20
const BITE_TIME := 0.80
const BLACK_TIME := 0.55
const PUNCH_IN := 32.0   # degrees the lens narrows during the lunge

var running := false
var _sound: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.stream = SoundBank.screech()
	add_child(_sound)


# Await this. It returns when the screen is black and the monster is done.
func play(player: CharacterBody3D, enemy: CharacterBody3D, hud: CanvasLayer) -> void:
	if running:
		return
	running = true
	player.lock()
	enemy.begin_attack()
	_sound.play()
	var cam: Camera3D = player.cam
	var base_fov := cam.fov
	# A small light on the camera, so the face is readable even in an unlit corner.
	var key_light := OmniLight3D.new()
	key_light.light_color = Color(1.0, 0.82, 0.66)
	key_light.light_energy = 1.6
	key_light.omni_range = 3.5
	key_light.position = Vector3(0.0, 0.15, 0.1)
	cam.add_child(key_light)

	var to: Vector3 = enemy.mouth_position() - cam.global_position
	var yaw_from: float = player.yaw
	var pitch_from: float = player.pitch
	var yaw_to := atan2(-to.x, -to.z)
	var pitch_to := clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.6, -0.2)
	var t := 0.0
	while t < 1.0:
		await get_tree().process_frame
		t = minf(t + get_process_delta_time() / TURN_TIME, 1.0)
		var ease_out := 1.0 - pow(1.0 - t, 3.0)
		player.set_look(lerp_angle(yaw_from, yaw_to, ease_out), lerpf(pitch_from, pitch_to, ease_out))

	var roll := _rng.randf_range(-0.22, 0.22)
	var from: Transform3D = enemy.global_transform
	var distance: float = enemy.jumpscare_distance
	t = 0.0
	while t < 1.0:
		await get_tree().process_frame
		t = minf(t + get_process_delta_time() / LUNGE_TIME, 1.0)
		enemy.global_transform = from.interpolate_with(_pose(cam, enemy, distance, roll), t * t * t)
		# Punch in: a narrower lens makes the face bigger.
		cam.fov = base_fov - PUNCH_IN * t * t * t

	enemy.bite()
	hud.flash()
	t = 0.0
	while t < 1.0:
		await get_tree().process_frame
		t = minf(t + get_process_delta_time() / BITE_TIME, 1.0)
		var shake := 0.07 * (1.0 - t * 0.5)
		cam.h_offset = _rng.randf_range(-shake, shake)
		cam.v_offset = _rng.randf_range(-shake, shake)
		cam.rotation.z = _rng.randf_range(-shake, shake)
		cam.fov = base_fov - PUNCH_IN + _rng.randf_range(-1.5, 1.5)
		var push := distance - 0.15 * minf(t * 5.0, 1.0) + _rng.randf_range(-0.03, 0.03)
		enemy.global_transform = _pose(cam, enemy, push, roll + _rng.randf_range(-0.08, 0.08))

	hud.blackout()
	key_light.queue_free()
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	cam.rotation.z = 0.0
	cam.fov = base_fov
	await get_tree().create_timer(BLACK_TIME).timeout
	running = false


# Where the monster must be for its face to sit `distance` metres in front of the camera, looking into it.
func _pose(cam: Camera3D, enemy: CharacterBody3D, distance: float, roll: float) -> Transform3D:
	var forward := -cam.global_basis.z
	var up := cam.global_basis.y
	var face_at := cam.global_position + forward * distance - up * 0.05
	var facing := Basis.looking_at(-forward, up).rotated(forward, roll)
	var offset: Vector3 = enemy.mouth_offset
	return Transform3D(facing, face_at - facing * offset)
