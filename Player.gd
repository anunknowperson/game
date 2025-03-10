extends CharacterBody3D

# Movement parameters
const WALK_SPEED = 2.0  # Reduced from 5.0 for slower movement
const RUN_SPEED = 5.0   # Faster run speed when shift is pressed
const JUMP_VELOCITY = 6.0
const MOUSE_SENSITIVITY = 0.002

# Health system
var max_health = 100
var current_health = 100
@onready var health_label = $Control/Label

# Stamina system
var max_stamina = 100
var current_stamina = 100
var stamina_regen_rate = 10  # Points per second
var stamina_run_cost = 70    # Points per second
var is_running = false
@onready var stamina_label = $Control/StaminaLabel  # Add this UI element

# Sound system
@onready var footstep_player = $FootstepPlayer  # Add this AudioStreamPlayer
@onready var damage_player = $DamagePlayer      # Add this AudioStreamPlayer
var footstep_timer = 0
var footstep_interval = 0.4  # Time between footsteps while walking
var run_footstep_interval = 0.25  # Time between footsteps while running
var is_walking = false  # Track walking state
var was_walking = false # Track previous walking state for sound management

# Sitting system
var is_sitting = false
@onready var standing_mesh = $StandingMesh
@onready var standing_shape = $StandingShape
@onready var sitting_mesh = $SittingMesh
@onready var sitting_shape = $SittingShape
@onready var standing_camera = $StandingCamera
@onready var sitting_camera = $SittingCamera
@onready var camera = $Camera3D

@export
var push_force = 1.0

# Gravity value
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var grabbed_object = null
var grab_distance = 0.0
var grab_offset = Vector3.ZERO

# Camera-related variables
@onready var mesh = $MeshInstance3D
@onready var name_label = $NameLabel
@export var raycast_distance = 3.0

# Player name
var player_name = "Player"

func _enter_tree():
	var args = Array(OS.get_cmdline_args())
	#set_multiplayer_authority(str(name).to_int(), true)

func _ready():
	if not is_multiplayer_authority():
		$Control.hide()
		
		$Voice.stream = AudioStreamOpusChunked.new()
		audiostreamopuschunked = $Voice.stream
		audiostreamopuschunked.audiosamplechunks = 50
		$Voice.play()
	else:
		$AudioStreamPlayer.stream = AudioStreamMicrophone.new()
		$AudioStreamPlayer.play()
	
	var args = Array(OS.get_cmdline_args())
	
	# Only process input for the player we control
	set_process_input(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	
	# Only show camera for our own player
	camera.current = is_multiplayer_authority()
	
	# For syncing player name
	if is_multiplayer_authority():
		player_name = WebrtcMultiplayer.manager.player_name
		call_deferred("rpc", "set_player_name", player_name)
		
	# Initialize stamina UI
	update_stamina_display()
	
	# Setup sitting/standing meshes and shapes
	setup_sitting_standing_state(false)

# RPC to sync the player name
@rpc("any_peer", "call_local", "reliable")
func set_player_name(new_name):
	player_name = new_name
	name_label.text = player_name

# Setup sitting/standing state
func setup_sitting_standing_state(sitting):
	is_sitting = sitting
	
	# Update meshes visibility
	if standing_mesh and sitting_mesh:
		standing_mesh.visible = !sitting
		sitting_mesh.visible = sitting
	
	# Update collision shapes
	if standing_shape and sitting_shape:
		standing_shape.disabled = sitting
		sitting_shape.disabled = !sitting
	
	# Update camera position
	if camera:
		if sitting:
			camera.position = sitting_camera.position
		else:
			camera.position = standing_camera.position
	
	# Sync with other players
	if is_multiplayer_authority():
		sync_sitting_standing.rpc(sitting)

# RPC to sync sitting/standing state with other players
@rpc("any_peer", "call_local", "reliable")
func sync_sitting_standing(sitting):
	# Don't update our own player (the authority already did that)
	if !is_multiplayer_authority():
		setup_sitting_standing_state(sitting)

func _input(event):
	if not is_multiplayer_authority():
		return
	
	# Mouse look (only when captured)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	# Handle interaction with grabbed interactable objects
	if event.is_action_pressed("interact_secondary") and grabbed_object and grabbed_object.is_in_group("rc_interactable"):
		interact_with_grabbed_object()
		
	# Toggle sitting state when CTRL is pressed
	if event.is_action_pressed("ui_sit"):  # Map CTRL to "ui_sit" in Project Settings
		setup_sitting_standing_state(!is_sitting)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
		
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump (only when standing)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and !is_sitting:
		velocity.y = JUMP_VELOCITY
	
	# Handle running (Shift key) - only when standing
	is_running = !is_sitting and Input.is_action_pressed("ui_run") and current_stamina > 0  # Add "ui_run" action mapped to Shift
	
	# Stamina management
	if is_running:
		current_stamina = max(0, current_stamina - stamina_run_cost * delta)
		if current_stamina <= 0:
			is_running = false
	else:
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
	
	update_stamina_display()
	
	# Get movement input direction
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Reduce or disable movement when sitting
	if is_sitting:
		# Either disable movement completely:
		# direction = Vector3.ZERO
		
		# Or reduce movement speed significantly:
		direction = direction * 0.3
	
	# Check if player is walking or running
	was_walking = is_walking
	is_walking = is_on_floor() and direction.length() > 0 and !is_sitting
	
	# Handle footstep sounds - now using RPC to sync with other players
	if is_walking != was_walking:
		# State has changed, need to update sound state
		if is_walking:
			# Started walking/running - RPC to all clients to start footsteps
			sync_footstep_sound.rpc(true, is_running)
		else:
			# Stopped walking/running - RPC to all clients to stop footsteps
			sync_footstep_sound.rpc(false, false)
	elif is_walking and is_running != was_running:
		# Still walking but changed from walking to running or vice versa
		sync_footstep_sound.rpc(true, is_running)
	
	# Store running state for next frame comparison
	was_running = is_running
	
	# Apply movement, but only if not being knocked back by explosion
	if explosion_velocity.length() < 0.5:  # Small threshold to determine if explosion effect is over
		if direction:
			var current_speed = RUN_SPEED if is_running else WALK_SPEED
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			var current_speed = RUN_SPEED if is_running else WALK_SPEED
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)
	else:
		# Add explosion velocity to movement velocity
		velocity.x += explosion_velocity.x
		velocity.z += explosion_velocity.z
		
		# Also apply vertical explosion velocity if it exists
		if abs(explosion_velocity.y) > 0.5:
			velocity.y += explosion_velocity.y * delta * 10  # Apply over time, adjust multiplier as needed
		
		# Gradually reduce explosion velocity over time
		explosion_velocity *= explosion_dampening
		
	# Apply movement
	move_and_slide()
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider().is_in_group("mp_rigidbody"):
			c.get_collider().get_parent().touch(-c.get_normal() * push_force * velocity.length())
	
	# Handle grabbed object physics
	if grabbed_object:
		handle_grabbed_object()
	
	# Check for button interaction (raycast)
	if Input.is_action_just_pressed("interact"): # You'll need to define this action
		perform_raycast()
	# Check for releasing grabbed object
	if Input.is_action_just_released("interact") and grabbed_object:
		release_object()

# Flag to track running state changes
var was_running = false

# New RPC to sync footstep sound state across the network
@rpc("any_peer", "call_local", "unreliable")
func sync_footstep_sound(is_playing, is_running_sound):
	if footstep_player:
		if is_playing:
			# Set pitch based on running state
			footstep_player.pitch_scale = 1.2 if is_running_sound else 1.0
			
			# Start playing if not already playing
			if not footstep_player.playing:
				footstep_player.play()
		else:
			# Stop playing if currently playing
			if footstep_player.playing:
				footstep_player.stop()

# Function to update stamina display
func update_stamina_display():
	if stamina_label:
		stamina_label.text = "Stamina: " + str(int(current_stamina)) + "/" + str(max_stamina)

# Modified function to play damage sound - now called by an RPC
func play_damage_sound():
	if damage_player and damage_player.stream:
		damage_player.play()

# New RPC to sync damage sound across the network
@rpc("any_peer", "call_local", "reliable")
func sync_damage_sound():
	play_damage_sound()

# New function to interact with grabbed objects
func interact_with_grabbed_object():
	if grabbed_object and grabbed_object.is_in_group("rc_interactable"):
		var mp_rigidbody = grabbed_object.get_parent()
		if mp_rigidbody and mp_rigidbody.is_in_group("mp_rigidbody"):
			# Call the interact method on the rigidbody
			mp_rigidbody.interact()

func handle_grabbed_object():
	# Calculate the target position (in front of the camera)
	var target_pos = camera.global_position - camera.global_transform.basis.z * grab_distance
	
	# Get the mp_rigidbody
	var mp_rigidbody = grabbed_object.get_parent()
	
	# Check if we should only move on X and Z axes
	var only_x_z = false
	var vertical_limit = 0.0
	
	if mp_rigidbody and mp_rigidbody.is_in_group("mp_rigidbody"):
		if mp_rigidbody.has_method("get") and mp_rigidbody.get("only_x") == true:
			only_x_z = true
			
			# Use current_y property instead of meta data
			vertical_limit = mp_rigidbody.current_y + 1.0
	
	# Modify target position if we're only moving on X and Z
	if only_x_z:
		target_pos.y = max(vertical_limit, grabbed_object.global_position.y)  # Keep at least current_y + 0.1
	
	# Calculate velocity needed to move toward target
	var current_pos = grabbed_object.global_position
	var velocity_to_target = (target_pos - current_pos) * 10.0  # Adjust multiplier for responsiveness

	# If we're only controlling X and Z, ensure vertical force is >= 0 when at or below the limit
	if only_x_z and current_pos.y <= vertical_limit and velocity_to_target.y < 0:
		velocity_to_target.y = 0
	
	# Extract the forward vectors - using the grabbed_object for current orientation
	var target_forward = -camera.global_transform.basis.z.normalized()
	var current_forward = -grabbed_object.global_transform.basis.z.normalized()
	
	# Calculate the rotation axis
	var rotation_axis = current_forward.cross(target_forward)
	var rotation_axis_length = rotation_axis.length()
	
	# Normalize rotation axis if not too small
	if rotation_axis_length > 0.001:
		rotation_axis = rotation_axis / rotation_axis_length
	else:
		# Vectors are parallel or anti-parallel
		if current_forward.dot(target_forward) < 0:
			# Anti-parallel - use any perpendicular axis
			rotation_axis = current_forward.cross(Vector3.UP)
			if rotation_axis.length() < 0.001:
				rotation_axis = current_forward.cross(Vector3.RIGHT)
			rotation_axis = rotation_axis.normalized()
		else:
			# Already aligned, no rotation needed
			rotation_axis = Vector3.ZERO
	
	# Calculate the angle between vectors
	var dot_product = current_forward.dot(target_forward)
	var angle = acos(clamp(dot_product, -1.0, 1.0))
	
	# Calculate angular velocity based on angle
	var angular_velocity = Vector3.ZERO
	
	if angle > 0.05:  # Only rotate if angle is significant
		# Scale rotation speed based on angle, but set a maximum
		var rotation_speed = min(angle * 2.0, 4.0)  # Reduced speed for smoother rotation
		angular_velocity = rotation_axis * rotation_speed
	else:
		# When nearly aligned, apply damping to stop rotation
		var current_angular_velocity = Vector3.ZERO
		current_angular_velocity = grabbed_object.angular_velocity
		angular_velocity = -current_angular_velocity * 0.95
	
	# Apply angular velocity through the mp_rigidbody
	if mp_rigidbody and mp_rigidbody.is_in_group("mp_rigidbody"):
		apply_angular_velocities(mp_rigidbody, angular_velocity)
	
	# Apply linear velocity
	apply_velocities(grabbed_object, velocity_to_target)

# Add a helper function to apply angular velocities to an object
func apply_angular_velocities(mp_rigidbody, angular_force):
	mp_rigidbody.apply_angular_velocities(angular_force)

# Modify your perform_raycast function to handle grabbable objects
func perform_raycast():
	# Create a new physics raycast
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.global_position
	var ray_end = ray_origin + camera.global_transform.basis.z * -raycast_distance
	
	# Perform the raycast
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	
	# Check if we hit something
	if result:
		var collider = result["collider"]
		# Check if the object is in the "rc_button" group
		if collider.is_in_group("rc_button"):
			# Call the press method on the button
			collider.press()
		# Check if the object is in the "rc_grabbable" group
		elif collider.is_in_group("rc_grabbable") and not grabbed_object:
			# Get the rigidbody parent
			var mp_rigidbody = collider.get_parent()
			if mp_rigidbody and mp_rigidbody.is_in_group("mp_rigidbody"):
				grab_object(collider, result["position"])
	# If we have a grabbed object and release the interact button, release it
	elif grabbed_object and Input.is_action_just_released("interact"):
		release_object()

# Add these new functions for grabbing and releasing objects
func grab_object(object, grab_point):
	grabbed_object = object
	# Calculate the distance from the camera to the grab point
	grab_distance = camera.global_position.distance_to(grab_point)
	# Calculate offset from object center to grab point
	grab_offset = grab_point - grabbed_object.global_position
	
	# Call pickup() on the mp_rigidbody
	var mp_rigidbody = grabbed_object.get_parent()
	if mp_rigidbody and mp_rigidbody.is_in_group("mp_rigidbody"):
		mp_rigidbody.pickup()

# Track explosion impact separately
var explosion_velocity = Vector3.ZERO
var explosion_dampening = 0.95  # Dampening factor (adjust as needed)

func apply_explosion_impact(force, hp_damage = 20):
	if not is_multiplayer_authority():
		return
		
	# Apply the explosion force directly to both the explosion_velocity and vertical velocity
	# This ensures consistent force application across all axes
	explosion_velocity.x = force.x
	explosion_velocity.z = force.z
	
	# Apply the same magnitude of force to the vertical component
	# This ensures the player gets "kicked" with equal force in all directions
	explosion_velocity.y = force.y * 3
	
	# Call move_and_slide() to apply the impulse immediately
	move_and_slide()
	
# Clear grab metadata when releasing object
func release_object():
	# Apply a small throw force in the direction we're looking
	if grabbed_object:
		var throw_direction = -camera.global_transform.basis.z
		var throw_force = throw_direction * 2.0  # Adjust throw strength as needed
		
		var mp_rigidbody = grabbed_object.get_parent()
		if mp_rigidbody and mp_rigidbody.is_in_group("mp_rigidbody"):
			# Clear any grab-related metadata
			if mp_rigidbody.has_meta("grab_start_time"):
				mp_rigidbody.remove_meta("grab_start_time")
			if mp_rigidbody.has_meta("initial_y"):
				mp_rigidbody.remove_meta("initial_y")
			
			# Call drop() on the mp_rigidbody
			mp_rigidbody.drop()
		
		apply_velocities(grabbed_object, throw_force)
		grabbed_object = null

func apply_velocities(mp_rigidbody, force):
	mp_rigidbody.get_parent().apply_velocities(force)

var audiostreamopuschunked : AudioStreamOpusChunked 
var opuspacketsbuffer = [ ]   # append incoming packets to this list

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		while audiostreamopuschunked.chunk_space_available() and opuspacketsbuffer.size() > 0:
			audiostreamopuschunked.push_opus_packet(opuspacketsbuffer.pop_front(), 0, 0)
		return
		
	var idx = AudioServer.get_bus_index("Record")
	var opuschunked = AudioServer.get_bus_effect(idx, 0)
	
	var chunks = []
	
	var prepend = PackedByteArray()
	while opuschunked.chunk_available():
		var opusdata : PackedByteArray = opuschunked.read_opus_packet(prepend)
		opuschunked.drop_chunk()
		chunks.append(opusdata)
	
	if chunks.size() > 0:
		send_data.rpc(chunks)
	
@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_data(data : Array):
	if is_multiplayer_authority():
		return
		
	if opuspacketsbuffer.size() < 15:
		opuspacketsbuffer.append_array(data)
	else:
		# If buffer is full, replace oldest chunks with newest ones
		# This ensures we keep the most recent audio data
		var overflow = data.size()
		var to_remove = min(overflow, opuspacketsbuffer.size())
		
		# Remove oldest chunks
		for i in range(to_remove):
			opuspacketsbuffer.remove_at(0)
		
		# Add newest chunks
		opuspacketsbuffer.append_array(data)

@rpc("any_peer", "call_local")
func apply_damage(amount):
	if is_multiplayer_authority():
		# Play damage sound using RPC to ensure all clients hear it
		sync_damage_sound.rpc()
		
		# Lower HP
		current_health = max(0, current_health - amount)
		
		# Update local health display
		update_health_display()
		
		# Sync health with all clients
		sync_health.rpc(current_health)
		
		# Check if player died
		if current_health <= 0:
			handle_death()

# Add a new RPC to sync health across clients
@rpc("authority", "call_remote", "reliable")
func sync_health(health_value):
	current_health = health_value
	update_health_display()

# Add a function to update the health display
func update_health_display():
	if health_label:
		health_label.text = "HP: " + str(current_health) + "/" + str(max_health)

# Add a function to handle player death
func handle_death():
	# Implement death behavior (respawn, game over, etc.)
	if is_multiplayer_authority():
		$Control/Label2.visible = true
	
	global_position.y += 50

func damage(amount):
	apply_damage.rpc(amount)
