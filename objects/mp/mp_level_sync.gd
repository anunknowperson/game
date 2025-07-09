extends Node
class_name MPLevelSync

var my_level := 0



func _init() -> void:
	name = "MPLevelSync"

@rpc("any_peer", "call_local", "reliable")
func _request_sync():
	var id = multiplayer.get_remote_sender_id()
	
	_sync_level.rpc_id(id, my_level)
	get_parent().synchronize_id(id)
	


@rpc("any_peer", "call_local", "reliable")
func _sync_level(level):
	my_level = level

func determine_level():
	Globals.level_manager.level_loaded.disconnect(determine_level)
	
	var prev_node = get_parent()
		
	while true:
		var pr = prev_node.get_parent()
		if pr.name == "LevelManager":
			my_level = pr.get_level_id(prev_node)
			
			return
		if pr == get_tree().root:
			return
		prev_node = pr

func _ready() -> void:
	if !is_multiplayer_authority():
		_request_sync.rpc_id(1)
		
	if multiplayer.get_unique_id() == 1:
		Globals.level_manager.level_loaded.connect(determine_level)
		
		
