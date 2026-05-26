extends Control
	
# ONREADY VARIABLES START HERE: *******************************************
@onready var game_viewport : SubViewport = $game_viewport_container/game_viewport
@onready var play_button : Button = $menu_ui/center/vbox/play_button
@onready var quit_button : Button = $menu_ui/center/vbox/quit_button
@onready var menu_bgm :  AudioStreamPlayer = $menu_bgm
@onready var hover_sound : AudioStreamPlayer = $hover_sound
@onready var select_sound : AudioStreamPlayer = $select_sound
@onready var options_button: Button = $menu_ui/center/vbox/options_button
# ONREADY VARIABLES END ************************************************************
	
# VARIABLES START HERE: ****************************************
var options_menu = preload("res://Scene/options_menu.tscn")
# VARIABLES END ***********************************************************
	
# FUNCTIONS START HERE: ********************************************************
func _ready() -> void:
	_setup_attract_mode()
	set_process_input(true)
	menu_bgm.finished.connect(menu_bgm.play)
	
	# Connect buttons
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.mouse_entered.connect(func(): play_button.grab_focus())
	quit_button.mouse_entered.connect(func(): quit_button.grab_focus())
	play_button.focus_entered.connect(_on_button_hover)
	quit_button.focus_entered.connect(_on_button_hover)
	play_button.grab_focus()
	options_button.pressed.connect(_on_options_pressed)
	options_button.mouse_entered.connect(func(): options_button.grab_focus())
	options_button.focus_entered.connect(_on_button_hover)
	
func _setup_attract_mode() -> void:
	# Clear any existing game scene in the viewport
	for child in game_viewport.get_children():
		child.queue_free()
	
	# Wait one frame for cleanup to complete
	await get_tree().process_frame
	
	# Load fresh game scene into SubViewport
	var game_scene = preload("res://Scene/game.tscn").instantiate()
	game_viewport.add_child(game_scene)
	
	# Disable player input and set up AI
	var player = game_scene.get_node("Player")
	if player:
		player.input_enabled = false
		player.attract_game_over.connect(_setup_attract_mode)
		var ai = load("res://Scripts/attract_ai.gd").new()
		player.add_child(ai)
	
	# Mute all audio in the attract mode game instance
	for audio in game_scene.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
		audio.volume_db = -80.0
	for audio in game_scene.find_children("*", "AudioStreamPlayer2D", true, false):
		audio.stop()
		audio.volume_db = -80.0
	
func _on_play_pressed() -> void:
	await _flash_button(play_button)
	select_sound.play()
	await select_sound.finished
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scene/game.tscn")
	
func _on_quit_pressed() -> void:
	await _flash_button(quit_button)
	select_sound.play()
	await select_sound.finished
	get_tree().quit()
	
func _on_button_hover() -> void:
	hover_sound.play()
	
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
	
func _on_options_pressed() -> void:
	select_sound.play()
	await get_tree().create_timer(0.3).timeout
	add_child(options_menu.instantiate())
# FUNCTIONS END **************************************************************
