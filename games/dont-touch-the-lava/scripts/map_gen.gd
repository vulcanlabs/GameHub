extends RefCounted

const PLAT_W := 3.2
const PLAT_H := 0.5
const PLAT_D := 3.2
# Edge-to-edge gap. A 7 m/s run and an 8.2 jump clear about 4 m. Stay under that.
const MIN_GAP := 2.0
const MAX_GAP := 3.4

static func build(parent: Node, level_index: int, platform_count: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_index + 1
	var count := clampi(platform_count, 4, 40)
	var root := Node3D.new()
	root.name = "Course"
	parent.add_child(root)
	var t := clampf(float(level_index) / 8.0, 0.0, 1.0)
	var gap := lerpf(MIN_GAP, MAX_GAP, t)
	var plats: Array = []
	var goal_area: Area3D = null
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var heading := 0.0
	for i in count:
		if i > 0:
			heading += rng.randf_range(-0.28, 0.28)
			heading = clampf(heading, -0.7, 0.7)
			var step := PLAT_D * 0.5 + gap + rng.randf_range(-0.15, 0.15) + PLAT_D * 0.5
			x += sin(heading) * step
			z += cos(heading) * step
			y = clampf(y + rng.randf_range(-0.12, 0.32), -0.3, 1.6)
		var goal := i == count - 1
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = Vector3(x, y, z)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(PLAT_W, PLAT_H, PLAT_D)
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = box.size
		mesh.mesh = box_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("e07a3d") if goal else Color("4a463f")
		if goal:
			mat.emission_enabled = true
			mat.emission = Color("e07a3d")
			mat.emission_energy_multiplier = 0.4
		mesh.material_override = mat
		body.add_child(mesh)
		root.add_child(body)
		if goal:
			goal_area = Area3D.new()
			goal_area.name = "Goal"
			goal_area.collision_layer = 4
			goal_area.collision_mask = 1
			goal_area.monitoring = true
			var area_shape := CollisionShape3D.new()
			var area_box := BoxShape3D.new()
			area_box.size = Vector3(PLAT_W * 0.7, 1.4, PLAT_D * 0.7)
			area_shape.shape = area_box
			area_shape.position = Vector3(0, 0.9, 0)
			goal_area.add_child(area_shape)
			body.add_child(goal_area)
		plats.append({"position": body.position, "top": y + PLAT_H * 0.5})
	return {"root": root, "platforms": plats, "goal": goal_area}
