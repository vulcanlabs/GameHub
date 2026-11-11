extends RefCounted

const PLAT_W := 2.4
const PLAT_H := 0.45
const PLAT_D := 2.4
const START_W := 6.4
const START_D := 6.4
# Edge-to-edge gap. A 7 m/s run and an 8.2 jump clears about 4.3 m after a landing margin.
const MIN_GAP := 1.3
const MAX_GAP := 4.3
const RUN_SPEED := 7.0
const JUMP_V := 8.2
const GRAVITY := 22.0
const JUMP_MARGIN := 0.85

static func build(parent: Node, level_index: int, platform_count: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_index + 1
	var count := clampi(platform_count, 4, 40)
	var root := Node3D.new()
	root.name = "Course"
	parent.add_child(root)
	var t := clampf(float(level_index) / 8.0, 0.0, 1.0)
	var plats: Array = []
	var centers: Array[Vector2] = []
	var radii: Array[float] = []
	var goal_area: Area3D = null
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var heading := 0.0
	var prev_size := Vector3(START_W, PLAT_H, START_D)
	for i in count:
		var goal := i == count - 1
		var size := Vector3(START_W, PLAT_H, START_D) if i == 0 else Vector3(PLAT_W, PLAT_H, PLAT_D)
		if i > 0:
			var rise := rng.randf_range(-0.45, 0.5)
			var ceiling := minf(_jump_gap(rise), lerpf(4.0, MAX_GAP, t))
			var gap := ceiling if goal else rng.randf_range(MIN_GAP, maxf(ceiling, MIN_GAP + 0.2))
			var spot := _place_ahead(rng, goal, heading, x, z, gap, ceiling, prev_size, size, centers, radii)
			x = spot.x
			z = spot.z
			heading = spot.heading
			y = clampf(y + rise, -0.8, 2.4)
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = Vector3(x, y, z)
		body.rotation.y = heading
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
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
		centers.append(Vector2(x, z))
		radii.append(_footprint(size))
		prev_size = size
	return {"root": root, "platforms": plats, "goal": goal_area}


static func _place_ahead(
	rng: RandomNumberGenerator,
	goal: bool,
	heading: float,
	x: float,
	z: float,
	gap: float,
	ceiling: float,
	prev_size: Vector3,
	size: Vector3,
	centers: Array[Vector2],
	radii: Array[float],
) -> Dictionary:
	var need := _furthest(centers) + 0.5
	var tries := 9 if goal else 12
	var best := {"x": x, "z": z, "heading": heading, "dist": -1.0}
	var found := false
	for attempt in tries:
		var turn := lerpf(-PI * 0.5, PI * 0.5, float(attempt) / 8.0) if goal else rng.randf_range(-PI * 0.5, PI * 0.5)
		var dir := heading + turn
		var step_gap := ceiling if goal else gap
		var step := prev_size.z * 0.5 + step_gap + size.z * 0.5
		var nx := x + sin(dir) * step
		var nz := z + cos(dir) * step
		if not _clear(nx, nz, _footprint(size), centers, radii):
			continue
		var dist := Vector2(nx, nz).length()
		if goal:
			if dist > float(best.dist):
				best = {"x": nx, "z": nz, "heading": dir, "dist": dist}
				found = dist > need
		elif dist > need:
			return {"x": nx, "z": nz, "heading": dir}
	if goal and found:
		return best
	var pushed := _push_outward(heading, x, z, ceiling, prev_size, size)
	if goal and float(best.dist) > pushed.dist:
		return best
	return pushed


static func _push_outward(
	heading: float,
	x: float,
	z: float,
	ceiling: float,
	prev_size: Vector3,
	size: Vector3,
) -> Dictionary:
	var away := heading if x * x + z * z < 0.01 else atan2(x, z)
	var dir := heading + clampf(wrapf(away - heading, -PI, PI), -PI * 0.5, PI * 0.5)
	var step := prev_size.z * 0.5 + ceiling + size.z * 0.5
	var nx := x + sin(dir) * step
	var nz := z + cos(dir) * step
	return {"x": nx, "z": nz, "heading": dir, "dist": Vector2(nx, nz).length()}


static func _furthest(centers: Array[Vector2]) -> float:
	var best := 0.0
	for c in centers:
		best = maxf(best, c.length())
	return best


static func _jump_gap(rise: float) -> float:
	var a := GRAVITY * 0.5
	var disc := JUMP_V * JUMP_V - 4.0 * a * maxf(rise, 0.0)
	if disc <= 0.0:
		return MIN_GAP
	var air := (JUMP_V + sqrt(disc)) / (2.0 * a)
	return maxf(RUN_SPEED * air - JUMP_MARGIN, MIN_GAP)


static func _footprint(size: Vector3) -> float:
	return 0.5 * sqrt(size.x * size.x + size.z * size.z)


static func _clear(px: float, pz: float, radius: float, centers: Array[Vector2], radii: Array[float]) -> bool:
	var last := centers.size() - 1
	for n in centers.size():
		if n == last:
			continue
		var need := radius + radii[n] + 0.35
		if Vector2(px, pz).distance_to(centers[n]) < need:
			return false
	return true
