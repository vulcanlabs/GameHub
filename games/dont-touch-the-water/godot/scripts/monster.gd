extends Node3D

const TYPES := {
	"stalker": {"c": Color("0c0c10"), "s": 1.9, "roam": 2.5, "charge": 9.5, "tele": false},
	"crawler": {"c": Color("3a1214"), "s": 1.45, "roam": 3.5, "charge": 12.0, "tele": false},
	"beast": {"c": Color("10281c"), "s": 2.8, "roam": 2.0, "charge": 8.0, "tele": false},
	"shadow": {"c": Color("050505"), "s": 1.9, "roam": 2.5, "charge": 9.0, "tele": true},
}

const ROAM_Y := -0.35

var kind := "stalker"
var state := "roam"
var has_tgt := false
var tgt := Vector2.ZERO
var calm := 0.0
var stats: Dictionary = TYPES.stalker


func setup(type: String) -> void:
	kind = type if TYPES.has(type) else "stalker"
	stats = TYPES[kind]
	scale = Vector3.ONE * float(stats.s)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stats.c
	mat.roughness = 0.35
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	body.mesh = sphere
	body.material_override = mat
	body.scale = Vector3(1.15, 0.62, 2.8)
	body.position = Vector3(0, -0.05, 0.2)
	add_child(body)
	var fin := MeshInstance3D.new()
	var fin_mesh := PrismMesh.new()
	fin_mesh.size = Vector3(0.15, 0.9, 1.4)
	fin.mesh = fin_mesh
	fin.material_override = mat
	fin.position = Vector3(0, 0.55, 0.3)
	add_child(fin)
	var jaw := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.05
	cone.height = 1.8
	jaw.mesh = cone
	var mouth := StandardMaterial3D.new()
	mouth.albedo_color = Color("1a0505")
	mouth.roughness = 0.6
	jaw.material_override = mouth
	jaw.rotation.x = PI / 2.0
	jaw.position = Vector3(0, -0.2, -1.85)
	add_child(jaw)
	for i in 7:
		var tooth := MeshInstance3D.new()
		var spike := CylinderMesh.new()
		spike.top_radius = 0.01
		spike.bottom_radius = 0.07
		spike.height = 0.28
		tooth.mesh = spike
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color("f4efe6")
		tooth.material_override = tm
		var side := -1.0 if i < 4 else 1.0
		var along := float(i % 4) - 1.5
		tooth.position = Vector3(side * 0.28, -0.05, -2.35 - along * 0.12)
		tooth.rotation.x = -0.4
		add_child(tooth)
	for x in [-0.42, 0.42]:
		var eye := MeshInstance3D.new()
		var eyeball := SphereMesh.new()
		eyeball.radius = 0.22
		eyeball.height = 0.44
		eye.mesh = eyeball
		var em := StandardMaterial3D.new()
		em.albedo_color = Color("ff1208")
		em.emission_enabled = true
		em.emission = Color("ff1208")
		em.emission_energy_multiplier = 4.0
		eye.material_override = em
		eye.position = Vector3(x, 0.32, -1.55)
		add_child(eye)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff2010")
	glow.light_energy = 2.4
	glow.omni_range = 11.0
	glow.position = Vector3(0, 0.4, -1.3)
	add_child(glow)


func place_far(near: Vector3) -> void:
	var a := randf() * TAU
	var d := 16.0 + randf() * 10.0
	position = Vector3(near.x + cos(a) * d, ROAM_Y, near.z + sin(a) * d)
	scale = Vector3.ONE * float(stats.s)
	state = "roam"
	has_tgt = false
	calm = 0.0


func loom(player: Vector3, forward: Vector2) -> void:
	state = "kill"
	scale = Vector3.ONE * float(stats.s) * 1.55
	position = Vector3(player.x + forward.x * 1.7, 0.95, player.z + forward.y * 1.7)
	rotation.y = atan2(forward.x, forward.y)


func alert(player: Vector3) -> void:
	if stats.tele:
		var a := randf() * TAU
		position = Vector3(player.x + cos(a) * 10.0, ROAM_Y, player.z + sin(a) * 10.0)
	state = "charge"
	calm = 0.0


func step(player: Vector3, in_water: bool, dt: float, t: float) -> bool:
	if state == "kill":
		return false
	var caught := false
	var tx: float
	var tz: float
	var sp: float
	if state == "roam":
		if not has_tgt or Vector2(tgt.x - position.x, tgt.y - position.z).length() < 2.0:
			var a := randf() * TAU
			var d := 12.0 + randf() * 16.0
			tgt = Vector2(player.x + cos(a) * d, player.z + sin(a) * d)
			has_tgt = true
		tx = tgt.x
		tz = tgt.y
		sp = float(stats.roam)
		position.y = ROAM_Y + sin(t * 2.0) * 0.08
	else:
		tx = player.x
		tz = player.z
		sp = float(stats.charge)
		position.y = 0.15
		var dist := Vector2(tx - position.x, tz - position.z).length()
		if dist < 2.6:
			sp = 0.0
			if in_water:
				caught = true
			else:
				calm += dt
				if calm > 1.6:
					state = "roam"
					has_tgt = false
	var dx := tx - position.x
	var dz := tz - position.z
	var d := Vector2(dx, dz).length()
	if sp > 0.0 and d > 0.001:
		position.x += (dx / d) * sp * dt
		position.z += (dz / d) * sp * dt
		rotation.y = atan2(-dx, -dz)
	return caught
