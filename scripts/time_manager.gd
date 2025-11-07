# time_manager.gd
extends Node

# Day tracking
var current_day: int = 1

# Time tracking (in seconds)
# 8 hour workday = 28800 seconds (9 AM to 5 PM)
var work_day_length: float = 28800.0
var current_time: float = 0.0  # Seconds since start of day

# Time speed (how fast time passes)
# 1.0 = real time, 60.0 = 1 real second = 1 game minute
var time_scale: float = 60.0

# Signals to notify other systems
signal time_updated(current_time: float)
signal day_ended
signal day_started(day_number: int)

# Is time currently flowing?
var time_running: bool = true


func _ready():
	print("TimeManager initialized - Day ", current_day)
	emit_signal("day_started", current_day)


func _process(delta):
	if not time_running:
		return
	
	# Advance time
	current_time += delta * time_scale
	
	# Emit update signal
	emit_signal("time_updated", current_time)
	
	# Check if workday is over
	if current_time >= work_day_length:
		end_day()


func end_day():
	print("Day ", current_day, " ended!")
	time_running = false
	
	emit_signal("day_ended")
	
	# Check if player went bankrupt - if so, don't show summary
	if EconomyManager.current_money <= 0:
		print("Player bankrupt - skipping end of day summary")
		return  # Stop here, game over screen will show
	
	# Show end of day summary
	show_end_of_day_summary()
	

func show_end_of_day_summary():
	# Load the summary scene
	var summary_scene = load("res://scenes/end_of_day_summary.tscn")  # Adjust path if needed
	var summary = summary_scene.instantiate()
	
	# Add to scene FIRST (so _ready() runs and @onready variables load)
	var canvas = CanvasLayer.new()
	get_tree().root.add_child(canvas)
	canvas.add_child(summary)
	
	# NOW set the data (after _ready has run)
	var earned = EconomyManager.daily_earnings
	var costs = EconomyManager.get_daily_costs()
	var total = EconomyManager.current_money
	
	summary.set_summary_data(current_day, earned, costs, total)
	
	# Pause game
	get_tree().paused = true
	
	# Wait for summary to close, then start next day
	await summary.tree_exited
	start_next_day()

func start_next_day():
	current_day += 1
	current_time = 0.0
	EconomyManager.reset_daily_earnings()  # Reset earnings tracker
	time_running = true
	print("Day ", current_day, " started!")
	emit_signal("day_started", current_day)

# Get current time as formatted string (HH:MM AM/PM)
func get_time_string() -> String:
	var total_hours = int(current_time / 3600) + 9  # Start at 9 AM
	var minutes = int((current_time / 60.0)) % 60
	
	# Convert to 12-hour format
	var am_pm = "AM"
	var display_hours = total_hours
	
	if total_hours >= 12:
		am_pm = "PM"
		if total_hours > 12:
			display_hours = total_hours - 12
	
	if display_hours == 0:
		display_hours = 12
	
	return "%d:%02d %s" % [display_hours, minutes, am_pm]

# Get time remaining in workday
func get_time_remaining() -> float:
	return work_day_length - current_time


# Pause/unpause time
func pause_time():
	time_running = false


func resume_time():
	time_running = true

func reset():
	current_day = 1
	current_time = 0.0
	time_running = true
