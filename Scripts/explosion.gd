extends Area2D

# VARIABLES START HERE: *******************************
@export var damage := 3
# VARIABLES END ***********************************

# FUNCTIONS START HERE: ************************************
func _ready() -> void:
	$explosion_sound.play()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.5, 0, 0.8), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	await get_tree().physics_frame
	for body in get_overlapping_bodies():
		if body.is_in_group("Enemies"):
			body.take_damage(damage)
	await $explosion_sound.finished
	queue_free()
# FUNCTIONS END ******************************************
