class_name SceneManager
extends Node

@export_file("*.tscn")
var default_scene := ""

@export
var min_loading_screen_time := 2.0

var current_scene: Node

@onready
var loading_screen := $LoadingScreen
@onready
var scene_container := $SceneContainer

const LOADING_RESOURCES := "Загрузка ресурсов..."
const INSTANSING_SCENE := "Инстанцирование сцены..."

func _enter_tree() -> void:
	Globals.scene_manager = self

func _ready() -> void:
	if default_scene != "":
		change_scene_to_file(default_scene, false)

func show_loading_screen():
	loading_screen.show_screen()
	print("show")
	await get_tree().process_frame
	loading_screen.set_loading_progress(0.0)

func set_loading_screen_text(text):
	loading_screen.set_status_text(text)

func set_loading_screen_progress(value :float):
	loading_screen.set_loading_progress(value)

func hide_load_bar():
	loading_screen.hide_load()

func hide_loading_screen():
	loading_screen.hide_screen()

func change_scene_to_file(path: String, show_loading_screen: bool = true, pass_control :bool = false) -> void:
	# Show loading screen only if requested
	if show_loading_screen:
		loading_screen.show_screen()
	
	loading_screen.set_status_text(LOADING_RESOURCES)
	
	loading_screen.set_loading_progress(0.0)
	
	# Start loading the new scene
	var load_status = ResourceLoader.load_threaded_request(path)
	if load_status != OK:
		print("Error: Failed to start loading scene: ", path)
		loading_screen.hide_screen()
		return
	
	# Start monitoring the loading progress
	_monitor_loading_progress(path, pass_control)

func _monitor_loading_progress(path: String, pass_control :bool) -> void:
	var progress_array := [0.0]
	
	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress_array)
		var progress = progress_array[0]
		
		# Update loading screen progress
		loading_screen.set_loading_progress(progress * 100.0)
		
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				# Loading completed successfully
				_finish_scene_change(path, pass_control)
				break
			ResourceLoader.THREAD_LOAD_FAILED:
				# Loading failed
				print("Error: Failed to load scene: ", path)
				loading_screen.hide_screen()
				break
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				# Invalid resource
				print("Error: Invalid resource: ", path)
				loading_screen.hide_screen()
				break
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# Still loading, wait a frame
				await get_tree().process_frame
		
		# Small delay to prevent excessive polling
		await get_tree().create_timer(0.01).timeout

func _finish_scene_change(path: String, pass_control :bool) -> void:
	# Get the loaded scene
	var new_scene_resource = ResourceLoader.load_threaded_get(path)
	if not new_scene_resource:
		print("Error: Failed to get loaded scene: ", path)
		loading_screen.hide_screen()
		return
	
	# Remove current scene if it exists
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	
	loading_screen.set_status_text(INSTANSING_SCENE)
	loading_screen.hide_load()
	await get_tree().process_frame
	
	# Instantiate and add new scene
	current_scene = new_scene_resource.instantiate()
	current_scene = current_scene
	$SceneContainer.add_child(current_scene)
	
	# Check if running on template build
	if OS.has_feature("template"):
		# Wait minimum time for loading screen to be visible
		await get_tree().create_timer(min_loading_screen_time).timeout
	else:
		# Original delay for smooth transition
		await get_tree().create_timer(0.1).timeout
	
	if not pass_control:
		loading_screen.hide_screen()
