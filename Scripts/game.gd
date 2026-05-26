extends Node2D
	
# ONREADY VAR START HERE: ******************************************
@onready var bgm = $bgm
@onready var boss_bgm = $boss_bgm
@onready var segment_manager = $segment_manager
# ONREADY VAR ENDS *********************************************
	
# VARIABLES START HERE: *************************************************
var coin = preload("res://Scene/coin.tscn")
var target = preload("res://Scene/target.tscn")
var pause_menu = preload("res://Scene/pause_menu.tscn")
# VARIABLES ENDS *******************************************************
	
# CONSTANTS START HERE: ********************************************
const SPAWN_MARGIN:= 60    #keep enemies away from the very edge
# CONSTANTS END ***********************************************
	
# FUNCTIONS START HERE: *********************************************
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	segment_manager.bgm = bgm
	segment_manager.boss_bgm = boss_bgm
	segment_manager.all_segments_cleared.connect(_on_game_won)
	var vp_w := int(get_viewport_rect().size.x)
	
	var new_coin = coin.instantiate()
	add_child(new_coin)
	new_coin.global_position.x = randi_range(SPAWN_MARGIN, vp_w - SPAWN_MARGIN)
	new_coin.global_position.y = randi_range(2400, 2800)
	
	var new_target = target.instantiate()
	add_child(new_target)
	new_target.global_position.x = randi_range(SPAWN_MARGIN, vp_w - SPAWN_MARGIN)
	new_target.global_position.y = randi_range(2400, 2800)
	
	bgm.play()
	bgm.finished.connect(bgm.play)
	
	var player = get_node("Player")
	player.input_enabled = false
	player.global_position = Vector2(540, 3200)
	var entrance := create_tween()
	entrance.set_ease(Tween.EASE_OUT)
	entrance.set_trans(Tween.TRANS_QUAD)
	entrance.tween_property(player, "global_position", Vector2(540, 2850), 3.0)
	entrance.tween_callback(func(): player.input_enabled = true)
	entrance.tween_interval(0.5)
	entrance.tween_callback(func(): segment_manager.start_segment())
	
func _on_game_won() -> void:
	print("YOU WIN!")
	get_tree().change_scene_to_file("res://Scene/win_screen.tscn")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var player = get_node("Player")
	$CanvasLayer/ProgressBar.value = player.player_health
	if Input.is_action_just_pressed("ui_cancel") and not get_tree().paused and not player.attract_mode:
		get_tree().paused = true
		bgm.volume_db = -20.0
		var menu = pause_menu.instantiate()
		menu.bgm = bgm
		add_child(menu)
	
# FUNTIONS END HERE ***************************************
