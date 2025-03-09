extends CSGBox3D

@export
var spawn_scene = preload("res://objects/mp_rigidbody.tscn")

var counter := 0

func press() -> void:
	var loc :Vector3 = $"../SpawnPoint".position
	var object_name = "rb_" + str(multiplayer.get_unique_id()) + "_" + str(counter)
	counter += 1
	rpc("spawn_rigidbody", multiplayer.get_unique_id(), loc, object_name)

@rpc("any_peer", "call_local", "reliable")
func spawn_rigidbody(id, pos, object_name) -> void:
	print(str(multiplayer.get_unique_id()) + " SPAWNING RIGIDBODY: " + str(id) + " at " + str(pos))
	
	var rigidbody = spawn_scene.instantiate()
	rigidbody.position = pos
	rigidbody.name = object_name
	rigidbody.set_multiplayer_authority(id, true)
	
	add_child(rigidbody, true)
