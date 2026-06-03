extends CharacterBody2D

enum WeaponMode { NORMAL, TRIPLE, RAPID }

# VARIABLES STARTS: *****************************************************
@onready var shoot_sound = $gun_shot
@onready var camera = $Camera2D
@onready var triple_shot_sound = $triple_shot_sound
@onready var rapid_shot_sound = $rapid_shot_sound
@onready var grenade_throw_sound = $grenade_throw_sound
@onready var hp_powerup_sound = $hp_powerup_sound
@onready var special_ammo_sound = $special_ammo_sound
@onready var grenade_pickup_sound = $grenade_pickup_sound
var input_enabled = true
var is_jumping = false
var bullet = preload("res://Scene/bullet.tscn")
var is_invincible = false
var attract_mode := false
var weapon_mode := WeaponMode.NORMAL
var special_ammo := 0
var grenade_count := 0
var fire_timer := 0.0
const RAPID_FIRE_RATE := 0.12
var grenade_scene = preload("res://Scene/grenade_projectile.tscn")
@export var speed = 250
@export var player_health : int = 100
@export var max_special_ammo := 10
@export var hp_restore_percent := 15
@export var grenades_per_pickup := 1
var lives := 3
var _is_dead := false
var _blink_tween : Tween
#VARIABLES END *******************************************************

# SIGNALS START HERE: ***********************************************
signal attract_game_over
signal ammo_changed(current_ammo: int, max_ammo: int)
signal weapon_mode_changed(mode: int)
signal grenade_count_changed(count: int)
signal health_changed(new_health: int)
signal lives_changed(new_lives: int)
signal player_respawn_needed
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
	if player_health <= 0 and not _is_dead:
		_is_dead = true
		if attract_mode:
			attract_game_over.emit()
		elif lives > 1:
			lives -= 1
			lives_changed.emit(lives)
			player_respawn_needed.emit()
		else:
			get_tree().change_scene_to_file("res://Scene/game_over.tscn")

func _physics_process(delta: float) -> void:
	if input_enabled:
		var direction = Input.get_vector("Move Left", "Move Right", "Move Up", "Move Down")
		velocity = speed * direction
		if fire_timer > 0:
			fire_timer -= delta
		
		if weapon_mode == WeaponMode.RAPID:
			if Input.is_action_pressed("Fire") and fire_timer <= 0:
				shoot()
				fire_timer = RAPID_FIRE_RATE
		else:
			if Input.is_action_just_pressed("Fire"):
				shoot()
		
		if Input.is_action_just_pressed("Throw Grenade") and grenade_count > 0:
			_throw_grenade()
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
		take_damage(10)

func take_damage(amount: int) -> void:
	if is_invincible:
		return
	player_health -= amount
	health_changed.emit(player_health)
	print("Player Health: ", player_health)
	is_invincible = true
	_start_blink()
	$InvincibilityTimer.start()

func _on_invincibility_timer_timeout() -> void:
	pass
	is_invincible	= false
	modulate = Color.WHITE #Changes colour back to normal!

func _start_blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween()
	_blink_tween.set_loops(12)
	_blink_tween.tween_callback(func(): visible = false)
	_blink_tween.tween_interval(0.1)
	_blink_tween.tween_callback(func(): visible = true)
	_blink_tween.tween_interval(0.1)
	await _blink_tween.finished
	is_invincible = false
	visible = true

func shoot() -> void:
	match weapon_mode:
		WeaponMode.NORMAL:
			_fire_bullet(0.0)	# 1 damage (default)
			shoot_sound.pitch_scale = randi_range(1, 2)
			shoot_sound.play()
		WeaponMode.TRIPLE:
			_fire_bullet(-15.0, 2)	# ← change 2 to whatever
			_fire_bullet(0.0, 2)
			_fire_bullet(15.0, 2)
			_use_special_ammo()
			triple_shot_sound.play()
		WeaponMode.RAPID:
			_fire_bullet(0.0, 3)	# ← change 1 to whatever
			_use_special_ammo()
			if not rapid_shot_sound.playing:
				rapid_shot_sound.play()

func _fire_bullet(angle_offset_deg: float, damage: int = 1) -> void:
	var new_bullet = bullet.instantiate()
	new_bullet.damage = damage
	get_parent().add_child(new_bullet)
	new_bullet.global_position = $Gun/Muzzle.global_position
	new_bullet.global_rotation = $Gun.global_rotation + deg_to_rad(angle_offset_deg)

func _use_special_ammo() -> void:
	special_ammo -= 1
	ammo_changed.emit(special_ammo, max_special_ammo)
	if special_ammo <= 0:
		weapon_mode = WeaponMode.NORMAL
		weapon_mode_changed.emit(WeaponMode.NORMAL)

func take_powerup(type: Powerup.Type) -> void:
	match type:
		Powerup.Type.TRIPLE_SHOT:
			weapon_mode = WeaponMode.TRIPLE
			special_ammo = max_special_ammo
			ammo_changed.emit(special_ammo, max_special_ammo)
			weapon_mode_changed.emit(WeaponMode.TRIPLE)
			special_ammo_sound.play()
		Powerup.Type.RAPID_SHOT:
			weapon_mode = WeaponMode.RAPID
			special_ammo = max_special_ammo
			ammo_changed.emit(special_ammo, max_special_ammo)
			weapon_mode_changed.emit(WeaponMode.RAPID)
			special_ammo_sound.play()
		Powerup.Type.HP_FILL:
			player_health = min(100, player_health + hp_restore_percent)
			health_changed.emit(player_health)
			hp_powerup_sound.play()
		Powerup.Type.GRENADE:
			grenade_count += grenades_per_pickup
			grenade_count_changed.emit(grenade_count)
			grenade_pickup_sound.play()

func _throw_grenade() -> void:
	var g = grenade_scene.instantiate()
	get_parent().add_child(g)
	g.global_position = $Gun/Muzzle.global_position
	g.direction = global_position.direction_to(get_global_mouse_position())
	grenade_count -= 1
	grenade_count_changed.emit(grenade_count)
	grenade_throw_sound.play()

func _on_jump_timer_timeout() -> void:
	$AnimationPlayer.play("jump")

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	is_jumping = false

func respawn() -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	player_health = 100
	health_changed.emit(player_health)
	_is_dead = false
	modulate = Color.WHITE
	visible = true
	is_invincible = true
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_callback(func(): visible = false)
	_blink_tween.tween_interval(0.15)
	_blink_tween.tween_callback(func(): visible = true)
	_blink_tween.tween_interval(0.15)

func end_invincibility() -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	is_invincible = false
	visible = true
#FUNCTIONS END HERE **************************************************
