extends CharacterBody3D

# Movement parameters
const SPEED = 5.0
const JUMP_VELOCITY = 6.0
const MOUSE_SENSITIVITY = 0.002

# Gravity value
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Camera-related variables
@onready var camera = $Camera3D
@onready var mesh = $MeshInstance3D
@onready var name_label = $NameLabel

# Player name
var player_name = "Player"

func _enter_tree():
	var args = Array(OS.get_cmdline_args())
	set_multiplayer_authority(str(name).to_int(), true)

func _ready():
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
		print("test: " + str(args) + str(get_node("/root/Game/Players/1").name))
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
	
	# Apply movement
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# Apply movement
	move_and_slide()
	
	# Sync position with other clients
	# rpc("update_position", global_position, rotation, velocity)

# RPC to sync position and rotation
#@rpc("any_peer", "unreliable")
#func update_position(pos, rot, vel):
#	# Only apply for other players, not ourselves
#	if not is_multiplayer_authority():
#		global_position = pos
#		rotation = rot
#		velocity = vel
