extends Node3D
class_name MPPhysicsSynchronizer


func _init() -> void:
	name = "MPPhysicsSyncronizer"

@onready var rigid_body: RigidBody3D = get_parent()

@export var position_smoothing: float = 0.3  # Lower values = faster corrections
@export var rotation_smoothing: float = 0.3
@export var threshold_position: float = 0.1  # Minimum position difference to sync
@export var threshold_rotation: float = 0.1  # Minimum rotation difference to sync
@export var teleport_threshold: float = 1.0  # if >1m off, snap instantly
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
	
	# Initial authority check
	_current_peer_id = multiplayer.get_unique_id()

func _physics_process(delta: float) -> void:

	# Handle physics synchronization based on authority
	if is_multiplayer_authority():
		_process_authority(delta)
	else:
		_process_non_authority(delta)

func _process_authority(delta: float) -> void:

	# Send current state to all peers
	var state = {
		"pos": rigid_body.global_position,
		"rot": rigid_body.global_transform.basis.get_rotation_quaternion(),
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
	# Calculate positional difference
	var position_error = target_position - rigid_body.global_position
	var position_error_len = position_error.length()

	# if we've drifted too far, teleport
	if position_error_len > teleport_threshold:
		# build a new transform with the correct basis and origin
		
		rigid_body.global_position = target_position

		return  # skip smoothing entirely
	
	
	# Apply linear velocity with correction factor
	var correction_velocity = position_error / position_smoothing
	rigid_body.linear_velocity = target_linear_velocity + correction_velocity
	
	
	
	# Handle rotation synchronization
	var current_quat = rigid_body.global_transform.basis.get_rotation_quaternion()

	# Calculate q_ω = q_2 * Quaternion.Inverse(q_1)
	# In our case: q_2 is target_rotation, q_1 is current_quat
	var q_omega = target_rotation * current_quat.inverse()
	# 1) build the raw difference quaternion
	var cur_q     = rigid_body.global_transform.basis.get_rotation_quaternion().normalized()
	var diff_q    = target_rotation.normalized() * cur_q.inverse()

	# 2) force it to use the “short” path: if w<0 then -diff_q has angle (2π–angle) ≤ π
	if diff_q.w < 0.0:
		diff_q = -diff_q

	# 3) now extract axis & angle, guaranteed angle ∈ [0, π]
	var axis  = diff_q.get_axis()
	var angle = diff_q.get_angle()

	# 4) build your angular velocity over your smoothing window
	
	# Calculate angular velocity vector ω = (angle/time)*axis
	# We need to apply this rotation over rotation_smoothing time
	var required_angular_velocity = Vector3.ZERO
	if angle > 0.0001:  # Avoid division by near-zero
		required_angular_velocity = (axis * angle) / rotation_smoothing
		
		# Blend with target angular velocity for smoother transitions
		var velocity_blend_factor = 0.5  # Balance between correction and target velocity
		rigid_body.angular_velocity = required_angular_velocity.lerp(
			target_angular_velocity,
			velocity_blend_factor
		)
	else:
		# If we're very close to target, just use the target angular velocity
		rigid_body.angular_velocity = target_angular_velocity

# Network RPC methods
@rpc("unreliable", "call_remote")
func receive_state(state: Dictionary) -> void:
	# Skip if we have authority
	if is_multiplayer_authority():
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
