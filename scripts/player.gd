# player.gd
extends CharacterBody3D

# Movement settings
var speed: float = 5.0
var gravity: float = 9.8

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Calculate movement direction
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# Apply movement
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0
	
	# Move the character
	move_and_slide()
	
# TEMPORARY TEST - Remove when production is built
func _input(_event):
	if Input.is_key_pressed(KEY_C):
		# Complete the FIRST active job
		if JobManager.active_jobs.size() > 0:
			var job_to_complete = JobManager.active_jobs[0]
			print("Completing job #", job_to_complete.job_id)
			JobManager.complete_job_and_pay(job_to_complete)
