class_name BallFlyers
extends Node3D
## Balls in the air: on their way into the nozzle, or pouring out of it into the pit.
##
## These are a picture of the transfer, not the transfer. The counts change the moment a ball is collected or
## deposited. At most CAPACITY balls are in flight at once; when more are moving than that (unloading runs at
## thousands a second) the stream shows a sample of them.

const CAPACITY := 640
const SUCK_SPEED := 15.0                    # m/s a collected ball averages on its way to the nozzle
const POUR_TIME := 0.55                     # seconds from nozzle to pit

## Where sucked balls fly to. Set by the vacuum; called every frame because the nozzle moves with the camera.
var suction_point: Callable

var _multimesh: MultiMesh
var _count := 0
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _pouring := PackedByteArray()
var _color := PackedColorArray()


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = BallManager.BALL_RADIUS
	mesh.height = BallManager.BALL_RADIUS * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = preload("res://assets/materials/ball_plastic.tres")
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = mesh
	_multimesh.instance_count = CAPACITY
	_multimesh.visible_instance_count = 0
	# Flying balls can be anywhere in the level, so the culling box covers all of it.
	_multimesh.custom_aabb = AABB(Vector3(-200.0, -20.0, -200.0), Vector3(400.0, 60.0, 400.0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = _multimesh
	node.layers = 2
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_from.resize(CAPACITY)
	_to.resize(CAPACITY)
	_age.resize(CAPACITY)
	_life.resize(CAPACITY)
	_pouring.resize(CAPACITY)
	_color.resize(CAPACITY)


func active() -> int:
	return _count


func clear() -> void:
	_count = 0
	_multimesh.visible_instance_count = 0


## A ball that was just collected at `from`. It flies to the nozzle and vanishes.
func add_sucked(from: Vector3, color: Color) -> void:
	if not suction_point.is_valid():
		return
	var distance: float = from.distance_to(suction_point.call())
	_add(from, from, clampf(distance / SUCK_SPEED, 0.12, 0.34), false, color)


## A ball leaving the nozzle at `from` and landing in the pit at `to`.
func add_poured(from: Vector3, to: Vector3, color: Color) -> void:
	_add(from, to, POUR_TIME, true, color)


func _add(from: Vector3, to: Vector3, life: float, pouring: bool, color: Color) -> void:
	if _count >= CAPACITY:
		return
	var slot := _count
	_from[slot] = from
	_to[slot] = to
	_age[slot] = 0.0
	_life[slot] = life
	_pouring[slot] = 1 if pouring else 0
	_color[slot] = color
	_multimesh.set_instance_color(slot, color)
	_count += 1


func _process(delta: float) -> void:
	if _count == 0:
		return
	var nozzle := Vector3.ZERO
	if suction_point.is_valid():
		nozzle = suction_point.call()
	var slot := 0
	while slot < _count:
		var age := _age[slot] + delta
		if age >= _life[slot]:
			_remove(slot)
			continue
		_age[slot] = age
		var t := age / _life[slot]
		var at: Vector3
		var size := 1.0
		if _pouring[slot] == 1:
			at = _from[slot].lerp(_to[slot], t)
			at.y += sin(t * PI) * 0.45
		else:
			# Slow lift off the pile, then a fast pull into the nozzle, shrinking as it enters.
			var pull := t * t
			at = _from[slot].lerp(nozzle, pull)
			at.y += sin(t * PI) * 0.1
			size = 1.0 - 0.3 * pull
		_multimesh.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3(size, size, size)), at))
		slot += 1
	_multimesh.visible_instance_count = _count


func _remove(slot: int) -> void:
	var last := _count - 1
	if slot != last:
		_from[slot] = _from[last]
		_to[slot] = _to[last]
		_age[slot] = _age[last]
		_life[slot] = _life[last]
		_pouring[slot] = _pouring[last]
		_color[slot] = _color[last]
		_multimesh.set_instance_color(slot, _color[last])
	_count = last
