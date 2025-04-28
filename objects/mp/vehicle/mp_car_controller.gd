extends Node3D

@export var engine_force_value: float = 400.0    # How hard the engine pushes
@export var brake_force_value: float = 4.0    # How strong the brakes are
@export var steering_angle_deg: float = 30.0     # Max wheel turn in degrees
@export var steering_speed: float = 5.0          # How quickly steering interpolates

var active: bool = false
var current_steering: float = 0.0                # Current steering angle in radians

@onready var vehicle_body: VehicleBody3D = $".."

func activate() -> void:
	active = true

func deactivate() -> void:
	active = false

func _physics_process(delta: float) -> void:
	if not active:
		return
	
	# --- input ---
	var forward_input := 0
	if Input.is_key_pressed(KEY_W):
		forward_input += 1
	if Input.is_key_pressed(KEY_S):
		forward_input -= 1

	var steer_input := 0
	if Input.is_key_pressed(KEY_D):
		steer_input -= 1
	if Input.is_key_pressed(KEY_A):
		steer_input += 1
		
	var brake_input := 0
	if Input.is_key_pressed(KEY_SPACE):
		brake_input = 1

	# --- apply engine force (forwards and backwards) ---
	if brake_input > 0:
		vehicle_body.engine_force = 0.0
		vehicle_body.brake = brake_force_value
	else:
		# Can drive both forward and backward now
		vehicle_body.engine_force = engine_force_value * forward_input
		vehicle_body.brake = 0.0
	
	# --- apply steering with interpolation ---
	var target_steering = deg_to_rad(steering_angle_deg) * steer_input
	
	# Interpolate steering
	current_steering = lerp(current_steering, target_steering, steering_speed * delta)
	
	# Apply the interpolated steering value
	vehicle_body.steering = current_steering
