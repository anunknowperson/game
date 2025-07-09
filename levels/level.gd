extends Node3D

var spawn_points = {}

func _ready() -> void:
	for spawn_point in $SpawnPoints.get_children():
		spawn_points[spawn_point.id] = spawn_point
