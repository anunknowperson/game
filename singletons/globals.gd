extends Node

# Controlled by MainMenu
var local := true

# Controlled by MainMenu
signal game_start

# Controlled by Player Spawner. [player_id] = Player object
var players = {}

# Controlled by MainMenu
var player_class = "TP"

# Store player class selections for all players
var player_options = {}
