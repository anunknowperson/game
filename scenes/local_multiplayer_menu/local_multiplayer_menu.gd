extends Control


@export_file("*.tscn")
var game_lobby_scene := "res://scenes/game_lobby/GameLobby.tscn"


func _ready() -> void:
	MultiplayerManager.connection_fail.connect(on_connection_failed)
	MultiplayerManager.connection_ok.connect(on_connected)

func on_connected() -> void:
	Globals.scene_manager.change_scene_to_file(game_lobby_scene)

func on_connection_failed() -> void:
	$VBoxContainer/ErrorLabel.show()

func _on_create_game_button_pressed() -> void:
	Globals.host = true
	Globals.first_player = true
	MultiplayerManager.create_game()
	Globals.scene_manager.change_scene_to_file(game_lobby_scene)


func _on_connect_button_pressed() -> void:
	Globals.host = false
	Globals.first_player = false
	MultiplayerManager.join_game()


func _on_address_edit_text_changed(new_text: String) -> void:
	Globals.server_ip = new_text


func _on_port_edit_text_changed(new_text: String) -> void:
	Globals.server_port = int(new_text)


func _on_nikcname_edit_text_changed(new_text: String) -> void:
	Globals.nickname = new_text
