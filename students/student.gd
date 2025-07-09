extends CharacterBody3D

@onready var container = get_parent()

@onready var model = $Model

# Player movement
@export var walk_speed = 3.0
@export var run_speed = 6.0
@export var crouch_speed = 1.5
@export var jump_velocity = 4.5
@export var mouse_sensitivity = 0.002

# Stamina settings
@export var stamina_drain_rate = 20.0  # Stamina drained per second while running
@export var stamina_regen_rate = 15.0  # Stamina regenerated per second while not running
@export var min_stamina_to_run = 10.0  # Minimum stamina needed to start running
@export var stamina_regen_delay = 1.0  # Delay before stamina starts regenerating after running

# Camera
@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D

# Movement states
var is_crouching = false
var is_running = false
var current_speed = 0.0
var stamina_regen_timer = 0.0  # Timer for stamina regeneration delay

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Only capture mouse and enable camera for the authority player
	if is_multiplayer_authority():
		MouseManager.capture()
		camera.current = true
	else:
		# Disable camera for non-authority players
		camera.current = false

func _input(event):
	# Only handle input if this player has authority
	if not is_multiplayer_authority():
		return
		
	# Handle mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate player horizontally
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotate camera vertically
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# Clamp camera vertical rotation
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	# Only process movement for authority player
	if not is_multiplayer_authority():
		return
	
	# Handle crouch input
	var crouch_input = Input.is_action_pressed("crouch")
	is_crouching = crouch_input
	
	# Handle run input (shift) - check stamina
	var run_input = Input.is_action_pressed("run")
	var can_run = run_input and not is_crouching and _can_run()
	
	# Update running state
	if can_run and container.st >= min_stamina_to_run:
		is_running = true
	else:
		is_running = false
	
	# Handle stamina
	_handle_stamina(delta)
	
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump (space)
	if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump")) and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	# Calculate movement direction relative to player's rotation
	var direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Determine speed based on state
	var target_speed = walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_running:
		target_speed = run_speed
	
	# Apply movement
	if direction:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
		current_speed = velocity.length()
	else:
		velocity.x = move_toward(velocity.x, 0, target_speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, target_speed * delta * 10)
		current_speed = velocity.length()

	move_and_slide()
	
	# Update animation based on movement state (only for authority)
	_update_animation_state(input_dir)
	
	# Send transform sync to other players
	_sync_transform()

func _handle_stamina(delta):
	# Only handle stamina for authority player
	if not is_multiplayer_authority():
		return
	
	# Check if we're moving and trying to run
	var is_moving = velocity.length() > 0.1
	var trying_to_run = Input.is_action_pressed("run") and not is_crouching and is_moving
	
	if is_running and trying_to_run:
		# Drain stamina while running
		var new_stamina = container.st - (stamina_drain_rate * delta)
		container.set_st(max(0, new_stamina))
		
		# Reset regeneration timer
		stamina_regen_timer = stamina_regen_delay
		
		# Stop running if stamina is too low
		if container.st <= 0:
			is_running = false
	else:
		# Regenerate stamina when not running
		if stamina_regen_timer > 0:
			stamina_regen_timer -= delta
		else:
			var new_stamina = container.st + (stamina_regen_rate * delta)
			container.set_st(min(100.0, new_stamina))

func _can_run() -> bool:
	# Check if player has enough stamina to run
	return container.st >= min_stamina_to_run

func _update_animation_state(input_dir: Vector2):
	# Only update animations on authority (they will be synced via the model)
	if not is_multiplayer_authority():
		return
		
	# Skip animation updates if model doesn't exist or is emoting
	if not model or not model.has_method("set_idle"):
		return
	
	# Check if player is in the air first - this takes priority
	if not is_on_floor():
		model.set_jump()
		return
	
	# Check if we're moving (only when on floor)
	var is_moving = input_dir != Vector2.ZERO
	
	# Calculate blend position for directional movement
	var blend_position = Vector2(input_dir.x, -input_dir.y) # Invert Y for proper forward direction
	
	if not is_moving:
		# Standing still
		if is_crouching:
			model.set_crouch_idle()
		else:
			model.set_idle()
	else:
		# Moving
		if is_crouching:
			model.set_crouch_walking()
		elif is_running:
			model.set_running(blend_position)
		else:
			model.set_walking(blend_position)

# Sync transform to other players via unreliable RPC
func _sync_transform():
	if is_multiplayer_authority():
		_sync_transform_rpc.rpc(global_transform, velocity)

@rpc("unreliable", "any_peer", "call_remote")
func _sync_transform_rpc(sync_transform: Transform3D, sync_velocity: Vector3):
	if not is_multiplayer_authority():
		# Apply the synced transform and velocity to non-authority players
		global_transform = sync_transform
		velocity = sync_velocity

# Optional: Add action map setup for custom input actions
func _setup_input_actions():
	# This function can be called to ensure input actions exist
	# You might want to add these to your input map:
	# - "move_forward" (W key)
	# - "move_backward" (S key) 
	# - "move_left" (A key)
	# - "move_right" (D key)
	# - "run" (Shift key)
	# - "crouch" (Ctrl key)
	# - "jump" (Space key)
	pass
