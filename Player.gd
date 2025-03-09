extends CharacterBody3D

# Movement parameters
const SPEED = 5.0
const JUMP_VELOCITY = 6.0
const MOUSE_SENSITIVITY = 0.002


@export
var push_force = 1.0

# Gravity value
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var grabbed_object = null
var grab_distance = 0.0
var grab_offset = Vector3.ZERO

# Camera-related variables
@onready var camera = $Camera3D
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
		$Voice.stream = AudioStreamOpusChunked.new()
		audiostreamopuschunked = $Voice.stream
		audiostreamopuschunked.audiosamplechunks = 10
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
		# Get player name from the multiplayer manager
		#var manager = get_node("/root/Main/MultiplayerManager")
		#if manager:
		#	player_name = manager.player_name
		player_name = WebrtcMultiplayer.manager.player_name
		# RPC to set our name for all clients
		#print("test: " + str(args) + str(get_node("/root/MultiplayerTestUI/Game/Players/1").name))
		call_deferred("rpc", "set_player_name", player_name)

# RPC to sync the player name
@rpc("any_peer", "call_local")
func set_player_name(new_name):
	player_name = new_name
	name_label.text = player_name

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

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
		
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get movement input direction
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply movement, but only if not being knocked back by explosion
	if explosion_velocity.length() < 0.5:  # Small threshold to determine if explosion effect is over
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
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

# New function to interact with grabbed objects
func interact_with_grabbed_object():
	if grabbed_object and grabbed_object.is_in_group("rc_interactable"):
		var mp_rigidbody = grabbed_object.get_parent()
		if mp_rigidbody and mp_rigidbody.is_in_group("mp_rigidbody"):
			# Call the interact method on the rigidbody
			mp_rigidbody.interact()
			print("Interacted with: " + grabbed_object.name)

# New function to handle the grabbed object's movement
func handle_grabbed_object():
	# Calculate the target position (in front of the camera)
	var target_pos = camera.global_position - camera.global_transform.basis.z * grab_distance
	
	# Calculate velocity needed to move toward target
	var current_pos = grabbed_object.global_position
	var velocity_to_target = (target_pos - current_pos) * 10.0  # Adjust multiplier for responsiveness
	
	# Apply the velocity to the rigidbody through proper RPC mechanism
	apply_velocities(grabbed_object, velocity_to_target)

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
	# Show a message or feedback that object is grabbed (optional)
	print("Grabbed: " + grabbed_object.name)


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
	explosion_velocity.y = force.y* 3
	
	# Call move_and_slide() to apply the impulse immediately
	move_and_slide()
	
	print("Explosion impact applied with force: " + str(force))
	
func release_object():
	# Apply a small throw force in the direction we're looking (optional)
	if grabbed_object:
		var throw_direction = -camera.global_transform.basis.z
		var throw_force = throw_direction * 2.0  # Adjust throw strength as needed
		apply_velocities(grabbed_object, throw_force)
		grabbed_object = null
		print("Released object")

func apply_velocities(mp_rigidbody, force):
	mp_rigidbody.get_parent().apply_velocities(force)


var audiostreamopuschunked : AudioStreamOpusChunked 
var opuspacketsbuffer = [ ]   # append incoming packets to this list

func _process(delta: float) -> void:
	if not is_multiplayer_authority():

		while audiostreamopuschunked.chunk_space_available() and opuspacketsbuffer.size() >0:
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
		
	if opuspacketsbuffer.size() < 10:
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
	
