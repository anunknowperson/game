extends Node3D
func _ready() -> void:
	$AnimationTree.set("parameters/conditions/atk", false)
	$AnimationTree.set("parameters/conditions/idle", true)
	$AnimationTree.set("parameters/conditions/move", true)

func move_anim() -> void:
	$AnimationTree.set("parameters/conditions/atk", false)
	$AnimationTree.set("parameters/conditions/idle", false)
	$AnimationTree.set("parameters/conditions/move", true)

func idle_anim() -> void:
	$AnimationTree.set("parameters/conditions/atk", false)
	$AnimationTree.set("parameters/conditions/move", false)
	$AnimationTree.set("parameters/conditions/idle", true)
func atk_anim() -> void:
	$AnimationTree.set("parameters/conditions/move", false)
	$AnimationTree.set("parameters/conditions/idle", false)
	$AnimationTree.set("parameters/conditions/atk", true)
