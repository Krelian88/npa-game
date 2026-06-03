extends Area2D

# VARIABLES START HERE: **************************
@export var speed = 2000
@export var damage := 1
var hit := false
# VARIABLES END ***********************************

# FUNCTIONS START HERE: *******************************
func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta

func _on_area_entered(_area: Area2D) -> void:
	# Target handles its own hit logic (see target.gd)
	pass

func _on_body_entered(body: Node2D) -> void:
	if hit:
		return
	if body.is_in_group("Enemies"):
		hit = true	
		body.take_damage(damage)
		queue_free()
# FUNCTIONS END ************************************
