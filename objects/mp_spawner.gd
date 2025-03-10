extends Node3D

@export var scene_to_spawn: PackedScene
@export var amount_to_spawn: int = 5
@export var spawn_radius: float = 10.0

func _ready() -> void:
	Globals.game_start.connect(game_start)

func game_start():
	if multiplayer.get_unique_id() == 1:
		# Generate random positions within the radius
		var positions = []
		for i in range(amount_to_spawn):
			var random_angle = randf() * TAU  # Random angle in radians (0 to 2π)
			var random_distance = randf() * spawn_radius  # Random distance within radius
			var pos_x = cos(random_angle) * random_distance
			var pos_z = sin(random_angle) * random_distance
			positions.append(Vector3(pos_x, 0, pos_z))
		
		# Call RPC with amount and positions array
		spawn_monsters.rpc(1, amount_to_spawn, positions)

@rpc("any_peer", "call_local", "reliable")
func spawn_monsters(id, amount, positions) -> void:
	for i in range(amount):
		var object = scene_to_spawn.instantiate()
		
		# Name is id + index
		object.name = str(id) + "_" + str(i)
		object.set_multiplayer_authority(id, true)
		
		add_child(object, true)
		
		# Use the position from the array
		if i < positions.size():
			object.global_position = global_position + positions[i]
		else:
			object.global_position = global_position
