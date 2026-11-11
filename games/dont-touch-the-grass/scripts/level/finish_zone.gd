# The glowing pad on the last platform. Walking onto it finishes the level, once.
extends Area3D

signal reached

const GLOW := Color(0.55, 1.0, 0.90)

var _used := false


# The node sits on the platform surface. `pad` is the side of the glowing square.
func build(pad: float) -> void:
	collision_layer = 16       # Triggers
	collision_mask = 1         # Player
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(pad * 0.85, 1.2, pad * 0.85)
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)

	var glow := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(pad, pad)
	glow.mesh = quad
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = load("res://shaders/finish_glow.gdshader")
	glow_mat.set_shader_parameter("glow_color", GLOW)
	glow.material_override = glow_mat
	glow.position.y = 0.012
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)

	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(pad * 0.86, 2.2, pad * 0.86)
	beam.mesh = beam_mesh
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = load("res://shaders/finish_beam.gdshader")
	beam_mat.set_shader_parameter("glow_color", GLOW)
	beam_mat.set_shader_parameter("height", 2.2)
	beam.material_override = beam_mat
	beam.position.y = 1.1
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)

	var lamp := OmniLight3D.new()
	lamp.light_color = GLOW
	lamp.light_energy = 1.8
	lamp.omni_range = 6.0
	lamp.position.y = 0.8
	add_child(lamp)

	body_entered.connect(_on_body_entered)


func reset() -> void:
	_used = false


func _on_body_entered(body: Node3D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	reached.emit()
