extends Node
## Player preferences. Stored in user://settings.cfg, apart from run saves, so a run reset never touches them.
##
## Read with Settings.get_value("camera", "fov"). Write with Settings.set_value(...): the value is clamped,
## applied at once, announced through `changed`, and written to disk shortly after.
##
## Window, frame pacing and anti-aliasing are applied here. Everything that belongs to a scene (field of view,
## shadows, the centre dot, bus volumes) is applied by the node that owns it when `changed` fires.

signal changed(section: String, key: String)

const VERSION := 1

const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const FPS_CAPS := [0, 30, 60, 90, 120, 144, 240]

enum Quality { LOW, MEDIUM, HIGH, ULTRA }
enum Shadows { OFF, LOW, HIGH }
enum AntiAliasing { OFF, FXAA, MSAA_2X, MSAA_4X, TAA }

const DEFAULTS := {
	"graphics": {
		"resolution": "1920x1080",
		"fullscreen": true,
		"quality": Quality.HIGH,
		"shadows": Shadows.HIGH,
		"ambient_occlusion": true,
		"anti_aliasing": AntiAliasing.MSAA_2X,
		"render_scale": 1.0,
		"vsync": true,
		"fps_cap": 0,
	},
	"camera": {
		"fov": 90.0,
		"mouse_sensitivity": 0.5,
		"head_bob": true,
		"camera_shake": true,
		"dot_visible": true,
		"dot_size": 3.0,
		"dot_opacity": 0.35,
		"dot_color": Color.WHITE,
	},
	"audio": {
		"master": 0.8,
		"music": 0.6,
		"footsteps": 0.75,
		"vacuum": 0.65,
		"balls": 0.7,
		"environment": 0.5,
		"alerts": 0.8,
		"monster": 0.7,
	},
}

## [min, max] for every numeric setting. Values outside are clamped on load and on write.
const RANGES := {
	"graphics/quality": [0, 3],
	"graphics/shadows": [0, 2],
	"graphics/anti_aliasing": [0, 4],
	"graphics/render_scale": [0.5, 1.0],
	"graphics/fps_cap": [0, 240],
	"camera/fov": [60.0, 120.0],
	"camera/mouse_sensitivity": [0.05, 2.0],
	"camera/dot_size": [1.0, 12.0],
	"camera/dot_opacity": [0.05, 1.0],
}

## The 3D view is drawn at about this many lines unless the player raises the render scale. On a high-density
## screen (a 4K monitor, a Retina laptop) drawing every pixel costs several times more than 1080p does.
const COMFORTABLE_LINES := 1080.0

## What each quality preset sets. Picking a preset writes these; each can still be changed on its own afterwards.
## Render scale is a ceiling for Low, Medium and High (see auto_render_scale); Ultra draws every pixel.
const PRESETS := [
	{"shadows": Shadows.OFF, "ambient_occlusion": false, "anti_aliasing": AntiAliasing.OFF, "render_scale": 0.75},
	{"shadows": Shadows.LOW, "ambient_occlusion": false, "anti_aliasing": AntiAliasing.FXAA, "render_scale": 1.0},
	{"shadows": Shadows.HIGH, "ambient_occlusion": true, "anti_aliasing": AntiAliasing.MSAA_2X, "render_scale": 1.0},
	{"shadows": Shadows.HIGH, "ambient_occlusion": true, "anti_aliasing": AntiAliasing.MSAA_4X, "render_scale": 1.0},
]

var path := "user://settings.cfg"
## False under the automatic test and the screenshot tool, which bring their own window size.
var manage_window := true

var _values := {}
var _save_wait := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg == "--playtest" or arg.begins_with("--shots") or arg == "--perf":
			manage_window = false
			path = "user://settings_dev.cfg"
	_values = DEFAULTS.duplicate(true)
	_values["graphics"]["render_scale"] = auto_render_scale()
	if manage_window:
		load_file()
	_apply_all_graphics()


func _process(delta: float) -> void:
	if _save_wait < 0.0:
		return
	_save_wait -= delta
	if _save_wait < 0.0:
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _save_wait >= 0.0:
		save()


func get_value(section: String, key: String) -> Variant:
	return _values[section][key]


func set_value(section: String, key: String, value: Variant) -> void:
	if not DEFAULTS.has(section) or not DEFAULTS[section].has(key):
		push_warning("Unknown setting %s/%s" % [section, key])
		return
	var clean: Variant = _clean(section, key, value)
	if clean == null or _same(clean, _values[section][key]):
		return
	var scale_before := auto_render_scale()
	_values[section][key] = clean
	if section == "graphics":
		if key == "quality":
			var preset: Dictionary = PRESETS[clean]
			for preset_key: String in preset:
				var wanted: Variant = preset[preset_key]
				if preset_key == "render_scale" and clean != Quality.ULTRA:
					wanted = minf(wanted, auto_render_scale())
				set_value("graphics", preset_key, wanted)
		_apply_graphics(key)
		# A render scale the player never changed follows the window when it changes size.
		if (key == "fullscreen" or key == "resolution") and is_equal_approx(get_value("graphics", "render_scale"), scale_before):
			set_value("graphics", "render_scale", auto_render_scale())
	changed.emit(section, key)
	_save_wait = 0.4


func reset_section(section: String) -> void:
	for key: String in DEFAULTS[section]:
		set_value(section, key, DEFAULTS[section][key])
	if section == "graphics":
		set_value("graphics", "render_scale", auto_render_scale())


## The render scale that draws the 3D view at about 1080 lines in the current window: 1.0 on a 1080p screen,
## 0.75 on 1440p, 0.5 on 4K. This is the starting value and what Restore Defaults returns to.
func auto_render_scale() -> float:
	if not manage_window:
		return 1.0
	var lines := float(String(get_value("graphics", "resolution")).split("x")[1])
	if get_value("graphics", "fullscreen"):
		lines = DisplayServer.screen_get_size(get_window().current_screen).y
	return clampf(snappedf(COMFORTABLE_LINES / maxf(lines, 1.0), 0.05), 0.5, 1.0)


func save() -> void:
	_save_wait = -1.0
	var file := ConfigFile.new()
	file.set_value("meta", "version", VERSION)
	for section: String in _values:
		for key: String in _values[section]:
			file.set_value(section, key, _values[section][key])
	var error := file.save(path)
	if error != OK:
		push_warning("Could not save settings to %s (error %d)" % [path, error])


## Reads the file over the defaults. A missing file, a missing key or a value of the wrong type keeps the default.
func load_file() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]:
			if not file.has_section_key(section, key):
				continue
			var clean: Variant = _clean(section, key, file.get_value(section, key))
			if clean != null:
				_values[section][key] = clean


# Returns the value in the default's type and inside its range, or null when it cannot be used.
func _clean(section: String, key: String, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[section][key]
	var bounds: Array = RANGES.get("%s/%s" % [section, key], [])
	match typeof(fallback):
		TYPE_BOOL:
			return value if typeof(value) == TYPE_BOOL else null
		TYPE_INT:
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return null
			var whole := int(value)
			return whole if bounds.is_empty() else clampi(whole, bounds[0], bounds[1])
		TYPE_FLOAT:
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return null
			var number := float(value)
			if section == "audio":
				return clampf(number, 0.0, 1.0)
			return number if bounds.is_empty() else clampf(number, bounds[0], bounds[1])
		TYPE_COLOR:
			return value if typeof(value) == TYPE_COLOR else null
		TYPE_STRING:
			if typeof(value) != TYPE_STRING:
				return null
			if key == "resolution" and not RESOLUTIONS.has(value):
				return null
			return value
	return null


func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
		return is_equal_approx(a, b)
	return a == b


func _apply_all_graphics() -> void:
	for key: String in DEFAULTS["graphics"]:
		_apply_graphics(key)


func _apply_graphics(key: String) -> void:
	var window := get_window()
	match key:
		"fullscreen", "resolution":
			if not manage_window:
				return
			if get_value("graphics", "fullscreen"):
				window.mode = Window.MODE_FULLSCREEN
			else:
				window.mode = Window.MODE_WINDOWED
				var parts: PackedStringArray = String(get_value("graphics", "resolution")).split("x")
				var size := Vector2i(int(parts[0]), int(parts[1]))
				var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
				window.size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
				window.position = screen.position + (screen.size - window.size) / 2
		"render_scale":
			var scale: float = get_value("graphics", "render_scale")
			window.scaling_3d_scale = scale
			# Below full size the picture is enlarged with FSR 1, which keeps edges sharper than plain filtering.
			window.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
		"vsync":
			var mode := DisplayServer.VSYNC_ENABLED if get_value("graphics", "vsync") else DisplayServer.VSYNC_DISABLED
			DisplayServer.window_set_vsync_mode(mode)
		"fps_cap":
			Engine.max_fps = get_value("graphics", "fps_cap")
		"anti_aliasing":
			var mode: int = get_value("graphics", "anti_aliasing")
			window.msaa_3d = Viewport.MSAA_DISABLED
			window.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			window.use_taa = false
			match mode:
				AntiAliasing.FXAA:
					window.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
				AntiAliasing.MSAA_2X:
					window.msaa_3d = Viewport.MSAA_2X
				AntiAliasing.MSAA_4X:
					window.msaa_3d = Viewport.MSAA_4X
				AntiAliasing.TAA:
					window.use_taa = true
