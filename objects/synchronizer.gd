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

# Grab state variables
var is_grabbed := false
var grab_target_position := Vector3.ZERO
var grab_target_forward := Vector3.ZERO

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
		
		# Handle grab physics on authority
		if is_grabbed:
			_process_grab(delta)
	else:
		_process_non_authority(delta)

func _process_authority(delta: float) -> void:
	# Sync timer (only sync if not being grabbed or if it's time)
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

# Process grab physics calculations on the authority side
func _process_grab(delta: float) -> void:
	if not is_grabbed or not has_authority():
		return
		
	var ox = get_parent().only_x
	
	var target_pos = grab_target_position
	
	# Handle vertical limit for only_x objects
	if ox:
		var vertical_limit = get_parent().current_y + 0.3
		if rigid_body.global_position.y < vertical_limit:
			target_pos.y = vertical_limit
	
	# Calculate velocity needed to move toward target position
	var position_error = target_pos - rigid_body.global_position
	
	# Add damping to reduce oscillation
	var current_velocity = rigid_body.linear_velocity
	var damping_factor = 2.0 # Increase for more damping
	
	# Apply position correction with damping
	var correction_velocity = position_error / 1.0
	if correction_velocity.y < 0 and ox:
		correction_velocity.y = 0
	
	# Apply different smoothing factors for each axis
	if ox:
		correction_velocity.y *= 50
		correction_velocity.x *= 10
		correction_velocity.z *= 10
	else:
		correction_velocity *= 10
		correction_velocity.y *= 2
	
	# Apply damping based on current velocity
	var damped_force = correction_velocity * 30 * rigid_body.mass / 25
	damped_force -= current_velocity * damping_factor * rigid_body.mass
	
	# Calculate rotation correction
	var target_quat = Quaternion()
	var target_forward = grab_target_forward
	
	# Create a quaternion from target forward direction
	var up = Vector3.UP
	if abs(target_forward.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var right = target_forward.cross(up).normalized()
	up = right.cross(target_forward).normalized()
	
	# Create basis from vectors
	var target_basis = Basis(right, up, -target_forward)
	target_quat = Quaternion(target_basis)
	
	# Calculate rotation difference
	var current_quat = Quaternion(rigid_body.global_transform.basis.get_rotation_quaternion())
	var rotation_difference = current_quat.inverse() * target_quat
	
	# Calculate angular correction
	var axis = rotation_difference.get_axis()
	var angle = rotation_difference.get_angle()
	
	var angular_correction = Vector3.ZERO
	if angle > 0.001:
		angular_correction = (axis * angle) / rotation_smoothing
	
	# Apply forces with damping
	
	rigid_body.apply_central_force(damped_force)
	
	# For only_x objects, modify rotation behavior
	if get_parent().only_x:
		# Only rotate around Y axis
		angular_correction.x = 0
		angular_correction.z = 0
		angular_correction.y *= 2.0
	else:
		angular_correction *= 2.0
	
	# Apply angular damping to reduce rotational jiggling
	var angular_damping = rigid_body.angular_velocity * damping_factor * 0.5 * rigid_body.mass / 25
	if ox:
		rigid_body.angular_velocity = angular_correction * rigid_body.mass / 25 - angular_damping
	
	# Apply counter-gravity
	if is_grabbed:
		rigid_body.apply_central_force(Vector3(0, 9.8, 0))

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

# New RPC for updating grab target from player
@rpc("any_peer", "reliable")
func update_grab_target(target_position: Vector3, target_forward: Vector3) -> void:
	if has_authority():
		grab_target_position = target_position
		grab_target_forward = target_forward

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
func touch(force: Vector3) -> void:
	if has_authority():
		rigid_body.apply_central_impulse(force)

# Grab and release functions
@rpc("any_peer", "reliable")
func pickup() -> void:
	if has_authority():
		is_grabbed = true
		rigid_body.linear_damp = 4.0
		rigid_body.angular_damp = 2.0
		
		if get_parent().only_x:
			rigid_body.physics_material_override.friction = 0.0

@rpc("any_peer", "reliable")
func drop(throw_direction: Vector3 = Vector3.ZERO) -> void:
	if has_authority():
		is_grabbed = false
		rigid_body.linear_damp = 1.0
		rigid_body.angular_damp = 1.0
		
		if get_parent().only_x:
			rigid_body.physics_material_override.friction = 1.0
			
		# Apply throw force if provided
		if throw_direction != Vector3.ZERO:
			apply_throw(throw_direction)

# Apply throw force
func apply_throw(force: Vector3) -> void:
	if has_authority():
		rigid_body.apply_central_impulse(force * 2.0)

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
	var grab_status = "Grabbed" if is_grabbed else "Not Grabbed"
	
	debug_label.text = auth_text + "\nOwner: " + owner_id + "\nPeer: " + peer_id + "\n" + grab_status
