class_name Powerup
extends Area2D

enum Type { TRIPLE_SHOT, RAPID_SHOT, HP_FILL, GRENADE }

# VARIABLES START HERE: ****************************************
@export var type : Type = Type.TRIPLE_SHOT
# VARIABLES END ******************************************

# FUNCTIONS START HERE: ****************************************
func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.take_powerup(type)
		queue_free()
# FUNCTIONS END **********************************************
