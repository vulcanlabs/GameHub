# The grass you see: a dark ground plane plus a MultiMesh of solid grass tufts across the whole room.
# This is only the picture. Touching it is detected by grass_hazard.gd.
extends Node3D

const Materials = preload("res://scripts/materials.gd")

const TUFTS_PER_M2 := 34.0
const BLADES_PER_TUFT := 8
# The field is cut into squares this size so squares behind the camera are not drawn.
const CHUNK := 4.0
# Squares further than this from the camera are drawn with fewer, wider tufts. The fog hides the difference.
const FAR_DISTANCE := 13.0
const FAR_KEEP_EVERY := 5
const FAR_WIDEN := 2.3

# The route test turns this off so it does not rebuild every blade on all 50 levels.
static var dense := true

var blade_count := 0
var _blade_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


# `area` is the floor. No grass grows inside the `blocked` footprints (walls, pillars, poles).
func build(area: Rect2, blocked: Array[Rect2]) -> void:
	_rng.seed = 7
	_ground(area)
	if dense:
		_blades(area, blocked)


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


func _blades(area: Rect2, blocked: Array[Rect2]) -> void:
	var count := int(area.get_area() * TUFTS_PER_M2)
	var chunks := {}
	for i in count:
		var at := _free_spot(area, blocked)
		var h := _rng.randf_range(0.22, 0.46)
		var w := _rng.randf_range(0.8, 1.3)
		var xf := Transform3D.IDENTITY
		xf = xf.scaled(Vector3(w, h, w))
		xf = xf.rotated(Vector3.UP, _rng.randf() * TAU)
		xf.origin = Vector3(at.x, 0.0, at.y)
		var cell := Vector2i(((at - area.position) / CHUNK).floor())
		if not chunks.has(cell):
			chunks[cell] = []
		chunks[cell].append(xf)
	var tuft := _tuft()
	_blade_mat = Materials.grass_blade()
	for cell: Vector2i in chunks:
		var transforms: Array = chunks[cell]
		var center := area.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CHUNK
		# Close up: every tuft. Far away: one tuft in FAR_KEEP_EVERY, drawn wider so the floor stays covered.
		var far: Array = []
		for i in range(0, transforms.size(), FAR_KEEP_EVERY):
			var xf: Transform3D = transforms[i]
			far.append(Transform3D(xf.basis * Basis.from_scale(Vector3(FAR_WIDEN, 1.0, FAR_WIDEN)), xf.origin))
		var near_chunk := _chunk(tuft, transforms, center)
		near_chunk.visibility_range_end = FAR_DISTANCE
		var far_chunk := _chunk(tuft, far, center)
		far_chunk.visibility_range_begin = FAR_DISTANCE
	blade_count = count * BLADES_PER_TUFT


# One square of grass. The node sits at the square's centre because the near/far switch measures from there.
func _chunk(tuft: Mesh, transforms: Array, center: Vector2) -> MultiMeshInstance3D:
	var origin := Vector3(center.x, 0.0, center.y)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tuft
	mm.instance_count = transforms.size()
	for i in transforms.size():
		var xf: Transform3D = transforms[i]
		xf.origin -= origin
		mm.set_instance_transform(i, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = origin
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = _blade_mat
	add_child(mmi)
	return mmi


func _free_spot(area: Rect2, blocked: Array[Rect2]) -> Vector2:
	var at := Vector2.ZERO
	for attempt in 8:
		at = Vector2(
			_rng.randf_range(area.position.x, area.end.x),
			_rng.randf_range(area.position.y, area.end.y)
		)
		var inside := false
		for rect in blocked:
			if rect.has_point(at):
				inside = true
				break
		if not inside:
			break
	return at


func _tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BLADES_PER_TUFT:
		var yaw := float(i) / float(BLADES_PER_TUFT) * TAU + 0.11
		var lean := 0.12 + float(i % 4) * 0.11
		var width := 0.016 + float(i % 3) * 0.004
		var offset := Vector3(cos(yaw * 1.7), 0.0, sin(yaw * 1.7)) * (0.04 + float(i % 3) * 0.035)
		_blade(st, yaw, lean, width, offset)
	return st.commit()


# One blade: a tapered strip that curves outward, made of a quad and a tip. UV.y runs 0 at the root to 1 at the tip.
func _blade(st: SurfaceTool, yaw: float, lean: float, width: float, offset: Vector3) -> void:
	var turn := Basis.from_euler(Vector3(0.0, yaw, 0.0))
	var root_l := offset + turn * Vector3(-width, 0.0, 0.0)
	var root_r := offset + turn * Vector3(width, 0.0, 0.0)
	var mid_l := offset + turn * Vector3(-width * 0.75, 0.55, lean * 0.4)
	var mid_r := offset + turn * Vector3(width * 0.75, 0.55, lean * 0.4)
	var tip := offset + turn * Vector3(0.0, 1.0 - lean * 0.3, lean * 1.5)
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
