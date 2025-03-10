extends Node
class_name MPRigidbodySync

# Parent RigidBody3D node reference
@onready var rigid_body: RigidBody3D = get_parent().get_node("RigidBody3D")
@onready var debug_label: Label3D = get_parent().get_node("RigidBody3D/Label3D")

# Sync configuration
@export var sync_interval: float = 0.05  # How often to send updates (seconds)
@export var position_smoothing: float = 0.3  # Lower values = faster corrections
@export var rotation_smoothing: float = 0.3
@export var threshold_position: float = 0.1  # Minimum position difference to sync
@export var threshold_rotation: float = 0.1  # Minimum rotation difference to sync
@export var authority_mode: AuthorityMode = AuthorityMode.OWNER  # Default to owner authority

# Target transform for non-authoritative instances
var target_position: Vector3
var target_linear_velocity: Vector3
var target_angular_velocity: Vector3
var target_rotation: Quaternion

# Reference values for extrapolation and interpolation
var last_sync_time: float = 0.0
var has_initial_state: bool = false
var last_state_timestamp: float = 0.0

# Authority enums
enum AuthorityMode {
	OWNER,      # Peer that owns the node has authority
	SERVER,     # Server always has authority
	MANUAL      # Authority handled manually
}

# Manual authority tracker
var _authority_peer_id: int = -1
var _current_peer_id: int = -1

func _ready() -> void:
	# Set up multiplayer properties
	set_process(true)
	target_position = rigid_body.position
	target_rotation = Quaternion(rigid_body.quaternion)
	
	# Set up network sync
	multiplayer.peer_connected.connect(_on_player_connected)
	
	# Initialize debug label
	if debug_label:
		_update_debug_label()
	
	# Initial authority check
	_current_peer_id = multiplayer.get_unique_id()
	if has_authority():
		if debug_label:
			debug_label.text = "Has Authority\nID: " + str(_current_peer_id)

func _process(delta: float) -> void:
	# Update debug info
	if debug_label:
		_update_debug_label()
	
	# Handle physics synchronization based on authority
	if has_authority():
		_process_authority(delta)
	else:
		_process_non_authority(delta)

func _process_authority(delta: float) -> void:
	# Sync timer
	last_sync_time += delta
	if last_sync_time >= sync_interval:
		last_sync_time = 0.0
		
		# Send current state to all peers
		var state = {
			"pos": rigid_body.position,
			"rot": rigid_body.quaternion,
			"lin_vel": rigid_body.linear_velocity,
			"ang_vel": rigid_body.angular_velocity,
			"timestamp": Time.get_ticks_msec() / 1000.0
		}
		
		# Only sync if there's significant change
		if has_initial_state:
			var position_diff = state.pos.distance_to(target_position)
			var rotation_diff = abs(state.rot.angle_to(target_rotation))
			
			if position_diff > threshold_position or rotation_diff > threshold_rotation:
				rpc("receive_state", state)
				# Update target values
				target_position = state.pos
				target_rotation = state.rot
				target_linear_velocity = state.lin_vel
				target_angular_velocity = state.ang_vel
				last_state_timestamp = state.timestamp
		else:
			# Always send initial state
			rpc("receive_state", state)
			target_position = state.pos
			target_rotation = state.rot
			target_linear_velocity = state.lin_vel
			target_angular_velocity = state.ang_vel
			last_state_timestamp = state.timestamp
			has_initial_state = true

func _process_non_authority(delta: float) -> void:
	if not has_initial_state:
		return
	
	# Apply received physics state using velocities
	# Calculate positional and rotational difference
	var position_error = target_position - rigid_body.position
	var target_quat = target_rotation
	var current_quat = Quaternion(rigid_body.quaternion)
	
	# Apply linear velocity with correction factor
	var correction_velocity = position_error / position_smoothing
	rigid_body.linear_velocity = target_linear_velocity + correction_velocity
	
	# Apply angular velocity with correction factor
	# Create a rotation that goes from current to target orientation
	var rotation_difference = current_quat.inverse() * target_quat
	
	# Convert rotation difference to axis and angle for corrective angular velocity
	var axis = rotation_difference.get_axis()
	var angle = rotation_difference.get_angle()
	
	# Create corrective angular velocity
	if angle > 0.001:
		var correction_angular = (axis * angle) / rotation_smoothing
		rigid_body.angular_velocity = target_angular_velocity + correction_angular

# Network RPC methods
@rpc("unreliable", "call_remote")
func receive_state(state: Dictionary) -> void:
	# Skip if we have authority
	if has_authority():
		return
	
	# Only accept newer state
	if has_initial_state and state.timestamp <= last_state_timestamp:
		return
	
	# Store target transform
	target_position = state.pos
	target_rotation = state.rot
	target_linear_velocity = state.lin_vel
	target_angular_velocity = state.ang_vel
	last_state_timestamp = state.timestamp
	has_initial_state = true

# Authority management
func has_authority() -> bool:
	match authority_mode:
		AuthorityMode.OWNER:
			return rigid_body.is_multiplayer_authority()
		AuthorityMode.SERVER:
			return multiplayer.is_server()
		AuthorityMode.MANUAL:
			return _current_peer_id == _authority_peer_id
	return false

func set_authority(peer_id: int) -> void:
	if authority_mode != AuthorityMode.MANUAL:
		push_warning("Trying to manually set authority while not in MANUAL mode")
		return
	
	_authority_peer_id = peer_id
	if debug_label:
		_update_debug_label()

@rpc("any_peer", "reliable")
func touch(force):
	if is_multiplayer_authority():
		rigid_body.apply_central_impulse(force)

func pickup():
	rigid_body.linear_damp = 4.0
	rigid_body.angular_damp = 2.0
	
	if get_parent().only_x:
		var rigid_body :RigidBody3D = get_parent().get_node("RigidBody3D")
		rigid_body.physics_material_override.friction = 0.0
func drop():
	rigid_body.linear_damp = 1.0
	rigid_body.angular_damp = 1.0
	if get_parent().only_x:
		var rigid_body :RigidBody3D = get_parent().get_node("RigidBody3D")
		rigid_body.physics_material_override.friction = 1.0

@rpc("any_peer", "reliable")
func apply_velocities(force):
	if is_multiplayer_authority():
		# Get the RigidBody3D node
		var rigid_body = get_parent().get_node("RigidBody3D")  # Adjust path to your actual RigidBody3D node
		
		# Apply velocity - using this instead of directly setting position
		# This approach is better for physics interactions
		var current_vel = rigid_body.linear_velocity
		var target_vel = force
		
		# Calculate a smooth interpolation between current and target velocity
		# This makes the movement feel more natural
		#rigid_body.linear_velocity = current_vel.lerp(target_vel, 0.5)
		rigid_body.apply_central_force(force * 20.0* rigid_body.mass / 8.0)
		
		# Optional: Add a small upward force to counteract gravity slightly
		# This helps prevent the object from falling while being carried
		rigid_body.apply_central_force(Vector3(0, 9.8, 0))

@rpc("any_peer", "reliable")
func apply_angular_velocities(angular_force):
	if is_multiplayer_authority():

		# Get the RigidBody3D node
		var rigid_body = get_parent().get_node("RigidBody3D")  # Adjust path if needed
		if rigid_body:
			# Apply angular velocity directly
			rigid_body.apply_torque(angular_force * (25.0 if get_parent().only_x else 2))
			
			# Use a more aggressive damping to prevent oscillation
			
			

# Event handlers
func _on_player_connected(id: int) -> void:
	# Send initial state to new players if we have authority
	if has_authority() and has_initial_state:
		var state = {
			"pos": rigid_body.position,
			"rot": rigid_body.quaternion,
			"lin_vel": rigid_body.linear_velocity,
			"ang_vel": rigid_body.angular_velocity,
			"timestamp": Time.get_ticks_msec() / 1000.0
		}
		rpc_id(id, "receive_state", state)

func _update_debug_label() -> void:
	if not debug_label:
		return
		
	var auth_text = "No Authority"
	if has_authority():
		auth_text = "Has Authority"
	
	var owner_id = str(rigid_body.get_multiplayer_authority())
	var peer_id = str(_current_peer_id)
	
	debug_label.text = auth_text + "\nOwner: " + owner_id + "\nPeer: " + peer_id
