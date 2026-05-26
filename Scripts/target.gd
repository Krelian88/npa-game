extends Area2D

@onready var hit_targetfx = $hit_targetfx

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Bullet"):
		hit_targetfx.play()
		area.queue_free()
		
		var vp_w := int(get_viewport_rect().size.x)
		global_position.x = randi_range(60, vp_w - 60)
		global_position.y = randi_range(2400, 2800)
