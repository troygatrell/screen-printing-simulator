# job_manager.gd
extends Node

# Storage for all jobs
var all_jobs: Array[Job] = []

# Track MULTIPLE active jobs
var active_jobs: Array[Job] = []  # Changed from: var current_job: Job = null

# Counter for assigning unique IDs
var next_job_id: int = 1


# Add a new job to the system
func add_job(job: Job) -> void:
	print("JobManager.add_job called for: ", job.customer_name)
	job.job_id = next_job_id
	next_job_id += 1
	all_jobs.append(job)
	print("Added job #", job.job_id, " for ", job.customer_name)
	print("Total jobs now: ", all_jobs.size())


# Get a specific job by its ID
func get_job_by_id(id: int) -> Job:
	for job in all_jobs:
		if job.job_id == id:
			return job
	return null


# UPDATED: Add job to active jobs (instead of replacing)
func select_job(job: Job) -> void:
	if not active_jobs.has(job):
		active_jobs.append(job)
		print("Added job #", job.job_id, " to active jobs. Total active: ", active_jobs.size())
	else:
		print("Job #", job.job_id, " is already active")
		
# UPDATED: Check if a job is currently active
func is_job_active(job: Job) -> bool:
	return active_jobs.has(job)
	
# UPDATED: Remove a job from active jobs
func cancel_job(job: Job) -> void:
	if active_jobs.has(job):
		active_jobs.erase(job)
		print("Cancelled job #", job.job_id, ". Active jobs remaining: ", active_jobs.size())

# Get all incomplete jobs
func get_pending_jobs() -> Array[Job]:
	var pending: Array[Job] = []
	for job in all_jobs:
		if not job.is_complete:
			pending.append(job)
	return pending

func check_overdue_jobs() -> void:
	for job in all_jobs:
		if not job.is_complete and TimeManager.current_day > job.due_day:
			job.is_overdue = true
			print("Job #", job.job_id, " is now OVERDUE!")

# Call this every day
func _ready():
	# Connect to TimeManager's day started signal
	TimeManager.day_started.connect(_on_day_started)
	
	# Generate initial jobs for Day 1
	generate_daily_jobs(3)

func _on_day_started(day_number: int):
	print("JobManager: New day started - ", day_number)
	check_overdue_jobs()
	
	# Generate new jobs if it's a new day (not Day 1, which already has jobs)
	if day_number > 1:
		generate_daily_jobs(3)  # 3 jobs per day

# UPDATED: Calculate payment with job parameter
func calculate_job_payment(job: Job) -> float:
	var base_payment = job.payment_amount
	
	if TimeManager.current_day < job.due_day:
		var bonus = base_payment * 0.2
		print("Early completion bonus: $", bonus)
		return base_payment + bonus
	elif job.is_overdue:
		var penalty = base_payment * 0.5
		print("Late completion penalty: -$", penalty)
		return base_payment - penalty
	
	return base_payment

# UPDATED: Complete specific job and pay player
func complete_job_and_pay(job: Job) -> void:
	if not active_jobs.has(job):
		print("Error: Job #", job.job_id, " is not active!")
		return
	
	var payment = calculate_job_payment(job)
	EconomyManager.add_money(payment)
	
	job.is_complete = true
	active_jobs.erase(job)
	
	print("Job #", job.job_id, " completed! Paid $", payment, ". Active jobs: ", active_jobs.size())

# UPDATED: Reset function for game over
func reset():
	all_jobs.clear()
	active_jobs.clear()  # Changed from: current_job = null
	next_job_id = 1

# Random customer names pool
var customer_names = [
	"Alice's Cafe",
	"Bob's Gym", 
	"Charlie's Band",
	"Dave's Diner",
	"Emma's Boutique",
	"Frank's Hardware",
	"Grace's Bakery",
	"Henry's Sports",
	"Iris's Salon",
	"Jack's Auto Shop"
]

# Available shirt colors
var shirt_colors = [
	Color.WHITE,
	Color.BLACK,
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW
]

# Print locations
var print_locations = [
	"full_front",
	"left_chest",
	"back",
	"full_back"
]

# Generate random jobs for the day
func generate_daily_jobs(num_jobs: int = 3) -> void:
	print("Generating ", num_jobs, " jobs for Day ", TimeManager.current_day)
	
	# Shuffle customer names to ensure unique customers
	var available_customers = customer_names.duplicate()
	available_customers.shuffle()
	
	# Limit jobs to available customers
	var jobs_to_create = min(num_jobs, available_customers.size())
	
	for i in range(jobs_to_create):
		var job = Job.new()
		
		# Take next customer from shuffled list (ensures uniqueness)
		job.customer_name = available_customers[i]
		
		# Random shirt specs
		job.shirt_color = shirt_colors[randi() % shirt_colors.size()]
		job.num_shirts = randi_range(10, 50)
		job.num_colors = randi_range(1, 3)
		job.print_location = print_locations[randi() % print_locations.size()]
		
		# Random due date (1-3 days from now)
		job.due_day = TimeManager.current_day + randi_range(1, 3)
		job.due_date = "Day " + str(job.due_day)
		
		# Calculate payment
		job.payment_amount = calculate_job_value(job)
		
		add_job(job)

# Calculate how much a job is worth based on complexity
func calculate_job_value(job: Job) -> float:
	var base_price = 5.0  # $5 per shirt base
	var shirt_value = job.num_shirts * base_price
	
	# Multiply by number of colors (more colors = more complex)
	var color_multiplier = 1.0 + (job.num_colors - 1) * 0.3  # +30% per extra color
	
	# Location complexity
	var location_multiplier = 1.0
	if job.print_location == "full_front" or job.print_location == "full_back":
		location_multiplier = 1.5  # 50% more for full prints
	
	var total = shirt_value * color_multiplier * location_multiplier
	
	return round(total)
