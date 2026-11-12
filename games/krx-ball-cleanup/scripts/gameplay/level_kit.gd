class_name LevelKit
extends RefCounted
## Building blocks shared by the level scripts: a box or a pipe with its material and, when wanted, its collision.
##
## The tile, concrete and steel materials are mapped in world space (triplanar), so a box of any size shows
## tiles at their true size without stretching and neighbouring boxes line up.

const WORLD_LAYER := 2                      # physics layer "World"


## A box centred on `centre`. With `solid`, the player collides with it.
static func box(parent: Node3D, size: Vector3, centre: Vector3, material: Material, solid := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = centre
	parent.add_child(node)
	if solid:
		collider(parent, size, centre)
	return node


## Collision with nothing to see: a box centred on `centre`.
static func collider(parent: Node3D, size: Vector3, centre: Vector3) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var hit := CollisionShape3D.new()
	hit.shape = shape
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = centre
	body.add_child(hit)
	parent.add_child(body)
	return body


## A round bar or pipe from `from` to `to`. No collision: these are all out of the player's reach.
static func pipe(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material, sides := 20) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = sides
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = (from + to) * 0.5
	var along := (to - from).normalized()
	if absf(along.dot(Vector3.UP)) < 0.999:
		node.quaternion = Quaternion(Vector3.UP, along)
	parent.add_child(node)
	return node


## A flat-coloured material that glows, for lamps and signs.
static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
