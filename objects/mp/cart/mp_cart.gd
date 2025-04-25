extends RigidBody3D
class_name MPCart

@export
var value_label :Label3D

var mp_authority := MPAuthority.new()
var mp_physics_synchronizer := MPPhysicsSynchronizer.new()
var mp_interactable := MPInteractable.new()
var mp_grabbable := MPGrabbable.new()
var mp_movable := MPCartMovable.new()

func _ready() -> void:
	add_child(mp_authority)
	add_child(mp_interactable)
	add_child(mp_grabbable)
	add_child(mp_physics_synchronizer)
	add_child(mp_movable)
	
	mp_movable.grab_confirmed.connect(transfer_authorities_on_grab)
	

func transfer_authorities_on_grab() -> void:
	for prop in props_in_cart:
		prop.mp_authority.authorize(multiplayer.get_unique_id())

var props_in_cart := []

func _on_objects_detector_body_entered(body: Node3D) -> void:
	if body is MPProp:
		props_in_cart.append(body)
		calculate_value()


func _on_objects_detector_body_exited(body: Node3D) -> void:
	if body is MPProp:
		props_in_cart.erase(body)
		calculate_value()

func calculate_value() -> void:
	var cost := 0
	
	for prop in props_in_cart:
		cost += prop.value
	
	value_label.text = str(cost)
