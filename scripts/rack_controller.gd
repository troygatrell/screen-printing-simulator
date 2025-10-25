# rack_controller.gd
# Handles all screen rack interaction for the player

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal screen_stored_to_rack
signal screen_retrieved_from_rack

# ============================================================================
# EXPORTS
# ============================================================================

@export var exit_transition_speed = 3.0
@export var exit_distance_threshold = 0.15

# ============================================================================
# VARIABLES
# ============================================================================

var screen_rack_in_range = null
var rack_exit_target_position = Vector3.ZERO
var rack_exit_target_rotation = Vector3.ZERO

# References
var player: CharacterBody3D
var screen_carrier

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Get reference to parent player
	player = get_parent()
	if not player:
		push_error("RackController must be a child of the player!")
		return
	
	# Get screen carrier sibling
	screen_carrier = player.get_node_or_null("ScreenCarrier")
	if not screen_carrier:
		push_warning("RackController: No ScreenCarrier found!")

# ============================================================================
# PUBLIC FUNCTIONS - RACK DETECTION
# ============================================================================

func is_rack_in_range() -> bool:
	"""Check if a screen rack is in range"""
	return screen_rack_in_range != null

func get_rack_in_range():
	"""Get the rack currently in range"""
	return screen_rack_in_range

func rack_entered_range(rack):
	"""Called when a rack enters range"""
	screen_rack_in_range = rack
	print("RackController: Screen rack in range")

func rack_exited_range(rack):
	"""Called when a rack exits range"""
	if rack == screen_rack_in_range:
		screen_rack_in_range = null
		print("RackController: Screen rack left range")

# ============================================================================
# PUBLIC FUNCTIONS - SCREEN STORAGE
# ============================================================================

func can_store_screen() -> bool:
	"""Check if player can store a screen in the rack"""
	if not screen_rack_in_range:
		return false
	if not screen_carrier or not screen_carrier.is_carrying_screen():
		return false
	return true

func store_screen_to_rack() -> bool:
	"""Store carried screen into the rack"""
	if not screen_carrier or not screen_carrier.is_carrying_screen():
		print("RackController: No screen being carried!")
		return false
	
	if not screen_rack_in_range:
		print("RackController: No screen rack in range!")
		return false
	
	# Restore collision before storing
	screen_carrier.restore_screen_collision()
	
	# Get the screen from carrier
	var screen = screen_carrier.give_screen_to(screen_rack_in_range)
	
	if not screen:
		print("RackController: Failed to get screen from carrier!")
		return false
	
	# Store the screen in the rack
	if screen_rack_in_range.load_screen_to_rack(screen):
		print("RackController: Successfully stored screen in rack")
		screen_stored_to_rack.emit()
		return true
	else:
		print("RackController: Failed to store screen in rack (rack may be full)")
		# If rack is full, give screen back to carrier
		screen_carrier.receive_screen_from(screen_rack_in_range, screen)
		return false

# ============================================================================
# PUBLIC FUNCTIONS - SCREEN RETRIEVAL
# ============================================================================

func can_retrieve_screen() -> bool:
	"""Check if player can retrieve a screen from the rack"""
	if not screen_rack_in_range:
		return false
	if screen_carrier and screen_carrier.is_carrying_screen():
		return false
	# Check if rack has any screens
	return screen_rack_in_range.get_screen_count() > 0

func retrieve_screen_from_rack() -> bool:
	"""Retrieve a screen from the rack and start transition"""
	if not screen_rack_in_range:
		print("RackController: No screen rack in range!")
		return false
	
	if screen_carrier and screen_carrier.is_carrying_screen():
		print("RackController: Already carrying a screen!")
		return false
	
	# Get the first filled slot
	var slot_index = screen_rack_in_range.get_nearest_filled_slot()
	
	if slot_index == -1:
		print("RackController: Rack is empty!")
		return false
	
	# Remove screen from rack
	var screen = screen_rack_in_range.remove_screen_from_rack(slot_index)
	
	if not screen:
		print("RackController: Failed to retrieve screen from rack")
		return false
	
	# Give to screen carrier
	if screen_carrier.receive_screen_from(screen_rack_in_range, screen):
		print("RackController: Screen picked up from rack")
		
		# Setup exit transition targets
		rack_exit_target_rotation = player.global_rotation + Vector3(0, PI/2, 0)
		rack_exit_target_position = player.global_position + player.global_transform.basis.z * 0.5
		
		screen_retrieved_from_rack.emit()
		return true
	else:
		print("RackController: Failed to receive screen - carrier busy")
		# Put screen back in rack
		screen_rack_in_range.load_screen_to_rack(screen, slot_index)
		return false

# ============================================================================
# PUBLIC FUNCTIONS - TRANSITION FROM RACK
# ============================================================================

func update_transition_from_rack(delta) -> bool:
	"""
	Update transition away from rack with screen.
	Returns true when transition is complete.
	"""
	player.global_position = player.global_position.lerp(rack_exit_target_position, exit_transition_speed * delta)
	player.global_rotation = player.global_rotation.lerp(rack_exit_target_rotation, exit_transition_speed * delta)
	
	if player.global_position.distance_to(rack_exit_target_position) < exit_distance_threshold:
		player.global_position = rack_exit_target_position
		
		# Re-enable collision when transition complete
		if screen_carrier:
			screen_carrier.enable_extended_collision()
		
		return true
	
	return false
