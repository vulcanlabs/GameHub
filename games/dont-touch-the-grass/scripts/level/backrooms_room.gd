# The Backrooms hall: floor collider, walls, drop ceiling, pillars, ceiling lights, fog.
# Same look for every level. The level data only changes sizes and positions.
extends Node3D

const Materials = preload("res://scripts/materials.gd")
const CeilingLight = preload("res://scripts/level/ceiling_light.gd")

const WALL_THICKNESS := 0.4
const DOOR_HEIGHT := 2.3
const COLUMN_SIZE := 0.7

var size := Vector3.ZERO
# Footprints of everything that stands on the floor. Used to keep grass and monsters out of walls.
var blockers: Array[Rect2] = []
var lights: Array[Node3D] = []


func build(data: Dictionary) -> void:
	size = data["room"]
	_environment()
	_floor()
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


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.54, 0.30)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.6
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_light_color = Color(0.20, 0.18, 0.09)
	env.fog_density = 0.016
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.92, 0.86, 0.62)
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_ambient_inject = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 2.0, 1.0, size.z + 2.0)
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
