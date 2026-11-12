# The hall: floor collider, walls, optional drop ceiling, pillars, lights, fog.
# `look` is "dungeon" (Backrooms) or "outdoor" (daylight, sky, no roof). Parkour stays the same.
extends Node3D

const Materials = preload("res://scripts/materials.gd")
const CeilingLight = preload("res://scripts/level/ceiling_light.gd")

const WALL_THICKNESS := 0.4
const DOOR_HEIGHT := 2.3
const COLUMN_SIZE := 0.7

var size := Vector3.ZERO
# Footprints of everything that stands on the floor. Used to keep grass and monsters out of walls.
var blockers: Array[Rect2] = []
# Outdoor mounds. Grass grows on the slope and skips only the hole at the top.
var hills: Array[Dictionary] = []
var lights: Array[Node3D] = []


func build(data: Dictionary, look: String = "dungeon") -> void:
	size = data["room"]
	var outdoor := look == "outdoor"
	_environment(outdoor)
	_floor(outdoor)
	if outdoor:
		_sun()
		_hills(data)
	else:
		_ceiling()
		_outer_walls()
		for rect: Rect2 in data.get("walls", []):
			_wall(rect, 0.0, size.y, true)
		for rect: Rect2 in data.get("lintels", []):
			_wall(rect, DOOR_HEIGHT, size.y, false)
		for at: Vector2 in data.get("columns", []):
			var half := Vector2(COLUMN_SIZE, COLUMN_SIZE) * 0.5
			_wall(Rect2(at - half, half * 2.0), 0.0, size.y, true)
		_lights(data["lights"])


func floor_rect() -> Rect2:
	return Rect2(-size.x * 0.5, -size.z * 0.5, size.x, size.z)


func field_rect() -> Rect2:
	return Rect2(-size.x * 4.0, -size.z * 4.0, size.x * 8.0, size.z * 8.0)


func _environment(outdoor: bool) -> void:
	var env := Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.6
	env.glow_enabled = true
	if outdoor:
		var sky := Sky.new()
		sky.sky_material = ProceduralSkyMaterial.new()
		var sky_mat: ProceduralSkyMaterial = sky.sky_material
		sky_mat.sky_top_color = Color(0.38, 0.64, 0.95)
		sky_mat.sky_horizon_color = Color(0.86, 0.90, 0.96)
		sky_mat.ground_bottom_color = Color(0.42, 0.52, 0.28)
		sky_mat.ground_horizon_color = Color(0.70, 0.76, 0.55)
		sky_mat.sun_angle_max = 30.0
		sky_mat.sun_curve = 0.08
		sky_mat.energy_multiplier = 1.15
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.55
		env.glow_intensity = 0.28
		env.glow_bloom = 0.02
		env.fog_enabled = true
		env.fog_light_color = Color(0.78, 0.86, 0.95)
		env.fog_density = 0.0018
		env.fog_aerial_perspective = 0.25
		env.volumetric_fog_enabled = false
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.04
		env.adjustment_saturation = 1.05
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color.BLACK
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.54, 0.30)
		env.ambient_light_energy = 0.12
		env.glow_intensity = 0.55
		env.glow_bloom = 0.06
		env.fog_enabled = true
		env.fog_light_color = Color(0.20, 0.18, 0.09)
		env.fog_density = 0.018
		env.volumetric_fog_enabled = false
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 0.9
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.rotation_degrees = Vector3(-42.0, 40.0, 0.0)
	add_child(sun)


func _floor(outdoor: bool) -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var floor_span := Vector2(size.x, size.z) * (8.0 if outdoor else 1.0) + Vector2(2.0, 2.0)
	box.size = Vector3(floor_span.x, 1.0, floor_span.y)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)


func _ceiling() -> void:
	var mesh_i := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	plane.flip_faces = true
	mesh_i.mesh = plane
	mesh_i.material_override = Materials.ceiling()
	mesh_i.position.y = size.y
	add_child(mesh_i)
	var body := StaticBody3D.new()
	body.name = "Ceiling"
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 0.5, size.z)
	shape.shape = box
	shape.position.y = size.y + 0.25
	body.add_child(shape)
	add_child(body)


func _outer_walls() -> void:
	var w := size.x
	var d := size.z
	var t := WALL_THICKNESS
	_wall(Rect2(-w * 0.5 - t, -d * 0.5 - t, w + t * 2.0, t), 0.0, size.y, false)
	_wall(Rect2(-w * 0.5 - t, d * 0.5, w + t * 2.0, t), 0.0, size.y, false)
	_wall(Rect2(-w * 0.5 - t, -d * 0.5, t, d), 0.0, size.y, false)
	_wall(Rect2(w * 0.5, -d * 0.5, t, d), 0.0, size.y, false)


func _hills(data: Dictionary) -> void:
	var spots: Array[Vector2] = []
	for at: Vector2 in data.get("columns", []):
		spots.append(at)
	for rect: Rect2 in data.get("walls", []):
		spots.append(rect.get_center())
	if spots.is_empty():
		spots = [
			Vector2(-size.x * 0.28, size.z * 0.22),
			Vector2(size.x * 0.24, -size.z * 0.18),
			Vector2(size.x * 0.08, size.z * 0.30),
		]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in spots.size():
		var roll := rng.randf()
		var radius: float
		var height: float
		if roll < 0.22:
			radius = rng.randf_range(0.7, 1.15)
			height = rng.randf_range(0.35, 0.55)
		elif roll < 0.72:
			radius = rng.randf_range(1.5, 2.4)
			height = rng.randf_range(0.7, 1.15)
		else:
			radius = rng.randf_range(2.8, 4.2)
			height = rng.randf_range(1.35, 2.1)
		_hill(spots[i], radius, height)


func _hill(at: Vector2, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = Vector3(at.x, 0.0, at.y)
	var mesh_i := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 14
	cone.rings = 1
	mesh_i.mesh = cone
	mesh_i.position.y = height * 0.5
	mesh_i.material_override = Materials.dirt()
	body.add_child(mesh_i)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * 0.72
	cyl.height = height * 0.7
	shape.shape = cyl
	shape.position.y = height * 0.35
	body.add_child(shape)
	add_child(body)
	hills.append({"at": at, "radius": radius, "height": height})


# One wallpapered block from `bottom` to `top`. `on_floor` adds a baseboard and keeps grass and monsters out.
func _wall(rect: Rect2, bottom: float, top: float, on_floor: bool) -> void:
	var center := rect.get_center()
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = Vector3(center.x, (bottom + top) * 0.5, center.y)
	var dims := Vector3(rect.size.x, top - bottom, rect.size.y)
	var mesh_i := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = dims
	mesh_i.mesh = box_mesh
	mesh_i.material_override = Materials.wallpaper(size.y)
	body.add_child(mesh_i)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dims
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	if on_floor:
		blockers.append(rect)
	if bottom <= 0.0:
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(rect.size.x + 0.05, 0.16, rect.size.y + 0.05)
		board.mesh = board_mesh
		board.material_override = Materials.baseboard()
		board.position = Vector3(center.x, 0.08, center.y)
		add_child(board)


func _lights(cfg: Dictionary) -> void:
	var spacing: float = cfg["spacing"]
	var columns: int = cfg["columns"]
	var rows: int = cfg["rows"]
	var dead: Array = cfg.get("dead", [])
	var flicker: Array = cfg.get("flicker", [])
	for i in columns:
		for j in rows:
			var cell := Vector2i(i, j)
			var mode := CeilingLight.Mode.ON
			if cell in dead:
				mode = CeilingLight.Mode.DEAD
			elif cell in flicker:
				mode = CeilingLight.Mode.FLICKER
			var light := CeilingLight.new()
			light.position = Vector3((i - (columns - 1) * 0.5) * spacing, size.y, (j - (rows - 1) * 0.5) * spacing)
			add_child(light)
			light.build(mode, i * 31 + j * 7 + 1)
			lights.append(light)
