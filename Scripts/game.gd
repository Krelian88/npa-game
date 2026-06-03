extends Node2D

# ONREADY VAR START HERE: ******************************************
@onready var bgm = $bgm
@onready var boss_bgm = $boss_bgm
@onready var segment_manager = $segment_manager
@onready var indicator_sfx = $indicator_sfx
@onready var move_indicator_left = $CanvasLayer/move_indicator_left
@onready var move_indicator_right = $CanvasLayer/move_indicator_right
@onready var ammo_bar = $CanvasLayer/ammo_bar
@onready var grenade_counter_label = $CanvasLayer/grenade_counter
@onready var player = $Player
@onready var life_1 = $CanvasLayer/life_1
@onready var life_2 = $CanvasLayer/life_2
# ONREADY VAR ENDS *********************************************

# VARIABLES START HERE: *************************************************
var coin = preload("res://Scene/coin.tscn")
var target = preload("res://Scene/target.tscn")
var pause_menu = preload("res://Scene/pause_menu.tscn")
var _hp_tween : Tween
# VARIABLES ENDS *******************************************************

# CONSTANTS START HERE: ********************************************
const SPAWN_MARGIN:= 60    #keep enemies away from the very edge
# CONSTANTS END ***********************************************

# FUNCTIONS START HERE: *********************************************
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	segment_manager.bgm = bgm
	segment_manager.indicator_sfx = indicator_sfx
	segment_manager.move_indicator_left = move_indicator_left
	segment_manager.move_indicator_right = move_indicator_right
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
		
	player.input_enabled = false
	player.global_position = Vector2(540, 3200)
	var entrance := create_tween()
	entrance.set_ease(Tween.EASE_OUT)
	entrance.set_trans(Tween.TRANS_QUAD)
	entrance.tween_property(player, "global_position", Vector2(540, 2850), 3.0)
	entrance.tween_callback(func(): player.input_enabled = true)
	entrance.tween_interval(0.5)
	entrance.tween_callback(func(): segment_manager.start_segment())
	player.ammo_changed.connect(_on_ammo_changed)
	player.weapon_mode_changed.connect(_on_weapon_mode_changed)
	player.grenade_count_changed.connect(_on_grenade_count_changed)
	player.health_changed.connect(_on_health_changed)
	player.lives_changed.connect(_on_lives_changed)
	player.player_respawn_needed.connect(_on_player_respawn_needed)
	ammo_bar.visible = false
	grenade_counter_label.visible = false

func _on_game_won() -> void:
	print("YOU WIN!")
	get_tree().change_scene_to_file("res://Scene/win_screen.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if Input.is_action_just_pressed("ui_cancel") and not get_tree().paused and not player.attract_mode:
		get_tree().paused = true
		bgm.volume_db = -20.0
		var menu = pause_menu.instantiate()
		menu.bgm = bgm
		add_child(menu)

func _on_ammo_changed(current: int, max_val: int) -> void:
	ammo_bar.max_value = max_val
	ammo_bar.value = current

func _on_weapon_mode_changed(mode: int) -> void:
	ammo_bar.visible = mode != 0

func _on_grenade_count_changed(count: int) -> void:
	grenade_counter_label.visible = count > 0
	grenade_counter_label.text = "GRENADES: %d" % count

func _on_health_changed(new_health: int) -> void:
	if _hp_tween:
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.set_ease(Tween.EASE_OUT)
	_hp_tween.set_trans(Tween.TRANS_QUAD)
	_hp_tween.tween_property($CanvasLayer/hp_bar, "value", float(new_health), 0.3)

func _on_lives_changed(new_lives: int) -> void:
	life_1.visible = new_lives >= 2
	life_2.visible = new_lives >= 3

func _on_player_respawn_needed() -> void:
	player.input_enabled = false
	await get_tree().create_timer(2.0).timeout # Time that takes for the player to get back into the scene.
	var seg = SegmentManager.SEGMENTS[segment_manager.current_segment]
	player.global_position = Vector2(seg["start_x"], seg["y_max"] + 100)
	player.respawn()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(player, "global_position", Vector2(seg["start_x"], seg["y_max"] - 150), 2.0)
	await tween.finished
	player.input_enabled = true
	await get_tree().create_timer(1.0).timeout
	player.end_invincibility()
# FUNTIONS END HERE ***************************************
