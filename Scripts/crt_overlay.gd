extends ColorRect

# FUNCTIONS START HERE **********************************************
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	visible = config.get_value("video", "crt_enabled", true)
# FUNCTIONS END ***********************************************
