class_name SegmentManager
	
extends Node
	
# SIGNALS START HERE: **********************************************
signal segment_cleared(segment_index)
signal all_segments_cleared
#SIGNALS END ******************************************
	
#CONSTANTS START HERE: ***************************************************
const SEGMENT_COUNT := 4
const LEVEL_HEIGHT := 3000
const SEGMENT_HEIGHT := 750 # LEVEL_HEIGHT PER SEGMENT_COUNT

# SEGMENTS SIZE AND DIVISION:
const SEGMENTS := [
	{"y_min": 2250, "y_max": 3000, "start_x": 540, "start_y": 2850, "enemies": 3},
	{"y_min": 1500, "y_max": 2250, "start_x": 540, "start_y": 2100, "enemies": 6},
	{"y_min": 750,  "y_max": 1500, "start_x": 540, "start_y": 1350, "enemies": 10},
	{"y_min": 0,    "y_max": 750,  "start_x": 540, "start_y": 600, "enemies": 0}
]
const SPAWN_MARGIN := 60

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
#VARIABLES END ****************************************************
	
#FUNCTIONS START HERE: ****************************************************
func _ready() -> void:
	player = get_parent().get_node("Player")
	draw_debug_boundaries.call_deferred()
	
func start_segment() -> void:
	enemies_alive = SEGMENTS[current_segment]["enemies"]
	print("[SegmentManager] Starting segment %d with %d enemies" % [current_segment+ 1, enemies_alive])
	place_top_wall()
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
	if enemies_alive <= 0:
		_on_segment_complete.call_deferred()
	
func spawn_enemies() -> void:
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
	var seg : Dictionary = SEGMENTS[current_segment]
	var batch := mini(randi_range(1, 3), enemies_to_spawn)
	for i in range(batch):
		var scene = enemy_scenes[randi() % enemy_scenes.size()]
		var new_enemy : EnemyBase = scene.instantiate()
		var entries : Array = SPAWN_ENTRIES[current_segment]
		var entry : Dictionary = entries[randi() % entries.size()]
		new_enemy.position = entry["from"]
		new_enemy.is_entering = true
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(new_enemy, "position", entry["to"], 0.8)
		tween.tween_callback(func():
			if is_instance_valid(new_enemy):
				new_enemy.is_entering = false
		)
		new_enemy.died.connect(on_enemy_died)
		get_parent().add_child(new_enemy)
		enemies_to_spawn -= 1
	spawn_timer.wait_time = randf_range(1.0, 3.0)
	
func on_enemy_died() -> void:
	enemies_alive = max(0, enemies_alive - 1)
	print("[SegmentManager] Enemies remainig: %d" % enemies_alive)
	if enemies_alive <= 0 and enemies_to_spawn <= 0 and not boss_alive:
		_on_segment_complete.call_deferred()
	
func _on_segment_complete() -> void:
	segment_cleared.emit(current_segment)
	print("[SegmentManager] Segment %d cleared!" % (current_segment + 1))
	remove_top_wall()
	place_bottom_wall()
	advance_to_next_segment()
	if current_segment < SEGMENT_COUNT:
		transition_to_next_segment()
	
func advance_to_next_segment() -> void:
		if spawn_timer:
			spawn_timer.queue_free()
			spawn_timer = null
		current_segment += 1
		if current_segment >= SEGMENT_COUNT:
			all_segments_cleared.emit()
		else:
			start_segment()
	
func transition_to_next_segment() -> void:
	var seg: Dictionary = SEGMENTS[current_segment]
	var target_pos := Vector2(seg["start_x"], seg["start_y"])
	
	player.input_enabled = false
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "position", target_pos, 2.0)
	tween.tween_callback(func():
		if not player.attract_mode:
			player.input_enabled = true
	)
	
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
	
func draw_debug_boundaries() -> void:
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
