class_name EnemyBase
extends CharacterBody2D
	
# SIGNALS START HERE: *****************************
signal died # ← declares the signal
# SIGNALS END ************************************
	
# VARIABLES START HERE: ******************************
var enemy_health = 0
var speed = 0
var is_entering := false
# VARIABLES END *************************************
	
# FUNCTIONS START HERE: ****************************
func take_damage() -> void:
	enemy_health -= 1
	if enemy_health <= 0:
		died.emit() # ← broadcasts the signal before disappearing
		queue_free()
	
func _ready() -> void:
	pass
	
func _physics_process(delta: float) -> void:
	if is_entering:
		return
	var player = get_parent().get_node("Player")
	if player:
		var direction = global_position.direction_to(player.global_position)
		velocity = speed * direction
		move_and_slide()
# FUNCTIONS END *****************************************
