# performance_monitor.gd
# Attach this to a Control node in your UI or create as an autoload
extends Control

# Display settings
@export var update_interval = 0.5  # Update display every 0.5 seconds
@export var show_detailed = false  # Show more detailed stats

# UI elements
var label: Label
var time_since_update = 0.0

# Tracked metrics
var frame_times = []
var max_samples = 60

func _ready():
	# Create label for display
	label = Label.new()
	label.position = Vector2(10, 10)
	add_child(label)
	
	# Style the label
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_font_size_override("font_size", 16)

func _process(delta):
	time_since_update += delta
	
	# Track frame time
	frame_times.append(delta)
	if frame_times.size() > max_samples:
		frame_times.pop_front()
	
	# Update display at interval
	if time_since_update >= update_interval:
		time_since_update = 0.0
		_update_display()

func _update_display():
	var text = ""
	
	# FPS
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	text += "FPS: " + str(int(fps)) + "\n"
	
	# Frame time (ms)
	var avg_frame_time = _get_average_frame_time() * 1000.0
	text += "Frame: " + str(avg_frame_time).pad_decimals(2) + " ms\n"
	
	# Memory
	var memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	text += "Memory: " + str(int(memory_mb)) + " MB\n"
	
	if show_detailed:
		# Physics time
		var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		text += "Physics: " + str(physics_time).pad_decimals(2) + " ms\n"
		
		# Process time
		var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		text += "Process: " + str(process_time).pad_decimals(2) + " ms\n"
		
		# Objects
		var objects = Performance.get_monitor(Performance.OBJECT_COUNT)
		text += "Objects: " + str(objects) + "\n"
		
		# Nodes
		var nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		text += "Nodes: " + str(nodes) + "\n"
		
		# Draw calls
		var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		text += "Draw Calls: " + str(draw_calls) + "\n"
	
	label.text = text

func _get_average_frame_time() -> float:
	if frame_times.is_empty():
		return 0.0
	
	var sum = 0.0
	for time in frame_times:
		sum += time
	
	return sum / frame_times.size()

func toggle_detailed():
	show_detailed = !show_detailed

# Call this from anywhere to show/hide monitor
func toggle_visibility():
	visible = !visible
