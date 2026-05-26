extends Control
	
# ONREADY VARIABLES START HERE: ****************************************
@onready var resume_button : Button = $menu_ui/panel/vbox/resume_button
@onready var options_button : Button = $menu_ui/panel/vbox/options_button
@onready var quit_button : Button = $menu_ui/panel/vbox/quit_button
@onready var hover_sound : AudioStreamPlayer = $hover_sound
@onready var select_sound : AudioStreamPlayer = $select_sound
# ONREADY VARIABLES END ****************************************
	
# VARIABLES START HERE: ***************************************
var bgm : AudioStreamPlayer = null
var options_menu = preload("res://Scene/options_menu.tscn")
# VARIABLES END *******************************************
	
# FUNCTIONS START HERE: ******************************************
func _ready() -> void:
	set_process_input(true)
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	resume_button.mouse_entered.connect(func(): resume_button.grab_focus())
	options_button.mouse_entered.connect(func(): options_button.grab_focus())
	quit_button.mouse_entered.connect(func(): quit_button.grab_focus())
	resume_button.focus_entered.connect(_on_button_hover)
	options_button.focus_entered.connect(_on_button_hover)
	quit_button.focus_entered.connect(_on_button_hover)
	resume_button.grab_focus()
	
func _on_button_hover() -> void:
	hover_sound.play()
	
func _on_resume_pressed() -> void:
	await _flash_button(resume_button)
	select_sound.play()
	await get_tree().create_timer(0.3).timeout
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if bgm:
		bgm.volume_db = 0.0
	get_tree().paused = false
	queue_free()
	
func _on_options_pressed() -> void:
	await _flash_button(options_button)
	select_sound.play()
	await get_tree().create_timer(0.3).timeout
	$menu_ui.visible = false
	var opts = options_menu.instantiate()
	add_child(opts)
	await opts.tree_exited
	$menu_ui.visible = true
	
func _on_quit_pressed() -> void:
	await _flash_button(quit_button)
	select_sound.play()
	await get_tree().create_timer(0.3).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scene/main_menu.tscn")
	
func _flash_button(button: Button) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "modulate", Color(0.887, 0.136, 0.085, 1.0), 0.08)
	tween.tween_property(button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
	await tween.finished
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		if event.is_action_pressed("ui_cancel"):
			_on_resume_pressed()
	elif event is InputEventMouseMotion:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
# FUNCTIONS END ***************************************************
