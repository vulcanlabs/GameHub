# Every surface in the game gets its material here, so the look stays consistent across all levels.
# All of it is procedural (noise + shaders). There are no image textures in this project yet:
# swap in real texture sets here when you have them and every level picks them up.
extends RefCounted

static var _cache: Dictionary = {}


static func clear() -> void:
	_cache.clear()


static func noise(seed_value: int, frequency: float, as_normal := false, bump := 6.0, octaves := 5) -> NoiseTexture2D:
	var key := "noise:%d:%f:%s:%f:%d" % [seed_value, frequency, as_normal, bump, octaves]
	if _cache.has(key):
		return _cache[key]
	var tex := _noise_texture(seed_value, frequency, octaves)
	tex.as_normal_map = as_normal
	tex.bump_strength = bump
	_cache[key] = tex
	return tex


static func tinted_noise(seed_value: int, frequency: float, dark: Color, light: Color) -> NoiseTexture2D:
	var key := "tint:%d:%f:%s:%s" % [seed_value, frequency, dark.to_html(), light.to_html()]
	if _cache.has(key):
		return _cache[key]
	var ramp := Gradient.new()
	ramp.set_color(0, dark)
	ramp.set_color(1, light)
	var tex := _noise_texture(seed_value, frequency, 5)
	tex.color_ramp = ramp
	_cache[key] = tex
	return tex


static func _noise_texture(seed_value: int, frequency: float, octaves: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = frequency
	n.fractal_octaves = octaves
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = n
	return tex


static func shader(path: String, key: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	mat.set_shader_parameter("noise", noise(3, 0.04))
	_cache[key] = mat
	return mat


static func wallpaper(room_height: float) -> ShaderMaterial:
	var mat := shader("res://shaders/wallpaper.gdshader", "wallpaper")
	mat.set_shader_parameter("stain_noise", noise(5, 0.012, false, 6.0, 3))
	mat.set_shader_parameter("room_height", room_height)
	return mat


static func ceiling() -> ShaderMaterial:
	return shader("res://shaders/ceiling.gdshader", "ceiling")


# Old floor tiles for platform tops. Same family as the ceiling, with its own dirt.
static func floor_tile() -> ShaderMaterial:
	var mat := shader("res://shaders/floor_tile.gdshader", "floor_tile")
	mat.set_shader_parameter("noise", noise(21, 0.08, false, 4.0, 5))
	return mat


static func grass_blade() -> ShaderMaterial:
	var mat := shader("res://shaders/grass_blade.gdshader", "grass_blade")
	mat.set_shader_parameter("noise", noise(31, 0.16, false, 4.0, 4))
	return mat


static func grass_ground() -> ShaderMaterial:
	var mat := shader("res://shaders/grass_ground.gdshader", "grass_ground")
	mat.set_shader_parameter("noise", noise(33, 0.07, false, 4.0, 4))
	return mat


static func dirt() -> StandardMaterial3D:
	if _cache.has("dirt"):
		return _cache["dirt"]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tinted_noise(44, 0.09, Color(0.28, 0.18, 0.09), Color(0.52, 0.36, 0.16))
	mat.normal_enabled = true
	mat.normal_texture = noise(45, 0.08, true, 4.0)
	mat.normal_scale = 0.7
	mat.roughness = 0.96
	_cache["dirt"] = mat
	return mat


static func dirt_dark() -> StandardMaterial3D:
	if _cache.has("dirt_dark"):
		return _cache["dirt_dark"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.05, 0.03)
	mat.roughness = 1.0
	_cache["dirt_dark"] = mat
	return mat


static func field() -> StandardMaterial3D:
	if _cache.has("field"):
		return _cache["field"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.42, 0.16)
	mat.roughness = 0.95
	_cache["field"] = mat
	return mat


# Worn concrete for platform slabs.
static func concrete() -> StandardMaterial3D:
	if _cache.has("concrete"):
		return _cache["concrete"]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tinted_noise(11, 0.012, Color(0.33, 0.32, 0.29), Color(0.52, 0.50, 0.45))
	mat.normal_enabled = true
	mat.normal_texture = noise(12, 0.05, true, 3.0)
	mat.normal_scale = 0.6
	mat.roughness = 0.92
	_world_triplanar(mat, 0.35)
	_cache["concrete"] = mat
	return mat


# Rusted steel for poles, frames, light housings.
static func steel() -> StandardMaterial3D:
	if _cache.has("steel"):
		return _cache["steel"]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tinted_noise(21, 0.06, Color(0.07, 0.065, 0.06), Color(0.34, 0.17, 0.08))
	mat.normal_enabled = true
	mat.normal_texture = noise(22, 0.12, true, 3.0)
	mat.metallic = 0.75
	mat.roughness = 0.58
	_world_triplanar(mat, 0.9)
	_cache["steel"] = mat
	return mat


static func baseboard() -> StandardMaterial3D:
	if _cache.has("baseboard"):
		return _cache["baseboard"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.09, 0.05)
	mat.roughness = 0.6
	_cache["baseboard"] = mat
	return mat


# One shared material for every steady light panel. Flickering panels get their own copy.
static func light_panel() -> StandardMaterial3D:
	if _cache.has("light_panel"):
		return _cache["light_panel"]
	var mat := new_light_panel()
	_cache["light_panel"] = mat
	return mat


static func new_light_panel() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.82, 0.68)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.93, 0.70)
	mat.emission_energy_multiplier = 2.6
	return mat


static func dead_light_panel() -> StandardMaterial3D:
	if _cache.has("dead_light_panel"):
		return _cache["dead_light_panel"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.28, 0.20)
	mat.roughness = 0.4
	_cache["dead_light_panel"] = mat
	return mat


# Insect shell: glossy, with a fine grain that follows the body part.
static func chitin(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "chitin:%s:%f" % [color.to_html(), roughness]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = tinted_noise(31, 0.02, Color(0.62, 0.58, 0.58), Color(1, 1, 1))
	mat.normal_enabled = true
	mat.normal_texture = noise(32, 0.03, true, 2.0, 3)
	mat.normal_scale = 0.35
	mat.roughness = roughness
	mat.metallic = 0.1
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.25
	mat.clearcoat_roughness = 0.5
	mat.rim_enabled = true
	mat.rim = 0.3
	mat.rim_tint = 0.7
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.8, 0.8, 0.8)
	_cache[key] = mat
	return mat


static func _world_triplanar(mat: StandardMaterial3D, scale: float) -> void:
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(scale, scale, scale)
