extends Node

# The MultiplayerManager singleton instance
var manager: MultiplayerManager

func _ready():
	# Create the multiplayer manager
	manager = MultiplayerManager.new()
	add_child(manager)
	
	# Print debug info
	print("WebRTC Multiplayer singleton initialized")
