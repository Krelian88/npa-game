extends Area2D

# VARIABLES START HERE: ********************************
@export var travel_distance := 300.0
@export var speed := 250.0

var direction := Vector2.ZERO
var distance_traveled := 0.0
var explosion_scene = preload("res://Scene/explosion.tscn")
# VARIABLES END ***************************************

# FUNCTIONS START HERE: ***********************************
func _physics_process(delta: float) -> void:
	var move := direction * speed * delta
	position += move
	distance_traveled += move.length()
	if distance_traveled >= travel_distance:
		_explode()

func _explode() -> void:
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
	queue_free()
# FUNCTIONS END **************************************
