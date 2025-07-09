extends Control

@export_file("*.tscn")
var game_scene := ""

var skill_button = preload("res://scenes/game_lobby/skill_button.tscn")

func _enter_tree() -> void:
	Globals.connect("lobby_player_container_model_changed",lobby_player_container_model_changed )

func _ready() -> void:
	if not Globals.first_player:
		$"%StartGameButton".hide()
	
	$"%NameEdit".text = Globals.nickname
	
	MultiplayerManager.player_connected.connect(player_connected)
	MultiplayerManager.player_disconnected.connect(player_disconnected)
	MultiplayerManager.player_info_changed.connect(player_info_changed)

func player_info_changed(_peer_id, _player_info):
	update_players()

func player_connected(_peer_id, _player_info):
	update_players()

func player_disconnected(_peer_id):
	update_players()

func update_players():
	var amount = 0
	
	for info in MultiplayerManager.players.values():
		if info["ready"]:
			amount+=1
	
	if amount == len(MultiplayerManager.players):
		$"%StartGameButton".disabled = false
		
	else:
		$"%StartGameButton".disabled = true

func lobby_player_container_model_changed() -> void:
	$"%StudentName".text = Globals.lobby_player_container_model.student_name
	$"%StudentDesc".text = Globals.lobby_player_container_model.student_desc
	
	for children in $"%SkillList".get_children():
		children.queue_free()
	
	for skill in  Globals.lobby_player_container_model.skills:
		var sb = skill_button.instantiate()
		sb.show_skill(skill)
		$"%SkillList".add_child(sb)
		
	

func _on_name_edit_text_changed(new_text: String) -> void:
	Globals.nickname = new_text
	MultiplayerManager.update_player_info()


func _on_major_select_item_selected(index: int) -> void:
	Globals.major = index
	MultiplayerManager.update_player_info()


func _on_color_select_color_changed(color: Color) -> void:
	Globals.color = color
	MultiplayerManager.update_player_info()


func _on_student_select_pressed() -> void:
	$Main.hide()
	$StudentSelect.show()


func _on_ready_button_pressed() -> void:
	Globals.is_ready = !Globals.is_ready
	
	if Globals.is_ready:
		$"%ReadyButton".add_theme_color_override("font_color", Color.GREEN)
		$"%ReadyButton".add_theme_color_override("font_focus_color", Color.GREEN)
		$"%ReadyButton".text = "ОТОЗВАТЬ ДОКУМЕНТЫ"
	else:
		$"%ReadyButton".add_theme_color_override("font_color", Color.RED)
		$"%ReadyButton".add_theme_color_override("font_focus_color", Color.RED)
		$"%ReadyButton".text = "ОТПРАВИТЬ ДОКУМЕНТЫ"
	
	MultiplayerManager.update_player_info()


func _on_name_edit_focus_entered() -> void:
	Globals.input_focus = true


func _on_name_edit_focus_exited() -> void:
	Globals.input_focus = false


func _on_left_student_button_pressed() -> void:
	Globals.student -= 1
	if Globals.student == -1:
		Globals.student = len(Globals.student_name_decode) - 1
	
	MultiplayerManager.update_player_info()
	


func _on_right_student_button_pressed() -> void:
	
	
	Globals.student = (Globals.student + 1) % len(Globals.student_name_decode)
	MultiplayerManager.update_player_info()


func _on_select_student_button_pressed() -> void:
	$StudentSelect.hide()
	$Main.show()
	

@rpc("any_peer", "call_local", "reliable")
func start_game() -> void:
	Globals.scene_manager.change_scene_to_file(game_scene, true, true)

func _on_start_game_button_pressed() -> void:
	start_game.rpc()
