extends Node3D

signal on_interaction

@export var only_x :bool = false
var current_y := 0.0

# Grab state tracking
var is_grabbed := false
var grabber_id := -1

func _physics_process(delta):
	if only_x == false:
		return
	
	find_maximum_ray_intersection()
	
func find_maximum_ray_intersection():
	var ray_origins = [
		$RigidBody3D/Marker3D,
		$RigidBody3D/Marker3D2,
		$RigidBody3D/Marker3D3,
		$RigidBody3D/Marker3D4
	]
	
	var space_state = get_world_3d().direct_space_state
	var max_y = -INF
	
	for marker in ray_origins:
		if marker == null:
			continue
			
		var from = marker.global_position
		var to = from + Vector3(0, -100, 0)  # Cast ray downward
		
		# Set up raycast parameters
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [$RigidBody3D]  # Exclude the rigid body itself from raycast
		
		# Perform the raycast
		var result = space_state.intersect_ray(query)
		
		if result and "position" in result:
			var hit_y = result.position.y
			if hit_y > max_y:
				max_y = hit_y
	
	# Only update if we found at least one intersection
	if max_y != -INF:
		current_y = max_y

func touch(force):
	if is_multiplayer_authority():
		$Synchronizer.touch(force)
	else:
		$Synchronizer.rpc_id(get_multiplayer_authority(), "touch", force)
		
func pickup():
	if is_multiplayer_authority():
		is_grabbed = true
		grabber_id = multiplayer.get_remote_sender_id()
		$Synchronizer.pickup()
	else:
		$Synchronizer.rpc_id(get_multiplayer_authority(), "pickup")

func drop(throw_direction = Vector3.ZERO):
	if is_multiplayer_authority():
		is_grabbed = false
		grabber_id = -1
		$Synchronizer.drop()
		
		# Apply throw force if provided
		if throw_direction != Vector3.ZERO:
			$Synchronizer.apply_throw(throw_direction * 2.0)
	else:
		# Forward throw direction to authority
		$Synchronizer.rpc_id(get_multiplayer_authority(), "drop", throw_direction)
		
func interact():
	on_interaction.emit()
	
# New function to update grab target - called by player, forwarded to authority
func update_grab_target(target_position: Vector3, target_forward: Vector3):
	if is_multiplayer_authority():
		# Direct local call if we're the authority
		$Synchronizer.update_grab_target(target_position, target_forward)
	else:
		# Forward to authority
		$Synchronizer.rpc_id(get_multiplayer_authority(), "update_grab_target", target_position, target_forward)
