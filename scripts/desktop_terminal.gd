extends Control

# @onready node references
@onready var available_jobs_list = $JobListBackground/ScrollContainer/JobListContainer/AvailableJobsList
@onready var active_jobs_list = $JobListBackground/ScrollContainer/JobListContainer/ActiveJobsList
@onready var job_details = $DetailsBackground/JobDetails
@onready var no_jobs_label = $JobListBackground/NoJobsLabel
@onready var customer_label = $DetailsBackground/JobDetails/CustomerLabel
@onready var shirt_color_label = $DetailsBackground/JobDetails/ShirtColorLabel
@onready var num_shirts_label = $DetailsBackground/JobDetails/NumShirtsLabel
@onready var colors_label = $DetailsBackground/JobDetails/ColorsLabel
@onready var location_label = $DetailsBackground/JobDetails/LocationLabel
@onready var due_date_label = $DetailsBackground/JobDetails/DueDateLabel
@onready var payment_label = $DetailsBackground/JobDetails/PaymentLabel
@onready var select_job_button = $DetailsBackground/JobDetails/SelectJobButton
@onready var close_button = $CloseButton

# Public variables
var selected_job: Job = null

# Private variables
var _is_refreshing: bool = false  # Add underscore since it's internal


# Built-in virtual functions
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== Desktop Terminal Starting ===")
	
	job_details.visible = false
	
	select_job_button.pressed.connect(_on_select_job_button_pressed)
	close_button.pressed.connect(close_terminal)
	
	print("Jobs in manager: ", JobManager.all_jobs.size())
	print("Refreshing job list...")
	refresh_job_list()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): 
		close_terminal()


# Public methods
func refresh_job_list():
	if _is_refreshing:  # Update variable name
		return
	_is_refreshing = true
	
	print("refresh_job_list called")
	
	for child in available_jobs_list.get_children():
		child.queue_free()
	for child in active_jobs_list.get_children():
		child.queue_free()
	
	var available_jobs = []
	var active_jobs = []
	
	for job in JobManager.all_jobs:
		if job.is_complete:
			continue
		elif JobManager.is_job_active(job):
			active_jobs.append(job)
		else:
			available_jobs.append(job)
	
	print("Available jobs: ", available_jobs.size())
	print("Active jobs: ", active_jobs.size())
	
	no_jobs_label.visible = (available_jobs.is_empty() and active_jobs.is_empty())
	
	for job in available_jobs:
		var job_button = create_job_button(job)
		available_jobs_list.add_child(job_button)
	
	for job in active_jobs:
		var job_button = create_job_button(job)
		active_jobs_list.add_child(job_button)
	
	_is_refreshing = false


func create_job_button(job: Job) -> Button:
	var job_button = Button.new()
	
	var days_left = job.due_day - TimeManager.current_day
	var due_info = ""
	
	if job.is_overdue:
		due_info = "OVERDUE!"
	elif days_left == 0:
		due_info = "Due TODAY"
	elif days_left == 1:
		due_info = "1 day left"
	else:
		due_info = str(days_left) + " days left"
	
	job_button.text = job.customer_name + "\n$%d  |  %s" % [job.payment_amount, due_info]
	job_button.pressed.connect(_on_job_button_pressed.bind(job))
	
	job_button.custom_minimum_size = Vector2(250, 60)
	job_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	# NEW: Color-code by difficulty
	var button_color = Color("#0f3460")  # Default blue
	if JobManager.is_job_too_complex(job):
		button_color = Color("#5a1010")  # Dark red for too hard
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = button_color  # Use difficulty color
	style_normal.set_corner_radius_all(4)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = button_color.lightened(0.2)  # Slightly lighter on hover
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

func display_job_details(job: Job):
	customer_label.text = "Customer: " + job.customer_name
	shirt_color_label.text = "Shirt Color: " + _color_to_name(job.shirt_color)
	num_shirts_label.text = "Quantity: " + str(job.num_shirts) + " shirts"
	
	var total_screens = 0
	for loc_data in job.print_locations:
		total_screens += loc_data["colors"]
	colors_label.text = "Screens Needed: " + str(total_screens)
	
	var locations_text = "Locations: "
	for i in range(job.print_locations.size()):
		var loc_data = job.print_locations[i]
		var location_name = loc_data["location"].replace("_", " ").capitalize()
		var color_count = loc_data["colors"]
		
		locations_text += location_name + " (" + str(color_count) + " color"
		if color_count > 1:
			locations_text += "s"
		locations_text += ")"
		
		if i < job.print_locations.size() - 1:
			locations_text += ", "
	
	location_label.text = locations_text
	payment_label.text = "Payment: $%.2f" % job.payment_amount
	
	if job.is_overdue:
		due_date_label.text = "Due Date: " + job.due_date + " (OVERDUE!)"
		due_date_label.add_theme_color_override("font_color", Color.RED)
	else:
		due_date_label.text = "Due Date: " + job.due_date
		due_date_label.add_theme_color_override("font_color", Color.WHITE)
	
	for label in [customer_label, shirt_color_label, num_shirts_label, 
				  colors_label, location_label, due_date_label, payment_label]:
		if label != due_date_label:
			label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 16)
	
	if JobManager.is_job_active(job):
		select_job_button.text = "Cancel Job"
	else:
		select_job_button.text = "Start This Job"
	
	job_details.visible = true


func close_terminal():
	get_tree().paused = false
	var canvas_parent = get_parent()
	if canvas_parent:
		canvas_parent.queue_free()


# Private methods
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


# Signal callbacks
func _on_job_button_pressed(job: Job):
	selected_job = job
	display_job_details(job)


func _on_select_job_button_pressed():
	if selected_job:
		if JobManager.is_job_active(selected_job):
			# Cancelling a job - no warning needed
			print("Cancelling job #", selected_job.job_id)
			JobManager.cancel_job(selected_job)
			job_details.visible = false
			selected_job = null
			refresh_job_list()
		else:
			# Starting a job - check complexity
			if JobManager.is_job_too_complex(selected_job):
				_show_complexity_warning(selected_job)
			else:
				_accept_job(selected_job)


# NEW: Show warning dialog
func _show_complexity_warning(job: Job):
	var warning_scene = load("res://scenes/complexity_warning.tscn")  # Adjust path!
	var warning = warning_scene.instantiate()
	
	get_tree().root.add_child(warning)
	
	warning.set_warning_data(job)
	warning.job_accepted.connect(_on_warning_accepted.bind(job))
	warning.job_cancelled.connect(_on_warning_cancelled)
	


# NEW: Accept job (with or without warning)
func _accept_job(job: Job):
	JobManager.select_job(job)
	print("Started working on job #", job.job_id)
	job_details.visible = false
	selected_job = null
	refresh_job_list()


# Signal callbacks for warning dialog
func _on_warning_accepted(job: Job):
	_accept_job(job)


func _on_warning_cancelled():
	# Just close dialog, keep job details visible
	pass
