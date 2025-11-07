# job_manager.gd
extends Node

# 2. Signals
# (No signals defined)

# 3. Enums
# (No enums defined)

# 4. Constants
const CUSTOMER_NAMES = [
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

const SHIRT_COLORS = [
	Color.WHITE,
	Color.BLACK,
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW
]

const PRINT_LOCATIONS = [
	"left_chest",
	"right_chest",
	"full_front",
	"full_back"
]

const LOCATION_CONFLICTS = {
	"full_front": ["left_chest", "right_chest"],  # Full front overlaps chest prints
	"full_back": [],  # Full back doesn't conflict with anything (front side)
	"left_chest": ["full_front", "right_chest"],  # Chest prints conflict with full front and each other
	"right_chest": ["full_front", "left_chest"]
}

const BASE_SHIRT_PRICE = 5.0
const EARLY_BONUS_MULTIPLIER = 0.2
const LATE_PENALTY_MULTIPLIER = 0.5
const HARD_JOB_CHANCE = 0.33
const COLOR_COMPLEXITY_MULTIPLIER = 0.3
const FULL_PRINT_MULTIPLIER = 0.5
const SMALL_PRINT_MULTIPLIER = 0.3
const DEFAULT_JOBS_PER_DAY = 3

# 5. Exported variables (@export)
@export var multi_location_chance: float = 0.15

# 6. Public variables
var all_jobs: Array[Job] = []
var active_jobs: Array[Job] = []
var next_job_id: int = 1
var all_screens: Array[Screen] = []
var next_screen_id: int = 1

# 7. Private variables (prefixed with _)
# (No private variables defined)

# 8. @onready variables (node references)
# (No @onready variables defined)

# 9. Built-in virtual functions (in order they're called)
func _ready():
	# Connect to TimeManager's day started signal
	TimeManager.day_started.connect(_on_day_started)
	
	# Generate initial jobs for Day 1
	generate_daily_jobs(DEFAULT_JOBS_PER_DAY)

func _on_day_started(day_number: int):
	print("JobManager: New day started - ", day_number)
	check_overdue_jobs()
	
	# Generate new jobs if it's a new day (not Day 1, which already has jobs)
	if day_number > 1:
		generate_daily_jobs(DEFAULT_JOBS_PER_DAY)

# 10. Public methods (your custom functions)
func add_job(job: Job) -> void:
	print("JobManager.add_job called for: ", job.customer_name)
	job.job_id = next_job_id
	next_job_id += 1
	all_jobs.append(job)
	print("Added job #", job.job_id, " for ", job.customer_name)
	print("Total jobs now: ", all_jobs.size())

func get_job_by_id(id: int) -> Job:
	for job in all_jobs:
		if job.job_id == id:
			return job
	return null

func select_job(job: Job) -> void:
	if not active_jobs.has(job):
		active_jobs.append(job)
		print("Added job #", job.job_id, " to active jobs. Total active: ", active_jobs.size())
	else:
		print("Job #", job.job_id, " is already active")

func is_job_active(job: Job) -> bool:
	return active_jobs.has(job)

func cancel_job(job: Job) -> void:
	if active_jobs.has(job):
		active_jobs.erase(job)
		print("Cancelled job #", job.job_id, ". Active jobs remaining: ", active_jobs.size())

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

func calculate_job_payment(job: Job) -> float:
	var base_payment = job.payment_amount
	
	if TimeManager.current_day < job.due_day:
		var bonus = base_payment * EARLY_BONUS_MULTIPLIER
		print("Early completion bonus: $", bonus)
		return base_payment + bonus
	elif job.is_overdue:
		var penalty = base_payment * LATE_PENALTY_MULTIPLIER
		print("Late completion penalty: -$", penalty)
		return base_payment - penalty
	
	return base_payment

func complete_job_and_pay(job: Job) -> void:
	if not active_jobs.has(job):
		print("Error: Job #", job.job_id, " is not active!")
		return
	
	var payment = calculate_job_payment(job)
	EconomyManager.add_money(payment)
	
	job.is_complete = true
	active_jobs.erase(job)
	
	print("Job #", job.job_id, " completed! Paid $", payment, ". Active jobs: ", active_jobs.size())

func reset():
	all_jobs.clear()
	active_jobs.clear()
	all_screens.clear()  # ADD THIS
	next_job_id = 1
	next_screen_id = 1  # ADD THIS
	generate_daily_jobs(3)
	print("JobManager reset complete - generated Day 1 jobs")

func generate_daily_jobs(num_jobs: int = DEFAULT_JOBS_PER_DAY) -> void:
	print("Generating ", num_jobs, " jobs for Day ", TimeManager.current_day)
	
	var available_customers = CUSTOMER_NAMES.duplicate()
	available_customers.shuffle()
	
	var jobs_to_create = min(num_jobs, available_customers.size())
	
	for i in range(jobs_to_create):
		var job = Job.new()
		job.customer_name = available_customers[i]
		job.shirt_color = SHIRT_COLORS[randi() % SHIRT_COLORS.size()]
		
		# 1 in 3 chance of generating above-capacity job (on last job only)
		var generate_hard_job = (i == jobs_to_create - 1) and (randf() < HARD_JOB_CHANCE)
		
		if generate_hard_job:
			# Ignore employee limits for this job
			job.num_shirts = randi_range(30, 50)
			job.print_locations = _generate_complex_locations()
		else:
			# Normal generation with limits
			var num_employees = EconomyManager.num_employees
			var max_shirts = 20 if num_employees == 0 else (40 if num_employees == 1 else 50)
			job.num_shirts = randi_range(10, max_shirts)
			job.print_locations = generate_print_locations()
		
		# Calculate due date and payment
		var base_due_days = randi_range(1, 3)
		if job.print_locations.size() > 1:
			base_due_days += 1
		
		job.due_day = TimeManager.current_day + base_due_days
		job.due_date = "Day " + str(job.due_day)
		job.payment_amount = calculate_job_value(job)
		
		add_job(job)

func generate_print_locations() -> Array[Dictionary]:
	var locations: Array[Dictionary] = []
	
	# Determine complexity limits based on employees
	var num_employees = EconomyManager.num_employees
	var max_locations = 2 if num_employees == 0 else (3 if num_employees == 1 else 4)
	var max_colors_per_location = 2 if num_employees == 0 else 3
	
	print("Generating job with %d employees - Max locations: %d, Max colors: %d" % [num_employees, max_locations, max_colors_per_location])
	
	# Shuffle available locations
	var shuffled_locations = PRINT_LOCATIONS.duplicate()
	shuffled_locations.shuffle()
	
	# Randomly decide number of locations (1 to max)
	var num_locations = randi_range(1, max_locations)
	
	# Add locations
	for i in range(num_locations):
		if i < shuffled_locations.size():
			var candidate = shuffled_locations[i]
			
			# Check conflicts
			if i == 0 or not _has_conflict(candidate, locations):
				locations.append({
					"location": candidate,
					"colors": randi_range(1, max_colors_per_location)
				})
	
	return locations

func calculate_job_value(job: Job) -> float:
	var shirt_value = job.num_shirts * BASE_SHIRT_PRICE
	
	# Calculate total screens needed
	var total_screens = 0
	for loc_data in job.print_locations:
		total_screens += loc_data["colors"]
	
	# Color complexity (based on total screens)
	var color_multiplier = 1.0 + (total_screens - 1) * COLOR_COMPLEXITY_MULTIPLIER
	
	# Location complexity (based on number and type of locations)
	var location_multiplier = 1.0
	for loc_data in job.print_locations:
		var location = loc_data["location"]
		if location == "full_front" or location == "full_back":
			location_multiplier += FULL_PRINT_MULTIPLIER
		else:
			location_multiplier += SMALL_PRINT_MULTIPLIER
	
	var total = shirt_value * color_multiplier * location_multiplier
	
	return round(total)

func is_job_too_complex(job: Job) -> bool:
	var num_employees = EconomyManager.num_employees
	
	# Count total locations and screens
	var num_locations = job.print_locations.size()
	var total_screens = 0
	for loc_data in job.print_locations:
		total_screens += loc_data["colors"]
	
	# Complexity thresholds
	if num_employees == 0:
		return num_locations > 2 or total_screens > 4 or job.num_shirts > 20
	elif num_employees == 1:
		return num_locations > 3 or total_screens > 6 or job.num_shirts > 40
	else:
		return false  # With 2+ employees, can handle anything

func get_recommended_employees(job: Job) -> int:
	var num_locations = job.print_locations.size()
	var total_screens = 0
	for loc_data in job.print_locations:
		total_screens += loc_data["colors"]
	
	# Recommend based on complexity
	if num_locations <= 2 and total_screens <= 4 and job.num_shirts <= 20:
		return 0  # Can do solo
	elif num_locations <= 3 and total_screens <= 6 and job.num_shirts <= 40:
		return 1  # Need 1 employee
	else:
		return 2  # Need 2+ employees

func create_screen(job: Job, location: String, color_index: int) -> Screen:
	var screen = Screen.new()
	screen.screen_id = next_screen_id
	next_screen_id += 1
	
	screen.job_id = job.job_id
	screen.customer_name = job.customer_name
	screen.location = location
	screen.color_index = color_index
	
	# Generate color name (we'll make this fancier later)
	screen.color_name = "Color " + str(color_index)
	
	all_screens.append(screen)
	print("Created screen #", screen.screen_id, " for ", job.customer_name, " - ", location, " - ", screen.color_name)
	
	return screen


# NEW: Get all screens for a specific job
func get_screens_for_job(job: Job) -> Array[Screen]:
	var job_screens: Array[Screen] = []
	for screen in all_screens:
		if screen.job_id == job.job_id:
			job_screens.append(screen)
	return job_screens


# NEW: Check how many screens a job needs vs has
func get_job_screen_progress(job: Job) -> Dictionary:
	var needed = 0
	var burned = 0
	
	# Count needed screens
	for loc_data in job.print_locations:
		needed += loc_data["colors"]
	
	# Count burned screens
	burned = get_screens_for_job(job).size()
	
	return {
		"needed": needed,
		"burned": burned
	}


# 11. Private methods (prefixed with _)
func _generate_complex_locations() -> Array[Dictionary]:
	var locations: Array[Dictionary] = []
	var shuffled_locations = PRINT_LOCATIONS.duplicate()
	shuffled_locations.shuffle()
	
	var num_locations = randi_range(3, 4)  # Always 3-4 locations
	
	for i in range(num_locations):
		if i < shuffled_locations.size():
			var candidate = shuffled_locations[i]
			if i == 0 or not _has_conflict(candidate, locations):
				locations.append({
					"location": candidate,
					"colors": randi_range(2, 3)  # Always 2-3 colors
				})
	
	return locations

func _has_conflict(new_location: String, existing_locations: Array[Dictionary]) -> bool:
	var conflicts = LOCATION_CONFLICTS[new_location]
	
	for loc_data in existing_locations:
		var existing_loc = loc_data["location"]
		if existing_loc in conflicts:
			return true  # Conflict found!
	
	return false  # No conflicts
