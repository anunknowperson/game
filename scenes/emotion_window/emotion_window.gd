extends Control
class_name EmotionWindow
# Define a custom signal for emote selection
signal emote_selected(id)

@onready
var button_list := $List

func _enter_tree() -> void:
	KeyhintManager.add_keyhint("J - действие")
	Globals.emotion_window = self

func _exit_tree() -> void:
	KeyhintManager.remove_keyhint("J - действие")

func _ready():
	
	# Ensure the processing of input events
	set_process_input(true)

func set_emotions(dict):
	# Clear any existing buttons first
	for child in button_list.get_children():
		child.queue_free()
	
	# Create buttons for each emote in the dictionary
	for emote_name in dict.keys():
		var emote_id = dict[emote_name]
		
		# Create a new button for this emote
		var button = Button.new()
		button.text = emote_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 40  # Set a minimum height for the button
		
		# Connect the button's pressed signal to a local function
		button.connect("pressed", _on_emote_button_pressed.bind(emote_id))
		
		# Add the button to the list
		button_list.add_child(button)

# Called when an emote button is pressed
func _on_emote_button_pressed(emote_id):
	# Emit the signal with the emote id
	emit_signal("emote_selected", emote_id)

func _input(event):
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and not Globals.input_focus:
		if event.keycode == KEY_J:
			visible = !visible
			
			if visible:
				MouseManager.ui_capture()
			else:
				MouseManager.ui_release()
