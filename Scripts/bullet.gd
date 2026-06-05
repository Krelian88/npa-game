extends Area2D

# VARIABLES START HERE: **************************
@export var speed = 2000
@export var damage := 1
@export var bullet_type: String = ""
var hit := false
@onready var anim = $anim
# VARIABLES END ***********************************

# FUNCTIONS START HERE: *******************************
func _ready() -> void:
	anim.visible = false
	if bullet_type != "":
		$AnimatedSprite2D.visible = false
		anim.visible = true
		anim.play(bullet_type)

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
