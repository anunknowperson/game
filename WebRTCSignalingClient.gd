class_name WebRTCSignalingClient
extends Node

# Signals
signal connected(id, use_mesh)
signal disconnected()
signal lobby_joined(lobby_name)
signal lobby_created(lobby_name)
signal lobby_list_received(lobbies)
signal lobby_sealed()
signal peer_connected(id)
signal peer_disconnected(id)
signal offer_received(id, offer)
signal answer_received(id, answer)
signal candidate_received(id, mid, index, sdp)

# Constants
enum Message {JOIN, ID, PEER_CONNECT, PEER_DISCONNECT, OFFER, ANSWER, CANDIDATE, SEAL, LIST_LOBBIES}

# WebSocket and connection properties
var ws: WebSocketPeer = WebSocketPeer.new()
var server_url: String = ""
var code: int = 1000
var reason: String = "Unknown"
var old_state: int = WebSocketPeer.STATE_CLOSED

# Lobby properties
var current_lobby: String = ""
var mesh_mode: bool = true
var sealed: bool = false
var my_id: int = 0

# WebRTC properties
var rtc_mp: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()

func _ready():
	print("WebRTCSignalingClient initialized")
	set_process(true)

# Called every frame to handle WebSocket messages
func _process(_delta):
	ws.poll()
	var state = ws.get_ready_state()
	
	# Handle connection state changes
	if state != old_state:
		if state == WebSocketPeer.STATE_OPEN:
			print("WebSocket connection established")
		
			# Emit connected signal with a temporary ID until we receive a real one
			# This will allow UI to proceed without waiting for lobby join
			call_deferred("emit_signal", "connected", 999999, true)
		elif state == WebSocketPeer.STATE_CLOSED:
			code = ws.get_close_code()
			reason = ws.get_close_reason()
			print("WebSocket disconnected with code: %d, reason: %s" % [code, reason])
			disconnected.emit()
			
			# Reset state when disconnected
			if !sealed:
				stop()
	
	# Process incoming messages
	while state == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count():
		if not _parse_msg():
			print("Error parsing message from server")
	
	old_state = state

# Connect to the signaling server
func connect_to_server(url: String) -> void:
	server_url = url
	close()
	code = 1000
	reason = "Unknown"
	
	print("Attempting to connect to WebSocket server: ", url)
	
	# Make sure WebSocket is properly initialized
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		print("WebSocket is closed, attempting to connect")
		var err = ws.connect_to_url(url)
		if err != OK:
			print("Error connecting to WebSocket: ", err)
		else:
			print("WebSocket connection initiated")
	else:
		print("WebSocket is not in closed state, current state: ", ws.get_ready_state())

# Close the connection to the server
func close() -> void:
	ws.close()
	current_lobby = ""
	sealed = false

# Create a new lobby
func create_lobby(max_players: int = 4, use_mesh: bool = true) -> void:
	mesh_mode = use_mesh
	_send_msg(Message.JOIN, 0 if use_mesh else 1, "")
	print("Creating a new lobby with max players: ", max_players)

# Join an existing lobby
func join_lobby(lobby_name: String, use_mesh: bool = true) -> void:
	mesh_mode = use_mesh
	_send_msg(Message.JOIN, 0 if use_mesh else 1, lobby_name)
	print("Joining lobby: ", lobby_name)

# Request a list of available lobbies
func request_lobby_list() -> void:
	_send_msg(Message.LIST_LOBBIES, 0)
	print("Requesting lobby list")

# Seal the lobby (only host can do this)
func seal_lobby() -> void:
	_send_msg(Message.SEAL, 0)
	print("Sealing lobby")

# Start the signaling process
func start(url: String, lobby_name: String = "", use_mesh: bool = true) -> void:
	stop()
	sealed = false
	mesh_mode = use_mesh
	connect_to_server(url)
	
	# Auto-join or create a lobby when connection is established
	if lobby_name.is_empty():
		# Will create a new lobby when connected
		await connected
		create_lobby(4, use_mesh)
	else:
		# Will join the specified lobby when connected
		await connected
		join_lobby(lobby_name, use_mesh)

# Stop everything
func stop() -> void:
	multiplayer.multiplayer_peer = null
	rtc_mp.close()
	close()
	my_id = 0
	current_lobby = ""
	sealed = false

# Create a WebRTC peer connection
func _create_peer(id: int) -> WebRTCPeerConnection:
	var peer: WebRTCPeerConnection = WebRTCPeerConnection.new()
	peer.initialize({
		"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ]
	})
	peer.session_description_created.connect(_offer_created.bind(id))
	peer.ice_candidate_created.connect(_new_ice_candidate.bind(id))
	rtc_mp.add_peer(peer, id)
	
	# Create offer for peers with a lower ID (but not if we're ID 1 - the host)
	if id < rtc_mp.get_unique_id() and rtc_mp.get_unique_id() != 1:
		peer.create_offer()
	
	return peer

# Handle new ICE candidate
func _new_ice_candidate(mid_name: String, index_name: int, sdp_name: String, id: int) -> void:
	_send_candidate(id, mid_name, index_name, sdp_name)

# Handle created offer or answer
func _offer_created(type: String, data: String, id: int) -> void:
	if not rtc_mp.has_peer(id):
		return
	
	print("Created ", type, " for peer ", id)
	rtc_mp.get_peer(id).connection.set_local_description(type, data)
	
	if type == "offer":
		_send_offer(id, data)
	else:
		_send_answer(id, data)

# Send an ICE candidate to the server
func _send_candidate(id: int, mid: String, index: int, sdp: String) -> int:
	return _send_msg(Message.CANDIDATE, id, "\n%s\n%d\n%s" % [mid, index, sdp])

# Send an offer to the server
func _send_offer(id: int, offer: String) -> int:
	return _send_msg(Message.OFFER, id, offer)

# Send an answer to the server
func _send_answer(id: int, answer: String) -> int:
	return _send_msg(Message.ANSWER, id, answer)

# Handle when we receive our ID from the server
func _handle_connected(id: int, use_mesh: bool) -> void:
	print("Received ID from server: %d, using mesh mode: %s" % [id, use_mesh])
	my_id = id
	
	if use_mesh:
		print("Mesh peer initialized")
		rtc_mp.create_mesh(id)
	elif id == 1:
		print("Server peer initialized")
		rtc_mp.create_server()
	else:
		print("Client peer initialized")
		rtc_mp.create_client(id)
	
	multiplayer.multiplayer_peer = rtc_mp
	connected.emit(id, use_mesh)

# Handle when we've joined a lobby
func _handle_lobby_joined(lobby_name: String) -> void:
	current_lobby = lobby_name
	print("Joined lobby: ", lobby_name)
	
	if lobby_name == "":
		lobby_created.emit(lobby_name)
	else:
		lobby_joined.emit(lobby_name)

# Handle when the lobby is sealed
func _handle_lobby_sealed() -> void:
	sealed = true
	lobby_sealed.emit()
	print("Lobby has been sealed")

# Handle when we disconnect
func _handle_disconnected() -> void:
	print("Disconnected: %d: %s" % [code, reason])
	disconnected.emit()
	
	if not sealed:
		stop()  # Unexpected disconnect

# Handle when a peer connects
func _handle_peer_connected(id: int) -> void:
	print("Peer connected %d" % id)
	_create_peer(id)
	peer_connected.emit(id)

# Handle when a peer disconnects
func _handle_peer_disconnected(id: int) -> void:
	print("Peer disconnected %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.remove_peer(id)
	peer_disconnected.emit(id)

# Handle when we receive an offer
func _handle_offer_received(id: int, offer: String) -> void:
	print("Got offer from peer %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("offer", offer)
	offer_received.emit(id, offer)

# Handle when we receive an answer
func _handle_answer_received(id: int, answer: String) -> void:
	print("Got answer from peer %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("answer", answer)
	answer_received.emit(id, answer)

# Handle when we receive an ICE candidate
func _handle_candidate_received(id: int, mid: String, index: int, sdp: String) -> void:
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.add_ice_candidate(mid, index, sdp)
	candidate_received.emit(id, mid, index, sdp)

# Handle when we receive a list of lobbies
func _handle_lobby_list(lobbies_json: String) -> void:
	var lobbies = JSON.parse_string(lobbies_json)
	if lobbies is Array:
		print("Received list of %d lobbies" % lobbies.size())
		lobby_list_received.emit(lobbies)

# Parse a message from the server
func _parse_msg() -> bool:
	var packet := ws.get_packet()
	var msg_text := packet.get_string_from_utf8()
	
	print("Received message from server: %s" % msg_text)
	
	var parsed = JSON.parse_string(msg_text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("type") or not parsed.has("id"):
		return false
	
	var msg := parsed as Dictionary
	var type := int(msg.type)  # Directly convert to int
	var src_id := int(msg.id)  # Directly convert to int
	var data := str(msg.data)  # Convert data to string
	
	match type:
		Message.ID:
			_handle_connected(src_id, data == "true")
		Message.JOIN:
			_handle_lobby_joined(data)
		Message.SEAL:
			_handle_lobby_sealed()
		Message.PEER_CONNECT:
			_handle_peer_connected(src_id)
		Message.PEER_DISCONNECT:
			_handle_peer_disconnected(src_id)
		Message.OFFER:
			_handle_offer_received(src_id, data)
		Message.ANSWER:
			_handle_answer_received(src_id, data)
		Message.LIST_LOBBIES:
			_handle_lobby_list(data)
		Message.CANDIDATE:
			var candidate: PackedStringArray = data.split("\n", false)
			if candidate.size() != 3:
				return false
			if not candidate[1].is_valid_int():
				return false
			_handle_candidate_received(src_id, candidate[0], candidate[1].to_int(), candidate[2])
		_:
			return false
	
	return true

# Send a message to the server
func _send_msg(type: int, id: int, data: String = "") -> int:
	print("Sending message to server - Type: %d, ID: %d, Data: %s" % [type, id, data])
	return ws.send_text(JSON.stringify({
		"type": type,
		"id": id,
		"data": data
	}))
