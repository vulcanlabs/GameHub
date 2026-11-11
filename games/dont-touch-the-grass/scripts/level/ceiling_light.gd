# One fluorescent ceiling panel. Three kinds: steady, flickering, dead.
# The node sits at ceiling height; the panel hangs just below it and a spotlight shines straight down.
extends Node3D

const Materials = preload("res://scripts/materials.gd")

enum Mode { ON, FLICKER, DEAD }

const ENERGY := 4.5
const PANEL_GLOW := 2.6

var mode := Mode.ON
var _lamp: SpotLight3D
var _panel_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _lit := true
var _next := 0.0


func build(p_mode: Mode, seed_value: int) -> void:
	mode = p_mode
	_rng.seed = seed_value
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.24, 0.05, 0.64)
	frame.mesh = frame_mesh
	frame.material_override = Materials.steel()
	frame.position.y = -0.025
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frame)

	var panel := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(1.14, 0.02, 0.54)
	panel.mesh = panel_mesh
	panel.position.y = -0.055
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)

	if mode == Mode.DEAD:
		panel.material_override = Materials.dead_light_panel()
		set_process(false)
		return
	_panel_mat = Materials.new_light_panel() if mode == Mode.FLICKER else Materials.light_panel()
	panel.material_override = _panel_mat

	_lamp = SpotLight3D.new()
	_lamp.position.y = -0.12
	_lamp.rotation_degrees.x = -90.0
	_lamp.light_color = Color(1.0, 0.91, 0.66)
	_lamp.light_energy = ENERGY
	# Kept tight on purpose: every extra lamp that reaches a spot on the floor costs frame rate there.
	_lamp.spot_range = 9.0
	_lamp.spot_angle = 54.0
	_lamp.spot_angle_attenuation = 0.7
	_lamp.spot_attenuation = 1.3
	_lamp.shadow_enabled = true
	_lamp.shadow_bias = 0.06
	_lamp.light_volumetric_fog_energy = 1.4
	add_child(_lamp)
	set_process(mode == Mode.FLICKER)


func _process(delta: float) -> void:
	_next -= delta
	if _next > 0.0:
		return
	_lit = not _lit
	if _lit:
		# Either a quick stutter or a longer stretch of working normally.
		_next = _rng.randf_range(0.04, 0.12) if _rng.randf() < 0.55 else _rng.randf_range(0.6, 3.5)
	else:
		_next = _rng.randf_range(0.03, 0.16)
	var level := 1.0 if _lit else 0.05
	_lamp.light_energy = ENERGY * level
	_panel_mat.emission_energy_multiplier = PANEL_GLOW * level
