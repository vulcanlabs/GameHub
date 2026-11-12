class_name CentreDot
extends Control
## The aiming dot. It is anchored to the exact centre of the screen and drawn around its own origin, so it
## stays centred at any resolution, aspect ratio or field of view.
##
## Size is the diameter in pixels at 1080p. The interface scales with the window, so 3 means 3 pixels on a
## 1080p screen and 6 on a 4K one. Visibility, size, opacity and colour come from the camera settings.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Settings.changed.connect(_on_setting_changed)
	_refresh()


func diameter() -> float:
	return Settings.get_value("camera", "dot_size")


func color() -> Color:
	var tint: Color = Settings.get_value("camera", "dot_color")
	tint.a = Settings.get_value("camera", "dot_opacity")
	return tint


func _draw() -> void:
	draw_circle(Vector2.ZERO, diameter() * 0.5, color(), true, -1.0, true)


func _refresh() -> void:
	visible = Settings.get_value("camera", "dot_visible")
	queue_redraw()


func _on_setting_changed(section: String, key: String) -> void:
	if section == "camera" and key.begins_with("dot_"):
		_refresh()
