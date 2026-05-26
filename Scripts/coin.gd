extends Area2D

@onready var coin_sound = $coinfx

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		coin_sound.play()
		var vp_w := int(get_viewport_rect().size.x)
		global_position.x = randi_range(60,vp_w - 60)
		global_position.y = randi_range(2400,2800)
