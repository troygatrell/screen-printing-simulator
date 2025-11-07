extends Control

@onready var jobs_container = $Background/MainContainer/JobsScrollContainer/JobsContainer
@onready var title_label = $Background/MainContainer/TitleLabel
@onready var close_button = $Background/MainContainer/CloseButton


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_on_close_pressed)
	
	# Style title
	title_label.add_theme_color_override("font_color", Color("#00ff41"))
	title_label.add_theme_font_size_override("font_size", 24)
	
	# Load active jobs
	_load_jobs()


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_close_ui()


func _load_jobs():
	# Clear existing
	for child in jobs_container.get_children():
		child.queue_free()
	
	# Get active jobs
	var active_jobs = JobManager.active_jobs
	
	if active_jobs.is_empty():
		var no_jobs = Label.new()
		no_jobs.text = "No active jobs. Select jobs from the computer terminal first."
		jobs_container.add_child(no_jobs)
		return
	
	# Create a panel for each job
	for job in active_jobs:
		var job_panel = _create_job_panel(job)
		jobs_container.add_child(job_panel)


func _create_job_panel(job: Job) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(650, 0)
	
	# Style panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#16213e")
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	# VBoxContainer inside panel
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Job header
	var header = Label.new()
	header.text = "Job: " + job.customer_name + " - $" + str(job.payment_amount)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color("#00ff41"))
	vbox.add_child(header)
	
	# Progress label
	var progress_data = JobManager.get_job_screen_progress(job)
	var progress = Label.new()
	progress.text = "Screens: %d/%d burned" % [progress_data["burned"], progress_data["needed"]]
	vbox.add_child(progress)
	
	# Create burn buttons for each location/color
	for loc_data in job.print_locations:
		var location = loc_data["location"]
		var num_colors = loc_data["colors"]
		
		for color_idx in range(1, num_colors + 1):
			# Check if this screen already exists
			var already_burned = _is_screen_burned(job, location, color_idx)
			
			var burn_button = Button.new()
			burn_button.text = "%s - Color %d" % [location.replace("_", " ").capitalize(), color_idx]
			
			if already_burned:
				burn_button.text += " ✓"
				burn_button.disabled = true
			else:
				burn_button.text = "Burn: " + burn_button.text
				burn_button.pressed.connect(_on_burn_screen.bind(job, location, color_idx))
			
			vbox.add_child(burn_button)
	
	return panel


func _is_screen_burned(job: Job, location: String, color_index: int) -> bool:
	var screens = JobManager.get_screens_for_job(job)
	for screen in screens:
		if screen.location == location and screen.color_index == color_index:
			return true
	return false


func _on_burn_screen(job: Job, location: String, color_index: int):
	print("Burning screen: ", job.customer_name, " - ", location, " - Color ", color_index)
	JobManager.create_screen(job, location, color_index)
	
	# Refresh the UI to show progress
	_load_jobs()


func _on_close_pressed():
	_close_ui()


func _close_ui():
	get_tree().paused = false
	var canvas_parent = get_parent()
	if canvas_parent:
		canvas_parent.queue_free()
