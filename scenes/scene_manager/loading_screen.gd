extends Control
class_name LoadingScreen

@onready var color_rect := $ColorRect
@onready var progress_bar := $TextureProgressBar
@onready var status_label := $StatusLabel

# Don't initialize the tween here, create it when needed
var tween = null

@export var fade_duration := 0.4

func set_status_text(text: String):
	status_label.text = text

func show_screen():
	show()
	progress_bar.show()
	# Kill any existing tween
	if tween:
		tween.kill()
	# Create a new tween when needed
	tween = create_tween()
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)

func hide_load():
	progress_bar.hide()

func hide_screen():
	# Kill any existing tween
	if tween:
		tween.kill()
	# Create a new tween when needed
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(hide).set_delay(fade_duration)

func set_loading_progress(value: float):
	progress_bar.value = value
