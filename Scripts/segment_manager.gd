class_name SegmentManager

extends Node

# SIGNALS START HERE: **********************************************
signal segment_cleared(segment_index)
signal all_segments_cleared
signal score_earned(points: int)
#SIGNALS END ******************************************

#CONSTANTS START HERE: ***************************************************
const SEGMENT_COUNT := 4
const LEVEL_HEIGHT := 3000
const SEGMENT_HEIGHT := 750 # LEVEL_HEIGHT PER SEGMENT_COUNT

# SEGMENTS SIZE AND DIVISION:
const SEGMENTS := [
	{"y_min": 2250, "y_max": 3000, "start_x": 540, "start_y": 2850, "enemies": 35},
	{"y_min": 1500, "y_max": 2250, "start_x": 540, "start_y": 2100, "enemies": 35},
	{"y_min": 750,  "y_max": 1500, "start_x": 540, "start_y": 1350, "enemies": 35},
	{"y_min": 0,    "y_max": 750,  "start_x": 540, "start_y": 600, "enemies": 0}
]
const SPAWN_MARGIN := 60

# The next CONSTANT defines which enemy types can spawn in each segment.
# Each array is a "pool" — the code picks a random index from it.
# More copies of an index = higher probability of that type spawning.
# Index 0 = enemy.tscn, Index 1 = enemy2.tscn, Index 2 = enemy3.tscn
# Example: [0, 0, 1] means 67% chance of type 1, 33% chance of type 2.
# To adjust difficulty, add or remove entries — only the ratio matters, not the total count.
const SEGMENT_ENEMY_POOLS := [
	[0, 0, 0, 0, 0, 1],        # Segment 0: mostly type 1 only and rarely type 2
	[0, 0, 0, 1, 1, 2],     # Segment 1: type 1 dominant, type 2 present, type 3 rare
	[0, 0, 1, 1, 2, 2],     # Segment 2: all three types equally
	[0, 1, 2],              # Segment 3 (boss minions): all three types equally
]
# SEGMENTS POINT OF ENTRY FOR ENEMIES:
const SPAWN_ENTRIES := [
	# Segment 0 (y: 2250-3000) — top, left, right
	[
		{"from": Vector2(540, 2220),  "to": Vector2(540, 2420)},
		{"from": Vector2(-40, 2625),  "to": Vector2(150, 2625)},
		{"from": Vector2(1120, 2625), "to": Vector2(930, 2625)},
	],
	# Segment 1 (y: 1500-2250) — adds top-left and top-right corners
	[
		{"from": Vector2(540, 1470),  "to": Vector2(540, 1670)},
		{"from": Vector2(-40, 1875),  "to": Vector2(150, 1875)},
		{"from": Vector2(1120, 1875), "to": Vector2(930, 1875)},
		{"from": Vector2(-40, 1470),  "to": Vector2(150, 1670)},
		{"from": Vector2(1120, 1470), "to": Vector2(930, 1670)},
	],
	# Segment 2 (y: 750-1500) — adds upper-left, upper-right, and bottom middle
	[
		{"from": Vector2(540, 720),   "to": Vector2(540, 920)},
		{"from": Vector2(-40, 1125),  "to": Vector2(150, 1125)},
		{"from": Vector2(1120, 1125), "to": Vector2(930, 1125)},
		{"from": Vector2(-40, 720),   "to": Vector2(150, 920)},
		{"from": Vector2(1120, 720),  "to": Vector2(930, 920)},
		{"from": Vector2(-40, 937),   "to": Vector2(150, 937)},
		{"from": Vector2(1120, 937),  "to": Vector2(930, 937)},
		{"from": Vector2(540, 1520),  "to": Vector2(540, 1330)},
	],
	# Segment 3 (y: 0-750) — boss minions, same layout as segment 2
	[
		{"from": Vector2(540, -30),   "to": Vector2(540, 170)},
		{"from": Vector2(-40, 375),   "to": Vector2(150, 375)},
		{"from": Vector2(1120, 375),  "to": Vector2(930, 375)},
		{"from": Vector2(-40, -30),   "to": Vector2(150, 170)},
		{"from": Vector2(1120, -30),  "to": Vector2(930, 170)},
		{"from": Vector2(-40, 187),   "to": Vector2(150, 187)},
		{"from": Vector2(1120, 187),  "to": Vector2(930, 187)},
		{"from": Vector2(540, 770),   "to": Vector2(540, 580)},
	],
]
#CONSTANTS END **************************************************

#VARIABLES START HERE: ****************************************************
var current_segment := 0
var enemies_to_spawn := 0
var spawn_timer : Timer = null
var enemies_alive := 0
var wall_top : StaticBody2D = null
var wall_bottom : StaticBody2D = null
var player : CharacterBody2D = null
var bgm : AudioStreamPlayer = null
var boss_bgm : AudioStreamPlayer = null
var enemy_scenes := [
	preload("res://Scene/enemy.tscn"),
	preload("res://Scene/enemy2.tscn"),
	preload("res://Scene/enemy3.tscn")
]
var boss_scene = preload("res://Scene/boss.tscn")
var boss_alive := false
var waiting_for_player := false
var _indicator_tween : Tween = null
var move_indicator_left : AnimatedSprite2D = null
var move_indicator_right : AnimatedSprite2D = null
var indicator_sfx : AudioStreamPlayer = null
var _completion_pending := false
#VARIABLES END ****************************************************

#FUNCTIONS START HERE: ****************************************************
func _ready() -> void:
	player = get_parent().get_node("Player")
	# draw_debug_boundaries.call_deferred()  This call the function to draw provisional colours to differentiate the segments, no need for them once I have sprites background

func start_segment() -> void:
	_completion_pending = false
	enemies_alive = 0
	if not player.attract_mode:
		print("[SegmentManager] Starting segment %d with %d enemies" % [current_segment + 1, SEGMENTS[current_segment]["enemies"]])
	place_top_wall()
	if player:
		player.set_camera_top_limit(SEGMENTS[current_segment]["y_min"])
	if current_segment == 3:
		_start_boss_sequence()
	else:
		spawn_enemies()

func _start_boss_sequence() -> void:
	print("[SegmentManager] Boss sequence started — fading BGM...")
	# Fade out main BGM over 3.5 seconds
	if bgm and bgm.playing:
		var tween := create_tween()
		tween.tween_property(bgm, "volume_db", -80.0, 3.5)
		await tween.finished
		bgm.stop()
		bgm.volume_db = 0.0  # Reset so it's ready if player returns to main menu
	# Start boss BGM
	if boss_bgm:
		boss_bgm.play()
		boss_bgm.finished.connect(boss_bgm.play)  # Loop it
	print("[SegmentManager] Boss BGM playing — waiting 4.5s before boss enters...")
	# Wait 4.5 seconds, then spawn boss
	await get_tree().create_timer(4.5).timeout
	spawn_boss()

func spawn_boss() -> void:
	print("[SegmentManager] BOSS FIGHT!")
	boss_alive = true
	var new_boss : Boss = boss_scene.instantiate()
	new_boss.position = Vector2(540, -100)  # Off-screen above segment 4
	new_boss.died.connect(_on_boss_died)
	get_parent().add_child(new_boss)
	# Slide boss in from the top
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(new_boss, "position", Vector2(540, 80), 1.5)
	tween.tween_callback(func():
		if is_instance_valid(new_boss):
			new_boss.is_entering = false
	)

func _on_boss_died() -> void:
	print("[SegmentManager] Boss defeated!")
	boss_alive = false
	score_earned.emit(5000)
	if enemies_alive <= 0:
		_on_segment_complete.call_deferred()

func spawn_enemies() -> void:
	if spawn_timer:
		spawn_timer.queue_free()
		spawn_timer = null
	enemies_to_spawn = SEGMENTS[current_segment]["enemies"]
	spawn_timer = Timer.new()
	spawn_timer.wait_time = randf_range(1.0, 3.0)
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if enemies_to_spawn <= 0:
		spawn_timer.queue_free()
		spawn_timer = null
		return
	var entries : Array = SPAWN_ENTRIES[current_segment]
	var entry : Dictionary = entries[randi() % entries.size()]
	var batch := mini(randi_range(2, 4), enemies_to_spawn) # this changes the amount of enemies per wave, more is more
	for i in range(batch):
		var pool : Array = SEGMENT_ENEMY_POOLS[current_segment]
		var scene = enemy_scenes[pool[randi() % pool.size()]]
		var new_enemy : EnemyBase = scene.instantiate()
		new_enemy.collision_mask = 0
		var spawn_offset := Vector2(randf_range(-25, 25), randf_range(-15, 15))
		new_enemy.position = entry["from"] + spawn_offset
		new_enemy.is_entering = true
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(new_enemy, "position", entry["to"], 0.8)
		var enemy_id := new_enemy.get_instance_id()
		tween.tween_callback(func():
			var e = instance_from_id(enemy_id) if enemy_id else null
			if is_instance_valid(e):
				e.is_entering = false
)
		new_enemy.died.connect(on_enemy_died)
		get_parent().add_child(new_enemy)
		enemies_alive += 1
		enemies_to_spawn -= 1
	spawn_timer.wait_time = randf_range(0.5, 1.5) # this changes the time between waves of attacks, less is faster

func on_enemy_died(points: int) -> void:
	enemies_alive = max(0, enemies_alive - 1)
	score_earned.emit(points)
	print("[SegmentManager] Enemies remaining: %d, to spawn: %d" % [enemies_alive, enemies_to_spawn])
	if enemies_alive <= 0 and enemies_to_spawn <= 0 and not boss_alive and not waiting_for_player and not _completion_pending:
		_completion_pending = true
		_on_segment_complete.call_deferred()

func _on_segment_complete() -> void:
	_completion_pending = false
	if current_segment >= SEGMENT_COUNT:
		return
	if waiting_for_player:
		return	
	print("[DEBUG] Segment complete triggered: enemies_alive=%d, enemies_to_spawn=%d" % [enemies_alive, enemies_to_spawn])
	segment_cleared.emit(current_segment)
	print("[SegmentManager] Segment %d cleared!" % (current_segment + 1))
	remove_top_wall()
	if player:
		player.set_camera_top_limit(0)
	if current_segment < SEGMENT_COUNT - 1:
		place_bottom_wall()
		_show_indicator()
		waiting_for_player = true
	else:
		advance_to_next_segment()

func _process(_delta: float) -> void:
	if waiting_for_player and player:
		if player.global_position.y < SEGMENTS[current_segment]["y_min"] - 50:
			waiting_for_player = false
			_hide_indicator()
			advance_to_next_segment()
	# Smoothly lock camera bottom once the wall has naturally left the bottom of the screen
	if player and wall_bottom:
		var boundary_y : float = wall_bottom.position.y
		var viewport_half : float = get_viewport().get_visible_rect().size.y / 2.0
		if player.global_position.y < boundary_y - viewport_half:
			player.set_camera_bottom_limit(boundary_y)

func _show_indicator() -> void:
	if _indicator_tween:
		_indicator_tween.kill()
	for ind in [move_indicator_left, move_indicator_right]:
		if ind:
			ind.visible = true
			ind.play()
	if indicator_sfx:
		indicator_sfx.play()
	_indicator_tween = create_tween()
	_indicator_tween.set_loops()          # change to set_loops(6) to limit blink count
	_indicator_tween.tween_interval(0.4)  # how long it stays VISIBLE
	_indicator_tween.tween_callback(func():
		for ind in [move_indicator_left, move_indicator_right]:
			if ind: ind.visible = false
	)
	_indicator_tween.tween_interval(0.3)  # how long it stays INVISIBLE
	_indicator_tween.tween_callback(func():
		for ind in [move_indicator_left, move_indicator_right]:
			if ind: ind.visible = true
		if indicator_sfx:
			indicator_sfx.play()          # beep on every blink
	)

func _hide_indicator() -> void:
	if _indicator_tween:
		_indicator_tween.kill()
		_indicator_tween = null
	for ind in [move_indicator_left, move_indicator_right]:
		if ind:
			ind.visible = false

func advance_to_next_segment() -> void:
		if spawn_timer:
			spawn_timer.queue_free()
			spawn_timer = null
		current_segment += 1
		if current_segment >= SEGMENT_COUNT:
			all_segments_cleared.emit()
		else:
			start_segment()

# ********** THIS FUNCTION IS NO LONGER NEEDED BUT KEPT COMMENT OUT AS REFERENCE ************
#func transition_to_next_segment() -> void:
#	var seg: Dictionary = SEGMENTS[current_segment]
#	var target_pos := Vector2(seg["start_x"], seg["start_y"])
#	
#	player.input_enabled = false
#	
#	var tween := create_tween()
#	tween.set_ease(Tween.EASE_IN_OUT)
#	tween.set_trans(Tween.TRANS_SINE)
#	tween.tween_property(player, "position", target_pos, 2.0)
#	tween.tween_callback(func():
#		if not player.attract_mode:
#			player.input_enabled = true
#	)

func create_wall(y_pos: float, one_way: bool = false) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1080, 20)
	shape.shape = rect
	shape.position = Vector2(540, 0)
	shape.one_way_collision = one_way
	wall.add_child(shape)
	wall.position = Vector2(0, y_pos)
	get_parent().add_child(wall)
	return wall

func place_top_wall() -> void:
	if wall_top:
		wall_top.queue_free()
	wall_top = create_wall(SEGMENTS[current_segment]["y_min"])

func place_bottom_wall() -> void:
	if wall_bottom:
		wall_bottom.queue_free()
	wall_bottom = create_wall(SEGMENTS[current_segment]["y_min"], true)

func remove_top_wall() -> void:
	if wall_top:
		wall_top.queue_free()
		wall_top = null

func draw_debug_boundaries() -> void: #colours to differentiate the segments, no need for them once I have sprites background
	var colors := [
		Color(1, 0, 0, 0.15),
		Color(0, 1, 0, 0.15),
		Color(0, 0, 1, 0.15),
		Color(1, 1, 0, 0.15)
	]
	for i in range(SEGMENTS.size()):
		var seg : Dictionary = SEGMENTS[i]
		var rect := ColorRect.new()
		rect.color = colors[i]
		rect.position = Vector2(0, seg["y_min"])
		rect.size = Vector2(1080, seg["y_max"] - seg["y_min"])
		rect.z_index = -1
		get_parent().add_child(rect)
#FUNCTIONS END ***********************************************
