extends Node3D
class_name MPInteractable

signal on_interact

func _init() -> void:
	name = "MPInteractable"

func _ready() -> void:
	get_parent().add_to_group("mp_interactable")

func interact() -> void:
	on_interact.emit()
