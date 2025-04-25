extends Node3D
class_name MPGrabbable

signal on_grab
signal on_hold(position: Vector3, forward: Vector3)
signal on_release

var obj :RigidBody3D

func _init() -> void:
	name = "MPGrabbable"

func _ready() -> void:
	obj = get_parent()
	obj.add_to_group("mp_grabbable")

func grab() -> void:
	on_grab.emit()

func hold(position: Vector3, forward: Vector3) -> void:
	on_hold.emit(position, forward)

func release() -> void:
	on_release.emit()
