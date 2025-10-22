# screen_rack.gd
extends Node3D

# Rack configuration
@export var num_slots = 17
@export var fallback_slot_spacing = 0.5  # Distance between slots if markers not found
@export var fallback_tilt_angle = 15.0  # Default tilt if no markers

# Slot management
var rack_slots = []  # Array to store screen references (null if empty)
var rack_slot_positions = []  # Array of Vector3 positions
var rack_slot_rotations = []  # Array of Vector3 rotations

# Interaction zone
@onready var interaction_area = $InteractionArea  # Add an Area3D child for detection

func _ready():
	_initialize_rack_slots()
	_setup_interaction_area()
	add_to_group("screen_racks")
	_preload_screens()

func _initialize_rack_slots():
	print("=== INITIALIZING SCREEN RACK ===")
	rack_slots.clear()
	rack_slot_positions.clear()
	rack_slot_rotations.clear()
	
	# Initialize arrays
	for i in range(num_slots):
		rack_slots.append(null)
	
	# Find marker positions and rotations
	for i in range(num_slots):
		var marker_name = "RackSlot" + str(i)
		var marker = find_child(marker_name, true, false)
		
		if marker:
			rack_slot_positions.append(marker.global_position)
			rack_slot_rotations.append(marker.rotation)
			print("✓ Found ", marker_name)
			print("  Position: ", marker.global_position)
			print("  Rotation: ", marker.rotation)
		else:
			# Fallback: create evenly spaced positions
			print("✗ ", marker_name, " NOT FOUND - using fallback")
			var offset = Vector3(i * fallback_slot_spacing, 0, 0)
			rack_slot_positions.append(global_position + offset)
			rack_slot_rotations.append(Vector3(deg_to_rad(fallback_tilt_angle), 0, 0))
			print("  Fallback position: ", rack_slot_positions[i])
	
	print("=== RACK INITIALIZED: ", rack_slot_positions.size(), " slots ===")

func _setup_interaction_area():
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Player near screen rack")

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("Player left screen rack")

# === CORE RACK FUNCTIONS ===

func get_nearest_empty_slot() -> int:
	"""Returns index of first empty slot, or -1 if full"""
	for i in range(num_slots):
		if rack_slots[i] == null:
			return i
	return -1

func get_nearest_filled_slot() -> int:
	"""Returns index of first filled slot, or -1 if empty"""
	for i in range(num_slots):
		if rack_slots[i] != null:
			return i
	return -1

func is_slot_filled(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= num_slots:
		return false
	return rack_slots[slot_index] != null

func get_screen_count() -> int:
	var count = 0
	for slot in rack_slots:
		if slot != null:
			count += 1
	return count

func load_screen_to_rack(screen: RigidBody3D, slot_index: int = -1) -> bool:
	"""Load a screen into the rack. If slot_index is -1, use nearest empty slot"""
	print("=== LOADING SCREEN TO RACK ===")
	
	# Auto-find empty slot if not specified
	if slot_index == -1:
		slot_index = get_nearest_empty_slot()
	
	if slot_index < 0 or slot_index >= num_slots:
		print("ERROR: Invalid slot index: ", slot_index)
		return false
	
	if rack_slots[slot_index] != null:
		print("ERROR: Slot ", slot_index, " already occupied")
		return false
	
	# Store reference
	rack_slots[slot_index] = screen
	
	# Reparent screen
	if screen.get_parent():
		screen.get_parent().remove_child(screen)
	add_child(screen)
	
	# Position and rotate using marker data
	var local_pos = to_local(rack_slot_positions[slot_index])
	screen.position = local_pos
	screen.rotation = rack_slot_rotations[slot_index]
	
	# Freeze physics
	screen.freeze = true
	screen.linear_velocity = Vector3.ZERO
	screen.angular_velocity = Vector3.ZERO
	
	print("Screen loaded to slot ", slot_index, " (", get_screen_count(), "/", num_slots, ")")
	_print_rack_status()
	return true

func remove_screen_from_rack(slot_index: int) -> RigidBody3D:
	"""Remove and return screen from specified slot"""
	print("=== REMOVING SCREEN FROM RACK ===")
	
	if slot_index < 0 or slot_index >= num_slots:
		print("ERROR: Invalid slot index: ", slot_index)
		return null
	
	if rack_slots[slot_index] == null:
		print("ERROR: Slot ", slot_index, " is empty")
		return null
	
	var screen = rack_slots[slot_index]
	rack_slots[slot_index] = null
	
	# Remove from rack but don't destroy
	remove_child(screen)
	
	print("Screen removed from slot ", slot_index, " (", get_screen_count(), "/", num_slots, ")")
	_print_rack_status()
	return screen

func _print_rack_status():
	var status = "Rack status: "
	for i in range(num_slots):
		status += str(i) + ":" + ("✓" if rack_slots[i] != null else "○") + " "
	print(status)

# === PRELOAD SCREENS ===

@export var preload_screen_scene: PackedScene  # Assign your screen.tscn in the inspector
@export var preload_count = 17  # How many screens to preload (default: fill all slots)

func _preload_screens():
	"""Automatically create and load screens into the rack at game start"""
	if not preload_screen_scene:
		print("No screen scene assigned for preloading")
		return
	
	var screens_to_load = min(preload_count, num_slots)
	print("=== PRELOADING ", screens_to_load, " SCREENS ===")
	
	for i in range(screens_to_load):
		var screen = preload_screen_scene.instantiate()
		if screen is RigidBody3D:
			if load_screen_to_rack(screen, i):
				print("Preloaded screen ", i + 1, "/", screens_to_load)
			else:
				print("Failed to preload screen ", i)
				screen.queue_free()
		else:
			print("ERROR: Preload scene is not a RigidBody3D!")
			screen.queue_free()
	
	print("=== PRELOAD COMPLETE ===")
	_print_rack_status()
