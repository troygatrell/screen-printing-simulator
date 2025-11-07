# player.gd
extends CharacterBody3D

# 2. Signals
# (none needed currently)

# 3. Enums
# (none needed currently)

# 4. Constants
const GRAVITY: float = 9.8
const ROTATION_SPEED: float = 0.15

# 5. Exported variables (@export)
@export var speed: float = 5.0

# 6. Public variables
# (none needed currently)

# 7. Private variables (prefixed with _)
# (none needed currently)

# 8. @onready variables (node references)
@onready var model: Node3D = $Model
@onready var animation_player = $Model/AnimationPlayer

# 9. Built-in virtual functions (in order they're called)
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_movement(delta)
	move_and_slide()

func _input(_event: InputEvent) -> void:
	# TEMPORARY TEST - Remove when production is built
	if Input.is_key_pressed(KEY_C):
		_complete_first_job()

# 10. Public methods (your custom functions)
# (none needed currently)

# 11. Private methods (prefixed with _)
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _handle_movement(_delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Rotate model to face movement direction
		var target_angle = atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, ROTATION_SPEED)
		
		# Play walking animation
		animation_player.play("Walk")
	else:
		velocity.x = 0
		velocity.z = 0

		# Play idle animation
		animation_player.play("Idle")

func _complete_first_job() -> void:
	if JobManager.active_jobs.size() > 0:
		var job_to_complete = JobManager.active_jobs[0]
		print("Completing job #", job_to_complete.job_id)
		JobManager.complete_job_and_pay(job_to_complete)
