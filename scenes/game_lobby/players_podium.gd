extends Node3D

@export
var lobby_player_container: PackedScene # instantiate for every player and call methods on start and when needed: set_nickname, set_student, set_major

@export
var spawn_anchor: Marker3D

# Dictionary to keep track of instantiated player nodes
var player_nodes = {}

# Player positioning constants
const PLAYER_DISTANCE = 1.2  # 1 meter between players
const PLAYERS_PER_ROW = 6
const ROW_OFFSET = -1.0  # Move in -Z direction for new rows
const ALTERNATE_ROW_OFFSET = 0.75  # Half distance offset for alternate rows

func _ready():
	MultiplayerManager.player_connected.connect(player_connected)
	MultiplayerManager.player_disconnected.connect(player_disconnected)
	MultiplayerManager.player_info_changed.connect(player_info_changed)
	
	update_players()

func update_players():
	var players = MultiplayerManager.players # Get the original player dictionary
	
	# Create a sorted array of player IDs based on join_time
	var sorted_player_ids = []
	for peer_id in players.keys():
		sorted_player_ids.append(peer_id)
	
	# Sort the player IDs by their join_time
	sorted_player_ids.sort_custom(func(a, b): 
		return players[a]["join_time"] < players[b]["join_time"])
	
	# Remove players that are no longer in the list
	for peer_id in player_nodes.keys():
		if not players.has(peer_id):
			remove_player(peer_id)
	
	# Add or update existing players using the sorted order
	var player_index = 0
	for peer_id in sorted_player_ids:
		var player_info = players[peer_id]
		
		if not player_nodes.has(peer_id):
			# Create new player
			create_player(peer_id, player_info, player_index)
		else:
			# Update existing player info
			update_player_info(peer_id, player_info)
			# Update position based on sorted order
			update_player_position(peer_id, player_index)
		
		player_index += 1

func create_player(peer_id: int, player_info: Dictionary, index: int):
	if not lobby_player_container:
		print("Error: lobby_player_container scene is not assigned!")
		return
	
	# Instantiate the player container
	var player_node = lobby_player_container.instantiate()
	
	add_child(player_node)
	player_node.name = str(peer_id)
	player_node.set_multiplayer_authority(peer_id, true)
	
	if peer_id == multiplayer.get_unique_id():
		get_parent().my_player_container = player_node
		
	# Store reference
	player_nodes[peer_id] = player_node
	
	# Set initial position
	update_player_position(peer_id, index)
	
	# Set player info
	set_player_info(player_node, player_info)

func remove_player(peer_id: int):
	if player_nodes.has(peer_id):
		var player_node = player_nodes[peer_id]
		player_node.queue_free()
		player_nodes.erase(peer_id)

func update_player_info(peer_id: int, player_info: Dictionary):
	if player_nodes.has(peer_id):
		var player_node = player_nodes[peer_id]
		set_player_info(player_node, player_info)

func set_player_info(player_node: Node, player_info: Dictionary):
	# Call the methods on the player container instance
	if player_node.has_method("set_nickname") and player_info.has("nickname"):
		player_node.set_nickname(player_info["nickname"])
	
	if player_node.has_method("set_student") and player_info.has("student"):
		player_node.set_student(player_info["student"])
	
	if player_node.has_method("set_major") and player_info.has("major"):
		player_node.set_major(player_info["major"])
	
	player_node.set_color(player_info["color"])
	player_node.set_ready(player_info["ready"])

func update_player_position(peer_id: int, index: int):
	if not player_nodes.has(peer_id) or not spawn_anchor:
		return
	
	var player_node = player_nodes[peer_id]
	var position = calculate_player_position(index)
	player_node.global_position = spawn_anchor.global_position + position

func calculate_player_position(index: int) -> Vector3:
	# Calculate row and column
	var row = index / PLAYERS_PER_ROW
	var col = index % PLAYERS_PER_ROW
	
	# Base position
	var x_pos = col * PLAYER_DISTANCE
	var z_pos = row * ROW_OFFSET
	
	# Apply offset for every second row (odd rows: 1, 3, 5...)
	if row % 2 == 1:
		x_pos += PLAYER_DISTANCE * ALTERNATE_ROW_OFFSET
	
	return Vector3(x_pos, 0, z_pos)

func player_info_changed(_peer_id, _player_info):
	update_players()

func player_connected(_peer_id, _player_info):
	update_players()

func player_disconnected(_peer_id):
	update_players()
