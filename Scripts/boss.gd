class_name Boss
extends CharacterBody2D
	
# SIGNALS START HERE: **************************
signal died
# SIGNALS END HERE ********************************
	
# MOVEMENT STATE
enum State { PATROL, CHARGE }
	
# CONSTANTS START HERE: **********************************
# THIS IS FOR PATROL BOUNDARIES (segment 4: y=0 to y=750, boss starts in top half)
const PATROL_BOUNDARY_LEFT := 100.0
const PATROL_BOUNDARY_RIGHT := 980.0
const PATROL_BOUNDARY_TOP := 50.0
const PATROL_BOUNDARY_BOTTOM := 350.0
# CONSTANTS END *****************************************
	
# VARIABLES START HERE: ***************************************
# STATS
@export_group("Stats")
@export var MAX_HEALTH : int = 50
	
@export_group("Movement")
@export var SPEED_PHASE_1 : float = 100.0
@export var SPEED_PHASE_2 : float = 180.0
@export var CHARGE_SPEED : float = 350.0
var health := MAX_HEALTH
var phase := 1
# MOVEMENT
var speed := SPEED_PHASE_1
var direction := 1.0  # 1 = right, -1 = left
var direction_y := 1.0  # vertical:   1 = down,  -1 = up
# SHOOTING
var shoot_timer : Timer = null
var bullet = preload("res://Scene/boss_bullet.tscn")
var player : CharacterBody2D = null
var segment_manager : Node = null
# MOVEMENT STATE
var state := State.PATROL
var charge_timer : Timer = null
var charge_direction := Vector2.ZERO
# MINIONS
var minion_timer : Timer = null
# ENTRANCE
var is_entering := true  # Frozen until entrance animation completes
# VARIABLES END HERE ***************************************
	
# FUNCTIONS START HERE: ****************************************************
func _ready() -> void:
	add_to_group("Enemies")
	player = get_parent().get_node("Player")
	segment_manager = get_parent().get_node("segment_manager")
	_start_shoot_timer()
	_start_charge_timer()
	
func take_damage() -> void:
	health -= 1
	print("[Boss] Health: %d" % health)
	if health <= MAX_HEALTH / 2 and phase == 1:
		_enter_phase_2()
	if health <= 0:
		died.emit()
		queue_free()
	
func _enter_phase_2() -> void:
	phase = 2
	speed = SPEED_PHASE_2
	print("[Boss] Phase 2 activated!")
	shoot_timer.wait_time = 0.8
	if charge_timer:
		charge_timer.wait_time = randf_range(1.5, 2.5)
	_start_minion_timer()
	
func _physics_process(_delta: float) -> void:
	if is_entering:
		return
	match state:
		State.PATROL:
			_patrol()
		State.CHARGE:
			velocity = charge_direction * CHARGE_SPEED
	move_and_slide()
	
func _patrol() -> void:
	velocity.x = speed * direction
	velocity.y = speed * direction_y
	if position.x >= PATROL_BOUNDARY_RIGHT:
		direction = -1.0
	elif position.x <= PATROL_BOUNDARY_LEFT:
		direction = 1.0
	if position.y >= PATROL_BOUNDARY_BOTTOM:
		direction_y = -1.0
	elif position.y <= PATROL_BOUNDARY_TOP:
		direction_y = 1.0
	
func _start_charge() -> void:
	if is_entering or not player:
		return
	state = State.CHARGE
	charge_direction = global_position.direction_to(player.global_position)
	# Calculate duration so the charge actually reaches the player's position
	var dist := global_position.distance_to(player.global_position)
	var duration := clampf(dist / CHARGE_SPEED, 0.3, 1.5)
	# Re-randomize next charge interval
	charge_timer.wait_time = randf_range(2.0, 4.0)
	# Timer to end this charge
	var dur_timer := Timer.new()
	dur_timer.wait_time = duration
	dur_timer.one_shot = true
	dur_timer.timeout.connect(_end_charge)
	dur_timer.timeout.connect(dur_timer.queue_free)
	add_child(dur_timer)
	dur_timer.start()
	
func _end_charge() -> void:
	state = State.PATROL
	velocity = Vector2.ZERO
	
func _start_charge_timer() -> void:
	charge_timer = Timer.new()
	charge_timer.wait_time = randf_range(2.0, 4.0)
	charge_timer.one_shot = false
	charge_timer.timeout.connect(_start_charge)
	add_child(charge_timer)
	charge_timer.start()
	
func _start_shoot_timer() -> void:
	shoot_timer = Timer.new()
	shoot_timer.wait_time = 2.0
	shoot_timer.one_shot = false
	shoot_timer.timeout.connect(_shoot)
	add_child(shoot_timer)
	shoot_timer.start()
	
func _shoot() -> void:
	if is_entering or not player:
		return
	var new_bullet = bullet.instantiate()
	new_bullet.direction = global_position.direction_to(player.global_position)
	new_bullet.position = global_position
	get_parent().add_child(new_bullet)
	
func _start_minion_timer() -> void:
	minion_timer = Timer.new()
	minion_timer.wait_time = randf_range(4.0, 8.0)
	minion_timer.one_shot = false
	minion_timer.timeout.connect(_spawn_minion)
	add_child(minion_timer)
	minion_timer.start()
	
func _spawn_minion() -> void:
	var enemy_scenes := [
		preload("res://Scene/enemy.tscn"),
		preload("res://Scene/enemy2.tscn"),
		preload("res://Scene/enemy3.tscn")
	]
	var count := randi_range(1, 2)
	for i in range(count):
		var scene = enemy_scenes[randi() % enemy_scenes.size()]
		var minion : EnemyBase = scene.instantiate()
		minion.position.x = randf_range(100, 980)
		minion.position.y = randf_range(0, 750)
		minion.died.connect(segment_manager.on_enemy_died)
		get_parent().add_child(minion)
		segment_manager.enemies_alive += 1
	minion_timer.wait_time = randf_range(4.0, 8.0)
# FUNCTIONS END *****************************************************
