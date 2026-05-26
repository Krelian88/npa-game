extends Node
	
# ONREADY VARIABLES START HERE: ****************************************
@onready var retry_button : Button = $menu_ui/panel/vbox/retry_button
@onready var quit_button : Button = $menu_ui/panel/vbox/quit_button
@onready var hover_sound : AudioStreamPlayer = $hover_sound
@onready var select_sound : AudioStreamPlayer = $select_sound
# ONREADY VARIABLES END ************************************************
	
# FUNCTIONS START HERE: ************************************************
func _ready() -> void:
	set_process_input(true)
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	retry_button.mouse_entered.connect(func(): retry_button.grab_focus())
	quit_button.mouse_entered.connect(func(): quit_button.grab_focus())
	retry_button.focus_entered.connect(_on_button_hover)
	quit_button.focus_entered.connect(_on_button_hover)
	retry_button.grab_focus()
	
func _on_button_hover() -> void:
	hover_sound.play()
	
func _on_retry_pressed() -> void:
	await _flash_button(retry_button)
	select_sound.play()
	await get_tree().create_timer(0.3).timeout
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scene/game.tscn")
	
func _on_quit_pressed() -> void:
	await _flash_button(quit_button)
	select_sound.play()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://Scene/main_menu.tscn")
	
func _flash_button(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "modulate", Color(0.887, 0.136, 0.085, 1.0), 0.08)
	tween.tween_property(button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
	await tween.finished
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif event is InputEventMouseMotion:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
# FUNCTIONS END ********************************************************
