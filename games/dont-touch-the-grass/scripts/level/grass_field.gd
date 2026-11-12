# The grass you see: a ground plane plus MultiMesh tufts.
# Outdoor ground is huge. Blades spawn only in chunks near the camera.
# This is only the picture. Touching it is detected by grass_hazard.gd.
extends Node3D

const Materials = preload("res://scripts/materials.gd")

const TUFTS_PER_M2 := 34.0
const BLADES_PER_TUFT := 8
const CHUNK := 4.0
const DRAW_DISTANCE := 28.0
const DRAW_FADE := 6.0

# The route test turns this off so it does not rebuild every blade on all 50 levels.
static var dense := true

var blade_count := 0
var _blade_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _hills: Array = []
var _area := Rect2()
var _blocked: Array[Rect2] = []
var _tuft: ArrayMesh
var _chunks: Dictionary = {}
var _last_cell := Vector2i(9999, 9999)


# `area` is where blades grow. `core` is unused for density now; the camera drives which squares exist.
func build(area: Rect2, blocked: Array[Rect2], _core := Rect2(), p_hills: Array = []) -> void:
	_rng.seed = 7
	_hills = p_hills
	_area = area
	_blocked = blocked
	_ground(area)
	set_process(false)
	if dense:
		_blade_mat = Materials.grass_blade()
		_tuft = _tuft_mesh()
		set_process(true)
		_refresh(Vector2.ZERO)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_refresh(Vector2(cam.global_position.x, cam.global_position.z))


# 0 = calm, 1 = the whole floor shivers. Driven by the chase.
func set_stir(amount: float) -> void:
	if _blade_mat == null:
		return
	_blade_mat.set_shader_parameter("stir", amount)


func _ground(area: Rect2) -> void:
	var mesh_i := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = area.size
	mesh_i.mesh = plane
	mesh_i.material_override = Materials.grass_ground()
	var center := area.get_center()
	mesh_i.position = Vector3(center.x, 0.0, center.y)
	add_child(mesh_i)


func _refresh(at: Vector2) -> void:
	var cell := Vector2i(((at - _area.position) / CHUNK).floor())
	if cell == _last_cell and not _chunks.is_empty():
		return
	_last_cell = cell
	var reach := ceili(DRAW_DISTANCE / CHUNK)
	var keep: Dictionary = {}
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var next := cell + Vector2i(dx, dz)
			var origin := _area.position + Vector2(next) * CHUNK
			var square := Rect2(origin, Vector2(CHUNK, CHUNK))
			if not _area.intersects(square):
				continue
			keep[next] = true
			if not _chunks.has(next):
				_spawn(next, square)
	for old: Vector2i in _chunks.keys():
		if keep.has(old):
			continue
		(_chunks[old] as Node).queue_free()
		_chunks.erase(old)
	blade_count = _chunks.size() * int(CHUNK * CHUNK * TUFTS_PER_M2) * BLADES_PER_TUFT


func _spawn(cell: Vector2i, square: Rect2) -> void:
	var clipped := Rect2(
		Vector2(maxf(square.position.x, _area.position.x), maxf(square.position.y, _area.position.y)),
		Vector2.ZERO
	)
	clipped.end = Vector2(minf(square.end.x, _area.end.x), minf(square.end.y, _area.end.y))
	if clipped.size.x <= 0.05 or clipped.size.y <= 0.05:
		return
	var count := maxi(4, int(clipped.get_area() * TUFTS_PER_M2))
	var transforms: Array = []
	_rng.seed = 7 + cell.x * 131 + cell.y * 9176
	for i in count:
		var at := _free_spot(clipped)
		var h := _rng.randf_range(0.22, 0.46)
		var w := _rng.randf_range(0.8, 1.3)
		var xf := Transform3D.IDENTITY
		xf = xf.scaled(Vector3(w, h, w))
		xf = xf.rotated(Vector3.UP, _rng.randf() * TAU)
		xf.origin = Vector3(at.x, _height_at(at), at.y)
		transforms.append(xf)
	_skirt(transforms, clipped)
	if transforms.is_empty():
		return
	var center := clipped.get_center()
	var chunk := _chunk(transforms, center)
	chunk.visibility_range_end = DRAW_DISTANCE
	chunk.visibility_range_end_margin = DRAW_FADE
	_chunks[cell] = chunk


func _chunk(transforms: Array, center: Vector2) -> MultiMeshInstance3D:
	var origin := Vector3(center.x, 0.0, center.y)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tuft
	mm.instance_count = transforms.size()
	for i in transforms.size():
		var xf: Transform3D = transforms[i]
		xf.origin -= origin
		mm.set_instance_transform(i, xf)
	mm.visible_instance_count = transforms.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = origin
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = _blade_mat
	add_child(mmi)
	return mmi


func _free_spot(zone: Rect2) -> Vector2:
	var at := Vector2.ZERO
	for attempt in 8:
		at = Vector2(
			_rng.randf_range(zone.position.x, zone.end.x),
			_rng.randf_range(zone.position.y, zone.end.y)
		)
		var inside := false
		for rect in _blocked:
			if rect.has_point(at):
				inside = true
				break
		if not inside:
			break
	return at


func _skirt(transforms: Array, square: Rect2) -> void:
	for hill in _hills:
		var center: Vector2 = hill["at"]
		var radius: float = hill["radius"]
		if center.distance_to(square.get_center()) > radius + CHUNK:
			continue
		var extra := maxi(8, int(TAU * radius * 1.2))
		for i in extra:
			var ang := _rng.randf() * TAU
			var dist := radius * _rng.randf_range(0.72, 1.08)
			var at := center + Vector2(cos(ang), sin(ang)) * dist
			if not square.has_point(at):
				continue
			var blocked := false
			for rect in _blocked:
				if rect.has_point(at):
					blocked = true
					break
			if blocked:
				continue
			var h := _rng.randf_range(0.18, 0.38)
			var w := _rng.randf_range(0.9, 1.4)
			var xf := Transform3D.IDENTITY
			xf = xf.scaled(Vector3(w, h, w))
			xf = xf.rotated(Vector3.UP, _rng.randf() * TAU)
			xf.origin = Vector3(at.x, _height_at(at), at.y)
			transforms.append(xf)


func _height_at(at: Vector2) -> float:
	var y := 0.0
	for hill in _hills:
		var center: Vector2 = hill["at"]
		var radius: float = hill["radius"]
		var height: float = hill["height"]
		var d := at.distance_to(center)
		if d >= radius:
			continue
		var t := 1.0 - d / radius
		y = maxf(y, height * t)
	return y


func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BLADES_PER_TUFT:
		var yaw := float(i) / float(BLADES_PER_TUFT) * TAU + 0.11
		var lean := 0.08 + float(i % 5) * 0.07
		var width := 0.008 + float(i % 3) * 0.003
		var offset := Vector3(cos(yaw * 1.7), 0.0, sin(yaw * 1.7)) * (0.04 + float(i % 3) * 0.035)
		_blade(st, yaw, lean, width, offset)
	return st.commit()


# One blade: a tapered strip that curves outward, made of a quad and a tip. UV.y runs 0 at the root to 1 at the tip.
func _blade(st: SurfaceTool, yaw: float, lean: float, width: float, offset: Vector3) -> void:
	var turn := Basis.from_euler(Vector3(0.0, yaw, 0.0))
	var root_l := offset + turn * Vector3(-width, 0.0, 0.0)
	var root_r := offset + turn * Vector3(width, 0.0, 0.0)
	var mid_l := offset + turn * Vector3(-width * 0.55, 0.58, lean * 0.35)
	var mid_r := offset + turn * Vector3(width * 0.55, 0.58, lean * 0.35)
	var tip := offset + turn * Vector3(0.0, 1.0, lean * 1.15)
	_vertex(st, root_l, 0.0)
	_vertex(st, root_r, 0.0)
	_vertex(st, mid_r, 0.55)
	_vertex(st, root_l, 0.0)
	_vertex(st, mid_r, 0.55)
	_vertex(st, mid_l, 0.55)
	_vertex(st, mid_l, 0.55)
	_vertex(st, mid_r, 0.55)
	_vertex(st, tip, 1.0)


func _vertex(st: SurfaceTool, at: Vector3, v: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0.5, v))
	st.add_vertex(at)
