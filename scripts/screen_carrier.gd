# screen_carrier.gd
# Handles all screen carrying mechanics for the player

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal screen_picked_up  # Emitted when player picks up a screen
signal screen_dropped    # Emitted when player drops a screen

# ============================================================================
# EXPORTS
# ============================================================================

@export var collision_size = Vector3(0.6, 0.8, 0.8)
@export var collision_position = Vector3(0, 1.5, -0.8)
@export var carry_position = Vector3(0, 1.2, -0.5)
@export var display_position = Vector3(0, 0.5, -0.25)
@export var display_rotation_degrees = -30.0

# ============================================================================
# VARIABLES
# ============================================================================

var screen_in_range = null
var carried_screen = null
var original_screen_collision_layer = 0
var original_screen_collision_mask = 0
var extended_collision = null

# References
var player: CharacterBody3D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Get reference to parent player
	player = get_parent()
	if not player:
		push_error("ScreenCarrier must be a child of the player!")

# ============================================================================
# PUBLIC FUNCTIONS
# ============================================================================

func is_carrying_screen() -> bool:
	"""Check if currently carrying a screen"""
	return carried_screen != null

func can_pickup_screen() -> bool:
	"""Check if there's a screen in range to pick up"""
	return screen_in_range != null

func get_carried_screen() -> RigidBody3D:
	"""Get reference to the carried screen"""
	return carried_screen

func pickup_screen() -> bool:
	"""Pick up a screen from the world"""
	if not screen_in_range:
		print("ScreenCarrier: No screen in range!")
		return false
	
	if carried_screen:
		print("ScreenCarrier: Already carrying a screen!")
		return false
	
	carried_screen = screen_in_range.get_parent()
	
	# Store original collision settings
	original_screen_collision_layer = carried_screen.collision_layer
	original_screen_collision_mask = carried_screen.collision_mask
	
	# Disable screen collision
	carried_screen.collision_layer = 0
	carried_screen.collision_mask = 0
	
	# Freeze and attach to player
	carried_screen.freeze = true
	carried_screen.linear_velocity = Vector3.ZERO
	carried_screen.angular_velocity = Vector3.ZERO
	carried_screen.get_parent().remove_child(carried_screen)
	player.add_child(carried_screen)
	carried_screen.position = carry_position
	carried_screen.rotation = Vector3.ZERO
	
	# Create extended collision
	_create_extended_collision()
	
	print("ScreenCarrier: Picked up screen")
	screen_picked_up.emit()
	return true

func drop_screen() -> bool:
	"""Drop the carried screen back into the world"""
	if not carried_screen:
		print("ScreenCarrier: No screen to drop!")
		return false
	
	# Get global transform before reparenting
	var screen_transform = carried_screen.global_transform
	
	# Reparent to world
	player.remove_child(carried_screen)
	player.get_tree().get_root().add_child(carried_screen)
	carried_screen.global_transform = screen_transform
	
	# Restore physics
	carried_screen.freeze = false
	carried_screen.collision_layer = original_screen_collision_layer
	carried_screen.collision_mask = original_screen_collision_mask
	
	# Remove extended collision
	_remove_extended_collision()
	
	print("ScreenCarrier: Dropped screen")
	carried_screen = null
	screen_dropped.emit()
	return true

func give_screen_to(recipient: Node) -> RigidBody3D:
	"""
	Transfer the carried screen to another node (like a rack or press).
	Returns the screen and clears carried_screen.
	Does NOT restore collision - recipient should handle that.
	"""
	if not carried_screen:
		print("ScreenCarrier: No screen to give!")
		return null
	
	var screen = carried_screen
	carried_screen = null
	
	# Remove extended collision
	_remove_extended_collision()
	
	if recipient:
		print("ScreenCarrier: Gave screen to ", recipient.name)
	else:
		print("ScreenCarrier: Gave screen to unknown")
	return screen

func receive_screen_from(donor: Node, screen: RigidBody3D) -> bool:
	"""
	Receive a screen from another node (like a rack or press).
	Assumes collision is already disabled on the screen.
	"""
	if carried_screen:
		print("ScreenCarrier: Already carrying a screen!")
		return false
	
	if not screen:
		print("ScreenCarrier: No screen provided!")
		return false
	
	# Store original collision settings
	original_screen_collision_layer = screen.collision_layer
	original_screen_collision_mask = screen.collision_mask
	
	# Disable screen collision (in case not already done)
	screen.collision_layer = 0
	screen.collision_mask = 0
	
	# Attach to player
	player.add_child(screen)
	screen.position = carry_position
	screen.rotation = Vector3.ZERO
	screen.freeze = true
	carried_screen = screen
	
	if donor:
		print("ScreenCarrier: Received screen from ", donor.name)
	else:
		print("ScreenCarrier: Received screen from unknown")
	screen_picked_up.emit()
	return true

func update_screen_position():
	"""Update carried screen position relative to player"""
	if not carried_screen:
		return
	
	carried_screen.position = display_position
	carried_screen.rotation = Vector3(deg_to_rad(display_rotation_degrees), 0, 0)

func restore_screen_collision():
	"""Restore the screen's collision layers (used before giving to press/rack)"""
	if carried_screen:
		carried_screen.collision_layer = original_screen_collision_layer
		carried_screen.collision_mask = original_screen_collision_mask

func disable_extended_collision():
	"""Temporarily remove extended collision (used during transitions)"""
	_remove_extended_collision()

func enable_extended_collision():
	"""Re-create extended collision"""
	if carried_screen and not extended_collision:
		_create_extended_collision()

func screen_in_range_entered(area):
	"""Called when a screen enters the grab zone"""
	if area.is_in_group("screens"):
		screen_in_range = area
		print("ScreenCarrier: Screen in range")

func screen_in_range_exited(area):
	"""Called when a screen exits the grab zone"""
	if area == screen_in_range:
		screen_in_range = null
		print("ScreenCarrier: Screen left range")

# ============================================================================
# PRIVATE FUNCTIONS
# ============================================================================

func _create_extended_collision():
	"""Create extended collision shape on player for screen"""
	if extended_collision:
		_remove_extended_collision()
	
	extended_collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = collision_size
	extended_collision.shape = box_shape
	extended_collision.position = collision_position
	
	player.add_child(extended_collision)
	print("ScreenCarrier: Created extended collision")

func _remove_extended_collision():
	"""Remove extended collision from player"""
	if extended_collision:
		player.remove_child(extended_collision)
		extended_collision.queue_free()
		extended_collision = null
		print("ScreenCarrier: Removed extended collision")
