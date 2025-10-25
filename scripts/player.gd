# player.gd
# State machine-based player controller for screen printing simulator

extends CharacterBody3D

# ============================================================================
# STATE MACHINE
# ============================================================================

enum State {
	IDLE,                          # Standing still
	WALKING,                       # Moving normally
	PUSHING_CART,                  # Pushing a cart with tank controls
	CARRYING_SCREEN,               # Walking while holding a screen
	TRANSITIONING_TO_PRINT,        # Walking to the press
	IN_PRINT_MODE,                 # At the press, controls locked
	TRANSITIONING_FROM_PRINT,      # Walking away from press
	TRANSITIONING_FROM_RACK        # Walking away from screen rack with screen
}

var current_state = State.IDLE

# ============================================================================
# EXPORT VARIABLES
# ============================================================================

@export var speed: int
@export var gravity = 9.8
@export var camera_smooth_speed = 5
@export var rotation_speed = 10.0

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var camera = get_viewport().get_camera_3d()
@onready var initial_camera_offset = camera.global_position - global_position
@onready var camera_offset = initial_camera_offset
@onready var animation_tree = $Model/AnimationTree
@onready var animation_state = animation_tree.get("parameters/playback")
@onready var grab_zone = $GrabZone
@onready var cart_controller = $CartController
@onready var screen_carrier = $ScreenCarrier
@onready var print_mode_controller = $PrintModeController
@onready var rack_controller = $RackController

# ============================================================================
# LIFECYCLE FUNCTIONS
# ============================================================================

func _ready():
	grab_zone.area_entered.connect(_on_grab_zone_area_entered)
	grab_zone.area_exited.connect(_on_grab_zone_area_exited)
	
	# Connect controller signals
	if cart_controller:
		cart_controller.cart_released.connect(_on_cart_released)

	add_to_group("player")

func _physics_process(delta):
	# Always apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Update based on current state
	match current_state:
		State.IDLE:
			_update_idle(delta)
		State.WALKING:
			_update_walking(delta)
		State.CARRYING_SCREEN:
			_update_carrying_screen(delta)
		State.PUSHING_CART:
			_update_pushing_cart(delta)
		State.TRANSITIONING_TO_PRINT:
			_update_transition_to_print(delta)
		State.IN_PRINT_MODE:
			_update_print_mode(delta)
		State.TRANSITIONING_FROM_PRINT:
			_update_transition_from_print(delta)
		State.TRANSITIONING_FROM_RACK:
			_update_transition_from_rack(delta)
	
	# Always move and update camera
	move_and_slide()
	_update_camera(delta)
	
	# Update carried items
	if cart_controller and cart_controller.is_pushing_cart():
		cart_controller.update_cart_position()
	if screen_carrier and screen_carrier.is_carrying_screen():
		screen_carrier.update_screen_position()

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _unhandled_input(event):
	if not event.is_action_pressed("interact"):
		return
	
	# Handle input based on current state
	match current_state:
		State.IDLE:
			_handle_idle_input()
		State.WALKING:
			_handle_walking_input()
		State.CARRYING_SCREEN:
			_handle_carrying_screen_input()
		State.PUSHING_CART:
			_handle_pushing_cart_input()
		State.IN_PRINT_MODE:
			_handle_print_mode_input()

func _handle_idle_input():
	"""Handle interact button when idle"""
	# Can grab cart handle
	if cart_controller and cart_controller.can_grab_cart():
		if cart_controller.grab_cart():
			change_state(State.PUSHING_CART)
		return
	
	# Can pick up screen from world
	if screen_carrier and screen_carrier.can_pickup_screen():
		if screen_carrier.pickup_screen():
			change_state(State.CARRYING_SCREEN)
		return
	
	# Can retrieve screen from rack
	if rack_controller and rack_controller.can_retrieve_screen():
		if rack_controller.retrieve_screen_from_rack():
			change_state(State.TRANSITIONING_FROM_RACK)
		return
	
	# Can enter print zone (even without screen)
	var zone = print_mode_controller.find_available_print_zone()
	if zone:
		if print_mode_controller.start_transition_to_print(zone):
			change_state(State.TRANSITIONING_TO_PRINT)
		return

func _handle_walking_input():
	"""Handle interact button when walking"""
	_handle_idle_input()

func _handle_carrying_screen_input():
	"""Handle interact button when carrying screen"""
	# Check if in print zone
	var zone = print_mode_controller.find_available_print_zone()
	if zone:
		# Remove collision before transition
		if screen_carrier:
			screen_carrier.disable_extended_collision()
		
		# Start transition to print mode
		if print_mode_controller.start_transition_to_print(zone):
			change_state(State.TRANSITIONING_TO_PRINT)
		return
	
	# Check if at screen rack
	if rack_controller and rack_controller.can_store_screen():
		if rack_controller.store_screen_to_rack():
			change_state(State.IDLE)
		return
	
	print("Can't drop screen here! Must be at press or screen rack")

func _handle_pushing_cart_input():
	"""Handle interact button when pushing cart"""
	if cart_controller:
		cart_controller.release_cart()
	# State change happens in signal handler

func _handle_print_mode_input():
	"""Handle interact button in print mode"""
	var action = print_mode_controller.handle_print_mode_input()
	
	match action:
		print_mode_controller.InputAction.REMOVE_SCREEN:
			# Controller already removed screen, just exit
			change_state(State.TRANSITIONING_FROM_PRINT)
		print_mode_controller.InputAction.EXIT:
			# Regular exit
			print_mode_controller.start_transition_from_print()
			change_state(State.TRANSITIONING_FROM_PRINT)
		print_mode_controller.InputAction.NONE:
			pass  # Do nothing

# ============================================================================
# STATE MACHINE
# ============================================================================

func change_state(new_state: State):
	"""Changes to a new state, handling exit and entry logic"""
	print("State change: ", State.keys()[current_state], " -> ", State.keys()[new_state])
	
	_exit_state(current_state)
	current_state = new_state
	_enter_state(new_state)

func _exit_state(old_state: State):
	"""Cleanup when leaving a state"""
	match old_state:
		State.PUSHING_CART:
			pass  # CartController handles cleanup
		
		State.IN_PRINT_MODE:
			# Disable press controls
			var press = get_tree().get_first_node_in_group("press")
			if press:
				press.disable_controls()

func _enter_state(new_state: State):
	"""Setup when entering a state"""
	match new_state:
		State.IDLE:
			animation_state.travel("Idle")
			velocity = Vector3.ZERO
		
		State.WALKING:
			animation_state.travel("Walk")
		
		State.CARRYING_SCREEN:
			animation_state.travel("Idle_Screen")
		
		State.PUSHING_CART:
			pass  # CartController handles extended collision
		
		State.TRANSITIONING_TO_PRINT:
			if screen_carrier and screen_carrier.is_carrying_screen():
				animation_state.travel("Walk_Screen")
			else:
				animation_state.travel("Walk")
		
		State.IN_PRINT_MODE:
			animation_state.travel("Idle")
			# Controller handles everything else in its _on_entered_print_mode()
			pass
		
		State.TRANSITIONING_FROM_PRINT:
			if screen_carrier and screen_carrier.is_carrying_screen():
				animation_state.travel("Walk_Screen")
			else:
				animation_state.travel("Walk")
				# Controller handles setup in start_transition_from_print()
		
		State.TRANSITIONING_FROM_RACK:
			animation_state.travel("Walk_Screen")
			# Controller handles setup in retrieve_screen_from_rack()

# ============================================================================
# STATE UPDATE FUNCTIONS
# ============================================================================

func _update_idle(_delta):
	"""Player is standing still"""
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir != Vector2.ZERO:
		change_state(State.WALKING)
		return
	
	# Stay idle
	velocity.x = move_toward(velocity.x, 0, speed)
	velocity.z = move_toward(velocity.z, 0, speed)

func _update_walking(delta):
	"""Player is walking normally"""
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir == Vector2.ZERO:
		change_state(State.IDLE)
		return
	
	var direction = (camera.transform.basis.z * input_dir.y + camera.transform.basis.x * input_dir.x).normalized()
	direction.y = 0
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	# Rotate toward movement direction
	var target_basis = Transform3D().looking_at(direction, Vector3.UP).basis
	transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)

func _update_carrying_screen(delta):
	"""Player is walking while carrying a screen"""
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir == Vector2.ZERO:
		animation_state.travel("Idle_Screen")
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		return
	
	animation_state.travel("Walk_Screen")
	
	var direction = (camera.transform.basis.z * input_dir.y + camera.transform.basis.x * input_dir.x).normalized()
	direction.y = 0
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	var target_basis = Transform3D().looking_at(direction, Vector3.UP).basis
	transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)

func _update_pushing_cart(delta):
	"""Player is pushing a cart with tank controls"""
	if not cart_controller:
		return
	
	# Let CartController handle the input and return velocity
	velocity = cart_controller.update_cart_pushing(delta, speed, rotation_speed)
	
	# Update animation based on movement
	if velocity.length() > 0.1:
		animation_state.travel("Push")
	else:
		animation_state.travel("Idle")

func _update_transition_to_print(delta):
	"""Player is walking to the press"""
	if print_mode_controller.update_transition_to_print(delta):
		change_state(State.IN_PRINT_MODE)
	velocity = Vector3.ZERO

func _update_print_mode(_delta):
	"""Player is at the press with locked controls"""
	velocity = print_mode_controller.update_print_mode(_delta)

func _update_transition_from_print(delta):
	"""Player is walking away from press"""
	if print_mode_controller.update_transition_from_print(delta):
		if screen_carrier and screen_carrier.is_carrying_screen():
			change_state(State.CARRYING_SCREEN)
		else:
			change_state(State.IDLE)
	velocity = Vector3.ZERO

func _update_transition_from_rack(delta):
	"""Player is walking away from rack with screen"""
	if rack_controller.update_transition_from_rack(delta):
		change_state(State.CARRYING_SCREEN)
	velocity = Vector3.ZERO

# ============================================================================
# CAMERA UPDATES
# ============================================================================

func _update_camera(delta):
	"""Updates camera position based on state"""
	var camera_target_position
	var camera_speed = camera_smooth_speed
	
	if current_state == State.IN_PRINT_MODE:
		camera_target_position = print_mode_controller.get_camera_target_position()
		camera_speed = 5.0
	else:
		camera_target_position = global_position + camera_offset
	
	camera.global_position = camera.global_position.lerp(camera_target_position, camera_speed * delta)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_grab_zone_area_entered(area):
	"""Detect when objects enter the player's grab zone"""
	if area.is_in_group("carts") and cart_controller:
		cart_controller.handle_in_range_entered(area)
	elif area.is_in_group("screens") and screen_carrier:
		screen_carrier.screen_in_range_entered(area)
	elif area.is_in_group("screen_racks") and rack_controller:
		rack_controller.rack_entered_range(area.get_parent())

func _on_grab_zone_area_exited(area):
	"""Detect when objects leave the player's grab zone"""
	if area.is_in_group("carts") and cart_controller:
		cart_controller.handle_in_range_exited(area)
	elif area.is_in_group("screens") and screen_carrier:
		screen_carrier.screen_in_range_exited(area)
	elif area.is_in_group("screen_racks") and rack_controller:
		rack_controller.rack_exited_range(area.get_parent())

func _on_cart_released():
	"""Called when CartController releases a cart"""
	print("Player: Cart released signal received")
	change_state(State.IDLE)

# ============================================================================
# ANIMATION CONTROL
# ============================================================================

func play_press_animation(anim_name: String):
	"""Play specific animation (called by press controller)"""
	animation_state.travel(anim_name)
