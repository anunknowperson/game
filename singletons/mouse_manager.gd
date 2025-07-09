extends Node

var game_captured := false

func _ready() -> void:
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func ui_capture():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func ui_release():
	if game_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func capture():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	game_captured = true
	# Toggle mouse capture

func release():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	game_captured = false
			
