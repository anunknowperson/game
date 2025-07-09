extends Node3D

var current_nickname = "None"
var current_major = -1
var current_student = -1

@onready
var student_models = {
	Globals.Student.VANYA_POH: preload("res://students/poh/Model.tscn"),
	Globals.Student.ABED: preload("res://students/poh/Model.tscn")
}

var current_student_model = null

func get_camera_anchor():
	return $CameraAnchor

func set_nickname(new_nickname):
	current_nickname = new_nickname
	$NicknameLabel.text = current_nickname

func set_major(new_major):
	current_major = new_major
	$StudentLabel.text = Globals.get_student_name(current_student) + (", ТП" if current_major == 0 else ", ПИ")

func set_student(new_student):
	if current_student != new_student:
		current_student = new_student
		$StudentLabel.text = Globals.get_student_name(current_student)
		
		if current_student_model:
			current_student_model.queue_free()
		current_student_model = student_models[current_student].instantiate()
		Globals.lobby_player_container_model = current_student_model
		
		current_student_model.set_multiplayer_authority(get_multiplayer_authority())
		add_child(current_student_model)

func set_color(new_color):
	$NicknameLabel.modulate = new_color

func set_ready(new_status):
	if new_status:
		$ReadyLabel.modulate = Color.GREEN
		$ReadyLabel.text = "Документы получены"
	else:
		$ReadyLabel.modulate = Color.RED
		$ReadyLabel.text = "Документов нет"

	
