extends Node3D


@export var start_level = 0

@export var player_scene = preload("res://students/player.tscn")

var players_loaded = 0

func _ready() -> void:

	MultiplayerManager.player_connected.connect(player_connected)
	MultiplayerManager.player_disconnected.connect(player_disconnected)
	MultiplayerManager.player_info_changed.connect(player_info_changed)
	
	Globals.level_manager.level_loaded.connect(level_loaded)
	Globals.level_manager.load_level(start_level, true)

func player_info_changed(_peer_id, _player_info):
	update_players()

func player_connected(_peer_id, _player_info):
	update_players()

func player_disconnected(_peer_id):
	update_players()

func update_players():
	players_loaded = 0
	
	for player_info in MultiplayerManager.players.values():
		if player_info["loaded"]:
			players_loaded += 1
	
	Globals.scene_manager.set_loading_screen_text("Ожидание игроков... (%d/%d)" % [players_loaded, len(MultiplayerManager.players)])
	
	if players_loaded == len(MultiplayerManager.players) and is_multiplayer_authority():
		print("Starting game!")
		_start_game.rpc()


@rpc("any_peer", "call_local", "reliable")
func _start_game() -> void:
	Globals.scene_manager.hide_loading_screen()


func level_loaded() -> void:
	Globals.level_manager.level_loaded.disconnect(level_loaded)
	
	Globals.scene_manager.set_loading_screen_text("Ожидание игроков... (%d/%d)" % [players_loaded, len(MultiplayerManager.players)])
	
	var spawn_point :SpawnPoint = Globals.level_manager.current_level.spawn_points[0]
	
	for player_peer in MultiplayerManager.players.keys():
		var pl = player_scene.instantiate()
		pl.name = str(player_peer)
		pl.set_multiplayer_authority(player_peer)
		$Players.add_child(pl)
		pl.set_player_position(spawn_point.get_spawn_position(MultiplayerManager.get_player_index(player_peer)))
		
		Globals.register_player_container(player_peer, pl)
	
	Globals.is_loaded = true
	
	MultiplayerManager.update_player_info()
	
	
