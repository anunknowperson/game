extends Control

@onready var connection_panel = $ConnectionPanel
@onready var lobby_panel = $LobbyPanel
@onready var game_panel = $GamePanel

@onready var server_url_input = $ConnectionPanel/VBoxContainer/ServerUrlInput
@onready var player_name_input = $ConnectionPanel/VBoxContainer/PlayerNameInput
@onready var connect_button = $ConnectionPanel/VBoxContainer/ConnectButton
@onready var status_label = $ConnectionPanel/VBoxContainer/StatusLabel

@onready var lobby_list = $LobbyPanel/VBoxContainer/LobbyList
@onready var refresh_button = $LobbyPanel/VBoxContainer/HBoxContainer/RefreshButton
@onready var create_lobby_button = $LobbyPanel/VBoxContainer/HBoxContainer/CreateLobbyButton
@onready var join_lobby_button = $LobbyPanel/VBoxContainer/HBoxContainer/JoinLobbyButton
@onready var max_players_input = $LobbyPanel/VBoxContainer/MaxPlayersInput
@onready var lobby_name_label = $LobbyPanel/VBoxContainer/LobbyNameLabel

@onready var player_list = $GamePanel/VBoxContainer/PlayerList
@onready var start_game_button = $GamePanel/VBoxContainer/StartGameButton
@onready var leave_button = $GamePanel/VBoxContainer/LeaveButton

# Reference to the multiplayer manager
var multiplayer_manager: MultiplayerManager

func _ready():
	# Initialize the multiplayer manager
	multiplayer_manager = WebrtcMultiplayer.manager
	
	# Connect signals
	multiplayer_manager.connection_established.connect(_on_connection_established)
	multiplayer_manager.connection_failed.connect(_on_connection_failed)
	multiplayer_manager.lobby_created.connect(_on_lobby_created)
	multiplayer_manager.lobby_joined.connect(_on_lobby_joined)
	multiplayer_manager.lobby_list_updated.connect(_on_lobby_list_updated)
	multiplayer_manager.player_joined.connect(_on_player_joined)
	multiplayer_manager.player_left.connect(_on_player_left)
	multiplayer_manager.game_started.connect(_on_game_started)
	
	# Set up initial state
	connection_panel.visible = true
	lobby_panel.visible = false
	game_panel.visible = false
	
	# Set up default values
	server_url_input.text = multiplayer_manager.server_url
	player_name_input.text = "Player" + str(randi() % 1000)
	max_players_input.value = 4
	
	# Connect UI signals
	connect_button.pressed.connect(_on_connect_button_pressed)
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	create_lobby_button.pressed.connect(_on_create_lobby_button_pressed)
	join_lobby_button.pressed.connect(_on_join_lobby_button_pressed)
	start_game_button.pressed.connect(_on_start_game_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)

func _on_connect_button_pressed():
	status_label.text = "Connecting..."
	
	# Set player name
	multiplayer_manager.set_player_name(player_name_input.text)
	
	# Connect to server
	multiplayer_manager.connect_to_server(server_url_input.text)

func _on_connection_established():
	print("CONNECTION WAS ESTABLISHED (this isn't priting)")
	
	status_label.text = "Connected!"
	
	# Switch to lobby panel
	connection_panel.visible = false
	lobby_panel.visible = true
	
	# Request lobby list
	multiplayer_manager.get_lobby_list()
	
func _on_connection_failed():
	status_label.text = "Connection failed!"

func _on_refresh_button_pressed():
	multiplayer_manager.get_lobby_list()

func _on_create_lobby_button_pressed():
	multiplayer_manager.create_lobby(int(max_players_input.value))

func _on_join_lobby_button_pressed():
	var selected_items = lobby_list.get_selected_items()
	if selected_items.size() > 0:
		var selected_index = selected_items[0]
		var lobby_name = lobby_list.get_item_metadata(selected_index)
		multiplayer_manager.join_lobby(lobby_name)

func _on_lobby_list_updated(lobbies):
	lobby_list.clear()
	
	for i in range(lobbies.size()):
		var lobby = lobbies[i]
		var text = "%s (%d/%d)" % [lobby.name, lobby.players, lobby.maxPlayers]
		lobby_list.add_item(text)
		lobby_list.set_item_metadata(i, lobby.name)

func _on_lobby_created(lobby_name):
	_on_lobby_joined(lobby_name)
	start_game_button.disabled = false

func _on_lobby_joined(lobby_name):
	# Switch to game panel
	lobby_panel.visible = false
	game_panel.visible = true
	
	# Update UI
	lobby_name_label.text = "Lobby: " + lobby_name
	
	# Clear player list and add ourselves
	player_list.clear()
	player_list.add_item("You: " + multiplayer_manager.player_name + " (Host)" if multiplayer_manager.is_host else "You: " + multiplayer_manager.player_name)
	
	# Disable start game button if not host
	start_game_button.disabled = !multiplayer_manager.is_host

func _on_player_joined(id, name):
	player_list.add_item(str(id) + ": " + name)

func _on_player_left(id):
	# Find and remove the player from the list
	for i in range(player_list.get_item_count()):
		var item_text = player_list.get_item_text(i)
		if item_text.begins_with(str(id) + ":"):
			player_list.remove_item(i)
			break

func _on_start_game_button_pressed():
	multiplayer_manager.start_game()

func _on_leave_button_pressed():
	multiplayer_manager.disconnect_from_server()
	
	# Reset UI
	connection_panel.visible = true
	lobby_panel.visible = false
	game_panel.visible = false
	status_label.text = ""

func _on_game_started():
	# In a real game, you would switch to the game scene here
	get_tree().change_scene_to_file("res://Game.tscn")
