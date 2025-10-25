# print_mode_controller.gd
# Handles all print zone interactions and screen loading/unloading.
#
# RESPONSIBILITIES:
# - Transition animations to/from print mode
# - Player position/rotation snapping to print zone
# - Screen loading/unloading to press heads
# - Camera zoom control during print mode
# - Press control enabling/disabling
# - Auto-loading screens when entering with one carried
#
# SIGNALS:
# - entered_print_mode: Emitted when player enters print mode
# - exited_print_mode: Emitted when player exits print mode
# - screen_loaded_to_press: Emitted when screen is loaded to press
# - screen_removed_from_press: Emitted when screen is removed from press
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

# ============================================================================
# EXPORTS
# ============================================================================

@export var transition_speed = 3.0
@export var distance_threshold = 0.15

# ============================================================================
# VARIABLES
# ============================================================================

var current_print_zone = null
var print_target_position = Vector3.ZERO
var print_target_rotation = Vector3.ZERO
var exit_target_position = Vector3.ZERO
var exit_target_rotation = Vector3.ZERO
var print_mode_camera_target = Vector3.ZERO

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

func update_print_mode(_delta) -> Vector3:
	"""
	Update while in print mode.
	Returns velocity (always zero - player is locked).
	"""
	return Vector3.ZERO

func get_camera_target_position() -> Vector3:
	"""Get the camera target position for print mode"""
	return print_mode_camera_target

# ============================================================================
# PUBLIC FUNCTIONS - INPUT HANDLING
# ============================================================================

enum InputAction {
	NONE,
	EXIT,
	REMOVE_SCREEN
}

func handle_print_mode_input() -> InputAction:
	"""
	Handle input while in print mode.
	Returns what action should be taken.
	"""
	# Check for Shift+E to remove screen
	if Input.is_action_pressed("shift-modifier"):
		if _can_remove_screen():
			if remove_screen_from_press():
				return InputAction.REMOVE_SCREEN
		else:
			print("No screen to remove from press")
		return InputAction.NONE
	
	# Regular E to exit
	return InputAction.EXIT

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
# PRIVATE FUNCTIONS
# ============================================================================

func _can_remove_screen() -> bool:
	"""Check if there's a screen available to remove from press"""
	var press = player.get_tree().get_first_node_in_group("press")
	if not press:
		return false
	
	return press.get_front_screen() != null

func _on_entered_print_mode():
	"""Called when entering print mode"""
	print("PrintModeController: Entered print mode")
	
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
