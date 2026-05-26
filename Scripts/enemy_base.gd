class_name EnemyBase
extends CharacterBody2D

signal died # ← declares the signal

var enemy_health = 0
var speed = 0

func take_damage() -> void:
	enemy_health -= 1
	if enemy_health <= 0:
		died.emit() # ← broadcasts the signal before disappearing
		queue_free()

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	var player = get_parent().get_node("Player")
	if player:
		var direction = global_position.direction_to(player.global_position)
		velocity = speed * direction
		move_and_slide()
