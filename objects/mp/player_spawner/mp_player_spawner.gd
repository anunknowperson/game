extends Node3D

@export
var player_scene = preload("res://objects/player/Player.tscn")


func _ready():
	
	if !Globals.local:
		Globals.game_start.connect(start_game)
	else:
		spawn_player(multiplayer.get_unique_id())

func start_game():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	rpc("spawn_player", multiplayer.get_unique_id())
	
	
@rpc("any_peer", "call_local", "reliable")
func spawn_player(id):
	_add_player(id)

func _on_peer_connected(id):
	_add_player(id)

func _on_peer_disconnected(id):
	if Globals.players.has(id):
		Globals.players[id].queue_free()
		Globals.players.erase(id)

func _add_player(id):
	var player_instance = player_scene.instantiate()
	player_instance.name = str(id)
	
	player_instance.set_multiplayer_authority(id, true)
	
	var peers :PackedInt32Array = multiplayer.get_peers()
	peers.sort()
	
	var spawn_position :Vector3 = get_children()[peers.find(id)].global_position
	
	player_instance.position = spawn_position
	add_child(player_instance, true)
	player_instance.position = spawn_position
	
	Globals.players[id] = player_instance
