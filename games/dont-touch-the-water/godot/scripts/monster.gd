extends Node3D

const TYPES := {
	"stalker": {"c": Color("1b1b22"), "s": 1.5, "roam": 2.5, "charge": 8.5, "tele": false},
	"crawler": {"c": Color("5a2323"), "s": 1.1, "roam": 3.5, "charge": 11.5, "tele": false},
	"beast": {"c": Color("1d4630"), "s": 2.4, "roam": 2.0, "charge": 7.5, "tele": false},
	"shadow": {"c": Color("050505"), "s": 1.6, "roam": 2.5, "charge": 8.0, "tele": true},
}

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
	mat.roughness = 0.8
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	body.mesh = sphere
	body.material_override = mat
	body.scale = Vector3(1.35, 0.75, 2.4)
	body.position.y = -0.15
	add_child(body)
	var jaw := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.15
	cone.bottom_radius = 0.9
	cone.height = 1.6
	jaw.mesh = cone
	jaw.material_override = mat
	jaw.rotation.x = PI / 2.0
	jaw.position = Vector3(0, -0.35, -1.7)
	add_child(jaw)
	for x in [-0.55, 0.55]:
		var eye := MeshInstance3D.new()
		var eyeball := SphereMesh.new()
		eyeball.radius = 0.28
		eyeball.height = 0.56
		eye.mesh = eyeball
		var em := StandardMaterial3D.new()
		em.albedo_color = Color("ff1a0a")
		em.emission_enabled = true
		em.emission = Color("ff1a0a")
		eye.material_override = em
		eye.position = Vector3(x, 0.25, -1.85)
		add_child(eye)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff3020")
	glow.light_energy = 0.6
	glow.omni_range = 8.0
	glow.position = Vector3(0, 0.2, -1.2)
	add_child(glow)


func place_far(near: Vector3) -> void:
	var a := randf() * TAU
	var d := 16.0 + randf() * 10.0
	position = Vector3(near.x + cos(a) * d, -1.1, near.z + sin(a) * d)
	state = "roam"
	has_tgt = false
	calm = 0.0


func alert(player: Vector3) -> void:
	if stats.tele:
		var a := randf() * TAU
		position = Vector3(player.x + cos(a) * 10.0, -1.1, player.z + sin(a) * 10.0)
	state = "charge"
	calm = 0.0


func step(player: Vector3, in_water: bool, dt: float, t: float) -> bool:
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
		position.y = -1.1 + sin(t * 2.0) * 0.08
	else:
		tx = player.x
		tz = player.z
		sp = float(stats.charge)
		position.y = -0.85
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
