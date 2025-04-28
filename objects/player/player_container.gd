extends Node3D

@onready
var body := $Player

func get_body() -> CharacterBody3D:
	return body

func set_body_position(pos :Vector3) -> void:
	body.position = pos

@rpc("any_peer", "call_local", "reliable")
func hide_player():
	$Player.process_mode = Node.PROCESS_MODE_DISABLED
	$Player.hide()
	$Player.active = false

@rpc("any_peer", "call_local", "reliable")
func show_player():
	$Player.process_mode = Node.PROCESS_MODE_INHERIT
	$Player.show()
	$Player.active = true
	
func take_control():
	hide_player.rpc()
	$Player/Camera3D.current = false

func return_control():
	show_player.rpc()
	$Player/Camera3D.current = true
