class_name EnemyBase
extends CharacterBody2D

# SIGNALS START HERE: *****************************
signal died(points: int) # ← declares the signal
# SIGNALS END ************************************

# VARIABLES START HERE: ******************************
var enemy_health = 0
var speed = 0
var is_entering := false
var _powerup_scenes := [
	preload("res://Scene/powerup_triple.tscn"),
	preload("res://Scene/powerup_rapid.tscn"),
	preload("res://Scene/powerup_hp.tscn"),
	preload("res://Scene/powerup_grenade.tscn"),
]
var _pause_timer := -1.0  # -1 means not yet initialised
var _is_paused := false
var _is_dead := false
var points: int = 0
# VARIABLES END *************************************

# FUNCTIONS START HERE: ****************************
func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	enemy_health -= amount
	if enemy_health <= 0:
		_is_dead = true
		_try_drop_powerup()
		died.emit(points) # ← broadcasts the signal before disappearing
		queue_free()

func _try_drop_powerup() -> void:
	if randf() < 0.2:
		var scene = _powerup_scenes[randi() % _powerup_scenes.size()]
		var pickup = scene.instantiate()
		pickup.global_position = global_position
		get_parent().call_deferred("add_child", pickup)

func _ready() -> void:
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if is_entering:
		return
	# Initialise on first active frame with a random offset so enemies are out of sync
	if _pause_timer < 0:
		_pause_timer = randf_range(0.5, 4.0)
	_pause_timer -= delta
	if _pause_timer <= 0:
		_is_paused = !_is_paused
		if _is_paused:
			_pause_timer = randf_range(0.3, 1.0)   # pause duration
		else:
			_pause_timer = randf_range(1.0, 3.5)   # move duration
	var player = get_parent().get_node("Player")
	if player and not _is_paused and player.input_enabled:
		var direction = global_position.direction_to(player.global_position)
		velocity = speed * direction
	else:
		velocity = Vector2.ZERO
	if global_position.x < 50:
		velocity.x = max(velocity.x, 0.0)
	elif global_position.x > 1030:
		velocity.x = min(velocity.x, 0.0)
	move_and_slide()
	position.x = clampf(position.x, 0.0, 1080.0)
# FUNCTIONS END *****************************************
