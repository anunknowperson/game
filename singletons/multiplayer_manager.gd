extends Node

const MAX_CONNECTIONS := 50

signal player_connected(peer_id, player_info)
signal player_info_changed(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

signal connection_ok
signal connection_fail

var players = {}

func get_player_index(peer_id):
	# Get all player entries and sort them by join_time
	var player_entries = []
	for id in players.keys():
		player_entries.append({"peer_id": id, "join_time": players[id]["join_time"]})
	
	# Sort by join_time
	player_entries.sort_custom(func(a, b): return a["join_time"] < b["join_time"])
	
	# Find the index of the requested peer_id
	for i in range(player_entries.size()):
		if player_entries[i]["peer_id"] == peer_id:
			return i
	
	# Return -1 if peer_id not found
	return -1

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func join_game():
	Globals.join_time = Time.get_unix_time_from_system()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(Globals.server_ip, Globals.server_port)
	if error:
		return error
		
	multiplayer.multiplayer_peer = peer
	
	return OK


func create_game():
	Globals.join_time = Time.get_unix_time_from_system()

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(Globals.server_port, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer

	var my_player_info = Globals.gather_player_info()

	players[1] = my_player_info
	player_connected.emit(1, my_player_info)


func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null
	players.clear()

@rpc("any_peer", "call_local", "reliable")
func _update_player_info(new_player_info):
	var player_id = multiplayer.get_remote_sender_id()
	players[player_id] = new_player_info
	player_info_changed.emit(player_id, new_player_info)

func update_player_info():
	_update_player_info.rpc(Globals.gather_player_info())

# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
	var my_player_info = Globals.gather_player_info()
	_register_player.rpc_id(id, my_player_info)


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)


func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)


func _on_connected_ok():
	var my_player_info = Globals.gather_player_info()
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = my_player_info
	player_connected.emit(peer_id, my_player_info)
	connection_ok.emit()


func _on_connected_fail():
	multiplayer.multiplayer_peer = null
	connection_fail.emit()


func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
