extends VehicleBody3D

@onready var mp_authority = $MPAuthority

@export var car_player_prefab = preload("res://objects/mp/vehicle/car_player.tscn")

@export var seats_positions :Array[Marker3D]= []

@export
var seats := [null, null, null, null, null]

var car_players := {}

var view = "fps" # fps/3rd

var my_car_player

var active := false

@rpc("any_peer", "call_local", "reliable")
func change_seat(player :int) -> void:
	var old_id = seats.find(Globals.players[player])
	
	var car_pl = car_players[seats[old_id]]
	
	var cpl = seats_positions[old_id].get_child(0)
	
	seats_positions[old_id].remove_child(cpl)

	var seat_count = seats.size()
	var freeid = (old_id + 1) % seat_count
	var start_idx = freeid
	while seats[freeid] != null:
		freeid = (freeid + 1) % seat_count
		if freeid == start_idx:
			return  # no free seats at all
	
	seats[freeid] = seats[old_id]
	seats[old_id] = null
	seats_positions[freeid].add_child(cpl)
	
	if player == multiplayer.get_unique_id():
		if freeid == 0:
			control_car()
		else:
			$MPCarController.deactivate()
	

@rpc("any_peer", "call_local", "reliable")
func add_player(player :int) -> void:
	
	
	var freeid = seats.find(null)
	
	seats[freeid] = Globals.players[player]
	
	var cpl = car_player_prefab.instantiate()
	car_players[seats[freeid]] = cpl
	
	cpl.set_multiplayer_authority(player, true)
	
	seats_positions[freeid].add_child(cpl)
	
	print(seats)
	
	if player == multiplayer.get_unique_id():
		my_car_player = cpl
		my_car_player.activate()
		
		call_deferred("activate")
	
	
	
@rpc("any_peer", "call_local", "reliable")
func remove_player(player :int) -> void:
	print("remove player")
	
	var id = seats.find(Globals.players[player])
	
	var cpl = seats_positions[id].get_child(0)
	
	if player == multiplayer.get_unique_id():
		cpl.deactivate()
	
	cpl.queue_free()
	
	seats[id] = null
	
	
	if $MPCarController.active:
		$MPCarController.deactivate()
	
	if player == multiplayer.get_unique_id():
		active = false
		view = "fps"
		$"3RDPersonCameraController".deactivate()
		Globals.players[player].set_body_position(global_position + Vector3.UP * 3)
		Globals.players[player].call_deferred("return_control")
		
	
func activate():
	active = true
	

func _input(event: InputEvent) -> void:
	
	if !active:
		return
	
	# leave car
	if Input.is_action_just_pressed("interact_secondary"):
		remove_player.rpc(multiplayer.get_unique_id())
	
	if Input.is_action_just_pressed("tab"):
		if view == "fps":
			my_car_player.deactivate()
			$"3RDPersonCameraController".activate()
			view = "3rd"
		else:
			my_car_player.activate()
			$"3RDPersonCameraController".deactivate()
			view = "fps"
	
	if Input.is_action_just_pressed("ctrl"):
		if null in seats:
			change_seat.rpc(multiplayer.get_unique_id())

func control_car() -> void:
	mp_authority.authorize(multiplayer.get_unique_id())
	
	$MPCarController.activate()
	
	# $"3RDPerson".current = true

func _on_mp_interactable_on_interact(player) -> void:

	if seats.count(null) == 0:
		return
	
	player.take_control()
	
	if seats[0] == null:
		control_car()
	
	add_player.rpc(player.get_multiplayer_authority())
		
		
	
	
