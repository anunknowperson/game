extends Node3D


var level_scene = preload("res://levels/test/TestLevel.tscn")


func _ready():
	
	var level = level_scene.instantiate()
	add_child(level)
