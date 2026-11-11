# A pad that sends the player to another pad. Walking onto it is the only way it fires.
# The pair shares a cooldown so the player is not bounced straight back.
extends Area3D

var destination := Vector3.ZERO
var partner: Area3D
var _cool := 0.0


func build(at: Vector3, color: Color) -> void:
	position = at
	collision_layer = 16
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.6, 0.7)
	shape.shape = box
	shape.position.y = 0.3
	add_child(shape)
	var mesh_i := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.04, 0.7)
	mesh_i.mesh = mesh
	mesh_i.position.y = 0.03
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_i.material_override = mat
	add_child(mesh_i)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)


func _on_body(body: Node3D) -> void:
	if _cool > 0.0 or not body.is_in_group("player") or body.locked:
		return
	_cool = 0.8
	if partner:
		partner._cool = 0.8
	body.teleport(destination + Vector3(0.0, 0.02, 0.0), body.yaw)
