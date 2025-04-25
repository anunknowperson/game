extends RigidBody3D

class_name MPProp

@export
var value := 100

var mp_authority := MPAuthority.new()
var mp_physics_synchronizer := MPPhysicsSynchronizer.new()
var mp_interactable := MPInteractable.new()
var mp_grabbable := MPGrabbable.new()
var mp_movable := MPMovable.new()

func _ready() -> void:
	add_child(mp_authority)
	add_child(mp_interactable)
	add_child(mp_grabbable)
	add_child(mp_physics_synchronizer)
	add_child(mp_movable)
	
	
