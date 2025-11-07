extends CanvasLayer

signal job_accepted
signal job_cancelled

@onready var warning_text = $ColorRect/Panel/VBoxContainer/WarningText
@onready var cancel_button = $ColorRect/Panel/VBoxContainer/HBoxContainer/CancelButton
@onready var accept_button = $ColorRect/Panel/VBoxContainer/HBoxContainer/AcceptButton


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	cancel_button.pressed.connect(_on_cancel)
	accept_button.pressed.connect(_on_accept)


func set_warning_data(job: Job):
	# Count complexity
	var num_locations = job.print_locations.size()
	var total_screens = 0
	for loc_data in job.print_locations:
		total_screens += loc_data["colors"]
	
	var recommended = JobManager.get_recommended_employees(job)
	
	var warning = "This job requires:\n"
	warning += "• %d print locations\n" % num_locations
	warning += "• %d total screens\n" % total_screens
	warning += "• %d shirts\n\n" % job.num_shirts
	warning += "Recommended: %d employee" % recommended
	if recommended != 1:
		warning += "s"
	warning += "\nYour staff: %d employee" % EconomyManager.num_employees
	if EconomyManager.num_employees != 1:
		warning += "s"
	warning += "\n\nThis will be extremely difficult to complete on time!"
	
	warning_text.text = warning


func _on_cancel():
	emit_signal("job_cancelled")
	queue_free()


func _on_accept():
	emit_signal("job_accepted")
	queue_free()
