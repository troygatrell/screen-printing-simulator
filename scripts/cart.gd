# cart.gd
# Manages shirt inventory for the cart
#
# RESPONSIBILITIES:
# - Shirt inventory storage (array of shirt objects)
# - Loading shirts into cart
# - Unloading shirts from cart
# - Capacity management
# - Visual/audio feedback for loading/unloading
#
# SIGNALS:
# - shirt_loaded: Emitted when a shirt is loaded into cart
# - shirt_unloaded: Emitted when a shirt is unloaded from cart
# - cart_full: Emitted when cart reaches max capacity
# - cart_empty: Emitted when last shirt is unloaded
#
# DEPENDENCIES:
# - Requires LoadingZone child (Area3D) for interaction detection
# - Requires HandleZone child (Area3D) for pushing (existing)

extends RigidBody3D

# ============================================================================
# SIGNALS
# ============================================================================

signal shirt_loaded(shirt)
signal shirt_unloaded(shirt)
signal cart_full
signal cart_empty

# ============================================================================
# EXPORTS
# ============================================================================

@export var max_capacity = 50
@export var loading_zone_path: NodePath = "LoadingZone"
@export var stack_position = Vector3(0, 0.5, 0)  # Where stack starts on cart
@export var shirt_stack_height = 0.15  # Height between each shirt in stack
@export var show_shirt_stack = true  # Toggle visual stacking

# Stack rotation (adjust these!)
@export var stack_rotation_x = -90.0  # Tilt
@export var stack_rotation_y = 0.0    # Spin
@export var stack_rotation_z = 0.0    # Roll

# Preloading options
@export var preload_shirt_scene: PackedScene
@export var preload_shirt_count = 10  # How many shirts to start with

# ============================================================================
# VARIABLES
# ============================================================================

var shirt_inventory = []  # Array of shirt references
var loading_zone: Area3D
var player_in_loading_zone = false
var player_ref = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	add_to_group("carts")
	
	# Get loading zone reference
	loading_zone = get_node_or_null(loading_zone_path)
	if not loading_zone:
		push_warning("Cart: No LoadingZone found at path: ", loading_zone_path)
		push_warning("Please add an Area3D child named 'LoadingZone' to the cart!")
	else:
		loading_zone.body_entered.connect(_on_loading_zone_entered)
		loading_zone.body_exited.connect(_on_loading_zone_exited)
		print("Cart: LoadingZone initialized")
	
	print("Cart initialized - Capacity: ", max_capacity)
	
	# Preload shirts if configured
	if preload_shirt_scene and preload_shirt_count > 0:
		_preload_shirts()

# ============================================================================
# PUBLIC FUNCTIONS - INVENTORY MANAGEMENT
# ============================================================================

func load_shirt(shirt: RigidBody3D) -> bool:
	"""Load a shirt into the cart inventory"""
	if not shirt:
		push_warning("Cart: Cannot load null shirt!")
		return false
	
	if is_full():
		push_warning("Cart: Cart is full! (", shirt_inventory.size(), "/", max_capacity, ")")
		cart_full.emit()
		return false
	
	# Tell the shirt to load into cart (this disables some physics)
	if shirt.load_into_cart(self):
		shirt_inventory.append(shirt)
		
		if show_shirt_stack:
			# Make shirt visible and stack it on cart
			shirt.visible = true
			shirt.freeze = true
			
			# CRITICAL: Completely disable collision
			shirt.collision_layer = 0
			shirt.collision_mask = 0
			
			# Remove from current parent
			if shirt.get_parent():
				shirt.get_parent().remove_child(shirt)
			
			# Add as child of cart
			add_child(shirt)
			
			# Position in stack (higher for each shirt)
			var stack_index = shirt_inventory.size() - 1
			shirt.position = stack_position + Vector3(0, stack_index * shirt_stack_height, 0)
			shirt.rotation = Vector3(
				deg_to_rad(stack_rotation_x), 
				deg_to_rad(stack_rotation_y), 
				deg_to_rad(stack_rotation_z)
			)

		
		print("Cart: Loaded shirt (", get_shirt_count(), "/", max_capacity, ")")
		shirt_loaded.emit(shirt)
		
		if is_full():
			cart_full.emit()
		
		return true
	
	return false

func unload_shirt() -> RigidBody3D:
	"""Unload the most recent shirt from cart"""
	if is_empty():
		push_warning("Cart: Cart is empty!")
		cart_empty.emit()
		return null
	
	# Get the last shirt (top of stack)
	var shirt = shirt_inventory.pop_back()
	
	if not shirt:
		push_warning("Cart: Shirt reference was null!")
		return null
	
	# Tell the shirt to unload from cart
	if shirt.unload_from_cart():
		# Remove from cart hierarchy
		if shirt.get_parent() == self:
			remove_child(shirt)
		
		# Add to world
		get_tree().get_root().add_child(shirt)
		
		# Position shirt near the loading zone
		if loading_zone:
			shirt.global_position = loading_zone.global_position + Vector3(0, 0.5, 0)
		else:
			shirt.global_position = global_position + Vector3(0, 0.5, 0)
		
		shirt.global_rotation = Vector3.ZERO
		
		print("Cart: Unloaded shirt (", get_shirt_count(), "/", max_capacity, ")")
		shirt_unloaded.emit(shirt)
		
		if is_empty():
			cart_empty.emit()
		
		return shirt
	else:
		# If unload failed, put it back in inventory
		shirt_inventory.append(shirt)
		return null

func unload_shirt_to_position(target_position: Vector3) -> RigidBody3D:
	"""Unload a shirt to a specific world position"""
	if is_empty():
		return null
	
	var shirt = shirt_inventory.pop_back()
	
	if not shirt:
		return null
	
	if shirt.unload_from_cart():
		# Remove from cart hierarchy
		if shirt.get_parent() == self:
			remove_child(shirt)
		
		# Add to world
		get_tree().get_root().add_child(shirt)
		
		shirt.global_position = target_position
		shirt.global_rotation = Vector3.ZERO
		
		print("Cart: Unloaded shirt to position (", get_shirt_count(), "/", max_capacity, ")")
		shirt_unloaded.emit(shirt)
		
		if is_empty():
			cart_empty.emit()
		
		return shirt
	else:
		shirt_inventory.append(shirt)
		return null

# ============================================================================
# PUBLIC FUNCTIONS - QUERIES
# ============================================================================

func get_shirt_count() -> int:
	"""Get current number of shirts in cart"""
	return shirt_inventory.size()

func is_full() -> bool:
	"""Check if cart is at max capacity"""
	return shirt_inventory.size() >= max_capacity

func is_empty() -> bool:
	"""Check if cart has no shirts"""
	return shirt_inventory.is_empty()

func get_capacity_string() -> String:
	"""Get formatted capacity string"""
	return str(get_shirt_count()) + "/" + str(max_capacity)

func is_player_at_loading_zone() -> bool:
	"""Check if player is in the loading zone"""
	return player_in_loading_zone

# ============================================================================
# PRIVATE FUNCTIONS - ZONE DETECTION
# ============================================================================

func _on_loading_zone_entered(body):
	"""Detect when player enters loading zone"""
	if body.is_in_group("player"):
		player_in_loading_zone = true
		player_ref = body
		print("Cart: Player entered loading zone")

func _on_loading_zone_exited(body):
	"""Detect when player exits loading zone"""
	if body.is_in_group("player") and body == player_ref:
		player_in_loading_zone = false
		player_ref = null
		print("Cart: Player left loading zone")

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func get_info() -> Dictionary:
	"""Get comprehensive cart information"""
	return {
		"shirt_count": get_shirt_count(),
		"max_capacity": max_capacity,
		"is_full": is_full(),
		"is_empty": is_empty(),
		"player_at_loading_zone": player_in_loading_zone
	}

func clear_inventory():
	"""Remove all shirts from inventory (for testing/reset)"""
	for shirt in shirt_inventory:
		if shirt:
			shirt.unload_from_cart()
	shirt_inventory.clear()
	print("Cart: Inventory cleared")
	cart_empty.emit()
	
func _preload_shirts():
	"""Automatically load shirts into cart at game start"""
	print("=== PRELOADING SHIRTS INTO CART ===")
	await get_tree().process_frame  # Wait one frame
	
	var count = min(preload_shirt_count, max_capacity)
	
	for i in range(count):
		var shirt = preload_shirt_scene.instantiate()
		if shirt is RigidBody3D:
			# Add to scene temporarily
			get_tree().get_root().add_child(shirt)
			
			# Load into cart
			if load_shirt(shirt):
				print("Preloaded shirt ", i + 1, "/", count)
			else:
				print("Failed to preload shirt ", i)
				shirt.queue_free()
		else:
			print("ERROR: Preload scene is not a RigidBody3D!")
			shirt.queue_free()
	
	print("=== CART PRELOAD COMPLETE: ", get_shirt_count(), " shirts ===")
