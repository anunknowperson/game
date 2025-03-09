extends Node3D

# Preload the player scene
var player_scene = preload("res://Player.tscn")

var level_scene = preload("res://Level.tscn")

# Dictionary to keep track of players
var players = {}



func _ready():
	
	var level = level_scene.instantiate()
	add_child(level)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	rpc("spawn_player", multiplayer.get_unique_id(), $Spawn.global_position + Vector3.FORWARD * randf_range(-0.5, 0.5))
	
	
@rpc("any_peer", "call_local")
func spawn_player(id, pos):
	_add_player(id, pos)

func _on_peer_connected(id, pos):
	_add_player(id, pos)

func _on_peer_disconnected(id):
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

func _add_player(id, pos):
	var player_instance = player_scene.instantiate()
	player_instance.name = str(id)
	
	player_instance.set_multiplayer_authority(id, true)
	player_instance.position = pos
	$Players.add_child(player_instance, true)
	
	players[id] = player_instance
