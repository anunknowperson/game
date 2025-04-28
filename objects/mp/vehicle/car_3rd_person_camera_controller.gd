extends Node3D

# -- CONFIGURABLE PROPERTIES --
@export var distance: float = 6.0            # How far the camera sits behind the vehicle
@export var sensitivity: Vector2 = Vector2(0.15, 0.15)
@export var min_pitch: float = -30.0         # degrees
@export var max_pitch: float = 60.0          # degrees

var active: bool = false                     # enable/disable input & movement
var yaw: float = 0.0                         # horizontal angle, degrees
var pitch: float = 10.0                      # vertical angle, degrees

@onready
var camera: Camera3D = $"3RDPersonCamera"

func activate() -> void:
	active = true
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func deactivate() -> void:
	active = false
	camera.current = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		# invert X if you prefer; here dragging right yaws right
		yaw   -= event.relative.x * sensitivity.x
		pitch -= event.relative.y * sensitivity.y
		pitch = clamp(pitch, min_pitch, max_pitch)
	
	# Toggle mouse capture with Esc (assuming ui_cancel is mapped)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not active:
		return

	# Assume this script sits on the vehicle root.
	var target_pos: Vector3 = global_transform.origin

	# Build a basis rotated first around Y (yaw), then local X (pitch)
	var rot: Basis = Basis(Vector3.UP,  deg_to_rad(yaw))
	rot = rot.rotated(rot * Vector3.RIGHT, deg_to_rad(pitch))

	# Place the camera at (0,0,distance) in that rotated frame, offset from target
	
	var cam_offset: Vector3 = rot * Vector3(0, 0, distance)
	camera.global_transform.origin = target_pos + cam_offset

	# Always look back at the vehicle
	camera.look_at(target_pos, Vector3.UP)
