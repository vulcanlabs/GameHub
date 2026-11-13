class_name Level2Pool
extends Node3D
## Level 2, the Poolroom: a tiled indoor pool hall east of the playroom.
##
## White 15 cm wall tiles, 30 cm floor tiles, a shallow pool, a stair into the water, and square pillars.
## There is no pit here. Deposit only happens back through the west door, in Level 1.
## The node is placed so its west doorway lines up with Level 1's east doorway.

const LEVEL_INDEX := 1
var level_index := LEVEL_INDEX
const WIDTH := 40.0
const DEPTH := 30.0
const HEIGHT := 7.0
const WALL := 0.4
const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 3.15
const BALL_SEED := 20261113
const POOL := Rect2(-11.0, -7.0, 22.0, 16.0)
const POOL_FLOOR := -1.35

var PILES: Array[Vector4] = []
var ball_seed := BALL_SEED

var _tile: Material = preload("res://assets/materials/wall_tile_white.tres")
var _mold: Material
var _floor: Material = preload("res://assets/materials/floor_tile_white.tres")
var _sign_font: Font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
var _water: StandardMaterial3D
var _water_time := 0.0
var _ripple: MeshInstance3D
var _ripple_life := 0.0


func _enter_tree() -> void:
	if PILES.is_empty():
		var origin := global_position
		PILES = [
			Vector4(origin.x - 16.0, origin.z - 11.0, 6.0, 4.0),
			Vector4(origin.x + 16.0, origin.z - 11.0, 6.0, 4.0),
			Vector4(origin.x - 16.0, origin.z + 11.0, 6.0, 4.0),
			Vector4(origin.x + 16.0, origin.z + 11.0, 6.0, 4.0),
			Vector4(origin.x, origin.z - 12.5, 4.0, 5.0),
			Vector4(origin.x, origin.z + 12.5, 4.0, 5.0),
		]


func _ready() -> void:
	var cream := _tile.duplicate() as StandardMaterial3D
	cream.albedo_color = Color(0.58, 0.58, 0.56)
	cream.roughness = 0.92
	_tile = cream
	_mold = cream.duplicate()
	(_mold as StandardMaterial3D).albedo_color = Color(0.48, 0.28, 0.16)
	_build_shell()
	_build_pool()
	_build_stairs()
	_build_pillars()
	_build_lights()
	_build_door_sign()
	_build_slide()


func contains(at: Vector3) -> bool:
	var local := at - global_position
	return absf(local.x) < WIDTH * 0.5 and absf(local.z) < DEPTH * 0.5 and local.y > -3.0


func spawn_point() -> Vector3:
	return global_position + Vector3(-WIDTH * 0.5 + 2.2, 0.05, 0.0)


func spawn_yaw() -> float:
	return -PI * 0.5


func ball_bounds() -> Rect2:
	var origin := Vector2(global_position.x, global_position.z)
	return Rect2(origin.x - WIDTH * 0.5 + 0.2, origin.y - DEPTH * 0.5 + 0.2, WIDTH - 0.4, DEPTH - 0.4)


func blocked_areas() -> Array[Rect2]:
	var origin := Vector2(global_position.x, global_position.z)
	var pool := Rect2(origin + POOL.position, POOL.size).grow(0.15)
	return [
		pool,
		Rect2(origin.x - WIDTH * 0.5, origin.y - DOOR_WIDTH * 0.5 - 0.3, 1.4, DOOR_WIDTH + 0.6),
	]


func _build_shell() -> void:
	var x := WIDTH * 0.5
	var z := DEPTH * 0.5
	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	csg.collision_layer = LevelKit.WORLD_LAYER
	csg.collision_mask = 0
	var slab := CSGBox3D.new()
	slab.size = Vector3(WIDTH, 0.4, DEPTH)
	slab.position = Vector3(0.0, -0.2, 0.0)
	slab.material = _floor
	csg.add_child(slab)
	var cut := CSGBox3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.size = Vector3(POOL.size.x, 1.2, POOL.size.y)
	cut.position = Vector3(POOL.get_center().x, 0.1, POOL.get_center().y)
	csg.add_child(cut)
	add_child(csg)
	# A solid deck under the tiles, so a gap in the pool shell cannot drop the player out of the map.
	LevelKit.collider(self, Vector3(WIDTH + 4.0, 0.5, DEPTH + 4.0), Vector3(0.0, -0.25, 0.0))
	_wall(-x - WALL, x + WALL, -z - WALL, -z)
	_wall(-x - WALL, x + WALL, z, z + WALL)
	_wall(x, x + WALL, -z, z)
	_wall(-x - WALL, -x, -z, -DOOR_WIDTH * 0.5)
	_wall(-x - WALL, -x, DOOR_WIDTH * 0.5, z)
	_wall(-x - WALL, -x, -DOOR_WIDTH * 0.5, DOOR_WIDTH * 0.5, DOOR_HEIGHT)
	LevelKit.box(self, Vector3(WIDTH + WALL * 2.0, 0.3, DEPTH + WALL * 2.0), Vector3(0.0, HEIGHT + 0.15, 0.0), _tile)


func _wall(x0: float, x1: float, z0: float, z1: float, from := 0.0, to := HEIGHT) -> void:
	var size := Vector3(x1 - x0, to - from, z1 - z0)
	if size.x < 0.01 or size.y < 0.01 or size.z < 0.01:
		return
	var centre := Vector3((x0 + x1) * 0.5, (from + to) * 0.5, (z0 + z1) * 0.5)
	LevelKit.box(self, size, centre, _tile)


func _build_pool() -> void:
	var half := POOL.size * 0.5
	var centre := Vector3(POOL.get_center().x, 0.0, POOL.get_center().y)
	LevelKit.box(self, Vector3(POOL.size.x + 0.4, absf(POOL_FLOOR), 0.25),
		centre + Vector3(0.0, POOL_FLOOR * 0.5, half.y + 0.05), _tile, false)
	LevelKit.box(self, Vector3(POOL.size.x + 0.4, absf(POOL_FLOOR), 0.25),
		centre + Vector3(0.0, POOL_FLOOR * 0.5, -half.y - 0.05), _tile, false)
	LevelKit.box(self, Vector3(0.25, absf(POOL_FLOOR), POOL.size.y),
		centre + Vector3(half.x + 0.05, POOL_FLOOR * 0.5, 0.0), _tile, false)
	LevelKit.box(self, Vector3(0.25, absf(POOL_FLOOR), POOL.size.y),
		centre + Vector3(-half.x - 0.05, POOL_FLOOR * 0.5, 0.0), _tile, false)
	LevelKit.box(self, Vector3(POOL.size.x, 0.2, POOL.size.y),
		Vector3(centre.x, POOL_FLOOR - 0.1, centre.z), _tile)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.15, 0.62, 0.58, 0.45)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.04
	water.metallic = 0.05
	water.clearcoat_enabled = true
	water.clearcoat = 0.65
	water.clearcoat_roughness = 0.12
	water.refraction_enabled = true
	water.refraction_scale = 0.04
	water.emission_enabled = true
	water.emission = Color(0.05, 0.22, 0.2)
	water.emission_energy_multiplier = 0.35
	_water = water
	var mesh := PlaneMesh.new()
	mesh.size = POOL.size
	var plane := MeshInstance3D.new()
	plane.mesh = mesh
	plane.position = Vector3(centre.x, -0.08, centre.z)
	plane.material_override = water
	add_child(plane)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.85
	ring.rings = 12
	ring.ring_segments = 24
	_ripple = MeshInstance3D.new()
	_ripple.mesh = ring
	_ripple.material_override = water
	_ripple.visible = false
	add_child(_ripple)


func _process(delta: float) -> void:
	_water_time += delta
	if _water != null:
		_water.uv1_offset.x = _water_time * 0.03
		_water.uv1_offset.y = sin(_water_time * 0.7) * 0.02
	if _ripple != null and _ripple.visible:
		_ripple_life -= delta
		var grow := 1.0 + (0.8 - _ripple_life) * 2.4
		_ripple.scale = Vector3(grow, 1.0, grow)
		if _ripple_life <= 0.0:
			_ripple.visible = false


func splash(at: Vector3) -> void:
	if _ripple == null:
		return
	_ripple.global_position = Vector3(at.x, -0.05, at.z)
	_ripple.scale = Vector3.ONE
	_ripple.visible = true
	_ripple_life = 0.8


func _build_stairs() -> void:
	var start := Vector3(POOL.get_center().x, 0.0, POOL.position.y)
	for n in 8:
		var t := float(n)
		var size := Vector3(3.2, 0.16, 0.55)
		var at := start + Vector3(0.0, -0.16 * (n + 1) * 0.5, 0.4 + n * 0.48)
		at.y = -0.16 * (n + 1)
		LevelKit.box(self, Vector3(size.x, 0.16, size.z), Vector3(at.x, at.y + 0.08, at.z), _tile)


func _build_pillars() -> void:
	for at: Vector2 in [Vector2(-6.0, -2.0), Vector2(6.0, -2.0), Vector2(-6.0, 4.0), Vector2(6.0, 4.0)]:
		var h := HEIGHT - POOL_FLOOR
		LevelKit.box(self, Vector3(1.1, h, 1.1), Vector3(at.x, POOL_FLOOR + h * 0.5, at.y), _tile)
		if at.x < 0.0:
			_pillar_eye(Vector3(at.x, 2.2, at.y + 0.56), 0.0)
			_pillar_eye(Vector3(at.x + 0.56, 2.2, at.y), PI * 0.5)


func _build_lights() -> void:
	for at: Vector3 in [Vector3(-10.0, 5.6, -8.0), Vector3(10.0, 5.6, -8.0), Vector3(-10.0, 5.6, 8.0), Vector3(10.0, 5.6, 8.0), Vector3(0.0, 5.8, 0.0)]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = Color(1.0, 0.98, 0.9)
		light.light_energy = 4.4
		light.omni_range = 16.0
		add_child(light)
	var housing := _tile.duplicate() as StandardMaterial3D
	var tube := LevelKit.glow(Color(0.9, 0.96, 0.92), 1.6)
	for at: Vector3 in [Vector3(-10.0, 6.7, -8.0), Vector3(10.0, 6.7, -8.0), Vector3(-10.0, 6.7, 8.0), Vector3(10.0, 6.7, 8.0), Vector3(0.0, 6.7, 0.0)]:
		LevelKit.box(self, Vector3(1.6, 0.08, 0.4), at, housing, false)
		LevelKit.box(self, Vector3(1.4, 0.02, 0.1), at + Vector3(0.0, -0.05, 0.0), tube, false)


func _build_door_sign() -> void:
	var x := -WIDTH * 0.5
	LevelKit.box(self, Vector3(0.05, 0.7, 2.6), Vector3(x + 0.08, 3.7, 0.0), _tile, false)
	var label := Label3D.new()
	label.text = "LEVEL 1   PLAYROOM"
	label.font = _sign_font
	label.font_size = 90
	label.pixel_size = 0.003
	label.position = Vector3(x + 0.12, 3.85, 0.0)
	label.rotation.y = PI * 0.5
	label.shaded = true
	label.double_sided = false
	label.outline_size = 8
	label.modulate = Color(0.12, 0.14, 0.16)
	add_child(label)
	var back := Label3D.new()
	back.text = "DEPOSIT BALLS HERE"
	back.font = _sign_font
	back.font_size = 64
	back.pixel_size = 0.003
	back.position = Vector3(x + 0.12, 3.45, 0.0)
	back.rotation.y = PI * 0.5
	back.shaded = true
	back.double_sided = false
	back.outline_size = 8
	back.modulate = Color(0.18, 0.5, 0.32)
	add_child(back)
	var probe := ReflectionProbe.new()
	probe.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	probe.size = Vector3(WIDTH, HEIGHT, DEPTH)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)


func _build_slide() -> void:
	var root := Node3D.new()
	root.name = "WaterSlide"
	root.position = Vector3(15.2, 0.0, 8.4)
	add_child(root)
	var rise := 0.18
	var run := 0.34
	for n in 16:
		var y := rise * float(n + 1)
		var z := -run * float(n)
		LevelKit.box(root, Vector3(1.6, rise, run), Vector3(0.0, y - rise * 0.5, z), _tile)
	var deck_y := rise * 16.0
	var deck_z := -run * 16.0
	LevelKit.box(root, Vector3(2.4, 0.16, 2.6), Vector3(-0.4, deck_y - 0.08, deck_z - 0.8), _tile)
	var rail := _paint(Color(0.72, 0.74, 0.76))
	rail.metallic = 0.4
	rail.roughness = 0.35
	var sides: Array[float] = [-0.85, 0.85]
	for side: float in sides:
		LevelKit.pipe(root, Vector3(side, 0.9, 0.2), Vector3(side, deck_y + 0.9, deck_z), 0.035, rail, 8)
	var points: Array[Vector3] = []
	var start := Vector3(-0.4, deck_y + 0.15, deck_z - 1.5)
	var end := Vector3(-15.2, -0.35, -6.2)
	for n in 28:
		var t := float(n) / 27.0
		var drop := t * t
		var sway := sin(t * PI) * 4.2
		points.append(Vector3(
			lerpf(start.x, end.x, t),
			lerpf(start.y, end.y, drop),
			lerpf(start.z, end.z, t) + sway
		))
	var path := Path3D.new()
	path.name = "Ride"
	var curve := Curve3D.new()
	curve.bake_interval = 0.08
	for p: Vector3 in points:
		curve.add_point(p)
	path.curve = curve
	root.add_child(path)
	var plastic := _paint(Color(0.16, 0.45, 0.82))
	plastic.roughness = 0.18
	plastic.metallic = 0.04
	plastic.clearcoat_enabled = true
	plastic.clearcoat = 0.55
	var poly := CSGPolygon3D.new()
	poly.mode = CSGPolygon3D.MODE_PATH
	poly.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	poly.path_interval = 0.12
	poly.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH
	poly.path_local = true
	poly.smooth_faces = true
	poly.material = plastic
	poly.polygon = _chute_profile()
	root.add_child(poly)
	poly.path_node = NodePath("../Ride")
	var mouth := Area3D.new()
	mouth.position = start + Vector3(0.0, 0.7, 0.35)
	mouth.collision_mask = 1
	mouth.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.5, 1.1)
	shape.shape = box
	mouth.add_child(shape)
	mouth.body_entered.connect(_on_slide_enter.bind(path))
	root.add_child(mouth)


func _on_slide_enter(body: Node, path: Path3D) -> void:
	if body is Player:
		(body as Player).start_slide(path)


func _chute_profile() -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(-0.55, 0.05))
	pts.append(Vector2(-0.62, 0.45))
	pts.append(Vector2(-0.4, 0.7))
	pts.append(Vector2(0.4, 0.7))
	pts.append(Vector2(0.62, 0.45))
	pts.append(Vector2(0.55, 0.05))
	return pts


func _pillar_eye(at: Vector3, yaw: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.28)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.88)
	mat.albedo_texture = _eye_tex()
	mat.roughness = 0.8
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.position = at
	node.rotation.y = yaw
	add_child(node)


func _eye_tex() -> ImageTexture:
	var image := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.86, 0.86, 0.84))
	var left := Vector2(20, 20)
	var right := Vector2(44, 20)
	for y in 40:
		for x in 64:
			var p := Vector2(x, y)
			if p.distance_to(left) < 8.0 or p.distance_to(right) < 8.0:
				image.set_pixel(x, y, Color(0.05, 0.05, 0.06))
			elif p.distance_to(left) < 11.0 or p.distance_to(right) < 11.0:
				image.set_pixel(x, y, Color(0.12, 0.12, 0.13))
	return ImageTexture.create_from_image(image)


func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	return material
