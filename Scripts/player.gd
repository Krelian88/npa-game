extends CharacterBody2D

#ONREADY VARIABLES STARTS: *****************************************************
@onready var shoot_sound = $gun_shot
@onready var camera = $Camera2D
#ONREADY VARIABLES END ********************************************************

#VARIABLES STARTS HERE: ****************************************************
var input_enabled = true
var is_jumping = false
var bullet = preload("res://Scene/bullet.tscn")
var is_invincible = false
var attract_mode := false
@export var speed = 250
@export var player_health = 100
#VARIABLES END *******************************************************

# SIGNALS START HERE: ***********************************************
signal attract_game_over
# SIGNALS END ****************************************************

#CONSTANTS STATRS HERE: *************************************************
const LEVEL_HEIGHT = 3000  # Total height of your level in pixels — change this freely
#CONSTANTS END *****************************************************

#Step 1 preload
#FUNCTIONS START HERE: **********************************************************
# Called when the node enters the scen tree for the first time.
func _ready() -> void:
	var vp = get_viewport_rect().size
	# X: lock exactly to screen width — no horizontal scrolling
	camera.limit_left = 0
	camera.limit_right = int(vp.x)
	# Y: level is taller than the screen
	camera.limit_top = 0					# top of the level
	camera.limit_bottom = LEVEL_HEIGHT		# bottom of the level
	
# Called every frame. 'delta' is the elapsed time since
func _process(_delta: float) -> void:
	if player_health <= 0:
		if attract_mode:
			attract_game_over.emit()
		else:
			get_tree().change_scene_to_file("res://Scene/game_over.tscn")
	
func _physics_process(_delta: float) -> void:
	if input_enabled:
		var direction = Input.get_vector("Move Left", "Move Right", "Move Up", "Move Down")
		velocity = speed * direction
		if Input.is_action_just_pressed("Fire"):
			shoot()
		if get_global_mouse_position() < global_position:
			$Gun.flip_v = true
		else:
			$Gun.flip_v = false
	elif not attract_mode:
			velocity = Vector2.ZERO
	
	move_and_slide()
	
	if is_jumping == false:
		$JumpTimer.start()
		is_jumping = true
	
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemies") and is_invincible == false:
		player_health -= 10
		print("Player Health: ", player_health) #Prints to the bottom of the screen
	#Turn on invincibility and starts the flash!
		is_invincible = true
		_start_blink()
		$InvincibilityTimer.start()
	
func _on_invincibility_timer_timeout() -> void:
	pass
	is_invincible	= false
	modulate = Color.WHITE #Changes colour back to normal!
	
func _start_blink() -> void:
	var tween := create_tween()
	tween.set_loops(12)
	tween.tween_callback(func(): visible = false)
	tween.tween_interval(0.1)
	tween.tween_callback(func(): visible = true)
	tween.tween_interval(0.1)
	await tween.finished
	is_invincible = false
	visible = true
	
func shoot() -> void:
	var new_bullet = bullet.instantiate()
	get_parent().add_child(new_bullet)
	new_bullet.global_position = $Gun/Muzzle.global_position
	new_bullet.global_rotation = $Gun.global_rotation
	shoot_sound.pitch_scale = randi_range(1, 2)
	shoot_sound.play()
	
func _on_jump_timer_timeout() -> void:
	$AnimationPlayer.play("jump")
	
func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	is_jumping = false
#FUNCTIONS END HERE **************************************************
