extends Node3D
class_name MPMovable

@export 
var pull_strength := 6

var obj
var mp_grabbable
var mp_authority

var grabbed_by := []
var grab_targets := {}

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
	pass
	# obj.apply_central_impulse(vec * 2)

func grab() -> void:
	if len(grabbed_by) == 0:
		mp_authority.authorize(multiplayer.get_unique_id())
		
	
	register_grab.rpc(multiplayer.get_unique_id())

func hold(position: Vector3, forward: Vector3) -> void:
	# print("Hold")
	set_grab_target.rpc(multiplayer.get_unique_id(), position)
	
func  _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if len(grab_targets) != 0:
			var grab_target := Vector3.ZERO
			
			for player in grab_targets:
				grab_target += grab_targets[player]
			
			grab_target /= len(grab_targets)

			obj.set_linear_velocity((grab_target - obj.global_position) * pull_strength)

func release() -> void:
	unregister_grab.rpc(multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "unreliable")
func set_grab_target(id :int, pos :Vector3) -> void:
	if id in grabbed_by:
		grab_targets[id] = pos

@rpc("any_peer", "call_local", "reliable")
func register_grab(id :int) -> void:
	grabbed_by.append(id)

@rpc("any_peer", "call_local", "reliable")
func unregister_grab(id :int) -> void:
	grabbed_by.erase(id)
	
	grab_targets.erase(id)
