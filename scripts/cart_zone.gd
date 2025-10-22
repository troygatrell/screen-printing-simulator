# cart_zone.gd
extends Area3D

# Type of zone - set this in the Inspector
@export_enum("Loading", "Unloading") var zone_type = "Loading"

# Snap position and rotation
# Adjust Y offset to lift cart above the floor to proper height
@export var snap_offset = Vector3(0, 0.5, 0) # Adjust if cart should be offset from zone center

# Visual feedback
var is_cart_in_zone = false
var cart_in_zone = null

func _ready():
	# Connect signals for both bodies and areas
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# Make sure this zone is in the "cart_zones" group
	add_to_group("cart_zones")

func _on_body_entered(body):
	# Check if a cart (RigidBody3D) entered the zone
	if body is RigidBody3D:
		cart_in_zone = body
		is_cart_in_zone = true
		print("Cart entered ", zone_type, " zone")

func _on_body_exited(body):
	if body == cart_in_zone:
		cart_in_zone = null
		is_cart_in_zone = false
		print("Cart left ", zone_type, " zone")

func _on_area_entered(area):
	# Also check if the cart's Area3D child (handle) entered
	if area.is_in_group("carts"):
		var cart = area.get_parent()
		if cart is RigidBody3D:
			cart_in_zone = cart
			is_cart_in_zone = true
			print("Cart (via area) entered ", zone_type, " zone")

func _on_area_exited(area):
	if area.is_in_group("carts"):
		var cart = area.get_parent()
		if cart == cart_in_zone:
			cart_in_zone = null
			is_cart_in_zone = false
			print("Cart (via area) left ", zone_type, " zone")

func is_cart_in_snap_range(cart: RigidBody3D) -> bool:
	"""Check if cart is close enough to this zone to snap"""
	if not cart:
		return false
	var distance = global_position.distance_to(cart.global_position)
	# Adjust this range as needed - smaller = must be closer to snap
	print("Distance from cart to zone: ", distance)
	return distance < 1.0  # Changed from 2.0 to 1.0 for tighter snapping

func snap_cart_to_zone(cart: RigidBody3D):
	"""Snaps the cart to the zone's position and rotation"""
	if cart:
		print("Cart position before snap: ", cart.global_position)
		print("Zone position: ", global_position)
		print("Snap offset: ", snap_offset)
		
		cart.global_position = global_position + snap_offset
		
		print("Cart position after snap: ", cart.global_position)
		
		# Don't change the cart's rotation - keep it facing the same way the player left it
		# This way the handle stays accessible
		# If you want a specific rotation, uncomment the next line:
		cart.global_rotation = global_rotation
		
		# Stop any movement
		cart.linear_velocity = Vector3.ZERO
		cart.angular_velocity = Vector3.ZERO
		print("Cart snapped to ", zone_type, " zone")
	else:
		print("ERROR: No cart to snap!")

func get_zone_type() -> String:
	return zone_type
