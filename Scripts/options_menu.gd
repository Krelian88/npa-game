extends Control
	
# ONREADY VARIABLES START HERE: *****************************************************
@onready var bgm_slider: HSlider = $menu_ui/CenterContainer/panel/MarginContainer/vbox/bgm_slider
@onready var sfx_slider: HSlider = $menu_ui/CenterContainer/panel/MarginContainer/vbox/sfx_slider
@onready var crt_toggle: CheckButton = $menu_ui/CenterContainer/panel/MarginContainer/vbox/crt_row/crt_toggle
@onready var back_button: Button = $menu_ui/CenterContainer/panel/MarginContainer/vbox/back_button
@onready var hover_sound: AudioStreamPlayer = $hover_sound
@onready var select_sound: AudioStreamPlayer = $select_sound
@onready var toggle_sound: AudioStreamPlayer = $menu_ui/CenterContainer/panel/MarginContainer/vbox/toggle_sound
# ONREADY VARIABLES END ************************************************************
	
# VARIABLES START HERE: ********************************************************
var config := ConfigFile.new()
# VARIABLES END ********************************************************
	
# CONSTANTS START HERE: *******************************************
const SAVE_PATH := "user://settings.cfg"
# CONSTANTS END ************************************************************
	
# FUNCTIONS START HERE: ****************************************************
func _ready() -> void:
	print("bgm_slider: ", bgm_slider)
	print("back_button: ", back_button)
	print("hover_sound: ", hover_sound)
	_load_settings()
	
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	crt_toggle.toggled.connect(_on_crt_toggled)
	
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(func(): back_button.grab_focus())
	back_button.focus_entered.connect(_on_hover)
	
	bgm_slider.mouse_entered.connect(_on_hover)
	sfx_slider.mouse_entered.connect(_on_hover)
	crt_toggle.mouse_entered.connect(_on_hover)
	crt_toggle.mouse_entered.connect(func(): crt_toggle.grab_focus())
	crt_toggle.focus_entered.connect(_on_hover)
	var teal_style := StyleBoxFlat.new()
	teal_style.bg_color = Color(0.686, 0.976, 0.910, 1.0)
	teal_style.set_border_width_all(2)
	teal_style.border_color = Color(1, 1, 1, 1)
	teal_style.content_margin_left = 30.0
	teal_style.content_margin_top = 10.0
	teal_style.content_margin_right = 30.0
	teal_style.content_margin_bottom = 10.0
	crt_toggle.add_theme_stylebox_override("hover", teal_style)
	crt_toggle.add_theme_stylebox_override("hover_pressed", teal_style)
	
	back_button.grab_focus()
	
func _load_settings() -> void:
	config.load(SAVE_PATH)
	
	var bgm_vol = config.get_value("audio", "bgm_volume", 0.0)
	var sfx_vol = config.get_value("audio", "sfx_volume", 0.0)
	var crt_on  = config.get_value("video", "crt_enabled", true)
	
	bgm_slider.value = bgm_vol
	sfx_slider.value = sfx_vol
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), bgm_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_vol)
	
	crt_toggle.button_pressed = crt_on
	crt_toggle.text = "ON" if crt_on else "OFF"
	CRTOverlay.get_node("screen").visible = crt_on
	
func _on_bgm_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), value)
	config.set_value("audio", "bgm_volume", value)
	config.save(SAVE_PATH)
	
func _on_sfx_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), value)
	config.set_value("audio", "sfx_volume", value)
	config.save(SAVE_PATH)
	
func _on_crt_toggled(button_pressed: bool) -> void:
	crt_toggle.text = "ON" if button_pressed else "OFF"
	toggle_sound.play()
	CRTOverlay.get_node("screen").visible = button_pressed
	config.set_value("video", "crt_enabled", button_pressed)
	config.save(SAVE_PATH)
	
func _on_hover() -> void:
	hover_sound.play()
	
func _on_back_pressed() -> void:
	select_sound.play()
	await get_tree().create_timer(0.3).timeout
	queue_free()
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
	elif event is InputEventMouseMotion:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
# FUNCTIONS END ***********************************************************
