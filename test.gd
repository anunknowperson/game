# TestSignalingUI.gd
extends Node

# UI element references.
var lobby_name_line_edit: LineEdit
var connect_button: Button
var log_text: RichTextLabel

func _ready() -> void:
	# Create a VBoxContainer to hold all UI elements.
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)
	
	# Create a header label.
	var header_label: Label = Label.new()
	header_label.text = "Signaling Test"
	vbox.add_child(header_label)
	
	# Create an HBoxContainer for lobby name input.
	var hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(hbox)
	
	var lobby_label: Label = Label.new()
	lobby_label.text = "Lobby Name:"
	hbox.add_child(lobby_label)
	
	lobby_name_line_edit = LineEdit.new()
	lobby_name_line_edit.placeholder_text = "Enter lobby name"
	hbox.add_child(lobby_name_line_edit)
	
	# Create the Connect button.
	connect_button = Button.new()
	connect_button.text = "Connect"
	# Use new callable syntax for signals.
	connect_button.pressed.connect(self._on_connect_pressed)
	vbox.add_child(connect_button)
	
	# Create a RichTextLabel for logging.
	log_text = RichTextLabel.new()
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	vbox.add_child(log_text)
	
	# Connect signals from the MeshSignalingClient autoload.
	Signaling.connected_to_server.connect(self._on_connected_to_server)
	Signaling.disconnected_from_server.connect(self._on_disconnected_from_server)
	Signaling.lobby_joined.connect(self._on_lobby_joined)
	Signaling.peer_connected.connect(self._on_peer_connected)
	Signaling.peer_disconnected.connect(self._on_peer_disconnected)
	Signaling.offer_received.connect(self._on_offer_received)
	Signaling.answer_received.connect(self._on_answer_received)
	Signaling.candidate_received.connect(self._on_candidate_received)
	
	_log("UI ready. Enter a lobby name and click Connect.")

func _on_connect_pressed() -> void:
	var lobby_name: String = lobby_name_line_edit.text.strip_edges()
	if lobby_name == "":
		lobby_name = "default"  # Use a default lobby if empty.
	_log("Connecting to ws://37.194.195.213:35410 with lobby '" + lobby_name + "'...")
	# Start the MeshSignalingClient with the server IP, lobby name, and mesh mode enabled.
	Signaling.start("ws://37.194.195.213:35410", lobby_name, true)
	Signaling.join_lobby()

func _on_connected_to_server() -> void:
	_log("Connected to signaling server.")

func _on_disconnected_from_server() -> void:
	_log("Disconnected from signaling server.")

func _on_lobby_joined(lobby_name: String) -> void:
	_log("Joined lobby: " + lobby_name)

func _on_peer_connected(peer_id: int) -> void:
	_log("Peer connected: " + str(peer_id))

func _on_peer_disconnected(peer_id: int) -> void:
	_log("Peer disconnected: " + str(peer_id))

func _on_offer_received(peer_id: int, offer: String) -> void:
	_log("Offer received from peer " + str(peer_id) + ": " + offer)

func _on_answer_received(peer_id: int, answer: String) -> void:
	_log("Answer received from peer " + str(peer_id) + ": " + answer)

func _on_candidate_received(peer_id: int, candidate: String) -> void:
	_log("ICE candidate received from peer " + str(peer_id) + ": " + candidate)

func _log(message: String) -> void:
	log_text.append_text("[color=cyan]" + message + "[/color]\n")
	log_text.scroll_to_line(log_text.get_line_count())
