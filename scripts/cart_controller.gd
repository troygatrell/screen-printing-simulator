# cart_controller.gd
# Handles all cart pushing mechanics for the player

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal cart_grabbed  # Emitted when player grabs a cart
signal cart_released  # Emitted when player releases a cart

# ============================================================================
# EXPORTS
# ============================================================================

@export var push_speed_multiplier = 0.5  # How much slower to move when pushing
@export var turn_speed_multiplier = 0.3  # How much to turn per input
@export var collision_size = Vector3(1.0, 1.5, 1.0)
@export var collision_position = Vector3(0, 0.75, -1.2)

# ============================================================================
# VARIABLES
# ============================================================================

var handle_in_range = null
var pushed_cart = null
var original_cart_collision_layer = 0
var original_cart_collision_mask = 0
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
		push_error("CartController must be a child of the player!")

# ============================================================================
# PUBLIC FUNCTIONS
# ============================================================================

func is_pushing_cart() -> bool:
	"""Check if currently pushing a cart"""
	return pushed_cart != null

func can_grab_cart() -> bool:
	"""Check if there's a cart handle in range"""
	return handle_in_range != null

func grab_cart():
	"""Grab and start pushing a cart"""
	if not handle_in_range:
		print("CartController: No cart handle in range!")
		return false
	
	pushed_cart = handle_in_range.get_parent()
	
	# Store original collision settings
	original_cart_collision_layer = pushed_cart.collision_layer
	original_cart_collision_mask = pushed_cart.collision_mask
	
	# Disable cart's own collision
	pushed_cart.collision_layer = 0
	pushed_cart.collision_mask = 0
	
	# Freeze cart physics
	pushed_cart.freeze = true
	pushed_cart.linear_velocity = Vector3.ZERO
	pushed_cart.angular_velocity = Vector3.ZERO
	
	# Create extended collision on player
	_create_extended_collision()
	
	print("CartController: Grabbed cart")
	cart_grabbed.emit()
	return true

func release_cart():
	"""Release the cart and snap it to zone if nearby"""
	if not pushed_cart:
		print("CartController: No cart to release!")
		return
	
	# Remove extended collision from player
	_remove_extended_collision()
	
	# Restore cart's collision
	pushed_cart.collision_layer = original_cart_collision_layer
	pushed_cart.collision_mask = original_cart_collision_mask
	
	# Check if near a cart zone and snap if so
	var cart_zones = get_tree().get_nodes_in_group("cart_zones")
	for zone in cart_zones:
		if zone.is_cart_in_snap_range(pushed_cart):
			zone.snap_cart_to_zone(pushed_cart)
			break
	
	# Release physics
	pushed_cart.linear_velocity = Vector3.ZERO
	pushed_cart.angular_velocity = Vector3.ZERO
	pushed_cart.freeze = false
	
	print("CartController: Released cart")
	pushed_cart = null
	
	cart_released.emit()

func update_cart_pushing(delta: float, speed: float, rotation_speed: float) -> Vector3:
	"""
	Handle tank control input and return velocity for player.
	Called from player's _physics_process when in PUSHING_CART state.
	"""
	if not pushed_cart:
		return Vector3.ZERO
	
	var push_input = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	var turn_input = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	
	# Turn player when pushing
	if push_input != 0:
		player.rotate_y(turn_input * rotation_speed * turn_speed_multiplier * delta)
	
	# Calculate push velocity
	var velocity = Vector3.ZERO
	if push_input != 0:
		var push_direction = -player.global_transform.basis.z
		velocity = push_direction * push_input * (speed * push_speed_multiplier)
	
	return velocity

func update_cart_position():
	"""Update cart position to follow player"""
	if not pushed_cart:
		return
	
	# Position cart behind player
	var cart_offset = -player.global_transform.basis.z * 1.2
	pushed_cart.global_position = player.global_position + cart_offset
	pushed_cart.global_rotation = player.global_rotation + Vector3(0, PI, 0)

func handle_in_range_entered(area):
	"""Called when something enters the grab zone"""
	if area.is_in_group("carts"):
		handle_in_range = area
		print("CartController: Cart handle in range")

func handle_in_range_exited(area):
	"""Called when something exits the grab zone"""
	if area == handle_in_range:
		handle_in_range = null
		print("CartController: Cart handle left range")

# ============================================================================
# PRIVATE FUNCTIONS
# ============================================================================

func _create_extended_collision():
	"""Create extended collision shape on player for cart"""
	if extended_collision:
		_remove_extended_collision()
	
	extended_collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = collision_size
	extended_collision.shape = box_shape
	extended_collision.position = collision_position
	
	player.add_child(extended_collision)
	print("CartController: Created extended collision")

func _remove_extended_collision():
	"""Remove extended collision from player"""
	if extended_collision:
		player.remove_child(extended_collision)
		extended_collision.queue_free()
		extended_collision = null
		print("CartController: Removed extended collision")
