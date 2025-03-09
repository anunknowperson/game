extends Node3D

signal on_interaction

func touch(force):
	if is_multiplayer_authority():
		$Synchronizer.touch(force)
	else:
		$Synchronizer.rpc_id(get_multiplayer_authority(), "touch", force)

func interact():
	on_interaction.emit()

func apply_velocities(force):
	if is_multiplayer_authority():
		$Synchronizer.apply_velocities(force)
	else:
		$Synchronizer.rpc_id(get_multiplayer_authority(), "apply_velocities", force)
