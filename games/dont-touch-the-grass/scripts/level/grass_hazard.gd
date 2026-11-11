# The dangerous part of the grass: one flat trigger volume over the whole floor.
# It only reports. chase_manager.gd decides what happens when the player touches it.
extends Area3D

signal player_touched_grass
signal player_left_grass

# The trigger reaches this high above the floor. Every platform top is far above it.
const HEIGHT := 0.3

var player_inside := false


func build(area: Rect2) -> void:
	collision_layer = 16       # Triggers
	collision_mask = 1         # Player
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(area.size.x, HEIGHT, area.size.y)
	shape.shape = box
	var center := area.get_center()
	shape.position = Vector3(center.x, HEIGHT * 0.5, center.y)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = true
	player_touched_grass.emit()


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = false
	player_left_grass.emit()
