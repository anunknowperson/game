extends CharacterBody3D

# Export variables for configuration
@export var movement_speed: float = 1.0
@export var run_speed: float = 2.0
@export var attack_range: float = 0.5
@export var attack_range_outer: float = 3.0
@export var attack_cooldown: float = 2.0
@export var idle_time_min: float = 10.0
@export var idle_time_max: float = 20.0
# Patrol locations will now be fetched from group instead of manually setting
@export var use_group_locations: bool = true
@export var patrol_group_name: String = "ms_loc"
# Keep this as a fallback or for manual override
@export var manual_patrol_locations: Array[Vector3] = []
# Sound variables
@export var random_laugh_chance: float = 0.003  # Chance per physics frame
@export var vision_angle_degrees: float = 90.0  # Field of view angle
@export var vision_distance: float = 15.0       # Maximum vision distance
@export var player_activation_radius: float = 3.5  # Radius to start looking for player
@export var chase_max_distance: float = 3.5    # Maximum distance to chase player without sight

# Actual patrol locations array (will be populated from group or manual list)
var patrol_locations: Array[Vector3] = []

# Navigation properties
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_controller: Node3D = $Model
@onready var footstep_sound: AudioStreamPlayer3D = $FootstepSound
@onready var laugh_sound: AudioStreamPlayer3D = $LaughSound
@onready var alert_sound: AudioStreamPlayer3D = $AlertSound
@onready var attack_sound: AudioStreamPlayer3D = $AttackSound

# State machine variables
enum State { IDLE, PATROL, CHASE, ATTACK }
var current_state: int = State.IDLE
var target_player = null
var last_attack_time: float = 0.0
var idle_timer: float = 0.0
var is_attack_animation_playing: bool = false
var player_detected: bool = false  # For vision detection
var last_sound_time: float = 0.0   # To prevent sound spam
var is_walking: bool = false       # Track walking state for sound
var last_known_player_position: Vector3 = Vector3.ZERO  # Track last seen player position
var time_since_last_seen: float = 0.0  # Time since player was last visible

# Multiplayer synchronization
@rpc("call_local")
func sync_animation_state(anim_state: String) -> void:
	match anim_state:
		"idle":
			animation_controller.idle_anim()
		"move":
			animation_controller.move_anim()
		"attack":
			animation_controller.atk_anim()

# Sound RPC functions
@rpc("call_local")
func start_walking_sound() -> void:
	pass
	# if not footstep_sound.playing:
	#	footstep_sound.play()

@rpc("call_local")
func stop_walking_sound() -> void:
	pass
	# if footstep_sound.playing:
	# 	footstep_sound.stop()

@rpc("call_local")
func play_laugh_sound() -> void:
	pass
	# laugh_sound.play()

@rpc("call_local")
func play_alert_sound() -> void:
	alert_sound.play()

@rpc("call_local")
func play_attack_sound() -> void:
	attack_sound.play()

func _ready():
	if is_multiplayer_authority():
		# Get patrol locations from group if enabled
		if use_group_locations:
			get_patrol_locations_from_group()
		else:
			patrol_locations = manual_patrol_locations
			
		if patrol_locations.size() == 0:
			push_warning("No patrol locations found for monster!")
		
		# Configure navigation agent
		navigation_agent.path_desired_distance = 0.5
		navigation_agent.target_desired_distance = 0.5
		
		# Set up the initial state
		change_state(State.IDLE)
		
		# Start the AI processing
		actor_setup.call_deferred()
	else:
		# Display debug info for non-authority instances
		$Label3D.text = "Not Authority\nUID: %s" % str(multiplayer.get_unique_id())
		$Label3D.modulate = Color.GREEN

func get_patrol_locations_from_group():
	patrol_locations = []
	var group_nodes = get_tree().get_nodes_in_group(patrol_group_name)
	
	if group_nodes.size() > 0:
		for node in group_nodes:
			patrol_locations.append(node.global_position)
		print("Found %d patrol locations from group: %s" % [patrol_locations.size(), patrol_group_name])
	else:
		push_warning("No nodes found in group: " + patrol_group_name)
		# Fall back to manual locations if group is empty
		patrol_locations = manual_patrol_locations

func actor_setup():
	# Wait for the first physics frame so the NavigationServer can sync
	await get_tree().physics_frame
	
	# Start the AI processing loop
	set_idle_timer()
	
	# Update debug info
	if $Label3D:
		$Label3D.text = "Authority\nUID: %s" % str(multiplayer.get_unique_id())
		$Label3D.modulate = Color.RED

func set_idle_timer():
	idle_timer = randf_range(idle_time_min, idle_time_max)

func change_state(new_state: int):
	if current_state == new_state:
		return
	
	var prev_state = current_state
	current_state = new_state
	
	# Handle walking sound state changes
	if new_state == State.IDLE:
		stop_walking_sound.rpc()
		is_walking = false
	elif (new_state == State.PATROL or new_state == State.CHASE) and not is_walking:
		start_walking_sound.rpc()
		is_walking = true
	
	match current_state:
		State.IDLE:
			sync_animation_state.rpc("idle")
			set_idle_timer()
		State.PATROL:
			sync_animation_state.rpc("move")
			choose_random_patrol_location()
		State.CHASE:
			sync_animation_state.rpc("move")
			if target_player:
				# Play alert sound when first detecting player
				if prev_state != State.CHASE and prev_state != State.ATTACK:
					play_alert_sound.rpc()
				set_movement_target(target_player.global_position)
				# Update last known position
				last_known_player_position = target_player.global_position
				time_since_last_seen = 0.0
		State.ATTACK:
			stop_walking_sound.rpc()
			is_walking = false
			if not is_attack_animation_playing:
				is_attack_animation_playing = true
				sync_animation_state.rpc("attack")
				# Play attack sound
				play_attack_sound.rpc()
				start_attack_sequence()
			last_attack_time = Time.get_ticks_msec() / 1000.0

func choose_random_patrol_location():
	if patrol_locations.size() > 0:
		var random_index = randi() % patrol_locations.size()
		set_movement_target(patrol_locations[random_index])

var nav_tar :Vector3

func set_movement_target(target_pos: Vector3):
	nav_tar = target_pos
	
	navigation_agent.set_target_position(target_pos)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	
	
	
	# Process current state
	match current_state:
		State.IDLE:
			# Look for players within activation radius
			find_closest_player()
			process_idle_state(delta)
		State.PATROL:
			find_closest_player()
			process_patrol_state(delta)
			maybe_play_random_laugh()
		State.CHASE:
			process_chase_state(delta)
		State.ATTACK:
			process_attack_state(delta)

func process_idle_state(delta):
	# Count down the idle timer
	idle_timer -= delta
	
	# If target is in range and detected by vision, chase them
	if target_player and is_player_detected(target_player):
		change_state(State.CHASE)
		return
	
	# When idle time is done, move to a new location
	if idle_timer <= 0:
		change_state(State.PATROL)

func process_patrol_state(delta):
	# If we're stuck or reached our destination
	if navigation_agent.is_navigation_finished():
		change_state(State.IDLE)
		return
	
	# If target is in range and detected by vision, chase them
	if target_player and is_player_detected(target_player):
		change_state(State.CHASE)
		return
	
	# Add this check to select a new patrol point when current one is reached
	if navigation_agent.is_navigation_finished():
		print("TO IDLE")
		change_state(State.IDLE)
		return
	
	# Otherwise, continue patrolling
	move_along_path(movement_speed)

func process_chase_state(delta):
	# Lost target or target disappeared or died
	if not target_player or not is_instance_valid(target_player) or target_player.dead:
		change_state(State.IDLE)
		return
	
	# Calculate distance to player
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	# Check if player is beyond chase_max_distance
	if distance_to_player > chase_max_distance:
		print("Player beyond chase range, returning to idle")
		change_state(State.IDLE)
		return
	
	# Check if player is visible 
	var is_visible = check_player_visibility(target_player)
	
	# If player not visible for too long, stop chasing
	if not is_visible:
		time_since_last_seen += delta
		if time_since_last_seen > 3.0:
			print("Lost sight of player for too long, returning to idle")
			change_state(State.IDLE)
			return
	else:
		# Reset timer and update last known position when player is visible
		time_since_last_seen = 0.0
		last_known_player_position = target_player.global_position
	
	# Always face the player during chase regardless of movement
	look_at(target_player.global_position, Vector3.UP)
	
	# If within attack range and player is visible, attack
	if is_visible and distance_to_player <= attack_range:
		# Only transition to attack if not in cooldown
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_attack_time > attack_cooldown:
			change_state(State.ATTACK)
		return
	
	var mvtg = null
	
	# Set movement target to player position if visible
	if is_visible:
		mvtg = target_player.global_position
	else:
		mvtg = last_known_player_position
	
	var new_velocity = global_position.direction_to(mvtg) * run_speed
	velocity = new_velocity
	move_and_slide()
	
func check_player_visibility(player):
	if not is_instance_valid(player) or player.dead:  # Skip dead players
		
		return false

	
	var space_state = get_world_3d().direct_space_state
	
	# First ray: monster's head to player's upper body
	var ray_start = global_position
	var ray_end = player.global_position + Vector3(0, 0.3, 0)
	
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = ray_start
	ray_query.to = ray_end
	ray_query.exclude = [self]
	ray_query.collision_mask = 1
	
	var result = space_state.intersect_ray(ray_query)
	
	# Check result of first ray
	var hit_player_upper = result.get("collider") == player
	
	#print("Visibility check: upper_body=", hit_player_upper, " head=", hit_player_head, 
	#	  " top_down=", ray2_visible, " is_visible=", is_visible)
	
	return hit_player_upper

func process_attack_state(delta):
	# Check if attack animation is still playing
	if is_attack_animation_playing:
		# Make sure we're facing the player even during attack animation
		if target_player and is_instance_valid(target_player) and not target_player.dead:
			look_at(target_player.global_position, Vector3.UP)
		return
		
	# Animation completed, determine next state based on player position
	if not target_player or not is_instance_valid(target_player) or target_player.dead:
		print("Target invalid or dead, returning to IDLE")
		change_state(State.IDLE)
		return
	
	# Rest of the function remains the same...
	
	# Calculate distance to player
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	# Check if we should chase or attack again
	if distance_to_player > attack_range:
		print("Player out of attack range, switching to CHASE")
		change_state(State.CHASE)
		return
	
	# Check if player is still visible
	var is_visible = check_player_visibility(target_player)
	if not is_visible:
		print("Player not visible, switching to CHASE")
		change_state(State.CHASE)
		return
	
	# Player still in range and visible, check cooldown for next attack
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time > attack_cooldown:
		# Start a new attack
		print("Starting new attack")
		is_attack_animation_playing = true
		sync_animation_state.rpc("attack")
		play_attack_sound.rpc()
		start_attack_sequence()
		last_attack_time = current_time
	else:
		# If in cooldown but player is moving away, switch to chase
		print("In cooldown, checking if should chase")
		if distance_to_player > attack_range * 0.8:  # Give some buffer
			print("Player moving away, switching to CHASE during cooldown")
			change_state(State.CHASE)

func start_attack_sequence():
	# Make sure we don't have an existing timer
	if has_node("AttackSequence"):
		$AttackSequence.queue_free()
	
	# Create a timer to handle the attack sequence properly
	var timer = Timer.new()
	timer.name = "AttackSequence"
	timer.one_shot = true
	timer.wait_time = 1.5  # Changed from 2.0 to 1.5 seconds for damage timing
	add_child(timer)
	timer.start()
	timer.timeout.connect(_on_attack_animation_completed)

func _on_attack_animation_completed():
	# Remove the sequence timer
	if has_node("AttackSequence"):
		$AttackSequence.queue_free()
	
	# Deal damage only if player still in range
	if target_player and is_instance_valid(target_player) and is_player_in_range(target_player, attack_range_outer):
		# Call damage on player
		print("Dealing damage to player")
		target_player.damage(5)
	
	# Mark animation as completed
	is_attack_animation_playing = false

func find_closest_player():
	var players = get_tree().get_nodes_in_group("mp_player")
	var min_distance = INF
	target_player = null
	
	for player in players:
		if not is_instance_valid(player) or player.dead:  # Skip dead players
			continue
			
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance and distance < player_activation_radius:
			min_distance = distance
			target_player = player

func is_player_in_range(player, range_distance):
	if not is_instance_valid(player) or player.dead:  # Skip dead players
		return false
	return global_position.distance_to(player.global_position) <= range_distance

func is_player_detected(player):
	if not is_instance_valid(player) or player.dead:  # Skip dead players
		return false
	
	# Check if player is in activation radius first
	var distance = global_position.distance_to(player.global_position)
	if distance > player_activation_radius:
		return false
	
	# Now check if player is in vision range
	if distance > vision_distance:
		return false
	
	# Use our new visibility check function
	return check_player_visibility(player)

func move_along_path(speed):

	if navigation_agent.is_navigation_finished():
		# If we've stopped moving, stop the walking sound
		if is_walking:
			stop_walking_sound.rpc()
			is_walking = false
		return
		
	var current_position = global_position
	var next_position = navigation_agent.get_next_path_position()
	
	# Calculate velocity
	var new_velocity = current_position.direction_to(next_position) * speed
	
	# Look in the direction of movement
	if new_velocity.length() > 0.1:
		look_at(global_position + Vector3(new_velocity.x, 0, new_velocity.z), Vector3.UP)
		
		# Make sure walking sound is playing while moving
		if not is_walking:
			start_walking_sound.rpc()
			is_walking = true
	else:
		# Stop walking sound if we're not moving
		if is_walking:
			stop_walking_sound.rpc()
			is_walking = false
	
	# Set velocity and move
	velocity = new_velocity
	
	move_and_slide()

func maybe_play_random_laugh():
	# Random chance to play laugh sound during patrol
	if randf() < random_laugh_chance:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_sound_time > 3.0:  # Ensure at least 3 seconds between laughs
			play_laugh_sound.rpc()
			last_sound_time = current_time
