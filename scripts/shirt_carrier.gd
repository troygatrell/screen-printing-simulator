# shirt_carrier.gd
# Handles shirt carrying mechanics for the player (separate from screen carrying)
#
# RESPONSIBILITIES:
# - Shirt pickup from world
# - Shirt carrying visual/physics
# - Shirt loading into cart
# - Integration with player state machine
#
# SIGNALS:
# - shirt_picked_up: Emitted when player picks up a shirt
# - shirt_loaded_to_cart: Emitted when shirt is loaded into cart
#
# DEPENDENCIES:
# - Must be child of player CharacterBody3D
# - Works alongside ScreenCarrier (both can't be active at once)

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal shirt_picked_up
signal shirt_loaded_to_cart

# ============================================================================
# EXPORTS
# ============================================================================

@export var carry_position = Vector3(0, 1.0, -0.5)
@export var display_rotation_degrees = -20.0

# ============================================================================
# VARIABLES
# ============================================================================

var carried_shirt: RigidBody3D = null
var shirt_in_range: RigidBody3D = null

# References
var player: CharacterBody3D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Get reference to parent player
	player = get_parent()
	if not player:
		push_error("ShirtCarrier must be a child of the player!")

# ============================================================================
# PUBLIC FUNCTIONS - CARRYING
# ============================================================================

func is_carrying_shirt() -> bool:
	"""Check if currently carrying a shirt"""
	return carried_shirt != null

func can_pickup_shirt() -> bool:
	"""Check if there's a shirt in range to pick up"""
	return shirt_in_range != null and not is_carrying_shirt()

func pickup_shirt() -> bool:
	"""Pick up a shirt from the world"""
	if not shirt_in_range:
		print("ShirtCarrier: No shirt in range!")
		return false
	
	if carried_shirt:
		print("ShirtCarrier: Already carrying a shirt!")
		return false
	
	carried_shirt = shirt_in_range
	
	# Only pick up shirts that are interactable (not in cart, not on platen)
	if not carried_shirt.is_interactable():
		print("ShirtCarrier: Shirt is not interactable!")
		carried_shirt = null
		return false
	
	# Disable physics
	carried_shirt.freeze = true
	carried_shirt.collision_layer = 0
	carried_shirt.collision_mask = 0
	
	# Attach to player
	var parent = carried_shirt.get_parent()
	if parent:
		parent.remove_child(carried_shirt)
	player.add_child(carried_shirt)
	
	carried_shirt.position = carry_position
	carried_shirt.rotation = Vector3(deg_to_rad(display_rotation_degrees), 0, 0)
	
	print("ShirtCarrier: Picked up shirt")
	shirt_picked_up.emit()
	return true

func load_shirt_to_cart(cart: RigidBody3D) -> bool:
	"""Load carried shirt into a cart"""
	if not carried_shirt:
		print("ShirtCarrier: No shirt to load!")
		return false
	
	if not cart:
		print("ShirtCarrier: No cart provided!")
		return false
	
	# Detach from player
	player.remove_child(carried_shirt)
	player.get_tree().get_root().add_child(carried_shirt)
	
	# Load into cart
	if cart.load_shirt(carried_shirt):
		print("ShirtCarrier: Shirt loaded into cart")
		carried_shirt = null
		shirt_loaded_to_cart.emit()
		return true
	else:
		# If loading failed, put shirt back in player's hands
		player.get_tree().get_root().remove_child(carried_shirt)
		player.add_child(carried_shirt)
		carried_shirt.position = carry_position
		carried_shirt.rotation = Vector3(deg_to_rad(display_rotation_degrees), 0, 0)
		print("ShirtCarrier: Failed to load shirt into cart (probably full)")
		return false

func drop_shirt() -> bool:
	"""Drop the carried shirt back into the world"""
	if not carried_shirt:
		print("ShirtCarrier: No shirt to drop!")
		return false
	
	# Get global transform before reparenting
	var shirt_transform = carried_shirt.global_transform
	
	# Reparent to world
	player.remove_child(carried_shirt)
	player.get_tree().get_root().add_child(carried_shirt)
	carried_shirt.global_transform = shirt_transform
	
	# Re-enable physics
	carried_shirt.freeze = false
	carried_shirt.collision_layer = 1
	carried_shirt.collision_mask = 1
	
	print("ShirtCarrier: Dropped shirt")
	carried_shirt = null
	return true

# ============================================================================
# PUBLIC FUNCTIONS - RANGE DETECTION
# ============================================================================

func shirt_entered_range(shirt: RigidBody3D):
	"""Called when a shirt enters pickup range"""
	if not shirt:
		return
	
	# Only detect interactable shirts
	if shirt.is_interactable():
		shirt_in_range = shirt
		print("ShirtCarrier: Shirt in range")

func shirt_exited_range(shirt: RigidBody3D):
	"""Called when a shirt exits pickup range"""
	if shirt == shirt_in_range:
		shirt_in_range = null
		print("ShirtCarrier: Shirt left range")

# ============================================================================
# PUBLIC FUNCTIONS - UPDATES
# ============================================================================

func update_shirt_position():
	"""Update carried shirt position relative to player"""
	if not carried_shirt:
		return
	
	carried_shirt.position = carry_position
	carried_shirt.rotation = Vector3(deg_to_rad(display_rotation_degrees), 0, 0)
