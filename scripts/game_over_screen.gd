# game_over_screen.gd
extends Control

@onready var try_again_button = $ColorRect/VBoxContainer/TryAgainButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	try_again_button.pressed.connect(_on_try_again)

func _on_try_again():
	print("Try Again button clicked!")
	
	# Reset all managers
	EconomyManager.reset()
	TimeManager.reset()
	JobManager.reset()
	
	# Unpause
	get_tree().paused = false
	
	# Remove this screen and its parent CanvasLayer
	var canvas_parent = get_parent()
	if canvas_parent:
		canvas_parent.queue_free()
	
	# Reload the scene
	get_tree().reload_current_scene()
