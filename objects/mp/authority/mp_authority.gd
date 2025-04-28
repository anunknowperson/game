extends Node3D
class_name MPAuthority

var authority_label: Label3D

@export
var offset := 0.2

func _init() -> void:
	name = "MPAuthority"

func _ready() -> void:
	get_parent().set_multiplayer_authority(1, true)
	
	# Create Label3D node to display the current authority
	authority_label = Label3D.new()
	authority_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	authority_label.text = "Авторити: " + str(get_multiplayer_authority())
	authority_label.font_size = 24
	authority_label.modulate = Color(1, 1, 0)  # Yellow for visibility 
	  # Position above the node
	add_child(authority_label)

func authorize(id: int) -> void:
	change_authority.rpc(id)

@rpc("any_peer", "call_local", "reliable")
func change_authority(id :int) -> void:
	get_parent().set_multiplayer_authority(id, true)

func _process(_delta: float) -> void:
	authority_label.global_position = global_position +  Vector3(0, offset, 0)
	authority_label.text = "Авторити: " + str(get_multiplayer_authority())
