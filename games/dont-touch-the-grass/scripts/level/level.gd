# Builds one level from a level_data.gd entry: room, grass, platforms, finish pad, monster navigation, monsters.
extends Node3D

const RoomScript = preload("res://scripts/level/backrooms_room.gd")
const GrassFieldScript = preload("res://scripts/level/grass_field.gd")
const GrassHazardScript = preload("res://scripts/level/grass_hazard.gd")
const PlatformScript = preload("res://scripts/level/platform.gd")
const FinishZoneScript = preload("res://scripts/level/finish_zone.gd")

# Add new monster kinds here (the spider goes in this list later).
const ENEMY_TYPES := {
	"ant": preload("res://scripts/enemies/ant.gd"),
}

# Monsters keep this far from walls and poles, and need this much headroom to walk under a platform.
const NAV_AGENT_RADIUS := 0.5
const NAV_AGENT_HEIGHT := 0.75

var data: Dictionary
var room: Node3D
var grass: Node3D
var hazard: Area3D
var finish: Area3D
var platforms: Array[StaticBody3D] = []
var enemies: Array[CharacterBody3D] = []
var nav_region: NavigationRegion3D


func build(level_data: Dictionary) -> void:
	data = level_data
	room = RoomScript.new()
	room.name = "Room"
	add_child(room)
	room.build(data)

	var blockers: Array[Rect2] = room.blockers.duplicate()
	for entry: Dictionary in data["platforms"]:
		var platform := PlatformScript.new()
		add_child(platform)
		platform.build(entry["at"], entry["size"], entry["top"])
		platforms.append(platform)
		blockers.append(platform.pole_rect())

	var area: Rect2 = room.floor_rect()
	grass = GrassFieldScript.new()
	grass.name = "GrassField"
	add_child(grass)
	grass.build(area, blockers)

	hazard = GrassHazardScript.new()
	hazard.name = "GrassHazard"
	add_child(hazard)
	hazard.build(area)

	var last := platforms[-1]
	finish = FinishZoneScript.new()
	finish.name = "FinishZone"
	finish.position = last.top_center()
	add_child(finish)
	finish.build(minf(last.size.x, last.size.y) * 0.6)

	_bake_navigation(area, blockers)


# Where the player's feet go at the start of the level.
func start_position() -> Vector3:
	return platforms[0].top_center()


# Face the second platform.
func start_yaw() -> float:
	var to: Vector3 = platforms[1].top_center() - platforms[0].top_center()
	return atan2(-to.x, -to.z)


func spawn_enemies(player: CharacterBody3D, chase: Node) -> void:
	for entry: Dictionary in data.get("enemies", []):
		spawn_enemy(entry["type"], entry["at"], player, chase)


# Also the entry point for stream actions later ("spawn a giant ant").
func spawn_enemy(type: String, at: Vector2, player: CharacterBody3D, chase: Node) -> CharacterBody3D:
	var enemy: CharacterBody3D = ENEMY_TYPES[type].new()
	add_child(enemy)
	enemy.setup(player, chase, Vector3(at.x, 0.0, at.y))
	enemies.append(enemy)
	return enemy


# Monsters path-find on a flat map of the floor with holes cut for walls, pillars and poles.
# Platform slabs are left out on purpose: monsters walk under them.
func _bake_navigation(area: Rect2, blockers: Array[Rect2]) -> void:
	var mesh := NavigationMesh.new()
	mesh.agent_radius = NAV_AGENT_RADIUS
	mesh.agent_height = NAV_AGENT_HEIGHT
	var source := NavigationMeshSourceGeometryData3D.new()
	var a := Vector3(area.position.x, 0.0, area.position.y)
	var b := Vector3(area.end.x, 0.0, area.position.y)
	var c := Vector3(area.end.x, 0.0, area.end.y)
	var d := Vector3(area.position.x, 0.0, area.end.y)
	source.add_faces(PackedVector3Array([a, b, c, a, c, d]), Transform3D.IDENTITY)
	for rect in blockers:
		var outline := PackedVector3Array([
			Vector3(rect.position.x, 0.0, rect.position.y),
			Vector3(rect.end.x, 0.0, rect.position.y),
			Vector3(rect.end.x, 0.0, rect.end.y),
			Vector3(rect.position.x, 0.0, rect.end.y),
		])
		source.add_projected_obstruction(outline, -0.5, 3.0, false)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	nav_region.navigation_mesh = mesh
	add_child(nav_region)
