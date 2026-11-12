# Giant spider. Same brain as the ant (enemy.gd). Low enough to walk under the platforms, wide so it reads bigger.
#
# PLACEHOLDER MODEL: spheres and cylinders, legs driven by sine waves. Not a sculpted spider.
# Replace the body in _build_model() and the clips in _animate(), begin_attack() and bite().
#
# Faces -Z.
extends "res://scripts/enemies/enemy.gd"

const Materials = preload("res://scripts/materials.gd")

var _model: Node3D
var _legs: Array[Dictionary] = []
var _fangs: Array[Node3D] = []
var _gait := 0.0
var _clock := 0.0
var _biting := false
var _sphere: SphereMesh
var _body: StandardMaterial3D
var _limb: StandardMaterial3D
var _eye_mat: StandardMaterial3D


func _init() -> void:
	kind = "spider"
	roam_speed = 2.2
	chase_speed = 9.2
	catch_radius = 1.85
	reach_height = 1.0
	head_distance = 0.95
	body_height = 0.85
	body_radius = 0.72
	mouth_offset = Vector3(0.0, 0.58, -1.05)
	jumpscare_distance = 1.1


func scare_stream() -> AudioStream:
	return SoundBank.spider_screech()


func begin_attack() -> void:
	_biting = false


func bite() -> void:
	_biting = true


func end_attack() -> void:
	_biting = false


func _build_model() -> void:
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 18
	_sphere.rings = 10
	_body = Materials.chitin(Color(0.07, 0.055, 0.05), 0.42)
	_limb = Materials.chitin(Color(0.04, 0.03, 0.028), 0.4)
	_eye_mat = Materials.chitin(Color(0.02, 0.0, 0.0), 0.08).duplicate()
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.75, 0.02, 0.0)
	_eye_mat.emission_energy_multiplier = 0.8

	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_model.scale = Vector3(1.42, 1.48, 1.42)
	_ellipsoid(Vector3(0.0, 0.38, 0.15), Vector3(0.42, 0.22, 0.48), _body)
	_ellipsoid(Vector3(0.0, 0.40, -0.42), Vector3(0.28, 0.16, 0.30), _body)
	for side: float in [1.0, -1.0]:
		for i in 4:
			_ellipsoid(Vector3(side * (0.10 + float(i) * 0.04), 0.50, -0.55 - float(i) * 0.02), Vector3(0.045, 0.05, 0.05), _eye_mat)
		var fang := Node3D.new()
		fang.position = Vector3(side * 0.08, 0.28, -0.68)
		_model.add_child(fang)
		_limb_between(fang, Vector3.ZERO, Vector3(side * 0.05, -0.16, -0.22), 0.03, 0.008, _limb)
		_fangs.append(fang)
	for i in 4:
		_build_leg(1.0, i)
		_build_leg(-1.0, i)


func _build_leg(side: float, index: int) -> void:
	var yaw := deg_to_rad(-50.0 + float(index) * 32.0)
	if side < 0.0:
		yaw = PI - yaw
	var hip := Node3D.new()
	hip.position = Vector3(side * 0.22, 0.36, -0.15 + float(index) * 0.16)
	hip.rotation.y = yaw
	_model.add_child(hip)
	var upper := 0.55
	var lower := 0.62
	_limb_between(hip, Vector3.ZERO, Vector3(upper, 0.18, 0.0), 0.035, 0.022, _limb)
	var knee := Node3D.new()
	knee.position = Vector3(upper, 0.18, 0.0)
	hip.add_child(knee)
	_limb_between(knee, Vector3.ZERO, Vector3(lower, -0.42, 0.0), 0.02, 0.01, _limb)
	_legs.append({"hip": hip, "knee": knee, "phase": float(index) * 1.4 + (0.0 if side > 0.0 else PI)})


func _animate(delta: float, moving: float) -> void:
	_clock += delta
	if _biting:
		for i in _fangs.size():
			var side := 1.0 if i == 0 else -1.0
			_fangs[i].rotation.z = side * (0.4 + sin(_clock * 36.0) * 0.5)
		return
	_gait += delta * TAU * moving / 1.1
	var stride := clampf(moving / 0.5, 0.0, 1.0)
	for leg in _legs:
		var hip: Node3D = leg["hip"]
		var knee: Node3D = leg["knee"]
		var phase: float = _gait + float(leg["phase"])
		hip.rotation.x = sin(phase) * 0.35 * stride
		knee.rotation.x = maxf(cos(phase), 0.0) * 0.4 * stride
	var open := 0.15
	if state == State.CHASING:
		open = 0.7
	elif state == State.SEARCHING:
		open = 0.45
	for i in _fangs.size():
		var side := 1.0 if i == 0 else -1.0
		_fangs[i].rotation.z = side * open


func _ellipsoid(at: Vector3, radii: Vector3, material: Material) -> void:
	var mesh_i := MeshInstance3D.new()
	mesh_i.mesh = _sphere
	mesh_i.scale = radii
	mesh_i.position = at
	mesh_i.material_override = material
	_model.add_child(mesh_i)


func _limb_between(parent: Node3D, from: Vector3, to: Vector3, radius_from: float, radius_to: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius_from
	mesh.top_radius = radius_to
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 8
	var mesh_i := MeshInstance3D.new()
	mesh_i.mesh = mesh
	mesh_i.material_override = material
	mesh_i.position = (from + to) * 0.5
	mesh_i.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
	parent.add_child(mesh_i)
