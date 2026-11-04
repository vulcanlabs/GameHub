extends Node3D

var bat := false
var phase := 0.0
var orbit_r := 12.0
var height := 6.0
var spin := 0.4
var mode := "orbit"
var age := 0.0
var left_wing: Node3D
var right_wing: Node3D


func setup(is_bat: bool) -> void:
	bat = is_bat
	phase = randf() * TAU
	orbit_r = 10.0 + randf() * 16.0
	height = (10.0 + randf() * 3.0) if bat else (5.0 + randf() * 4.0)
	spin = (0.3 + randf() * 0.4) * (-1.0 if randf() < 0.5 else 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("1a1220") if bat else Color("0a0a0a")
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.2, 0.7)
	body.mesh = box
	body.material_override = mat
	add_child(body)
	left_wing = _wing(mat, -1.0)
	right_wing = _wing(mat, 1.0)
	scale = Vector3.ONE * (0.8 if bat else 1.3)


func begin_attack(at: Vector3) -> void:
	mode = "attack"
	age = 0.0
	position = at


func step(player: Vector3, push: float, dt: float, t: float) -> Vector2:
	age += dt
	var flap := sin(t * (18.0 if bat else 11.0) + phase) * 0.9
	if left_wing:
		left_wing.rotation.z = flap
	if right_wing:
		right_wing.rotation.z = -flap
	if mode == "orbit":
		var a := phase + t * spin
		var nx := player.x + cos(a) * orbit_r
		var nz := player.z + sin(a) * orbit_r
		rotation.y = atan2(-(nx - position.x), -(nz - position.z))
		position = Vector3(nx, height + sin(t * 2.0 + phase), nz)
		return Vector2.ZERO
	if mode == "attack":
		var target := player + Vector3(0, 1.4, 0)
		var delta := target - position
		var dist := delta.length()
		if dist < 0.001:
			dist = 1.0
		position += delta / dist * 20.0 * dt
		rotation.y = atan2(-delta.x, -delta.z)
		if dist < 1.3 or age > 4.0:
			var flat := Vector2(delta.x, delta.z)
			var h := flat.length()
			if h < 0.001:
				h = 1.0
			mode = "leave"
			age = 0.0
			return flat / h * push * 1.4
		return Vector2.ZERO
	position.y += 8.0 * dt
	position.x += sin(phase) * 6.0 * dt
	position.z -= 6.0 * dt
	if age > 3.0:
		queue_free()
	return Vector2.ZERO


func _wing(mat: Material, side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position.x = side * 0.12
	var wing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.04, 0.4)
	wing.mesh = box
	wing.material_override = mat
	wing.position.x = side * 0.45
	pivot.add_child(wing)
	add_child(pivot)
	return pivot
