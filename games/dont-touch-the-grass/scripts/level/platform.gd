# A safe platform: a concrete slab in a steel frame, held up by exactly one steel pole.
# Monsters walk under the slab and around the pole. They cannot get on top.
extends StaticBody3D

const Materials = preload("res://scripts/materials.gd")

const SLAB_THICKNESS := 0.10
const FRAME_HEIGHT := 0.10
# Slab top to the lowest point of the frame. Monsters must be shorter than (top - UNDERSIDE_DROP).
const UNDERSIDE_DROP := 0.14

var size := Vector2.ONE
var top := 1.0
var pole_radius := 0.09
var poles: Array[StaticBody3D] = []


func build(center: Vector2, p_size: Vector2, p_top: float) -> void:
	size = p_size
	top = p_top
	position = Vector3(center.x, 0.0, center.y)
	collision_layer = 4        # Safe platforms
	collision_mask = 0
	add_to_group("safe_platform")
	pole_radius = 0.12 if maxf(size.x, size.y) > 2.6 else 0.09

	_box(self, Vector3(size.x, SLAB_THICKNESS, size.y), top - SLAB_THICKNESS * 0.5, Materials.concrete())
	_box(self, Vector3(size.x + 0.06, FRAME_HEIGHT, size.y + 0.06), top - UNDERSIDE_DROP + FRAME_HEIGHT * 0.5, Materials.steel())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, UNDERSIDE_DROP, size.y)
	shape.shape = box
	shape.position.y = top - UNDERSIDE_DROP * 0.5
	add_child(shape)
	_pole()


# Footprint of the walking surface on the floor plan.
func rect() -> Rect2:
	return Rect2(Vector2(position.x, position.z) - size * 0.5, size)


func top_center() -> Vector3:
	return Vector3(position.x, top, position.z)


func pole_rect() -> Rect2:
	var half := Vector2(pole_radius, pole_radius)
	return Rect2(Vector2(position.x, position.z) - half, half * 2.0)


func _pole() -> void:
	var pole_top := top - UNDERSIDE_DROP
	var body := StaticBody3D.new()
	body.name = "Pole"
	body.collision_layer = 2   # World: blocks the player and monsters
	body.collision_mask = 0
	add_child(body)
	poles.append(body)

	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = pole_radius
	shaft_mesh.bottom_radius = pole_radius
	shaft_mesh.height = pole_top
	shaft_mesh.radial_segments = 16
	shaft.mesh = shaft_mesh
	shaft.material_override = Materials.steel()
	shaft.position.y = pole_top * 0.5
	body.add_child(shaft)

	# Floor flange and the plate that carries the slab.
	var flange := MeshInstance3D.new()
	var flange_mesh := CylinderMesh.new()
	flange_mesh.top_radius = pole_radius * 2.4
	flange_mesh.bottom_radius = pole_radius * 2.6
	flange_mesh.height = 0.05
	flange_mesh.radial_segments = 16
	flange.mesh = flange_mesh
	flange.material_override = Materials.steel()
	flange.position.y = 0.025
	body.add_child(flange)
	var plate_side := minf(minf(size.x, size.y) * 0.5, pole_radius * 6.0)
	_box(body, Vector3(plate_side, 0.04, plate_side), pole_top - 0.02, Materials.steel())
	var collar := MeshInstance3D.new()
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = pole_radius * 2.0
	collar_mesh.bottom_radius = pole_radius * 1.05
	collar_mesh.height = 0.18
	collar_mesh.radial_segments = 16
	collar.mesh = collar_mesh
	collar.material_override = Materials.steel()
	collar.position.y = pole_top - 0.13
	body.add_child(collar)

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = pole_radius
	cylinder.height = pole_top
	shape.shape = cylinder
	shape.position.y = pole_top * 0.5
	body.add_child(shape)


func _box(parent: Node3D, dims: Vector3, center_y: float, material: Material) -> void:
	var mesh_i := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dims
	mesh_i.mesh = mesh
	mesh_i.material_override = material
	mesh_i.position.y = center_y
	parent.add_child(mesh_i)
