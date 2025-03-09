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
	
	rpc("spawn_player", multiplayer.get_unique_id())
	
	
@rpc("any_peer", "call_local")
func spawn_player(id):
	_add_player(id)

func _on_peer_connected(id):
	_add_player(id)

func _on_peer_disconnected(id):
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

func _add_player(id):
	var player_instance = player_scene.instantiate()
	player_instance.name = str(id)
	
	player_instance.set_multiplayer_authority(id, true)
	
	$Players.add_child(player_instance, true)
	
	players[id] = player_instance
