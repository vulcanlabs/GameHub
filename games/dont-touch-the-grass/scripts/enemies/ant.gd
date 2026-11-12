# Giant red ant. Movement and states come from enemy.gd; this file is the body and how it moves.
#
# PLACEHOLDER MODEL: the ant is assembled in code from stretched spheres and tapered cylinders, and its legs are
# driven by sine waves, not by an animator. It is a stand-in for a sculpted, rigged model.
# To replace it: load the real model inside _build_model() and play its clips from _animate(), begin_attack(), bite().
#
# The ant faces -Z. Collision stays under 0.95 m so it still walks under platforms.
# LOOK: rust-red head and thorax, black gaster, long elbowed antennae, sickle mandibles. Placeholder mesh.
extends "res://scripts/enemies/enemy.gd"

const Materials = preload("res://scripts/materials.gd")

const BODY_SCALE := Vector3(1.45, 1.55, 1.48)
const HIP_HEIGHT := 0.46
const LEG_SWING := 0.55
const LEG_LIFT := 0.42
const KNEE_BEND := 0.55
const ANKLE_KICK := 0.28
const STRIDE := 1.05

# Each leg pair: where it joins the body (z), which way it points on the right side (degrees, + is forward),
# upper leg length, lower leg length, foot length, how steeply the upper leg rises (degrees).
const LEG_PAIRS := [
	[-0.56, 48.0, 0.44, 0.60, 0.22, 30.0],
	[-0.34, -6.0, 0.50, 0.68, 0.24, 32.0],
	[-0.12, -52.0, 0.58, 0.84, 0.28, 30.0],
]

enum Attack { NONE, REARING, BITING }

var _model: Node3D
var _head: Node3D
var _gaster: Node3D
var _jaws: Array[Node3D] = []       # right, left
var _antennae: Array[Node3D] = []   # right, left
var _legs: Array[Dictionary] = []
var _gait := 0.0
var _clock := 0.0
var _attack := Attack.NONE
var _sphere: SphereMesh
var _shell: StandardMaterial3D
var _shell_dark: StandardMaterial3D
var _limb_mat: StandardMaterial3D
var _black: StandardMaterial3D
var _eye: StandardMaterial3D


func _init() -> void:
	kind = "ant"
	roam_speed = 2.4
	chase_speed = 8.8
	head_distance = 1.35
	body_height = 0.90
	body_radius = 0.55
	catch_radius = 1.55
	reach_height = 1.0
	mouth_offset = Vector3(0.0, 0.52 * BODY_SCALE.y, -1.05 * BODY_SCALE.z)
	jumpscare_distance = 1.25


func begin_attack() -> void:
	_attack = Attack.REARING


func bite() -> void:
	_attack = Attack.BITING


func end_attack() -> void:
	_attack = Attack.NONE


func _build_model() -> void:
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 20
	_sphere.rings = 10
	_shell = Materials.chitin(Color(0.62, 0.22, 0.10), 0.55)
	_shell_dark = Materials.chitin(Color(0.48, 0.14, 0.07), 0.62)
	_limb_mat = Materials.chitin(Color(0.38, 0.12, 0.07), 0.7)
	_black = Materials.chitin(Color(0.04, 0.04, 0.05), 0.78)
	_eye = Materials.chitin(Color(0.02, 0.02, 0.02), 0.12).duplicate()
	_eye.metallic = 0.35
	_eye.clearcoat = 0.8
	_eye.clearcoat_roughness = 0.08

	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_build_body()
	_build_head()
	for pair_index in LEG_PAIRS.size():
		_build_leg(pair_index, 1.0)
		_build_leg(pair_index, -1.0)
	_model.scale = BODY_SCALE


func _build_body() -> void:
	# Thorax: rust lumps, pinched at the waist like the photo.
	_ellipsoid(_model, Vector3(0.0, 0.54, -0.50), Vector3(0.18, 0.17, 0.20), _shell)
	_ellipsoid(_model, Vector3(0.0, 0.52, -0.28), Vector3(0.16, 0.16, 0.22), _shell)
	_ellipsoid(_model, Vector3(0.0, 0.50, -0.06), Vector3(0.14, 0.15, 0.16), _shell_dark)
	_ellipsoid(_model, Vector3(0.0, 0.48, 0.12), Vector3(0.07, 0.10, 0.08), _shell_dark)
	_limb_between(_model, Vector3(0.0, 0.48, 0.02), Vector3(0.0, 0.46, 0.28), 0.045, 0.04, _shell_dark)

	_gaster = Node3D.new()
	_gaster.position = Vector3(0.0, 0.46, 0.26)
	_model.add_child(_gaster)
	var radii := Vector3(0.30, 0.28, 0.42)
	var center := Vector3(0.0, 0.04, 0.42)
	_ellipsoid(_gaster, center, radii, _black)
	_ellipsoid(_gaster, center + Vector3(0.0, 0.02, -0.08), Vector3(radii.x * 0.92, radii.y * 0.9, 0.18), _black)


func _build_head() -> void:
	_limb_between(_model, Vector3(0.0, 0.50, -0.70), Vector3(0.0, 0.50, -0.80), 0.09, 0.08, _shell_dark)
	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.54, -0.72)
	_model.add_child(_head)
	_ellipsoid(_head, Vector3(0.0, 0.02, -0.22), Vector3(0.24, 0.20, 0.26), _shell)
	for side: float in [1.0, -1.0]:
		_ellipsoid(_head, Vector3(side * 0.16, 0.04, -0.18), Vector3(0.07, 0.08, 0.08), _eye)
	_ellipsoid(_head, Vector3(0.0, -0.06, -0.42), Vector3(0.10, 0.07, 0.08), _shell_dark)

	for side: float in [1.0, -1.0]:
		var jaw := Node3D.new()
		jaw.position = Vector3(side * 0.10, -0.08, -0.42)
		_head.add_child(jaw)
		_build_jaw(jaw, side)
		_jaws.append(jaw)

		var antenna := Node3D.new()
		antenna.position = Vector3(side * 0.12, 0.16, -0.28)
		_head.add_child(antenna)
		var elbow := Vector3(side * 0.38, 0.28, 0.05)
		var tip := elbow + Vector3(side * 0.55, -0.08, -0.22)
		_limb_between(antenna, Vector3.ZERO, elbow, 0.022, 0.016, _limb_mat)
		_limb_between(antenna, elbow, tip, 0.016, 0.006, _limb_mat)
		_ellipsoid(antenna, elbow, Vector3.ONE * 0.02, _limb_mat)
		_antennae.append(antenna)


# Sickle jaw, like an army ant soldier: a tapering hook with teeth along the inside.
# The hinge is the node's origin; the hook runs forward (-Z), droops, and curls toward the other jaw.
func _build_jaw(jaw: Node3D, side: float) -> void:
	var spine: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0), Vector3(0.04, -0.02, -0.16), Vector3(0.02, -0.05, -0.34),
		Vector3(-0.04, -0.08, -0.48), Vector3(-0.10, -0.12, -0.56),
	]
	# Thin quickly: the tips end up closest to the camera in the jumpscare, where everything looks twice as thick.
	var radii := [0.05, 0.038, 0.026, 0.016, 0.005]
	for i in spine.size():
		spine[i].x *= side
	_ellipsoid(jaw, spine[0], Vector3.ONE * 0.065, _shell_dark)
	for i in spine.size() - 1:
		_limb_between(jaw, spine[i], spine[i + 1], radii[i], radii[i + 1], _black)
		_ellipsoid(jaw, spine[i + 1], Vector3.ONE * radii[i + 1], _black)
	for i in [1, 2, 3]:
		var root: Vector3 = spine[i]
		var point := root + Vector3(-side * (0.07 + 0.012 * i), -0.03, -0.035)
		_limb_between(jaw, root, point, radii[i] * 0.7, 0.002, _black)


# A leg is a chain: hip (turns forward/back) > upper leg (lifts) > knee > lower leg > ankle > foot.
# Inside the chain +X always points away from the body.
func _build_leg(pair_index: int, side: float) -> void:
	var pair: Array = LEG_PAIRS[pair_index]
	var attach_z: float = pair[0]
	var yaw := deg_to_rad(pair[1])
	var upper: float = pair[2]
	var lower: float = pair[3]
	var foot: float = pair[4]
	var rise := deg_to_rad(pair[5])
	# How far the lower leg must angle down for the foot to rest on the floor.
	var drop := asin(clampf((HIP_HEIGHT + upper * sin(rise) - 0.02) / lower, -1.0, 1.0))

	var hip := Node3D.new()
	hip.position = Vector3(side * 0.15, HIP_HEIGHT, attach_z)
	var base_yaw := yaw if side > 0.0 else PI - yaw
	hip.rotation.y = base_yaw
	_model.add_child(hip)
	_ellipsoid(hip, Vector3.ZERO, Vector3.ONE * 0.075, _shell_dark)

	var thigh := Node3D.new()
	thigh.rotation.z = rise
	hip.add_child(thigh)
	_limb_between(thigh, Vector3.ZERO, Vector3(upper, 0.0, 0.0), 0.06, 0.042, _limb_mat)

	var knee := Node3D.new()
	knee.position.x = upper
	knee.rotation.z = -(rise + drop)
	thigh.add_child(knee)
	_ellipsoid(knee, Vector3.ZERO, Vector3.ONE * 0.052, _limb_mat)
	_limb_between(knee, Vector3.ZERO, Vector3(lower, 0.0, 0.0), 0.04, 0.022, _limb_mat)
	# Spurs along the shin.
	for along: float in [0.35, 0.6, 0.85]:
		var root := Vector3(lower * along, 0.0, 0.0)
		_limb_between(knee, root, root + Vector3(0.05, 0.07, 0.0), 0.012, 0.002, _black)

	var ankle := Node3D.new()
	ankle.position.x = lower
	ankle.rotation.z = drop
	knee.add_child(ankle)
	_limb_between(ankle, Vector3.ZERO, Vector3(foot, 0.0, 0.0), 0.02, 0.008, _black)

	# Tripod: right-front, left-middle, right-back move together. The other three plant.
	var in_first_tripod := (pair_index % 2 == 0) == (side > 0.0)
	_legs.append({
		"hip": hip, "thigh": thigh, "knee": knee, "ankle": ankle,
		"yaw": base_yaw, "rise": rise, "drop": drop, "side": side,
		"phase": 0.0 if in_first_tripod else PI,
		"front": pair_index == 0,
	})


func _animate(delta: float, moving: float) -> void:
	_clock += delta
	if _attack != Attack.NONE:
		_animate_attack()
		return
	_gait += delta * TAU * maxf(moving, 0.05) / STRIDE
	var stride := clampf(moving / 0.55, 0.0, 1.0)
	for leg in _legs:
		_pose_leg(leg, _gait + leg["phase"], stride)
	_model.position.y = absf(sin(_gait * 2.0)) * 0.028 * stride
	_model.rotation.z = sin(_gait * 2.0) * 0.04 * stride
	_model.rotation.x = 0.0
	_gaster.rotation.y = sin(_gait) * 0.07 * stride
	_gaster.rotation.x = sin(_clock * 1.7) * 0.03

	var jaw_open := 0.05 * sin(_clock * 2.3)
	var head_pitch := -0.18
	var head_yaw := sin(_clock * 0.9) * 0.22
	var feel := 1.0
	if state == State.CHASING:
		jaw_open = 0.40 + 0.28 * sin(_clock * 11.0)
		head_pitch = 0.05
		head_yaw = 0.0
		feel = 2.6
	elif state == State.SEARCHING:
		# Looking up at the platform, jaws snapping at the player it cannot reach.
		jaw_open = absf(sin(_clock * 5.0)) * 0.7
		head_pitch = 0.45 if moving < 0.5 else 0.15
		head_yaw = sin(_clock * 3.1) * 0.12
		feel = 2.0
	_head.rotation.x = lerp_angle(_head.rotation.x, head_pitch, minf(delta * 6.0, 1.0))
	_head.rotation.y = lerp_angle(_head.rotation.y, head_yaw, minf(delta * 6.0, 1.0))
	_set_jaws(jaw_open)
	for i in _antennae.size():
		var side := 1.0 if i == 0 else -1.0
		_antennae[i].rotation.x = sin(_clock * 3.3 * feel + i * 1.9) * 0.22
		_antennae[i].rotation.y = side * (0.1 + sin(_clock * 2.1 * feel + i * 0.7) * 0.25)


# Jumpscare pose. The jumpscare script moves the whole ant; this makes the body act.
func _animate_attack() -> void:
	var biting := _attack == Attack.BITING
	_head.rotation.x = 0.12 + (sin(_clock * 47.0) * 0.06 if biting else 0.0)
	_head.rotation.y = sin(_clock * 39.0) * 0.07 if biting else 0.0
	_set_jaws(0.32 + 0.50 * sin(_clock * 40.0) if biting else 0.9)
	_model.position.y = 0.0
	_gaster.rotation.x = -0.25
	for i in _antennae.size():
		var side := 1.0 if i == 0 else -1.0
		_antennae[i].rotation.x = 0.5 + sin(_clock * 30.0 + i) * 0.15
		_antennae[i].rotation.y = side * 0.55
	for leg in _legs:
		var hip: Node3D = leg["hip"]
		var thigh: Node3D = leg["thigh"]
		var knee: Node3D = leg["knee"]
		var ankle: Node3D = leg["ankle"]
		var side: float = leg["side"]
		var thrash := sin(_clock * 26.0 + float(leg["phase"]))
		if leg["front"]:
			hip.rotation.y = leg["yaw"] + side * (0.55 + thrash * 0.18)
			thigh.rotation.z = leg["rise"] + 0.75 + thrash * 0.2
			knee.rotation.z = -(leg["rise"] + leg["drop"]) - 0.4
			ankle.rotation.z = leg["drop"] + 0.2
		else:
			hip.rotation.y = leg["yaw"] + side * thrash * 0.3
			thigh.rotation.z = leg["rise"] + maxf(thrash, 0.0) * 0.3
			knee.rotation.z = -(leg["rise"] + leg["drop"])
			ankle.rotation.z = leg["drop"]


# One cycle: 0–PI the foot is in the air and swinging forward, PI–TAU the foot plants and pushes back.
func _pose_leg(leg: Dictionary, phase: float, stride: float) -> void:
	var hip: Node3D = leg["hip"]
	var thigh: Node3D = leg["thigh"]
	var knee: Node3D = leg["knee"]
	var ankle: Node3D = leg["ankle"]
	var side: float = leg["side"]
	var swing := 0.5 + 0.5 * sin(phase)
	var lift := maxf(sin(phase), 0.0)
	var plant := maxf(-sin(phase), 0.0)
	hip.rotation.y = leg["yaw"] + side * sin(phase) * LEG_SWING * stride
	thigh.rotation.z = leg["rise"] + lift * LEG_LIFT * stride - plant * 0.08 * stride
	knee.rotation.z = -(leg["rise"] + leg["drop"]) - lift * KNEE_BEND * stride + plant * 0.12 * stride
	ankle.rotation.z = leg["drop"] + (swing - 0.5) * ANKLE_KICK * stride


# Below 0 = hooks crossed, 0 = tips almost touching, 1 = gaping (about 60 degrees each side).
func _set_jaws(open: float) -> void:
	_jaws[0].rotation.y = -open
	_jaws[1].rotation.y = open


# --- Mesh helpers ---

func _ellipsoid(parent: Node3D, at: Vector3, radii: Vector3, material: Material) -> MeshInstance3D:
	var mesh_i := MeshInstance3D.new()
	mesh_i.mesh = _sphere
	mesh_i.scale = radii
	mesh_i.position = at
	mesh_i.material_override = material
	parent.add_child(mesh_i)
	return mesh_i


# Tapered tube from `from` to `to`.
func _limb_between(parent: Node3D, from: Vector3, to: Vector3, radius_from: float, radius_to: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius_from
	mesh.top_radius = radius_to
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 10
	mesh.rings = 1
	var mesh_i := MeshInstance3D.new()
	mesh_i.mesh = mesh
	mesh_i.material_override = material
	mesh_i.position = (from + to) * 0.5
	mesh_i.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
	parent.add_child(mesh_i)
