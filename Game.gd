extends Node3D

# Preload the player scene
var player_scene = preload("res://Player.tscn")

# Dictionary to keep track of players
var players = {}



func _ready():
	
	# Set up multiplayer authority and connect signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	var args = Array(OS.get_cmdline_args())
	
	# If we're the server/host, we need to create a player for ourselves
	if multiplayer.is_server():
		_add_player(multiplayer.get_unique_id())
		for peer in multiplayer.get_peers():
			_add_player(peer)

func _on_peer_connected(id):
	# When a peer connects, create a player for them
	_add_player(id)

func _on_peer_disconnected(id):
	# When a peer disconnects, remove their player
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

func _add_player(id):
	# Create a new player instance
	var player_instance = player_scene.instantiate()
	player_instance.name = str(id)
	
	# Set up the player's multiplayer authority
	player_instance.set_multiplayer_authority(id)
	
	# Add the player to the scene
	$Players.add_child(player_instance)
	
	# Store a reference to the player
	players[id] = player_instance
	
	# Position the player randomly on the plane (within bounds)
	# var rand_pos = Vector3(randf_range(-10, 10), 2, randf_range(-10, 10))
	# player_instance.global_position = rand_pos
