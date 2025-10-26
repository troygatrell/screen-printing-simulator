# shirt.gd (SIMPLIFIED VERSION - Uses Print Plane)
# State-based shirt controller for screen printing simulator
#
# RESPONSIBILITIES:
# - Shirt state management (blank, printed, drying, dried, folded)
# - Print plane material swapping (much simpler than texture compositing!)
# - Integration with cart inventory system
# - Integration with platen mounting system
# - Drying progress tracking
#
# SIGNALS:
# - state_changed: Emitted when shirt state changes
# - print_applied: Emitted when a print is applied to the shirt
# - drying_complete: Emitted when drying finishes
# - folded: Emitted when shirt is folded
#
# DEPENDENCIES:
# - Requires "PrintPlane" child node (MeshInstance3D with PlaneMesh)
# - Requires Area3D child for interaction detection

extends RigidBody3D

# ============================================================================
# STATE MACHINE
# ============================================================================

enum ShirtState {
	BLANK,          # Fresh shirt, no prints
	PRINTED,        # Has print applied, needs drying
	DRYING,         # Currently in dryer
	DRIED,          # Dry and ready for folding
	FOLDED          # Folded and ready for packaging
}

var current_state = ShirtState.BLANK

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(old_state, new_state)
signal print_applied(print_data)
signal drying_complete
signal folded

# ============================================================================
# EXPORTS
# ============================================================================

# Print plane settings
@export_group("Print Settings")
@export var print_plane_path: NodePath = "PrintPlane"  # Path to the plane mesh
@export var wet_ink_roughness = 0.4  # Roughness when ink is wet
@export var dry_ink_roughness = 0.8  # Roughness when ink is dry

# Drying settings
@export_group("Drying Settings")
@export var drying_time = 10.0  # Seconds to fully dry
@export var show_drying_progress = true

# Physics settings
@export_group("Physics Settings")
@export var folded_scale = Vector3(0.5, 0.2, 0.4)  # Scale when folded
@export var folded_mass = 0.1  # Lighter when folded
@export var unfolded_mass = 0.3

# ============================================================================
# VARIABLES
# ============================================================================

# Print tracking
var print_layers = []  # Array of print data: [{color: Color, design_id: String, texture: Texture2D}]
var current_print_material: StandardMaterial3D

# Drying tracking
var drying_progress = 0.0  # 0.0 to 1.0
var is_in_dryer = false

# Visual state
var original_scale = Vector3.ONE
var print_plane: MeshInstance3D

# Interaction
var interaction_area: Area3D
var is_player_nearby = false

# Cart tracking
var loaded_in_cart = false
var parent_cart = null

# Platen tracking
var mounted_on_platen = false
var parent_platen = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Cache references
	print_plane = get_node_or_null(print_plane_path)
	interaction_area = find_child("InteractionArea", true, false)
	
	if not print_plane:
		push_error("Shirt: No PrintPlane found at path: ", print_plane_path)
		push_error("Please add a MeshInstance3D child named 'PrintPlane' with PlaneMesh!")
		return
	
	if interaction_area:
		interaction_area.add_to_group("shirts")
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("Shirt: No Area3D child named 'InteractionArea' found!")
	
	# Initialize visual state
	original_scale = scale
	_setup_print_plane()
	_update_visual()
	_update_physics()
	
	# Add to shirt group
	add_to_group("shirts")
	
	print("Shirt initialized in state: ", ShirtState.keys()[current_state])
	
	#_test_print()

func _test_print():
	var arrow = load("res://textures/shirts/shirt_arrow_test.png")
	
	await get_tree().create_timer(2.0).timeout
	print("Applying print...")
	apply_print(Color.BLACK, "arrow", arrow)
	
	await get_tree().create_timer(2.0).timeout
	print("Starting dryer...")
	start_drying()
	
	# Watch it gradually become less shiny over 10 seconds!

func _process(delta):
	# Update drying progress
	if current_state == ShirtState.DRYING:
		_update_drying(delta)

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func change_state(new_state: ShirtState):
	"""Change shirt state with validation"""
	if new_state == current_state:
		return
	
	# Validate state transition
	if not _is_valid_transition(current_state, new_state):
		push_warning("Shirt: Invalid state transition from ", 
			ShirtState.keys()[current_state], " to ", ShirtState.keys()[new_state])
		return
	
	var old_state = current_state
	current_state = new_state
	
	print("Shirt state changed: ", ShirtState.keys()[old_state], " -> ", 
		ShirtState.keys()[new_state])
	
	_on_state_changed(old_state, new_state)
	state_changed.emit(old_state, new_state)

func _is_valid_transition(from: ShirtState, to: ShirtState) -> bool:
	"""Validate if state transition is allowed"""
	match from:
		ShirtState.BLANK:
			return to == ShirtState.PRINTED
		ShirtState.PRINTED:
			return to == ShirtState.DRYING
		ShirtState.DRYING:
			return to == ShirtState.DRIED
		ShirtState.DRIED:
			return to == ShirtState.FOLDED
		ShirtState.FOLDED:
			return false  # No transitions from folded state
	return false

func _on_state_changed(_old_state: ShirtState, new_state: ShirtState):
	"""Handle state change side effects"""
	_update_visual()
	_update_physics()
	
	# State-specific actions
	match new_state:
		ShirtState.PRINTED:
			print("Shirt printed with ", print_layers.size(), " layers")
		ShirtState.DRYING:
			drying_progress = 0.0
			is_in_dryer = true
		ShirtState.DRIED:
			is_in_dryer = false
			drying_complete.emit()
		ShirtState.FOLDED:
			_fold_shirt()
			folded.emit()

func get_state() -> ShirtState:
	"""Get current shirt state"""
	return current_state

func get_state_name() -> String:
	"""Get current state as string"""
	return ShirtState.keys()[current_state]

# ============================================================================
# PRINTING (SIMPLIFIED!)
# ============================================================================

func apply_print(print_color: Color, design_id: String = "", print_texture: Texture2D = null) -> bool:
	"""Apply a print to the shirt - MUCH simpler now!"""
	if current_state != ShirtState.BLANK:
		push_warning("Shirt: Can only print on blank shirts!")
		return false
	
	if not print_plane:
		push_error("Shirt: No print plane available!")
		return false
	
	# Create new material for the print
	current_print_material = StandardMaterial3D.new()
	
	if print_texture:
		# Use provided texture
		current_print_material.albedo_texture = print_texture
		current_print_material.albedo_color = print_color  # Tint the texture
	else:
		# No texture - just use solid color
		current_print_material.albedo_color = print_color
	
	# Set material properties
	current_print_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	current_print_material.roughness = wet_ink_roughness
	current_print_material.metallic = 0.0
	
	# Apply to print plane
	print_plane.material_override = current_print_material
	print_plane.visible = true
	
	# Track print data
	var print_data = {
		"color": print_color,
		"design_id": design_id,
		"texture": print_texture,
		"timestamp": Time.get_ticks_msec()
	}
	print_layers.append(print_data)
	
	print("Print applied - Color: ", print_color, ", Design: ", design_id)
	print_applied.emit(print_data)
	
	change_state(ShirtState.PRINTED)
	return true

func get_print_count() -> int:
	"""Get number of print layers"""
	return print_layers.size()

func get_print_data() -> Array:
	"""Get all print layer data"""
	return print_layers.duplicate()

# ============================================================================
# DRYING
# ============================================================================

func start_drying():
	"""Start the drying process"""
	if current_state != ShirtState.PRINTED:
		push_warning("Shirt: Can only dry printed shirts!")
		return false
	
	change_state(ShirtState.DRYING)
	print("Shirt entered dryer")
	return true

func _update_drying(delta):
	"""Update drying progress"""
	if drying_progress >= 1.0:
		_finish_drying()
		return
	
	drying_progress += delta / drying_time
	drying_progress = clamp(drying_progress, 0.0, 1.0)
	
	# Gradually change ink from glossy (wet) to matte (dry)
	if show_drying_progress and current_print_material:
		var current_roughness = lerp(wet_ink_roughness, dry_ink_roughness, drying_progress)
		current_print_material.roughness = current_roughness

func _finish_drying():
	"""Complete the drying process"""
	drying_progress = 1.0
	change_state(ShirtState.DRIED)
	print("Shirt drying complete")

func get_drying_progress() -> float:
	"""Get current drying progress (0.0 to 1.0)"""
	return drying_progress

func is_drying() -> bool:
	"""Check if shirt is currently drying"""
	return current_state == ShirtState.DRYING

# ============================================================================
# FOLDING
# ============================================================================

func fold():
	"""Fold the shirt"""
	if current_state != ShirtState.DRIED:
		push_warning("Shirt: Can only fold dried shirts!")
		return false
	
	change_state(ShirtState.FOLDED)
	return true

func _fold_shirt():
	"""Apply folding effects"""
	# Scale down
	scale = folded_scale
	
	# Make lighter
	mass = folded_mass
	
	print("Shirt folded")

func is_folded() -> bool:
	"""Check if shirt is folded"""
	return current_state == ShirtState.FOLDED

# ============================================================================
# CART MANAGEMENT
# ============================================================================

func load_into_cart(cart: Node) -> bool:
	"""Load shirt into a cart's inventory"""
	if loaded_in_cart:
		push_warning("Shirt: Already loaded in a cart!")
		return false
	
	loaded_in_cart = true
	parent_cart = cart
	
	# Disable physics when in cart
	freeze = true
	visible = false  # Hide while in cart inventory
	
	print("Shirt loaded into cart")
	return true

func unload_from_cart() -> bool:
	"""Unload shirt from cart"""
	if not loaded_in_cart:
		push_warning("Shirt: Not loaded in any cart!")
		return false
	
	loaded_in_cart = false
	parent_cart = null
	
	# Re-enable physics
	freeze = false
	visible = true
	
	print("Shirt unloaded from cart")
	return true

func is_in_cart() -> bool:
	"""Check if shirt is loaded in a cart"""
	return loaded_in_cart

func get_parent_cart():
	"""Get the cart this shirt is loaded in"""
	return parent_cart

# ============================================================================
# PLATEN MANAGEMENT
# ============================================================================

func mount_on_platen(platen: Node, platen_pos: Vector3, platen_rot: Vector3) -> bool:
	"""Mount shirt on a platen"""
	if mounted_on_platen:
		push_warning("Shirt: Already mounted on a platen!")
		return false
	
	if current_state != ShirtState.BLANK:
		push_warning("Shirt: Can only mount blank shirts on platens!")
		return false
	
	mounted_on_platen = true
	parent_platen = platen
	
	# Position on platen
	global_position = platen_pos
	global_rotation = platen_rot
	freeze = true
	
	print("Shirt mounted on platen")
	return true

func unmount_from_platen() -> bool:
	"""Unmount shirt from platen"""
	if not mounted_on_platen:
		push_warning("Shirt: Not mounted on any platen!")
		return false
	
	mounted_on_platen = false
	parent_platen = null
	freeze = false
	
	print("Shirt unmounted from platen")
	return true

func is_on_platen() -> bool:
	"""Check if shirt is mounted on a platen"""
	return mounted_on_platen

func get_parent_platen():
	"""Get the platen this shirt is mounted on"""
	return parent_platen

# ============================================================================
# VISUAL UPDATES (MUCH SIMPLER!)
# ============================================================================

func _setup_print_plane():
	"""Initialize the print plane"""
	if not print_plane:
		return
	
	# Hide the plane initially (no print yet)
	print_plane.visible = false
	
	print("Print plane initialized")

func _update_visual():
	"""Update visual appearance based on current state"""
	if not print_plane:
		return
	
	match current_state:
		ShirtState.BLANK:
			# Hide print plane - no print yet
			print_plane.visible = false
			
		ShirtState.PRINTED, ShirtState.DRYING, ShirtState.DRIED, ShirtState.FOLDED:
			# Show print plane with current material
			print_plane.visible = true
	
	print("Visual updated for state: ", ShirtState.keys()[current_state])

# ============================================================================
# PHYSICS UPDATES
# ============================================================================

func _update_physics():
	"""Update physics properties based on state"""
	match current_state:
		ShirtState.BLANK, ShirtState.PRINTED, ShirtState.DRYING, ShirtState.DRIED:
			mass = unfolded_mass
			scale = original_scale
		ShirtState.FOLDED:
			mass = folded_mass
			# Scale is set in _fold_shirt()

# ============================================================================
# INTERACTION DETECTION
# ============================================================================

func _on_body_entered(body):
	"""Detect when bodies enter interaction area"""
	if body.is_in_group("player"):
		is_player_nearby = true
		print("Player near shirt (", get_state_name(), ")")

func _on_body_exited(body):
	"""Detect when bodies exit interaction area"""
	if body.is_in_group("player"):
		is_player_nearby = false
		print("Player left shirt area")

func is_interactable() -> bool:
	"""Check if shirt can be interacted with"""
	# Can't interact with shirts in cart or on platen
	if loaded_in_cart or mounted_on_platen:
		return false
	
	# Can interact with blank or dried shirts
	return current_state in [ShirtState.BLANK, ShirtState.DRIED, ShirtState.FOLDED]

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func get_info() -> Dictionary:
	"""Get comprehensive shirt information"""
	return {
		"state": get_state_name(),
		"print_count": get_print_count(),
		"in_cart": loaded_in_cart,
		"on_platen": mounted_on_platen,
		"drying_progress": drying_progress,
		"is_folded": is_folded(),
		"interactable": is_interactable()
	}

func reset():
	"""Reset shirt to blank state"""
	current_state = ShirtState.BLANK
	print_layers.clear()
	drying_progress = 0.0
	is_in_dryer = false
	loaded_in_cart = false
	parent_cart = null
	mounted_on_platen = false
	parent_platen = null
	scale = original_scale
	mass = unfolded_mass
	
	if print_plane:
		print_plane.visible = false
	
	_update_visual()
	print("Shirt reset to blank state")
