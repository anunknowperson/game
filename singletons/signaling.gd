# MeshSignalingClient.gd
extends Node

var ws_client := WebSocketPeer.new()
var rtc_mp := WebRTCMultiplayerPeer.new() # For managing WebRTC peer connections.
var connected: bool = false
var lobby: String = ""
var unique_id: int = 0  # Our assigned id (host gets 1)

# Command codes matching the server.
const CMD_JOIN = 0
const CMD_ID = 1
const CMD_PEER_CONNECT = 2
const CMD_PEER_DISCONNECT = 3
const CMD_OFFER = 4
const CMD_ANSWER = 5
const CMD_CANDIDATE = 6

# Signals to notify your game logic.
signal connected_to_server()
signal disconnected_from_server()
signal lobby_joined(lobby_name)
signal peer_connected(peer_id)
signal peer_disconnected(peer_id)
signal offer_received(peer_id, offer)
signal answer_received(peer_id, answer)
signal candidate_received(peer_id, candidate)

func _ready() -> void:
	# Enable processing so _process(delta) is called.
	set_process(true)

func start(url: String, lobby_name: String = "", mesh: bool = true) -> void:
	# Reset state.
	unique_id = 0
	lobby = lobby_name
	connected = false
	rtc_mp = WebRTCMultiplayerPeer.new()
	
	
	# Set ICE servers via the configuration property.
	rtc_mp.configuration = { "iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] }
	# Connect to the signaling server.
	var err = ws_client.connect_to_url(url)
	if err != OK:
		push_error("Error connecting to signaling server: " + str(err))
	else:
		print("Connecting to signaling server...")
	# (The JOIN command is sent by join_lobby())

func _process(delta: float) -> void:
	ws_client.poll()
	while ws_client.get_available_packet_count() > 0:
		var packet: String = ws_client.get_packet().get_string_from_utf8()
		_handle_message(packet)

func _handle_message(packet: String) -> void:
	var js = JSON.new()
	var result = js.parse(packet)
	if result.error != OK:
		print("Error parsing JSON: " + result.error_string)
		return
	var msg = result.result
	var msg_type: int = int(msg.get("type", -1))
	var id: int = int(msg.get("id", -1))
	var data = msg.get("data", "")
	
	match msg_type:
		CMD_JOIN:
			# Lobby join confirmation (data contains lobby name).
			lobby = data
			emit_signal("lobby_joined", lobby)
		CMD_ID:
			# Receive assigned unique id.
			unique_id = id
			print("Assigned unique id: ", unique_id)
		CMD_PEER_CONNECT:
			emit_signal("peer_connected", id)
			_create_peer(id)
		CMD_PEER_DISCONNECT:
			emit_signal("peer_disconnected", id)
			if rtc_mp.has_peer(id):
				rtc_mp.remove_peer(id)
		CMD_OFFER:
			emit_signal("offer_received", id, data)
			if rtc_mp.has_peer(id):
				rtc_mp.get_peer(id).connection.set_remote_description("offer", data)
		CMD_ANSWER:
			emit_signal("answer_received", id, data)
			if rtc_mp.has_peer(id):
				rtc_mp.get_peer(id).connection.set_remote_description("answer", data)
		CMD_CANDIDATE:
			emit_signal("candidate_received", id, data)
			if rtc_mp.has_peer(id):
				# Assuming a single media stream; adjust as needed.
				rtc_mp.get_peer(id).connection.add_ice_candidate("audio", 0, data)
		_:
			print("Unknown command type: ", msg_type)

func join_lobby() -> void:
	# Send JOIN command.
	# For mesh mode, we send id=0; data is the lobby name (empty string creates a new lobby).
	var msg = { "type": CMD_JOIN, "id": 0, "data": lobby }
	ws_client.send_text(JSON.stringify(msg))

func send_offer(peer_id: int, offer: String) -> void:
	var msg = { "type": CMD_OFFER, "id": peer_id, "data": offer }
	ws_client.send_text(JSON.stringify(msg))

func send_answer(peer_id: int, answer: String) -> void:
	var msg = { "type": CMD_ANSWER, "id": peer_id, "data": answer }
	ws_client.send_text(JSON.stringify(msg))

func send_candidate(peer_id: int, candidate: String) -> void:
	var msg = { "type": CMD_CANDIDATE, "id": peer_id, "data": candidate }
	ws_client.send_text(JSON.stringify(msg))

func _create_peer(peer_id: int) -> void:
	# Create a new WebRTCPeerConnection for the given peer.
	var peer = WebRTCPeerConnection.new()
	peer.initialize({ "iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
	# Connect session description created signal using a lambda (callable) with the new syntax.
	peer.session_description_created.connect(
		Callable(func(desc_type: String, sdp: String) -> void:
		peer.set_local_description(desc_type, sdp)
		if desc_type == "offer":
			send_offer(peer_id, sdp)
		elif desc_type == "answer":
			send_answer(peer_id, sdp)
		)
	)
	# Connect ICE candidate signal.
	peer.ice_candidate_created.connect(
		Callable(func(media: String, index: int, candidate: String) -> void:
		send_candidate(peer_id, candidate)
		)
	)
	# Add the peer to the multiplayer mesh.
	rtc_mp.add_peer(peer, peer_id)
	# Create an offer if our unique id is greater than the other peer’s (so the host, which is id 1, never initiates an offer).
	if unique_id > peer_id:
		peer.create_offer()
