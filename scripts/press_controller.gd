# press_controller.gd
extends Node3D

# Carousel references
@onready var arms_carousel = $Arms
@onready var heads_carousel = $Heads

# Rotation settings
@export var rotation_speed = 3.0
@export var arms_rotation_delay = 0.3
@export var heads_rotation_delay = 0.3
@export var arms_snap_angle = 90.0
@export var heads_snap_angle = 60.0

# Screen positioning (fallback if markers don't exist)
@export var screen_radius = 1.5
@export var screen_height = 2.0
@export var screen_tilt_angle = 30.0

# Current rotation state
var arms_current_position = 0
var heads_current_position = 0
var arms_target_rotation = 0.0
var heads_target_rotation = 0.0
var heads_current_rotation = 0.0  # Internal tracker that doesn't auto-normalize
var is_rotating_arms = false
var is_rotating_heads = false
var heads_effective_speed = 1
var arms_animation_timer = 0.0
var heads_animation_timer = 0.0
const ANIMATION_DURATION = 1.0  # Your animations are 1 second


# Head slot management
var head_slots = [null, null, null, null, null, null]
var head_slot_positions = []

# Control state
var controls_enabled = false
var player_ref = null

func _ready():
	arms_target_rotation = rad_to_deg(arms_carousel.rotation.y)
	heads_target_rotation = rad_to_deg(heads_carousel.rotation.y)
	heads_current_rotation = heads_target_rotation  # Initialize internal tracker
	_get_head_slot_markers()
	print("Press controller ready")

func _process(delta):
	# Update animation timers
	if arms_animation_timer > 0:
		arms_animation_timer -= delta
	if heads_animation_timer > 0:
		heads_animation_timer -= delta

	_update_carousel_rotations(delta)
	
	if not controls_enabled:
		return
	
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		print("Press controller received input")
	
	_handle_input()

func _handle_input():
	var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
	
	if shift_pressed:
		if Input.is_action_just_pressed("move_left"):
			rotate_heads_left()
		elif Input.is_action_just_pressed("move_right"):
			rotate_heads_right()
	else:
		if Input.is_action_just_pressed("move_left"):
			rotate_arms_left()
		elif Input.is_action_just_pressed("move_right"):
			rotate_arms_right()

func rotate_arms_left():
	# Allow input only if animation is complete (even if carousel still rotating)
	if arms_animation_timer > 0:
		return
	
	if player_ref:
		player_ref.play_press_animation("Push_Arms_Left")
		
	# Start animation timer
	arms_animation_timer = ANIMATION_DURATION
	
	await get_tree().create_timer(arms_rotation_delay).timeout
	
	arms_current_position = (arms_current_position - 1) % 4
	arms_target_rotation -= arms_snap_angle
	is_rotating_arms = true
	print("Rotating arms to position: ", arms_current_position)

func rotate_arms_right():
	# Allow input only if animation is complete (even if carousel still rotating)
	if arms_animation_timer > 0:
		return
	
	if player_ref:
		player_ref.play_press_animation("Push_Arms_Right")
		
	# Start animation timer
	arms_animation_timer = ANIMATION_DURATION
	
	await get_tree().create_timer(arms_rotation_delay).timeout
	
	arms_current_position = (arms_current_position + 1) % 4
	arms_target_rotation += arms_snap_angle
	is_rotating_arms = true
	print("Rotating arms to position: ", arms_current_position)

func rotate_heads_left():
	# Allow input only if animation is complete (even if carousel still rotating)
	if heads_animation_timer > 0:
		return
	
	if not can_rotate_heads_left():
		print("Cannot rotate heads left - no screens loaded")
		return
	
	# Start animation timer
	heads_animation_timer = ANIMATION_DURATION
	
	# Find the next filled slot going left (clockwise)
	var target_slot = find_next_filled_slot_left(heads_current_position)
	if target_slot == -1:
		print("ERROR: No filled slots found but get_loaded_screen_count > 0")
		return
	
	# Calculate how many positions to rotate
	var steps = (target_slot - heads_current_position + 6) % 6
	if steps == 0:
		steps = 6  # Full rotation if same slot (only 1 screen)
		
	heads_effective_speed = rotation_speed / steps
	
	print("Rotating left from slot ", heads_current_position, " to slot ", target_slot, " (", steps, " steps)")
	
	if player_ref:
		player_ref.play_press_animation("Push_Heads_Right")
	
	await get_tree().create_timer(heads_rotation_delay).timeout
	
	# Update position and rotation
	heads_current_position = target_slot
	heads_target_rotation -= heads_snap_angle * steps
	is_rotating_heads = true
	print("Target rotation set to: ", heads_target_rotation)

func rotate_heads_right():
	# Allow input only if animation is complete (even if carousel still rotating)
	if heads_animation_timer > 0:
		return
	
	if not can_rotate_heads_right():
		print("Cannot rotate heads right - no screens loaded")
		return
		
	# Start animation timer
	heads_animation_timer = ANIMATION_DURATION
	
	# Find the next filled slot going right (counter-clockwise)
	var target_slot = find_next_filled_slot_right(heads_current_position)
	if target_slot == -1:
		print("ERROR: No filled slots found but get_loaded_screen_count > 0")
		return
	
	# Calculate how many positions to rotate
	var steps = (heads_current_position - target_slot + 6) % 6
	if steps == 0:
		steps = 6  # Full rotation if same slot (only 1 screen)
		
	heads_effective_speed = rotation_speed / steps
	
	print("Rotating right from slot ", heads_current_position, " to slot ", target_slot, " (", steps, " steps)")
	
	if player_ref:
		player_ref.play_press_animation("Push_Heads_Left")
	
	await get_tree().create_timer(heads_rotation_delay).timeout
	
	# Update position and rotation
	heads_current_position = target_slot
	heads_target_rotation += heads_snap_angle * steps
	is_rotating_heads = true
	print("Target rotation set to: ", heads_target_rotation)

func _update_carousel_rotations(delta):
	if is_rotating_arms:
		var current_rot_deg = rad_to_deg(arms_carousel.rotation.y)
		var angle_diff = arms_target_rotation - current_rot_deg
		
		while angle_diff > 180:
			angle_diff -= 360
		while angle_diff < -180:
			angle_diff += 360
		
		var new_rot_deg = current_rot_deg + (angle_diff * rotation_speed * delta)
		arms_carousel.rotation.y = deg_to_rad(new_rot_deg)
		
		if abs(angle_diff) < 0.5:
			arms_carousel.rotation.y = deg_to_rad(arms_target_rotation)
			is_rotating_arms = false
			print("Arms rotation complete")
	
	if is_rotating_heads:
		# Use internal rotation tracker instead of reading from carousel
		var angle_diff = heads_target_rotation - heads_current_rotation
		
		# Smoothly interpolate toward target
		heads_current_rotation += angle_diff * heads_effective_speed * delta
		
		# Apply to carousel (Godot will auto-normalize this visually)
		heads_carousel.rotation.y = deg_to_rad(heads_current_rotation)
		
		if abs(angle_diff) < 0.5:
			heads_current_rotation = heads_target_rotation
			heads_carousel.rotation.y = deg_to_rad(heads_target_rotation)
			# Normalize both after completion
			while heads_target_rotation <= -180:
				heads_target_rotation += 360
				heads_current_rotation += 360
			while heads_target_rotation > 180:
				heads_target_rotation -= 360
				heads_current_rotation -= 360
			is_rotating_heads = false
			print("Heads rotation complete - normalized to: ", heads_target_rotation)

func enable_controls(player = null):
	controls_enabled = true
	player_ref = player
	print("Press controls enabled")
	if not player_ref:
		print("WARNING: No player reference passed to enable_controls!")
	
	# Auto-rotate to nearest screen if current position is empty
	if get_loaded_screen_count() > 0 and not is_slot_filled(heads_current_position):
		print("No screen in current position - auto-rotating to nearest screen")
		var nearest = find_nearest_filled_slot(heads_current_position)
		if nearest != -1:
			# Calculate how many steps to rotate
			var steps_clockwise = (nearest - heads_current_position + 6) % 6
			var steps_counter = (heads_current_position - nearest + 6) % 6
			
			# Choose the shorter direction
			if steps_clockwise <= steps_counter:
				# Rotate clockwise (left)
				for i in range(steps_clockwise):
					heads_current_position = (heads_current_position + 1) % 6
					heads_target_rotation -= heads_snap_angle
			else:
				# Rotate counter-clockwise (right)
				for i in range(steps_counter):
					heads_current_position = (heads_current_position - 1 + 6) % 6
					heads_target_rotation += heads_snap_angle
			
			is_rotating_heads = true
			print("Auto-rotated to slot: ", heads_current_position)

func disable_controls():
	controls_enabled = false
	player_ref = null
	print("Press controls disabled")

func _get_head_slot_markers():
	print("=== INITIALIZING HEAD SLOT MARKERS ===")
	head_slot_positions.clear()
	
	print("Looking for markers in: ", heads_carousel.name)
	print("Heads carousel children: ", heads_carousel.get_children())
	
	for i in range(6):
		var marker_name = "ScreenSlot" + str(i)
		# Search recursively through all descendants
		var marker = _find_node_recursive(heads_carousel, marker_name)
		
		if marker:
			head_slot_positions.append(marker.global_position)
			print("✓ Found ", marker_name)
			print("  Path: ", marker.get_path())
			print("  Global position: ", marker.global_position)
			print("  Local position: ", marker.position)
			print("  Rotation: ", marker.rotation)
		else:
			print("✗ ", marker_name, " NOT FOUND - using calculated fallback")
			var angle = deg_to_rad(i * heads_snap_angle)
			var x = screen_radius * sin(angle)
			var z = screen_radius * cos(angle)
			var slot_pos = heads_carousel.global_position + Vector3(x, screen_height, z)
			head_slot_positions.append(slot_pos)
			print("  Calculated position: ", slot_pos)
	
	print("=== INITIALIZATION COMPLETE: ", head_slot_positions.size(), " positions loaded ===")
	print("")

func _find_node_recursive(node: Node, target_name: String) -> Node:
	"""Recursively search for a node by name in all descendants"""
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	
	return null

func get_nearest_empty_slot() -> int:
	for i in range(6):
		if head_slots[i] == null:
			return i
	return -1

func is_slot_filled(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= 6:
		return false
	return head_slots[slot_index] != null
	
func can_rotate_heads_left() -> bool:
	# Can rotate as long as there's at least one screen loaded
	return get_loaded_screen_count() > 0

func can_rotate_heads_right() -> bool:
	# Can rotate as long as there's at least one screen loaded
	return get_loaded_screen_count() > 0

func find_next_filled_slot_left(start_slot: int) -> int:
	"""Find the next filled slot going left (clockwise, increasing slot numbers)"""
	for i in range(1, 7):  # Check all 6 slots
		var check_slot = (start_slot + i) % 6
		if is_slot_filled(check_slot):
			return check_slot
	return -1  # No filled slots found

func find_next_filled_slot_right(start_slot: int) -> int:
	"""Find the next filled slot going right (counter-clockwise, decreasing slot numbers)"""
	for i in range(1, 7):  # Check all 6 slots
		var check_slot = (start_slot - i + 6) % 6
		if is_slot_filled(check_slot):
			return check_slot
	return -1  # No filled slots found

func find_nearest_filled_slot(start_slot: int) -> int:
	"""Find the nearest filled slot in either direction"""
	# Check both directions and return the closest one
	for distance in range(1, 7):
		# Check clockwise
		var clockwise = (start_slot + distance) % 6
		if is_slot_filled(clockwise):
			return clockwise
		# Check counter-clockwise
		var counter = (start_slot - distance + 6) % 6
		if is_slot_filled(counter):
			return counter
	return -1  # No filled slots found

func get_loaded_screen_count() -> int:
	var count = 0
	for slot in head_slots:
		if slot != null:
			count += 1
	return count

func get_front_screen() -> RigidBody3D:
	"""Returns the screen currently in front of the player"""
	# The slot in front is simply the current position!
	var front_slot_index = heads_current_position
	
	print("=== GET FRONT SCREEN DEBUG ===")
	print("heads_current_position: ", heads_current_position)
	print("front_slot_index: ", front_slot_index)
	print("heads_target_rotation: ", heads_target_rotation)
	print("heads actual rotation (deg): ", rad_to_deg(heads_carousel.rotation.y))
	
	for i in range(6):
		if head_slots[i] != null:
			print("Slot ", i, " has a screen")
	
	if head_slots[front_slot_index] != null:
		print("Screen found in front slot: ", front_slot_index)
		return head_slots[front_slot_index]
	
	print("No screen in front slot: ", front_slot_index)
	return null

func remove_front_screen() -> RigidBody3D:
	"""Removes and returns the screen in front of the player"""
	var front_slot_index = heads_current_position
	
	if head_slots[front_slot_index] == null:
		print("No screen to remove from slot: ", front_slot_index)
		return null
	
	var screen = head_slots[front_slot_index]
	head_slots[front_slot_index] = null
	
	# Remove from carousel
	heads_carousel.remove_child(screen)
	
	print("Removed screen from slot: ", front_slot_index)
	
	var loaded_count = get_loaded_screen_count()
	print("Screens remaining: ", loaded_count, "/6")
	
	var slot_status = "Slot status: "
	for i in range(6):
		slot_status += str(i) + ":" + ("✓" if head_slots[i] != null else "○") + " "
	print(slot_status)
	
	return screen

func load_screen_to_slot(screen: RigidBody3D, slot_index: int):
	print("=== LOADING SCREEN TO SLOT ", slot_index, " ===")
	
	if slot_index < 0 or slot_index >= 6:
		print("ERROR: Invalid slot index: ", slot_index)
		return false
	
	if head_slots[slot_index] != null:
		print("ERROR: Slot ", slot_index, " already occupied")
		return false
	
	head_slots[slot_index] = screen
	print("Screen stored in slot array")
	
	if screen.get_parent():
		print("Removing screen from parent: ", screen.get_parent().name)
		screen.get_parent().remove_child(screen)
	
	print("Adding screen to heads_carousel: ", heads_carousel.name)
	heads_carousel.add_child(screen)
	
	# Find the marker and use its current transform directly
	var marker_name = "ScreenSlot" + str(slot_index)
	var marker = _find_node_recursive(heads_carousel, marker_name)
	if marker:
		print("Found marker: ", marker_name)
		print("Marker global position: ", marker.global_position)
		print("Marker local rotation: ", marker.rotation)
		
		# Convert marker's global position to local position relative to heads_carousel
		var local_pos = heads_carousel.to_local(marker.global_position)
		screen.position = local_pos
		screen.rotation = marker.rotation
		print("Using marker transform - Position: ", screen.position, " Rotation: ", screen.rotation)
	else:
		print("No marker found, using fallback position")
		# Fallback: calculate position based on slot index
		var angle = deg_to_rad(slot_index * heads_snap_angle)
		var x = screen_radius * sin(angle)
		var z = screen_radius * cos(angle)
		screen.position = Vector3(x, screen_height, z)
		screen.rotation = Vector3(deg_to_rad(screen_tilt_angle), 0, 0)
		print("Using calculated transform - Position: ", screen.position)
	
	screen.freeze = true
	print("Screen frozen")
	
	var loaded_count = get_loaded_screen_count()
	print("Loaded screen into slot ", slot_index, " (", loaded_count, "/6 screens)")
	
	var slot_status = "Slot status: "
	for i in range(6):
		slot_status += str(i) + ":" + ("✓" if head_slots[i] != null else "○") + " "
	print(slot_status)
	print("=== SCREEN LOADING COMPLETE ===")
	
	return true
