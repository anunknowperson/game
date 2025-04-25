extends Node3D
class_name MPCartMovable

signal grab_confirmed

@export 
var pull_strength := 6
@export var rotation_smoothing := 0.2

var obj
var mp_grabbable
var mp_authority

var grabbed_by := []
var grab_targets := {}
var grab_directions := {}

var last_touched := 0.0
var touch_cooldown := 0.5

func _init() -> void:
	name = "MPMovable"

func _ready() -> void:
	
	obj = get_parent()
	
	obj.add_to_group("mp_movable")
	
	mp_authority = obj.get_node("MPAuthority")
	
	mp_grabbable = obj.get_node("MPGrabbable")
	mp_grabbable.connect("on_grab", grab)
	mp_grabbable.connect("on_hold", hold)
	mp_grabbable.connect("on_release", release)

func touch(vec :Vector3) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_touched < touch_cooldown:
		return  # Ignore touch if it's too soon after previous touch
	
	last_touched = current_time
	apply_touch.rpc_id(get_multiplayer_authority(), vec)

@rpc("any_peer", "call_local", "reliable")
func apply_touch(vec :Vector3) -> void:
	
	obj.apply_central_impulse(vec * 2)

func grab() -> void:
	if len(grabbed_by) == 0:
		mp_authority.authorize(multiplayer.get_unique_id())
		register_grab.rpc(multiplayer.get_unique_id())
		grab_confirmed.emit()

func hold(position: Vector3, forward: Vector3) -> void:
	# print("Hold")
	set_grab_target.rpc(multiplayer.get_unique_id(), position, forward)
	
func  _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if len(grab_targets) != 0:
			var grab_target := Vector3.ZERO
			
			for player in grab_targets:
				grab_target += grab_targets[player]
			
			grab_target /= len(grab_targets)
	
			var vel = (grab_target - obj.global_position) * pull_strength
			vel.y *= 0.1
			obj.set_linear_velocity(vel)
			
			# --- rotational alignment parallel to XZ plane ---
			# average the forward vectors
			var avg_dir = Vector3.ZERO
			for id in grab_directions.keys():
				avg_dir += grab_directions[id]
			avg_dir /= grab_directions.size()
			# flatten to XZ and normalize
			avg_dir.y = 0
			if avg_dir.length() < 0.001:
				return  # no meaningful direction

			avg_dir = avg_dir.normalized()

			# build target rotation
			var target_basis = Basis().looking_at(avg_dir, Vector3.UP)
			var target_quat  = target_basis.get_rotation_quaternion().normalized()

			# current rotation
			var cur_quat = obj.global_transform.basis.get_rotation_quaternion().normalized()

			# quaternion difference
			var diff_q = target_quat * cur_quat.inverse()
			if diff_q.w < 0.0:
				diff_q = -diff_q

			# axis-angle
			var axis  = diff_q.get_axis()
			var angle = diff_q.get_angle()

			if angle > 0.0001:
				# ω = axis * (angle / window)
				var required_ω = axis * (angle / rotation_smoothing)
				# apply directly
				obj.angular_velocity = required_ω
			else:
				obj.angular_velocity = Vector3.ZERO

func release() -> void:
	unregister_grab.rpc(multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "unreliable")
func set_grab_target(id :int, pos :Vector3, forward :Vector3) -> void:
	if id in grabbed_by:
		grab_targets[id] = pos
		grab_directions[id] = forward

@rpc("any_peer", "call_local", "reliable")
func register_grab(id :int) -> void:
	grabbed_by.append(id)

@rpc("any_peer", "call_local", "reliable")
func unregister_grab(id :int) -> void:
	grabbed_by.erase(id)
	
	grab_targets.erase(id)
	grab_directions.erase(id)
