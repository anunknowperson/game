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

@onready var game_scene = preload("res://scenes/game_container/GameContainer.tscn")

# Reference to the multiplayer manager
var multiplayer_manager: MultiplayerManager

var game_object

func _ready():
	Globals.local = false
	
	game_object = game_scene.instantiate()
	add_child(game_object)
	
	# Initialize the multiplayer manager
	multiplayer_manager = WebrtcMultiplayer.manager
	
	# Initialize player options dictionary
	Globals.player_options = {}
	
	# Connect signals
	multiplayer_manager.connection_established.connect(_on_connection_established)
	multiplayer_manager.connection_failed.connect(_on_connection_failed)
	multiplayer_manager.lobby_created.connect(_on_lobby_created)
	multiplayer_manager.lobby_joined.connect(_on_lobby_joined)
	multiplayer_manager.lobby_list_updated.connect(_on_lobby_list_updated)
	multiplayer_manager.player_joined.connect(_on_player_joined)
	multiplayer_manager.player_left.connect(_on_player_left)
	multiplayer_manager.game_started.connect(_on_game_started)
	multiplayer_manager.player_class_updated.connect(_on_player_class_updated)
	
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
	print("CONNECTION WAS ESTABLISHED")
	
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
	
	# Initialize player options for ourselves
	var my_id = multiplayer_manager.signaling.my_id
	if not Globals.player_options.has(my_id):
		Globals.player_options[my_id] = {"class": Globals.player_class}
	
	# Update player list
	update_player_list()
	
	# Disable start game button if not host
	start_game_button.disabled = !multiplayer_manager.is_host

func _on_player_joined(id, name):
	# Update player list with new player
	update_player_list()

func _on_player_left(id):
	# Update player list after player left
	update_player_list()

func _on_player_class_updated(id, player_class):
	# Update player list to show updated class
	update_player_list()

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
	connection_panel.visible = false
	lobby_panel.visible = false
	game_panel.visible = false
	
	Globals.game_start.emit()

func _on_tp_button_pressed() -> void:
	Globals.player_class = "TP"
	$"%ClassDescription".text = "🧮 Математическое превосходство: [color=#FF0000]Басов[/color] жалеет тпшек и не уебывает с первого раза.\n🚗 Жигули: [color=#FF0000]Яков Кирилленко[/color] не доебется (но если доебется можно отправиться в лабу), а также + ключи от [color=#FFFF00]жигулей[/color]"
	
	# Send class update to other players if connected
	if multiplayer_manager.signaling.my_id != 0:
		multiplayer_manager.set_player_class("TP")

func _on_se_button_pressed() -> void:
	Globals.player_class = "SE"
	$"%ClassDescription".text = "👨💻 Программисты: есть шанс 75% что [color=#FF0000]басов[/color] не доебется, т.к. не ведет у них. Однако если [color=#FF0000]басов[/color] доебется, то решить один легкий диффурчик не получиться.\n🧪 Завсегдатаи лабы: скорее всего, [color=#FF0000]Яков Кирилленко[/color] попросит убрать камеру, что может привести к проблемам.\n🚗 [color=#FFFF00]Ламборгини[/color]: автоматически даются ключи от [color=#FFFF00]ламборгини[/color] 🎉"
	
	# Send class update to other players if connected
	if multiplayer_manager.signaling.my_id != 0:
		multiplayer_manager.set_player_class("SE")

# Helper function to update the player list with classes
func update_player_list():
	player_list.clear()
	
	# Add ourselves
	var my_id = multiplayer_manager.signaling.my_id
	var my_class = Globals.player_class
	
	if my_class == "TP": my_class = "ТП"
	if my_class == "SE": my_class = "ПИ"
	
	var my_display = "You: " + multiplayer_manager.player_name + " [" + my_class + "]"
	if multiplayer_manager.is_host:
		my_display += " (Host)"
	player_list.add_item(my_display)
	
	# Add other players
	for id in multiplayer_manager.players.keys():
		var name = multiplayer_manager.players[id]
		var player_class = "ТП"  # Default
		
		# Get player class if available
		if Globals.player_options.has(id) and Globals.player_options[id].has("class"):
			player_class = Globals.player_options[id]["class"]
		
		if player_class == "TP": player_class = "ТП"
		if player_class == "SE": player_class = "ПИ"
		
		player_list.add_item(str(id) + ": " + name + " [" + player_class + "]")
