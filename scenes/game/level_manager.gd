extends Node3D
class_name LevelManager

signal level_loaded

var current_level = null
var loaded_levels = {}  # Dictionary to store all loaded levels for server
var first_load_complete = false  # Track if server has done initial load

var levels = [
	"res://levels/test/TestLevel.tscn", # 0,
	"res://levels/test/TestLevel2.tscn" # 1
]

const LOADING_LEVEL := "Загрузка уровня..."
const INSTANCING_LEVEL := "Инстанцирование уровня..."
const GRID_SPACING := 4000.0  # 4000 meters between levels

# Get level ID by instantiated level node
func get_level_id(node: Node) -> int:
	# Handle null or invalid node
	if not node:
		return -1
	
	# Check if this is the server with multiple loaded levels
	var is_server = multiplayer.get_unique_id() == 1
	print(node.name)
	if is_server:
		# Server scenario: search through loaded_levels dictionary
		for level_id in loaded_levels:
			if loaded_levels[level_id] == node:
				return level_id
		
		# Also check if it's the current level (in case it's not in loaded_levels for some reason)
		if current_level == node:
			# Try to find it in loaded_levels by reference
			for level_id in loaded_levels:
				if loaded_levels[level_id] == current_level:
					return level_id
	
	printerr("level id requested not on server.")
	
	# Node not found in any loaded levels
	return -1

func _enter_tree() -> void:
	Globals.level_manager = self

# Calculate grid position based on level ID
func _get_grid_position(level_id: int) -> Vector3:
	# Calculate grid coordinates
	# You can adjust the grid width as needed (e.g., 10 levels per row)
	var grid_width = 10
	var grid_x = level_id % grid_width
	var grid_z = level_id / grid_width
	
	# Convert to world position
	var world_x = grid_x * GRID_SPACING
	var world_z = grid_z * GRID_SPACING
	
	return Vector3(world_x, 0, world_z)

func load_level(id: int, pass_control :bool = false):
	if id < 0 or id >= levels.size():
		print("Error: Invalid level ID: ", id)
		return
	
	# Check if this is the server
	var is_server = multiplayer.get_unique_id() == 1
	
	print("ll" + str(multiplayer.get_unique_id()))
	
	if is_server:
		if not first_load_complete:
			# First time loading - load all levels
			_load_all_levels_for_server(id, pass_control)
		else:
			# Subsequent loads - just show loading screen with delays
			_show_fake_loading_for_server(id, pass_control)
	else:
		# Client behavior - load single level as before
		_load_single_level(id, pass_control)

func _load_all_levels_for_server(target_id: int, pass_control: bool):
	# Show loading screen
	Globals.scene_manager.show_loading_screen()
	Globals.scene_manager.set_loading_screen_text(LOADING_LEVEL)
	Globals.scene_manager.set_loading_screen_progress(0.0)
	
	# Start loading all levels
	var total_levels = levels.size()
	var loaded_count = 0
	
	for i in range(total_levels):
		var level_path = levels[i]
		
		# Start loading the level
		var load_status = ResourceLoader.load_threaded_request(level_path)
		if load_status != OK:
			print("Error: Failed to start loading level: ", level_path)
			continue
		
		# Monitor this level's loading
		await _monitor_single_level_loading(level_path, i, total_levels, loaded_count)
		loaded_count += 1
	
	# All levels loaded, now instantiate them
	Globals.scene_manager.set_loading_screen_text(INSTANCING_LEVEL)
	Globals.scene_manager.hide_load_bar()
	await get_tree().process_frame
	
	# Instantiate all levels
	for i in range(total_levels):
		var level_path = levels[i]
		var level_resource = ResourceLoader.load_threaded_get(level_path)
		if level_resource:
			var level_instance = level_resource.instantiate()
			add_child(level_instance)
			
			# Set position based on grid
			var grid_position = _get_grid_position(i)
			level_instance.position = grid_position
			
			# Store in loaded_levels dictionary
			loaded_levels[i] = level_instance
			
			print("Level ", i, " spawned at position: ", grid_position)
	
	# Set current level to the target
	current_level = loaded_levels.get(target_id)
	first_load_complete = true
	
	# Small delay for smooth transition
	await get_tree().create_timer(0.1).timeout
	
	if not pass_control:
		Globals.scene_manager.hide_loading_screen()
	
	# Emit signal that level is loaded
	level_loaded.emit()

func _monitor_single_level_loading(path: String, level_id: int, total_levels: int, loaded_count: int):
	var progress_array := [0.0]
	
	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress_array)
		var progress = progress_array[0]
		
		# Calculate overall progress
		var overall_progress = (loaded_count + progress) / total_levels * 100.0
		Globals.scene_manager.set_loading_screen_progress(overall_progress)
		
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				# Loading completed successfully
				return
			ResourceLoader.THREAD_LOAD_FAILED:
				# Loading failed
				print("Error: Failed to load level: ", path)
				return
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				# Invalid resource
				print("Error: Invalid level resource: ", path)
				return
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# Still loading, wait a frame
				await get_tree().process_frame
		
		# Small delay to prevent excessive polling
		await get_tree().create_timer(0.01).timeout

func _show_fake_loading_for_server(target_id: int, pass_control: bool):
	# Show loading screen with fake progress
	Globals.scene_manager.show_loading_screen()
	Globals.scene_manager.set_loading_screen_text(LOADING_LEVEL)
	Globals.scene_manager.set_loading_screen_progress(0.0)
	
	# Simulate loading progress
	var progress_steps = 10
	for i in range(progress_steps + 1):
		var progress = float(i) / progress_steps * 100.0
		Globals.scene_manager.set_loading_screen_progress(progress)
		await get_tree().create_timer(0.05).timeout  # Small delay between progress updates
	
	# Show instancing text
	Globals.scene_manager.set_loading_screen_text(INSTANCING_LEVEL)
	Globals.scene_manager.hide_load_bar()
	await get_tree().create_timer(0.1).timeout
	
	# Set current level to the target (all levels are already loaded)
	current_level = loaded_levels.get(target_id)
	
	# Small delay for smooth transition
	await get_tree().create_timer(0.1).timeout
	
	if not pass_control:
		Globals.scene_manager.hide_loading_screen()
	
	# Emit signal that level is loaded
	level_loaded.emit()

func _load_single_level(id: int, pass_control: bool):
	var level_path = levels[id]
	
	# Show loading screen
	Globals.scene_manager.show_loading_screen()
	Globals.scene_manager.set_loading_screen_text(LOADING_LEVEL)
	Globals.scene_manager.set_loading_screen_progress(0.0)
	
	# Start loading the level
	var load_status = ResourceLoader.load_threaded_request(level_path)
	if load_status != OK:
		print("Error: Failed to start loading level: ", level_path)
		Globals.scene_manager.hide_loading_screen()
		return
	
	# Start monitoring the loading progress
	_monitor_level_loading_progress(level_path, id, pass_control)

func _monitor_level_loading_progress(path: String, level_id: int, pass_control :bool) -> void:
	var progress_array := [0.0]
	
	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress_array)
		var progress = progress_array[0]
		
		# Update loading screen progress
		Globals.scene_manager.set_loading_screen_progress(progress * 100.0)
		
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				# Loading completed successfully
				_finish_level_change(path, level_id, pass_control)
				break
			ResourceLoader.THREAD_LOAD_FAILED:
				# Loading failed
				print("Error: Failed to load level: ", path)
				Globals.scene_manager.hide_loading_screen()
				break
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				# Invalid resource
				print("Error: Invalid level resource: ", path)
				Globals.scene_manager.hide_loading_screen()
				break
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# Still loading, wait a frame
				await get_tree().process_frame
		
		# Small delay to prevent excessive polling
		await get_tree().create_timer(0.01).timeout

func _finish_level_change(path: String, level_id: int, pass_control :bool) -> void:
	# Get the loaded level
	var new_level_resource = ResourceLoader.load_threaded_get(path)
	if not new_level_resource:
		print("Error: Failed to get loaded level: ", path)
		Globals.scene_manager.hide_loading_screen()
		return
	
	# Remove current level if it exists
	if current_level:
		current_level.queue_free()
		current_level = null
	
	Globals.scene_manager.set_loading_screen_text(INSTANCING_LEVEL)
	Globals.scene_manager.hide_load_bar()
	await get_tree().process_frame
	
	# Instantiate and add new level
	current_level = new_level_resource.instantiate()
	add_child(current_level)
	
	# Set the level position based on grid
	var grid_position = _get_grid_position(level_id)
	current_level.position = grid_position
	
	print("Level ", level_id, " spawned at position: ", grid_position)
	
	# Small delay for smooth transition
	await get_tree().create_timer(0.1).timeout
	
	if not pass_control:
		Globals.scene_manager.hide_loading_screen()
	
	# Emit signal that level is loaded
	level_loaded.emit()

func get_current_level() -> Node:
	return current_level

func get_level_count() -> int:
	return levels.size()

# Helper function to get the position of a specific level without loading it
func get_level_position(level_id: int) -> Vector3:
	return _get_grid_position(level_id)

# Helper function to load a level at a specific grid position
func load_level_at_position(id: int, grid_x: int, grid_z: int, pass_control: bool = false):
	if id < 0 or id >= levels.size():
		print("Error: Invalid level ID: ", id)
		return
	
	# Check if this is the server and handle accordingly
	var is_server = multiplayer.get_unique_id() == 1
	
	if is_server and first_load_complete:
		# Server with already loaded levels - just show fake loading
		_show_fake_loading_for_server_custom(Vector3(grid_x * GRID_SPACING, 0, grid_z * GRID_SPACING), pass_control)
	else:
		# Client or server first load - load normally
		var level_path = levels[id]
		
		# Show loading screen
		Globals.scene_manager.show_loading_screen()
		Globals.scene_manager.set_loading_screen_text(LOADING_LEVEL)
		Globals.scene_manager.set_loading_screen_progress(0.0)
		
		# Start loading the level
		var load_status = ResourceLoader.load_threaded_request(level_path)
		if load_status != OK:
			print("Error: Failed to start loading level: ", level_path)
			Globals.scene_manager.hide_loading_screen()
			return
		
		# Start monitoring the loading progress with custom position
		_monitor_level_loading_progress_custom(level_path, Vector3(grid_x * GRID_SPACING, 0, grid_z * GRID_SPACING), pass_control)

func _show_fake_loading_for_server_custom(custom_position: Vector3, pass_control: bool):
	# Show loading screen with fake progress
	Globals.scene_manager.show_loading_screen()
	Globals.scene_manager.set_loading_screen_text(LOADING_LEVEL)
	Globals.scene_manager.set_loading_screen_progress(0.0)
	
	# Simulate loading progress
	var progress_steps = 10
	for i in range(progress_steps + 1):
		var progress = float(i) / progress_steps * 100.0
		Globals.scene_manager.set_loading_screen_progress(progress)
		await get_tree().create_timer(0.05).timeout
	
	# Show instancing text
	Globals.scene_manager.set_loading_screen_text(INSTANCING_LEVEL)
	Globals.scene_manager.hide_load_bar()
	await get_tree().create_timer(0.1).timeout
	
	# For custom position, we need to handle differently since we don't remove levels
	# Just set the current level reference (this might need adjustment based on your needs)
	print("Server: Fake loading complete for custom position: ", custom_position)
	
	# Small delay for smooth transition
	await get_tree().create_timer(0.1).timeout
	
	if not pass_control:
		Globals.scene_manager.hide_loading_screen()
	
	# Emit signal that level is loaded
	level_loaded.emit()

func _monitor_level_loading_progress_custom(path: String, custom_position: Vector3, pass_control: bool) -> void:
	var progress_array := [0.0]
	
	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress_array)
		var progress = progress_array[0]
		
		# Update loading screen progress
		Globals.scene_manager.set_loading_screen_progress(progress * 100.0)
		
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				# Loading completed successfully
				_finish_level_change_custom(path, custom_position, pass_control)
				break
			ResourceLoader.THREAD_LOAD_FAILED:
				# Loading failed
				print("Error: Failed to load level: ", path)
				Globals.scene_manager.hide_loading_screen()
				break
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				# Invalid resource
				print("Error: Invalid level resource: ", path)
				Globals.scene_manager.hide_loading_screen()
				break
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# Still loading, wait a frame
				await get_tree().process_frame
		
		# Small delay to prevent excessive polling
		await get_tree().create_timer(0.01).timeout

func _finish_level_change_custom(path: String, custom_position: Vector3, pass_control: bool) -> void:
	# Get the loaded level
	var new_level_resource = ResourceLoader.load_threaded_get(path)
	if not new_level_resource:
		print("Error: Failed to get loaded level: ", path)
		Globals.scene_manager.hide_loading_screen()
		return
	
	# Remove current level if it exists
	if current_level:
		current_level.queue_free()
		current_level = null
	
	Globals.scene_manager.set_loading_screen_text(INSTANCING_LEVEL)
	Globals.scene_manager.hide_load_bar()
	await get_tree().process_frame
	
	# Instantiate and add new level
	current_level = new_level_resource.instantiate()
	add_child(current_level)
	
	# Set the level position to custom position
	current_level.position = custom_position
	
	print("Level spawned at custom position: ", custom_position)
	
	# Small delay for smooth transition
	await get_tree().create_timer(0.1).timeout
	
	if not pass_control:
		Globals.scene_manager.hide_loading_screen()
	
	# Emit signal that level is loaded
	level_loaded.emit()
