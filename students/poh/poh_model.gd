extends Node3D

var student_name := "Ваня Пох"
var student_desc := "aas"

var skills := [StudentSkillVonyat.new(), StudentSkillMother.new()]

@onready var player := $AnimationPlayer
@onready var animation_tree := $AnimationTree

const idle_anim = "poh/warrior_idle"

# Track if we're currently playing an emote
var is_emoting := false

func emote_selected(str):
	emote(str)

func _ready() -> void:
	# Enable animation tree by default
	animation_tree.active = true
	
	if is_multiplayer_authority() and Globals.emotion_window:
		Globals.emotion_window.emote_selected.connect(emote_selected)
		Globals.emotion_window.call_deferred("set_emotions", (get_available_animations()))
		Globals.lobby_player_container_model_changed.emit()

var emotes := {
	"entry" : {
		"loop": false,
		"time": 0.0
	},
	"breakdance_1990" : {
		"loop": true,
		"time": 5.0
	},
	"drinking" : {
		"loop": false,
		"time": 0.0
	},
	"situps" : {
		"loop": true,
		"time": 5.0
	},
	"salute" : {
		"loop": false,
		"time": 0.0
	},
	"punching" : {
		"loop": true,
		"time": 5.0
	},
	"soccer_trip" : {
		"loop": false,
		"time": 0.0
	}
}

func get_available_animations():
	return {
		"Это же Иван Похабов": "entry",
		"Зафлексить": "breakdance_1990",
		"Выпить": "drinking",
		"Зальчик": "situps",
		"Салют": "salute",
		"13212": "punching",
		"123132": "soccer_trip"
	}

# AnimationTree control methods - now with RPC sync
func set_idle():
	if is_emoting:
		return
	_set_idle.rpc()

@rpc("any_peer", "call_local", "reliable")
func _set_idle():
	animation_tree.set("parameters/Transition/transition_request", "idle")

func set_walking(blend_position: Vector2 = Vector2.ZERO):
	if is_emoting:
		return
	_set_walking.rpc(blend_position)

@rpc("any_peer", "call_local", "reliable")
func _set_walking(blend_position: Vector2 = Vector2.ZERO):
	# Reverse x component when moving backwards (y < 0)
	var adjusted_blend_position = blend_position
	if blend_position.y < 0:
		adjusted_blend_position.x *= -1
	
	animation_tree.set("parameters/Walking/blend_position", adjusted_blend_position)
	animation_tree.set("parameters/Transition/transition_request", "walking")

func set_running(blend_position: Vector2 = Vector2.ZERO):
	if is_emoting:
		return
	_set_running.rpc(blend_position)

@rpc("any_peer", "call_local", "reliable")
func _set_running(blend_position: Vector2 = Vector2.ZERO):
	# Reverse x component when moving backwards (y < 0)
	var adjusted_blend_position = blend_position
	if blend_position.y < 0:
		adjusted_blend_position.x *= -1
	
	animation_tree.set("parameters/Running/blend_position", adjusted_blend_position)
	animation_tree.set("parameters/Transition/transition_request", "running")

func set_jump():
	if is_emoting:
		return
	_set_jump.rpc()

@rpc("any_peer", "call_local", "reliable")
func _set_jump():
	animation_tree.set("parameters/Transition/transition_request", "jump")

func set_crouch_idle():
	if is_emoting:
		return
	_set_crouch_idle.rpc()

@rpc("any_peer", "call_local", "reliable")
func _set_crouch_idle():
	animation_tree.set("parameters/Transition/transition_request", "crouch_idle")

func set_crouch_walking():
	if is_emoting:
		return
	_set_crouch_walking.rpc()

@rpc("any_peer", "call_local", "reliable")
func _set_crouch_walking():
	animation_tree.set("parameters/Transition/transition_request", "crouch_walking")

func emote(name: String):
	_emote.rpc(name)

@rpc("any_peer", "call_local", "reliable")
func _emote(name: String):
	var emote = emotes[name]
	is_emoting = true
	
	if emote["loop"]:
		# For looped emotes: set animation name and transition to EmotionLooped
		animation_tree.get_tree_root().get_node("EmotionLooped").animation = "poh/" + name
		animation_tree.set("parameters/Transition/transition_request", "emotion_looped")
		
		# Wait for the specified time, then return to idle
		await get_tree().create_timer(emote["time"]).timeout
		_finish_emote()
	else:
		# For oneshot emotes: set animation name and trigger oneshot
		animation_tree.get_tree_root().get_node("Emotion").animation = "poh/" + name
		
		animation_tree.set("parameters/EmotionOneShot/request", true)
		
		
		
		# Wait for the animation to finish naturally, then return to idle
		# You might need to adjust this timing based on your actual animation lengths
		var anim_length = player.get_animation("poh/" + name).length
		await get_tree().create_timer(anim_length).timeout
		_finish_emote()

func _finish_emote():
	# Return to idle state
	_finish_emote_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func _finish_emote_rpc():
	is_emoting = false
	animation_tree.set("parameters/Transition/transition_request", "idle")

# Remove the old animation player callback since we're not using it anymore
# func _on_animation_player_animation_finished(anim_name: StringName) -> void:
