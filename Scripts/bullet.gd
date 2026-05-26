extends Area2D

@export var speed = 2000

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta

func _on_area_entered(area: Area2D) -> void:
	# Target handles its own hit logic (see target.gd)
	pass

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemies"):
		body.take_damage()
		queue_free()
