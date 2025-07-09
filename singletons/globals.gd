extends Node

# Controlled by LocalMultiplayerMenu

var host = null
var first_player := false

var server_ip := "127.0.0.1"
var server_port := 6363

var nickname := "Поступашка"

# Controlled by GameLobby
enum Student {
	VANYA_POH,
	ABED
}

enum Major {
	TP,
	SE
}

var major_name_decode = {
	Major.TP : "Технологии Программирования",
	Major.SE : "Программная Инженерия",
}

var student_name_decode = {
	Student.VANYA_POH : "Ваня Пох",
	Student.ABED : "Абед",
}

func get_major_name(major):
	return major_name_decode[major]
	
func get_student_name(student):
	return student_name_decode[student]

var student := Student.VANYA_POH
var major := Major.TP
var join_time = null
var color := Color.WHITE
var is_ready := false

var is_loaded := false

func gather_player_info():
	return {
		"nickname":nickname,
		"student":student,
		"major":major,
		"join_time":join_time,
		"color":color,
		"ready":is_ready,
		"loaded":is_loaded
		}

var lobby_player_container_model = null

signal lobby_player_container_model_changed

var input_focus := false

# Controller by SceneManager
var scene_manager :SceneManager = null

# Controller by LevelManager
var level_manager :LevelManager = null


# Controlled by EmotionWindow
var emotion_window :EmotionWindow = null


# Controlled by MainMenu
var local := true

# Controlled by MainMenu
signal game_start

# ---- PLAYERS MANAGEMENT ----

var players = {}

var mailing_list = []
var levels_mailing_lists = {}

func _ready() -> void:
	MultiplayerManager.player_disconnected.connect(player_disconnected)

func register_player_container(peer_id, player_container):
	players[peer_id] = player_container

func update_network_list():
	mailing_list = [1]
	levels_mailing_lists = {}  # Reset the levels mailing lists
	
	var my_level = players[multiplayer.get_unique_id()].on_level
	
	# Build both mailing_list and levels_mailing_lists
	for player in players:
		var player_level = players[player].on_level
		var player_id = players[player].get_multiplayer_authority()
		
		# Add to levels_mailing_lists
		if not levels_mailing_lists.has(player_level):
			levels_mailing_lists[player_level] = [1]
		levels_mailing_lists[player_level].append(player_id)
		
		# Add to mailing_list if on same level as current player
		if player_level == my_level:
			mailing_list.append(player_id)
	


func player_disconnected(peer_id):
	players.erase(peer_id)

# ---- PLAYERS MANAGEMENT END ----

# Controlled by Player Spawner. [player_id] = Player object
# var players = {}



# Controlled by MainMenu
var player_class = "TP"

# Store player class selections for all players
var player_options = {}
