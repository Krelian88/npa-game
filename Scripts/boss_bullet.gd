extends Area2D

# VARIABLES START HERE: *******************************************
@export var speed := 200.0
var direction := Vector2.ZERO
# VARIABLES END ****************************************************

# FUNCTIONS START HERE: *******************************************
func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.take_damage(15)
		queue_free()

func _on_area_entered(_area: Area2D) -> void:
	pass
# FUNCTIONS END *******************************************
