# desktop_terminal.gd
extends Control

# References to UI elements
@onready var available_jobs_list = $ScrollContainer/JobListContainer/AvailableJobsList
@onready var active_jobs_list = $ScrollContainer/JobListContainer/ActiveJobsList
@onready var job_details = $JobDetails
@onready var no_jobs_label = $NoJobsLabel

@onready var customer_label = $JobDetails/CustomerLabel
@onready var shirt_color_label = $JobDetails/ShirtColorLabel
@onready var num_shirts_label = $JobDetails/NumShirtsLabel
@onready var colors_label = $JobDetails/ColorsLabel
@onready var location_label = $JobDetails/LocationLabel
@onready var due_date_label = $JobDetails/DueDateLabel
@onready var select_job_button = $JobDetails/SelectJobButton
@onready var payment_label = $JobDetails/PaymentLabel

# Currently selected job
var selected_job: Job = null
var is_refreshing: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== Desktop Terminal Starting ===")
	
	# Hide details panel initially
	job_details.visible = false
	
	# Connect the button
	select_job_button.pressed.connect(_on_select_job_button_pressed)
	
	# Check what's in the manager
	print("Jobs in manager: ", JobManager.all_jobs.size())
	
	# Load and display jobs
	print("Refreshing job list...")
	refresh_job_list()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): 
		close_terminal()

# Create buttons for all pending jobs

func refresh_job_list():
	if is_refreshing:
		return
	is_refreshing = true
	
	print("refresh_job_list called")
	
	# Clear both lists
	for child in available_jobs_list.get_children():
		child.queue_free()
	for child in active_jobs_list.get_children():
		child.queue_free()
	
	# Get all jobs
	var available_jobs = []
	var active_jobs = []
	
	for job in JobManager.all_jobs:
		if job.is_complete:
			continue
		elif JobManager.is_job_active(job):  # CHANGED: Check if in active_jobs array
			active_jobs.append(job)
		else:
			available_jobs.append(job)
	
	print("Available jobs: ", available_jobs.size())
	print("Active jobs: ", active_jobs.size())
	
	# Show/hide "no jobs" message
	no_jobs_label.visible = (available_jobs.is_empty() and active_jobs.is_empty())
	
	# Create buttons for available jobs
	for job in available_jobs:
		var job_button = create_job_button(job)
		available_jobs_list.add_child(job_button)
	
	# Create buttons for active jobs
	for job in active_jobs:
		var job_button = create_job_button(job)
		active_jobs_list.add_child(job_button)
	
	is_refreshing = false
	
func _on_job_button_pressed(job: Job):
	selected_job = job
	display_job_details(job)

# Show the job details on the right side

func display_job_details(job: Job):
	customer_label.text = "Customer: " + job.customer_name
	shirt_color_label.text = "Shirt Color: " + _color_to_name(job.shirt_color)
	num_shirts_label.text = "Quantity: " + str(job.num_shirts) + " shirts"
	colors_label.text = "Print Colors: " + str(job.num_colors)
	location_label.text = "Print Location: " + job.print_location
	payment_label.text = "Payment: $" + str(job.payment_amount)
	
	if job.is_overdue:
		due_date_label.text = "Due Date: " + job.due_date + " (OVERDUE!)"
		due_date_label.add_theme_color_override("font_color", Color.RED)
	else:
		due_date_label.text = "Due Date: " + job.due_date
		due_date_label.add_theme_color_override("font_color", Color.WHITE)
	
	# STYLE THE LABELS
	for label in [customer_label, shirt_color_label, num_shirts_label, 
				  colors_label, location_label, due_date_label, payment_label]:
		if label != due_date_label:
			label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 16)
	
	# CHANGED: Update button based on whether job is active
	if JobManager.is_job_active(job):
		select_job_button.text = "Cancel Job"
	else:
		select_job_button.text = "Start This Job"
	
	job_details.visible = true

# When "Start This Job" is clicked
func _on_select_job_button_pressed():
	if selected_job:
		# CHANGED: Toggle active status instead of replacing
		if JobManager.is_job_active(selected_job):
			print("Cancelling job #", selected_job.job_id)
			JobManager.cancel_job(selected_job)
		else:
			JobManager.select_job(selected_job)
			print("Started working on job #", selected_job.job_id)
		
		# Refresh the list and hide details
		job_details.visible = false
		selected_job = null
		refresh_job_list()

# Helper function to convert Color to readable name
func _color_to_name(color: Color) -> String:
	if color.is_equal_approx(Color.WHITE):
		return "White"
	elif color.is_equal_approx(Color.BLACK):
		return "Black"
	elif color.is_equal_approx(Color.RED):
		return "Red"
	elif color.is_equal_approx(Color.BLUE):
		return "Blue"
	else:
		return "Custom"

func close_terminal():
	get_tree().paused = false
	var canvas_parent = get_parent()
	if canvas_parent:
		canvas_parent.queue_free()

func create_job_button(job: Job) -> Button:
	var job_button = Button.new()
	job_button.text = "Job #%d: %s" % [job.job_id, job.customer_name]
	job_button.pressed.connect(_on_job_button_pressed.bind(job))
	
	# style the button
	job_button.custom_minimum_size = Vector2(260, 40)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#0f3460")
	style_normal.set_corner_radius_all(4)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color("#16557a")
	style_hover.set_corner_radius_all(4)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color("#00ff41")
	style_pressed.set_corner_radius_all(4)
	
	job_button.add_theme_stylebox_override("normal", style_normal)
	job_button.add_theme_stylebox_override("hover", style_hover)
	job_button.add_theme_stylebox_override("pressed", style_pressed)
	
	job_button.add_theme_color_override("font_color", Color.WHITE)
	job_button.add_theme_color_override("font_hover_color", Color("#00ff41"))
	job_button.add_theme_color_override("font_pressed_color", Color.BLACK)
	
	return job_button
