class_name MultiplayerManager
extends Node

# Signaling properties
var signaling: WebRTCSignalingClient
var server_url: String = "ws://37.194.195.213:35410"

# Lobby properties
var current_lobby: String = ""
var player_name: String = "Player"
var is_host: bool = false

# Signals
signal connection_established()
signal connection_failed()
signal player_joined(id, name)
signal player_left(id)
signal lobby_created(lobby_name)
signal lobby_joined(lobby_name)
signal lobby_list_updated(lobbies)
signal game_started()

# Dictionary of players with their names
var players = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	# Create the signaling client
	signaling = WebRTCSignalingClient.new()
	add_child(signaling)
	
	# Connect signals
	signaling.connected.connect(_on_signaling_connected)
	signaling.disconnected.connect(_on_signaling_disconnected)
	signaling.lobby_joined.connect(_on_lobby_joined)
	signaling.lobby_created.connect(_on_lobby_created)
	signaling.lobby_list_received.connect(_on_lobby_list_received)
	signaling.peer_connected.connect(_on_peer_connected)
	signaling.peer_disconnected.connect(_on_peer_disconnected)
	signaling.lobby_sealed.connect(_on_lobby_sealed)
	
	# Set up multiplayer network callbacks
	multiplayer.peer_connected.connect(_on_network_peer_connected)
	multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)

# Create a new lobby
func create_lobby(max_players: int = 4, use_mesh: bool = true) -> void:
	is_host = true
	signaling.create_lobby(max_players, use_mesh)

# Join an existing lobby
func join_lobby(lobby_name: String) -> void:
	is_host = false
	signaling.join_lobby(lobby_name)

# Request a list of available lobbies
func get_lobby_list() -> void:
	signaling.request_lobby_list()

# Start the connection to the server
func connect_to_server(url: String = "") -> void:
	if url != "":
		server_url = url
	
	signaling.connect_to_server(server_url)

# Disconnect from everything
func disconnect_from_server() -> void:
	signaling.stop()
	players.clear()
	current_lobby = ""
	is_host = false

# Start the game (only host can call this)
func start_game() -> void:
	if !is_host:
		push_error("Only the host can start the game")
		return
	
	# Seal the lobby so no more players can join
	signaling.seal_lobby()
	
	# Notify all peers that the game is starting
	rpc("_on_game_started")
	_on_game_started()

# Set player name
func set_player_name(name: String) -> void:
	player_name = name
	print("MY PLAYER NAME IS: " + player_name)
	
	# If we're already connected, update our name for others
	if signaling.my_id != 0:
		rpc("_register_player", signaling.my_id, name)

# Update the _on_signaling_connected function
func _on_signaling_connected(id, use_mesh) -> void:
	print("Connected to signaling server with ID: ", id)
	
	connection_established.emit()
	
	# Register our player name
	if id != 0:
		rpc("_register_player", id, player_name)

# Callback when disconnected from the signaling server
func _on_signaling_disconnected() -> void:
	print("Disconnected from signaling server")
	connection_failed.emit()
	players.clear()

# Callback when joined a lobby
func _on_lobby_joined(lobby_name: String) -> void:
	current_lobby = lobby_name
	print("Joined lobby: ", lobby_name)
	lobby_joined.emit(lobby_name)

# Callback when created a lobby
func _on_lobby_created(lobby_name: String) -> void:
	current_lobby = lobby_name
	print("Created lobby: ", lobby_name)
	lobby_created.emit(lobby_name)

# Callback when the lobby list is received
func _on_lobby_list_received(lobbies: Array) -> void:
	print("Received lobby list: ", lobbies)
	lobby_list_updated.emit(lobbies)

# Callback when a peer connects to the signaling server
func _on_peer_connected(id: int) -> void:
	print("Peer connected to signaling: ", id)
	# We'll wait for the network peer connection to register the player

# Callback when a peer disconnects from the signaling server
func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected from signaling: ", id)
	# The network peer disconnect will handle removing the player

# Callback when the lobby is sealed
func _on_lobby_sealed() -> void:
	print("Lobby sealed, no more players can join")
	# Game will start shortly

# Callback when a peer connects to the multiplayer network
func _on_network_peer_connected(id: int) -> void:
	print("Network peer connected: ", id)
	
	# If we're already in the players list, send our info to the new player
	if signaling.my_id != 0:
		rpc_id(id, "_register_player", signaling.my_id, player_name)

# Callback when a peer disconnects from the multiplayer network
func _on_network_peer_disconnected(id: int) -> void:
	print("Network peer disconnected: ", id)
	
	if players.has(id):
		var disconnected_player_name = players[id]
		players.erase(id)
		player_left.emit(id)
		print("Player left: ", disconnected_player_name)

# RPC method to register a player
@rpc("any_peer", "reliable")
func _register_player(id: int, name: String) -> void:
	if id == multiplayer.get_unique_id():
		return  # Don't add ourselves
	
	players[id] = name
	print("Player registered: ", id, " as ", name)
	player_joined.emit(id, name)

# RPC method called when the game starts
@rpc("any_peer", "reliable")
func _on_game_started() -> void:
	print("Game starting!")
	game_started.emit()
