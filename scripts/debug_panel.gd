# debug_panel.gd
extends CanvasLayer

@onready var time_speed_label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/TimeSpeedLabel
@onready var slow_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/SlowButton
@onready var fast_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/FastButton
@onready var add_money_button = $Panel/MarginContainer/VBoxContainer/AddMoneyButton
@onready var complete_job_button = $Panel/MarginContainer/VBoxContainer/CompleteJobButton
@onready var skip_day_button = $Panel/MarginContainer/VBoxContainer/SkipDayButton
@onready var hire_employee_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer2/HireButton
@onready var fire_employee_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer2/FireButton

func _ready():
	# connect buttons
	slow_button.pressed.connect(_on_slow_pressed)
	fast_button.pressed.connect(_on_fast_pressed)
	add_money_button.pressed.connect(_on_add_money_pressed)
	complete_job_button.pressed.connect(_on_complete_job_pressed)
	skip_day_button.pressed.connect(_on_skip_day_pressed)
	hire_employee_button.pressed.connect(_on_hire_employee_pressed)
	fire_employee_button.pressed.connect(_on_fire_employee_pressed)
	
	# start hidden
	visible = false
	update_speed_display()
	
func _process(_delta: float) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(_event):
	# Toggle with F3 key
	if Input.is_key_pressed(KEY_0):  # or create custom "debug_toggle" action
		visible = !visible

func update_speed_display():
	time_speed_label.text = "%.1fx" % TimeManager.time_scale

func _on_slow_pressed():
	TimeManager.time_scale = max(1.0, TimeManager.time_scale - 10.0)
	update_speed_display()

func _on_fast_pressed():
	TimeManager.time_scale = min(300.0, TimeManager.time_scale + 10.0)
	update_speed_display()

func _on_add_money_pressed():
	EconomyManager.add_money(100)

func _on_complete_job_pressed():
	if JobManager.active_jobs.size() > 0:
		var job = JobManager.active_jobs[0]
		JobManager.complete_job_and_pay(job)

func _on_skip_day_pressed():
	# Fast forward to end of day
	TimeManager.current_time = TimeManager.work_day_length - 1

func _on_hire_employee_pressed():
	EconomyManager.hire_employee()
	
func _on_fire_employee_pressed():
	EconomyManager.fire_employee()
