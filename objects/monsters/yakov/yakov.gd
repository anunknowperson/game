extends CharacterBody3D

@onready var footstep_sound: AudioStreamPlayer3D = $FootstepSound
@onready var alert_sound: AudioStreamPlayer3D = $AlertSound
@onready var attack_sound: AudioStreamPlayer3D = $AttackSound

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@export var patrol_group_name: String = "ms_loc"

@export var player_activation_radius: float = 8.0  # Radius when to check with raycast

@export var attack_range: float = 1
@export var attack_range_outer: float = 4
@export var attack_cooldown: float = 2.0

@export var movement_speed: float = 2
@export var run_speed: float = 4

@export var idle_time_min: float = 5.0
@export var idle_time_max: float = 15.0

var is_walking: bool = false
var idle_timer: float = 0.0
var last_attack_time: float = 0.0

enum State { IDLE, PATROL, CHASE, ATTACK }
var current_state: int = State.IDLE

var patrol_locations: Array[Vector3] = []

var chase_target_player = null

func _ready() -> void:
	if is_multiplayer_authority():
		get_patrol_locations_from_group()
		set_idle_timer()
		current_state = State.IDLE
		
func get_player_class(player) -> String:
	if player and is_instance_valid(player):
		# Get player class from globals
		
		
		if Globals.player_options.has(player.get_multiplayer_authority()):
			return Globals.player_options[player.get_multiplayer_authority()]["class"]
	return ""

func set_idle_timer():
	idle_timer = randf_range(idle_time_min, idle_time_max)

func get_attack_target():
	var players = get_tree().get_nodes_in_group("mp_player")
	
	var target_player = null
	
	for player in players:
		if not is_instance_valid(player) or player.dead:  # Skip dead players
			continue
			
		var distance = global_position.distance_to(player.global_position)
		if distance < player_activation_radius:
			
			if check_player_visibility(player):
				target_player = player
				
	
	return target_player

var last_ignored_time = {}

func ignore_logic(player):
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if player in last_ignored_time:
		if current_time - last_ignored_time[player] > 10.0:
			last_ignored_time.erase(player)
		else:
			return true
		
	var player_class = get_player_class(player)
		
	if player_class == "TP":
		var val = randf()
		if val < 0.5:
			print("DECIDED TO IGNORE")
			last_ignored_time[player] = current_time
			
			print("Decided to ignore TP player:")

			return true

		
	return false


func process_idle_state(delta):
	var target = get_attack_target()
	
	if target:
		if !ignore_logic(target):
			
			play_alert_sound.rpc()
			chase_target_player = target
			current_state = State.CHASE
			return
	
	idle_timer -= delta
	
	
	# When idle time is done, move to a new location
	if idle_timer <= 0:
		choose_random_patrol_location()
		current_state = State.PATROL
	
func process_patrol_state(delta):
	# If target is in range and detected by vision, chase them
	var target = get_attack_target()
	
	if target:
		if !ignore_logic(target):
			
			play_alert_sound.rpc()
			chase_target_player = target
			current_state = State.CHASE
			return
	
	
	# Otherwise, continue patrolling
	move_along_path(movement_speed)

var last_visible = 0

func play_attack_on_others(player):
	for peer in multiplayer.get_peers():
		if peer != player.get_multiplayer_authority():
			play_attack_sound.rpc_id(peer)
	
	player.yakov_screamer.rpc()
	
	

func process_chase_state(delta):
	# If target is no longer valid
	var target = get_attack_target()
	
	if chase_target_player != target:
		
		if target != null and !ignore_logic(target):
			
			play_alert_sound.rpc()
			chase_target_player = target
			current_state = State.CHASE
		
		
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_visible > 6.0:
			current_state = State.IDLE
	else:
		var current_time = Time.get_ticks_msec() / 1000.0
		last_visible = current_time
	
	
	if !is_instance_valid(chase_target_player) or chase_target_player.dead :
		current_state = State.IDLE
		return
	
	# The rest of the function remains unchanged
	look_at(chase_target_player.global_position, Vector3.UP)
	
	var distance_to_player = global_position.distance_to(chase_target_player.global_position)
	
	if distance_to_player <= attack_range:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_attack_time > attack_cooldown:
			current_state = State.ATTACK
		return
	
	if distance_to_player >= 6.0:
		current_state = State.IDLE
	else:
		set_movement_target(chase_target_player.global_position)
		
		
		move_along_path(run_speed)

func process_attack_state(delta):
	var target = get_attack_target()
	
	if !is_instance_valid(chase_target_player) or chase_target_player.dead:
		current_state = State.IDLE
		return
	
	look_at(chase_target_player.global_position, Vector3.UP)
		
	# Rest of the function remains the same...
	
	
	# Player still in range and visible, check cooldown for next attack
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time > attack_cooldown:
		# Start a new attack
		var distance_to_player = global_position.distance_to(chase_target_player.global_position)
		if chase_target_player == target and distance_to_player <= attack_range:
		
			attack_player.call_deferred(chase_target_player)
			last_attack_time = current_time
		else:
			current_state = State.CHASE
			return


func attack_player(attacked_player):
	await get_tree().create_timer(1.5).timeout
	
	
	var distance_to_player = global_position.distance_to(attacked_player.global_position)
	
	# Deal damage only if player still in range
	if attacked_player and is_instance_valid(attacked_player) and distance_to_player <= attack_range_outer:
		var player_class = get_player_class(attacked_player)
		
		play_attack_on_others(attacked_player)
		
		# Determine damage based on player class
		if player_class == "TP":
			# Standard damage for TP class
			print("Dealing 100 damage to TP class player")
			attacked_player.damage(50)
		elif player_class == "SE":
			# For SE class, always hit with 150 damage (since ignored ones never get to this point)
			print("Dealing 150 damage to SE class player")
			attacked_player.damage(150)
		else:
			# Fallback to default behavior for unknown classes
			print("Dealing default damage to player")
			attacked_player.damage(50)
	else:
		current_state = State.CHASE

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	
	# DebugDraw3D.draw_sphere(mov_tar)
	
	match current_state:
		State.IDLE:
			process_idle_state(delta)
		State.PATROL:
			process_patrol_state(delta)
		State.CHASE:
			process_chase_state(delta)
		State.ATTACK:
			process_attack_state(delta)

	
func choose_random_patrol_location():
	var random_index = randi() % patrol_locations.size()
	set_movement_target(patrol_locations[random_index])

var mov_tar := Vector3.ZERO
func set_movement_target(target_pos: Vector3):
	mov_tar = target_pos
	navigation_agent.set_target_position(target_pos)

func get_patrol_locations_from_group():
	patrol_locations = []
	var group_nodes = get_tree().get_nodes_in_group(patrol_group_name)
	
	for node in group_nodes:
		patrol_locations.append(node.global_position)

func move_along_path(speed):
	if navigation_agent.is_navigation_finished():
		# If we've stopped moving, stop the walking sound
		if current_state== State.PATROL:
			set_idle_timer()
			current_state = State.IDLE
		
		if is_walking:
			stop_walking_sound.rpc()
			is_walking = false
		return
		
	var current_position = global_position
	var next_position = navigation_agent.get_next_path_position()
	
	# DebugDraw3D.draw_sphere(current_position, 0.3, Color.RED)
	# DebugDraw3D.draw_sphere(next_position, 0.3, Color.GREEN)
	
	# Calculate velocity
	var new_velocity = current_position.direction_to(next_position) * speed
	# Look in the direction of movement
	
	look_at(global_position + Vector3(new_velocity.x, 0, new_velocity.z), Vector3.UP)
		
	# Make sure walking sound is playing while moving
	if not is_walking:
		start_walking_sound.rpc()
		is_walking = true

	# Set velocity and move
	velocity = new_velocity
	
	move_and_slide()

func check_player_visibility(player):
	if not is_instance_valid(player) or player.dead:  # Skip dead players
		return false
	
	var space_state = get_world_3d().direct_space_state
	
	# First ray: monster's head to player's upper body
	var ray_start = global_position + Vector3(0, 1.5, 0)
	var ray_end = player.global_position + Vector3(0, 0.3, 0)
	
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = ray_start
	ray_query.to = ray_end
	ray_query.exclude = [self]
	ray_query.collision_mask = 1
	
	var result = space_state.intersect_ray(ray_query)
	
	# Check result of first ray
	var hit_player_upper = result.get("collider") == player
	
	# Third ray: monster's head to player's head
	var ray3_start = global_position + Vector3(0, 1.5, 0)
	var ray3_end = player.global_position + Vector3(0, 1.5, 0)
	
	var ray3_query = PhysicsRayQueryParameters3D.new()
	ray3_query.from = ray3_start
	ray3_query.to = ray3_end
	ray3_query.exclude = [self]
	ray3_query.collision_mask = 1
	
	var ray3_result = space_state.intersect_ray(ray3_query)
	
	# Check result of third ray
	var hit_player_head = ray3_result.get("collider") == player
	
	# Second ray: from above player pointing down
	var ray2_start = player.global_position + Vector3(0, 2.1, 0)
	var ray2_end = player.global_position
	
	var ray2_query = PhysicsRayQueryParameters3D.new()
	ray2_query.from = ray2_start
	ray2_query.to = ray2_end
	ray2_query.exclude = [self]
	ray2_query.collision_mask = 1
	
	var ray2_result = space_state.intersect_ray(ray2_query)
	
	# Check if first hit of ray2 is the player
	var ray2_visible = ray2_result.get("collider") == player
	
	# New visibility condition: (ray1 OR ray3) AND ray2
	var horizontal_visible = hit_player_upper or hit_player_head
	var is_visible = horizontal_visible and ray2_visible
	
	#print("Visibility check: upper_body=", hit_player_upper, " head=", hit_player_head, 
	#	  " top_down=", ray2_visible, " is_visible=", is_visible)
	
	return is_visible

# Sound RPC functions
@rpc("call_local")
func start_walking_sound() -> void:
	if not footstep_sound.playing:
		footstep_sound.play()

@rpc("call_local")
func stop_walking_sound() -> void:
	if footstep_sound.playing:
		footstep_sound.stop()

@rpc("call_local")
func play_alert_sound() -> void:
	alert_sound.play()

@rpc("call_local")
func play_attack_sound() -> void:
	attack_sound.play()
