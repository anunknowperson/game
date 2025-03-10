extends Node3D

signal on_interaction

@export var price :int = 500

@export var only_x :bool = false
var current_y := 0.0

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
		$Synchronizer.pickup()
	else:
		$Synchronizer.rpc_id(get_multiplayer_authority(), "pickup")

func drop():
	if is_multiplayer_authority():
		$Synchronizer.drop()
	else:
		$Synchronizer.rpc_id(get_multiplayer_authority(), "drop")
		

func interact():
	on_interaction.emit()
	
func apply_velocities(force):
	if is_multiplayer_authority():
		$Synchronizer.apply_velocities(force)
	else:
		$Synchronizer.rpc_id(get_multiplayer_authority(), "apply_velocities", force)
		
func apply_angular_velocities(angular_force):
	if is_multiplayer_authority():
		$Synchronizer.apply_angular_velocities(angular_force)
	else:
		$Synchronizer.rpc_id(get_multiplayer_authority(), "apply_angular_velocities", angular_force)
