extends Area2D

# VARIABLES START HERE: *******************************
@export var damage := 3
@onready var anim = $anim
# VARIABLES END ***********************************

# FUNCTIONS START HERE: ************************************
func _ready() -> void:
	$explosion_sound.play()
	anim.play("explode")
	anim.animation_finished.connect(_on_animation_finished)
	await get_tree().physics_frame
	for body in get_overlapping_bodies():
		if body.is_in_group("Enemies"):
			body.take_damage(damage)

func _on_animation_finished() -> void:
	anim.visible = false
	await $explosion_sound.finished
	queue_free()
# FUNCTIONS END ******************************************
