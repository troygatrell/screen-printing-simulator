# print_mode_controller.gd (UPDATED - Now handles shirts and rotation)
# Handles all print zone interactions, screen/shirt loading, and in-mode rotation.
#
# RESPONSIBILITIES:
# - Transition animations to/from print mode
# - Player position/rotation snapping to print zone
# - Screen loading/unloading to press heads
# - Shirt loading/unloading from cart and mounting on platens
# - Player rotation in print mode (press vs cart facing)
# - Camera zoom control during print mode
# - Press control enabling/disabling
#
# SIGNALS:
# - entered_print_mode: Emitted when player enters print mode
# - exited_print_mode: Emitted when player exits print mode
# - screen_loaded_to_press: Emitted when screen is loaded to press
# - screen_removed_from_press: Emitted when screen is removed from press
# - shirt_picked_up_in_print_mode: Emitted when shirt grabbed from cart
# - shirt_mounted_on_platen: Emitted when shirt mounted
#
# DEPENDENCIES:
# - Must be child of player CharacterBody3D
# - Requires ScreenCarrier sibling node
# - Requires print zones in "print_zones" group
# - Requires press in "press" group
# - Requires Camera3D in viewport

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal entered_print_mode
signal exited_print_mode
signal screen_loaded_to_press
signal screen_removed_from_press
signal shirt_picked_up_in_print_mode
signal shirt_mounted_on_platen

# ============================================================================
# EXPORTS
# ============================================================================

@export var transition_speed = 3.0
@export var distance_threshold = 0.15
@export var rotation_speed = 5.0  # Speed of rotation in print mode

# Shirt mounting adjustments
@export var platen_radius = 0.8
@export var shirt_height = 0.1
@export var shirt_rotation_x = -90.0  # Tilt (lay flat)
@export var shirt_rotation_y_offset = 0.0  # Extra Y rotation
@export var shirt_rotation_z = 0.0  # Roll

# Held shirt in print mode
@export var held_shirt_position = Vector3(0, 1.2, -0.3)
@export var held_shirt_rotation_x = 0.0
@export var held_shirt_rotation_y = 0.0
@export var held_shirt_rotation_z = 0.0
# ============================================================================
# VARIABLES
# ============================================================================

# Print mode state
var current_print_zone = null
var print_target_position = Vector3.ZERO
var print_target_rotation = Vector3.ZERO
var exit_target_position = Vector3.ZERO
var exit_target_rotation = Vector3.ZERO
var print_mode_camera_target = Vector3.ZERO

# Rotation state in print mode
enum FacingDirection {
	PRESS,  # Facing the press (default)
	CART    # Rotated 90° right to face cart
}
var facing_direction = FacingDirection.PRESS
var base_rotation_y = 0.0  # Store the base rotation when entering print mode
var is_rotating = false
var rotation_target = 0.0

# Shirt handling in print mode
var held_shirt_in_print_mode: RigidBody3D = null

# References (cached)
var player: CharacterBody3D
var screen_carrier
var camera: Camera3D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Get reference to parent player
	player = get_parent()
	if not player:
		push_error("PrintModeController must be a child of the player!")
		return
	
	# Get screen carrier sibling
	screen_carrier = player.get_node_or_null("ScreenCarrier")
	if not screen_carrier:
		push_warning("PrintModeController: No ScreenCarrier found!")
	
	# Get camera
	camera = player.get_viewport().get_camera_3d()

# ============================================================================
# PUBLIC FUNCTIONS - ZONE DETECTION
# ============================================================================

func find_available_print_zone():
	"""Find a print zone the player is currently in"""
	var print_zones = player.get_tree().get_nodes_in_group("print_zones")
	for zone in print_zones:
		if zone.is_player_in_zone():
			return zone
	return null

func is_in_print_mode() -> bool:
	"""Check if currently in print mode"""
	return current_print_zone != null

func get_current_zone():
	"""Get the current print zone"""
	return current_print_zone

# ============================================================================
# PUBLIC FUNCTIONS - TRANSITIONS
# ============================================================================

func start_transition_to_print(print_zone):
	"""Begin transition to print mode"""
	if not print_zone:
		push_error("PrintModeController: No print zone provided!")
		return false
	
	current_print_zone = print_zone
	print_target_position = print_zone.global_position + print_zone.snap_offset
	print_target_rotation = print_zone.snap_rotation
	
	print("PrintModeController: Starting transition to print")
	return true

func update_transition_to_print(delta) -> bool:
	"""
	Update transition to print mode.
	Returns true when transition is complete.
	"""
	if not current_print_zone:
		return true  # Transition complete (error case)
	
	# Lerp position and rotation
	player.global_position = player.global_position.lerp(print_target_position, transition_speed * delta)
	player.global_rotation = player.global_rotation.lerp(print_target_rotation, transition_speed * delta)
	
	# Check if complete
	if player.global_position.distance_to(print_target_position) < distance_threshold:
		player.global_position = print_target_position
		player.global_rotation = print_target_rotation
		_on_entered_print_mode()
		return true
	
	return false

func start_transition_from_print():
	"""Begin transition away from print mode"""
	if not current_print_zone:
		push_error("PrintModeController: No print zone to exit!")
		return false
	
	exit_target_rotation = player.global_rotation + Vector3(0, PI, 0)
	exit_target_position = player.global_position + player.global_transform.basis.z * 0.5
	
	print("PrintModeController: Starting transition from print")
	return true

func update_transition_from_print(delta) -> bool:
	"""
	Update transition from print mode.
	Returns true when transition is complete.
	"""
	# Lerp position and rotation
	player.global_position = player.global_position.lerp(exit_target_position, transition_speed * delta)
	player.global_rotation = player.global_rotation.lerp(exit_target_rotation, transition_speed * delta)
	
	# Check if complete
	if player.global_position.distance_to(exit_target_position) < distance_threshold:
		player.global_position = exit_target_position
		_on_exited_print_mode()
		return true
	
	return false

# ============================================================================
# PUBLIC FUNCTIONS - PRINT MODE UPDATE
# ============================================================================

func update_print_mode(delta) -> Vector3:
	"""
	Update while in print mode.
	Handles rotation if active.
	Returns velocity (always zero - player is locked).
	"""
	# Update rotation if rotating
	if is_rotating:
		_update_rotation(delta)
	
	return Vector3.ZERO

func get_camera_target_position() -> Vector3:
	"""Get the camera target position for print mode"""
	return print_mode_camera_target

# ============================================================================
# PUBLIC FUNCTIONS - ROTATION IN PRINT MODE
# ============================================================================

func can_rotate_to_cart() -> bool:
	"""Check if player can rotate to face cart"""
	return facing_direction == FacingDirection.PRESS and not is_rotating

func can_rotate_to_press() -> bool:
	"""Check if player can rotate to face press"""
	return facing_direction == FacingDirection.CART and not is_rotating

func rotate_to_cart():
	"""Rotate player 90° right to face cart"""
	if not can_rotate_to_cart():
		return false
	
	facing_direction = FacingDirection.CART
	rotation_target = base_rotation_y - deg_to_rad(90)  # 90° right
	is_rotating = true
	
	print("PrintModeController: Rotating to cart")
	return true

func rotate_to_press():
	"""Rotate player back to face press"""
	if not can_rotate_to_press():
		return false
	
	facing_direction = FacingDirection.PRESS
	rotation_target = base_rotation_y  # Back to original
	is_rotating = true
	
	print("PrintModeController: Rotating to press")
	return true

func _update_rotation(delta):
	"""Update rotation animation"""
	var current_y = player.global_rotation.y
	var diff = rotation_target - current_y
	
	# Normalize angle difference
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	
	# Lerp rotation
	var new_y = current_y + diff * rotation_speed * delta
	player.global_rotation.y = new_y
	
	# Check if complete
	if abs(diff) < 0.01:
		player.global_rotation.y = rotation_target
		is_rotating = false
		print("PrintModeController: Rotation complete - facing ", FacingDirection.keys()[facing_direction])

# ============================================================================
# PUBLIC FUNCTIONS - INPUT HANDLING
# ============================================================================

enum InputAction {
	NONE,
	EXIT,
	REMOVE_SCREEN,
	ROTATE_TO_CART,
	ROTATE_TO_PRESS,
	PICKUP_SHIRT,
	MOUNT_SHIRT
}

func handle_print_mode_input() -> InputAction:
	"""
	Handle input while in print mode.
	Returns what action should be taken.
	"""
	# Check for Space to rotate
	if Input.is_action_just_pressed("ui_select"):  # Space key
		if can_rotate_to_cart():
			rotate_to_cart()
			return InputAction.ROTATE_TO_CART
		elif can_rotate_to_press():
			rotate_to_press()
			return InputAction.ROTATE_TO_PRESS
		return InputAction.NONE
	
	# Check for E to interact
	if Input.is_action_just_pressed("interact"):
		# If holding a shirt, try to mount it
		if held_shirt_in_print_mode:
			if mount_shirt_on_platen():
				return InputAction.MOUNT_SHIRT
			return InputAction.NONE
		
		# If facing cart, try to pickup shirt
		if facing_direction == FacingDirection.CART:
			if pickup_shirt_from_cart():
				return InputAction.PICKUP_SHIRT
			return InputAction.NONE
		
		# If facing press with screen, check for screen removal
		if Input.is_action_pressed("shift-modifier"):
			if _can_remove_screen():
				if remove_screen_from_press():
					return InputAction.REMOVE_SCREEN
			else:
				print("No screen to remove from press")
			return InputAction.NONE
		
		# Regular E to exit
		return InputAction.EXIT
	
	return InputAction.NONE

# ============================================================================
# PUBLIC FUNCTIONS - SCREEN MANAGEMENT
# ============================================================================

func load_screen_to_press() -> bool:
	"""Load carried screen into the press"""
	if not screen_carrier or not screen_carrier.is_carrying_screen():
		print("PrintModeController: No screen being carried!")
		return false
	
	# Get the press
	var press = player.get_tree().get_first_node_in_group("press")
	if not press:
		print("PrintModeController: Press not found!")
		return false
	
	# Find nearest empty slot
	var slot_index = press.get_nearest_empty_slot()
	if slot_index == -1:
		print("PrintModeController: All head slots are full!")
		return false
	
	# Restore collision before loading
	screen_carrier.restore_screen_collision()
	
	# Get screen from carrier
	var screen = screen_carrier.give_screen_to(press)
	if not screen:
		print("PrintModeController: Failed to get screen from carrier!")
		return false
	
	# Load the screen
	if press.load_screen_to_slot(screen, slot_index):
		print("PrintModeController: Successfully loaded screen to head")
		screen_loaded_to_press.emit()
		return true
	else:
		print("PrintModeController: Failed to load screen to head")
		# If loading failed, give screen back to carrier
		screen_carrier.receive_screen_from(press, screen)
		return false

func remove_screen_from_press() -> bool:
	"""Remove a screen from the press and carry it"""
	if not screen_carrier:
		print("PrintModeController: No screen carrier available!")
		return false
	
	# Get the press
	var press = player.get_tree().get_first_node_in_group("press")
	if not press:
		print("PrintModeController: Press not found!")
		return false
	
	# Remove the front screen
	var screen = press.remove_front_screen()
	if not screen:
		print("PrintModeController: No screen to remove")
		return false
	
	# Give to screen carrier
	if screen_carrier.receive_screen_from(press, screen):
		print("PrintModeController: Screen removed and added to player")
		screen_removed_from_press.emit()
		return true
	else:
		print("PrintModeController: Failed to receive screen from press")
		# Put screen back
		press.load_screen_to_slot(screen, press.heads_current_position)
		return false

# ============================================================================
# PUBLIC FUNCTIONS - SHIRT MANAGEMENT
# ============================================================================

func pickup_shirt_from_cart() -> bool:
	"""Pickup a shirt from cart while in print mode"""
	if held_shirt_in_print_mode:
		print("PrintModeController: Already holding a shirt!")
		return false
	
	# Find cart at loading zone
	var cart = _find_cart_at_zone()
	if not cart:
		print("PrintModeController: No cart found!")
		return false
	
	# Unload shirt from cart to player's hands
	var shirt = cart.unload_shirt_to_position(player.global_position + Vector3(0, 1.0, 0))
	if not shirt:
		print("PrintModeController: Failed to unload shirt from cart (cart may be empty)")
		return false
	
	# Hold the shirt
	held_shirt_in_print_mode = shirt
	shirt.freeze = true
	
	# Parent to player (visible, held in hands)
	shirt.get_parent().remove_child(shirt)
	player.add_child(shirt)
	shirt.position = held_shirt_position  # ← Use export
	shirt.rotation = Vector3(
		deg_to_rad(held_shirt_rotation_x),
		deg_to_rad(held_shirt_rotation_y),
		deg_to_rad(held_shirt_rotation_z)
	)  # ← Use exports
	
	print("PrintModeController: Picked up shirt from cart")
	shirt_picked_up_in_print_mode.emit()
	return true

func mount_shirt_on_platen() -> bool:
	"""Mount held shirt onto the current platen"""
	if not held_shirt_in_print_mode:
		print("PrintModeController: No shirt to mount!")
		return false
	
	# Get the press
	var press = player.get_tree().get_first_node_in_group("press")
	if not press:
		print("PrintModeController: Press not found!")
		return false
	
	# Check if current platen is empty
	var platen_index = press.arms_current_position
	if not press.is_platen_empty(platen_index):
		print("PrintModeController: Platen ", platen_index, " already has a shirt!")
		return false
	
	# Get the Arms carousel (where platens are)
	var arms = press.get_node("Arms")
	if not arms:
		print("PrintModeController: Arms carousel not found!")
		return false
	
	# Detach from player
	var shirt = held_shirt_in_print_mode
	player.remove_child(shirt)
	
	# Attach to Arms carousel (so it rotates with the platens)
	arms.add_child(shirt)
	
	# Position shirt flat on the platen
	# Since it's a child of Arms, position is relative to Arms center
	var angle = deg_to_rad(platen_index * 90 + 90)
	
	var offset_x = platen_radius * cos(angle)
	var offset_z = platen_radius * sin(angle)
	
	print("DEBUG: Platen ", platen_index, " - Angle: ", rad_to_deg(angle), "° - Position: (", offset_x, ", ", offset_z, ")")
	
	shirt.position = Vector3(offset_x, shirt_height, offset_z)  # Low Y = flat on platen

	# Calculate Y rotation - add 180° for positions 1 and 3
	var y_rotation = angle + deg_to_rad(shirt_rotation_y_offset)
	if platen_index == 1 or platen_index == 3:
		y_rotation += deg_to_rad(180)  # Fix backward positions

	shirt.rotation = Vector3(
		deg_to_rad(shirt_rotation_x), 
		y_rotation,  # ← Use calculated value
		deg_to_rad(shirt_rotation_z)
	)
	
	shirt.freeze = true
	
	# Tell press this platen now has a shirt
	if press.mount_shirt_on_current_platen(shirt):
		# Update shirt's internal state
		var global_pos = shirt.global_position
		var global_rot = shirt.global_rotation
		shirt.mount_on_platen(press, global_pos, global_rot)
		
		print("PrintModeController: Shirt mounted on platen ", platen_index)
		held_shirt_in_print_mode = null
		shirt_mounted_on_platen.emit()
		return true
	else:
		# If mount failed, put back on player
		arms.remove_child(shirt)
		player.add_child(shirt)
		shirt.position = Vector3(0, 1.2, -0.3)
		return false

# ============================================================================
# PRIVATE FUNCTIONS
# ============================================================================

func _can_remove_screen() -> bool:
	"""Check if there's a screen available to remove from press"""
	var press = player.get_tree().get_first_node_in_group("press")
	if not press:
		return false
	
	return press.get_front_screen() != null

func _find_cart_at_zone() -> RigidBody3D:
	"""Find a cart at the cart zone"""
	# Get all carts
	var _carts = player.get_tree().get_nodes_in_group("carts")
	
	# Find cart zones
	var cart_zones = player.get_tree().get_nodes_in_group("cart_zones")
	
	# Check each cart zone
	for zone in cart_zones:
		if zone.cart_in_zone:
			return zone.cart_in_zone
	
	return null

func _on_entered_print_mode():
	"""Called when entering print mode"""
	print("PrintModeController: Entered print mode")
	
	# Store base rotation
	base_rotation_y = player.global_rotation.y
	facing_direction = FacingDirection.PRESS
	is_rotating = false
	
	# Apply camera zoom
	if current_print_zone:
		current_print_zone.apply_camera_zoom()
		print_mode_camera_target = current_print_zone.get_camera_target_position()
	
	# Enable press controls
	var press = player.get_tree().get_first_node_in_group("press")
	if press:
		press.enable_controls(player)
	
	# Auto-load screen if carrying one
	if screen_carrier and screen_carrier.is_carrying_screen():
		load_screen_to_press()
	
	entered_print_mode.emit()

func _on_exited_print_mode():
	"""Called when exiting print mode"""
	print("PrintModeController: Exited print mode")
	
	# Reset rotation state
	facing_direction = FacingDirection.PRESS
	is_rotating = false
	
	# Drop any held shirt
	if held_shirt_in_print_mode:
		# TODO: Properly handle shirt when exiting with one held
		held_shirt_in_print_mode = null
	
	# Disable press controls
	var press = player.get_tree().get_first_node_in_group("press")
	if press:
		press.disable_controls()
	
	# Restore camera zoom
	if current_print_zone:
		current_print_zone.restore_camera_zoom()
	
	# Clear zone reference
	current_print_zone = null
	
	exited_print_mode.emit()
