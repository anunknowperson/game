extends Node3D

const MOUSE_SENSITIVITY := 0.002

@onready var camera := $Camera3D

var active = true

func _ready() -> void:
	# Only enable input processing and camera for the local authority
	var is_authority = is_multiplayer_authority()
	camera.current = is_authority
	set_process_input(is_authority)
	
	# Optionally capture the mouse on start
	if is_authority:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func activate() -> void:
	$Camera3D.current = true
	active = true
	
func deactivate() -> void:
	$Camera3D.current = false
	active = false

func _input(event):
	if !active:
		return
		
	# Only the authority should steer the view
	if not is_multiplayer_authority():
		return

	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw the whole car (rotate around Y)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Pitch the camera up/down
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		# Clamp pitch to straight up/down
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

	# Toggle mouse capture with Esc (assuming ui_cancel is mapped)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
