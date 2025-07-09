extends Marker3D
class_name SpawnPoint

@export
var id := 0

@export
var one_point := true

@export
var grid_spacing := 1.0  # Distance between spawn points in meters

func get_spawn_position(player_id: int) -> Vector3:
	if one_point:
		return global_position
	else:
		# Calculate grid position based on player ID
		var grid_size = ceil(sqrt(len(MultiplayerManager.players)))
		var x_offset = (player_id % int(grid_size)) * grid_spacing
		var z_offset = (player_id / int(grid_size)) * grid_spacing
		
		# Center the grid around the spawn point
		var center_offset = (grid_size - 1) * grid_spacing * 0.5
		
		return global_position + Vector3(
			x_offset - center_offset,
			0,
			z_offset - center_offset
		)
