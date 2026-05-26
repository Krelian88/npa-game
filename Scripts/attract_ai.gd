extends Node
	
# VARIABLES START HERE: ******************************************
var player : CharacterBody2D
var target_pos : Vector2
var shoot_timer := 0.0
var move_timer := 0.0
# VARIABLES END *****************************************
	
# CONSTANTS START HERE: *******************************************
const MOVE_SPEED := 150.0
const SHOOT_INTERVAL := 0.5
const MOVE_INTERVAL := 3.0
# CONSTANT END ***************************************************
	
# FUNCTIONS START HERE: *****************************************
func _ready() -> void:
	process_physics_priority = -1
	player = get_parent()
	player.attract_mode = true
	_pick_new_target()
	
func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_shooting(delta)
	
func _handle_movement(delta: float) -> void:
	move_timer += delta
	if move_timer >= MOVE_INTERVAL:
		move_timer = 0.0
		_pick_new_target()
	var direction = player.global_position.direction_to(target_pos)
	player.velocity = direction * MOVE_SPEED
	
func _handle_shooting(delta: float) -> void:
	shoot_timer += delta
	if shoot_timer >= SHOOT_INTERVAL:
		shoot_timer = 0.0
		var enemies = get_tree().get_nodes_in_group("Enemies")
		if enemies.is_empty():
			return
		var nearest = enemies[0]
		for enemy in enemies:
			if player.global_position.distance_to(enemy.global_position) < player.global_position.distance_to(nearest.global_position):
				nearest = enemy
		var gun = player.get_node("Gun")
		var direction = player.global_position.direction_to(nearest.global_position)
		gun.rotation = direction.angle()
		gun.flip_v = nearest.global_position.x < player.global_position.x
		player.shoot()
	
func _pick_new_target() -> void:
	var py := player.global_position.y
	target_pos = Vector2(
		randf_range(100.0, 980.0),
		clamp(randf_range(py - 300.0, py + 300.0), 0.0, 3000.0)
	)
# FUNCTIONS END ******************************************
