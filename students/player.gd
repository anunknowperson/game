extends Node3D

var on_level :int = 0

var hp := 100.0
var sp := 100.0
var st := 100.0

@onready
var HPProgressBar := $"%HPProgressBar"
@onready
var STProgressBar := $"%STProgressBar"

func set_st(value :float):
	st = value
	STProgressBar.value = value

func damage(value :float):
	_damage.rpc_id(get_multiplayer_authority(), value)
	

@rpc("any_peer", "call_local", "reliable")
func _damage(value :float):
	hp -= value
	_update_hp.rpc(hp)
	HPProgressBar.value = hp
	

@rpc("any_peer", "call_remote", "reliable")
func _update_hp(value : float):
	hp = value
	HPProgressBar.value = hp
	

func _enter_tree() -> void:
	pass

func set_player_position(pos :Vector3):
	$Player.global_position = pos

@rpc("any_peer", "call_local", "reliable")
func _update_level(level: int):
	on_level = level
	Globals.update_network_list()

func change_level(level :int, spawn_point_id :int):
	if !is_multiplayer_authority():
		return
	
	Globals.level_manager.load_level(level)
	
	await Globals.level_manager.level_loaded
	
	var spawn_point :SpawnPoint = Globals.level_manager.current_level.spawn_points[spawn_point_id]
	$Player.global_position = spawn_point.get_spawn_position(MultiplayerManager.get_player_index(get_multiplayer_authority()))
	
	_update_level.rpc(level)
	

	
