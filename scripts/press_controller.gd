# press_controller.gd
# Hybrid controller for the screen printing press
# - Rotations use boolean flags (can happen simultaneously)
# - Head lowering uses state machine (exclusive actions)

extends Node3D

#region Head State Machine (for lowering/raising only)
enum HeadState {
	IDLE,           # Head is up, normal position
	LOWERING,       # Head arm is lowering down
	LOWERED,        # Head arm is fully lowered
	RAISING         # Head arm is raising back up
}

var head_state = HeadState.IDLE
#endregion

#region Carousel References
@onready var arms_carousel = $Arms
@onready var heads_carousel = $Heads
#endregion

#region Export Variables
@export var rotation_speed = 3.0
@export var arms_rotation_delay = 0.3
@export var heads_rotation_delay = 0.3
@export var arms_snap_angle = 90.0
@export var heads_snap_angle = 60.0
@export var preload_screen_scene: PackedScene
@export var preload_screen_count = 6

# Screen positioning (fallback if markers don't exist)
@export var screen_radius = 1.5
@export var screen_height = 2.0
@export var screen_tilt_angle = 30.0

# Head lowering settings
@export var arm_rotation_speed = 3.0
@export var lowered_rotation_degrees = 30.0
#endregion

#region Position Tracking
var arms_current_position = 0
var heads_current_position = 0
#endregion

#region Arms Rotation State
var arms_target_rotation = 0.0
var is_rotating_arms = false
var arms_animation_timer = 0.0
const ANIMATION_DURATION = 1.0
#endregion

#region Heads Rotation State
var heads_target_rotation = 0.0
var heads_current_rotation = 0.0  # Internal tracker that doesn't auto-normalize
var is_rotating_heads = false
var heads_effective_speed = 1.0
var heads_animation_timer = 0.0
#endregion

#region Head Lowering State
var lowered_arm_index = -1
var lowered_rotation = 0.0  # Set in _ready()
var arm_original_rotations = {}
#endregion

#region Head Slot Management
var head_slots = [null, null, null, null, null, null]
var head_slot_positions = []
#endregion

#region Control State
var controls_enabled = false
var player_ref = null
#endregion

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	add_to_group("press")
	
	# Initialize rotation tracking
	arms_target_rotation = rad_to_deg(arms_carousel.rotation.y)
	heads_target_rotation = rad_to_deg(heads_carousel.rotation.y)
	heads_current_rotation = heads_target_rotation
	
	# Initialize head lowering
	lowered_rotation = deg_to_rad(lowered_rotation_degrees)
	
	# Initialize head slots
	_get_head_slot_markers()
	
	print("Press controller ready")
	
	# Preload screens if configured
	if preload_screen_scene and preload_screen_count > 0:
		_preload_screens()

func _process(delta):
	# Update animation timers
	if arms_animation_timer > 0:
		arms_animation_timer -= delta
	if heads_animation_timer > 0:
		heads_animation_timer -= delta
	
	# Update rotations (can both happen simultaneously)
	_update_carousel_rotations(delta)
	
	# Update head lowering/raising (uses state machine)
	_update_head_arm(delta)
	
	# Only accept input when controls are enabled
	if controls_enabled:
		_handle_input()

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _handle_input():
	var shift_pressed = Input.is_action_pressed("shift-modifier")
	
	# Head lowering/raising (only when head is IDLE or LOWERED)
	if head_state == HeadState.IDLE:
		if Input.is_action_just_pressed("move_backward") and not shift_pressed:
			if is_slot_filled(heads_current_position):
				_start_lower_head()
				return
	
	if head_state == HeadState.LOWERED:
		if Input.is_action_just_pressed("move_forward") and not shift_pressed:
			_start_raise_head()
			return
	
	# Rotation input (can happen anytime, checked by animation timers)
	if shift_pressed:
		if Input.is_action_just_pressed("move_left"):
			_start_rotate_heads_left()
		elif Input.is_action_just_pressed("move_right"):
			_start_rotate_heads_right()
	else:
		if Input.is_action_just_pressed("move_left"):
			_start_rotate_arms_left()
		elif Input.is_action_just_pressed("move_right"):
			_start_rotate_arms_right()

# ============================================================================
# ROTATION UPDATE
# ============================================================================

func _update_carousel_rotations(delta):
	"""Update both carousel rotations (can happen simultaneously)"""
	
	# Update arms rotation
	if is_rotating_arms:
		var current_rot_deg = rad_to_deg(arms_carousel.rotation.y)
		var angle_diff = arms_target_rotation - current_rot_deg
		
		# Normalize angle difference
		while angle_diff > 180:
			angle_diff -= 360
		while angle_diff < -180:
			angle_diff += 360
		
		# Smoothly rotate
		var new_rot_deg = current_rot_deg + (angle_diff * rotation_speed * delta)
		arms_carousel.rotation.y = deg_to_rad(new_rot_deg)
		
		# Check if rotation complete
		if abs(angle_diff) < 0.5:
			arms_carousel.rotation.y = deg_to_rad(arms_target_rotation)
			is_rotating_arms = false
			print("Arms rotation complete")
	
	# Update heads rotation
	if is_rotating_heads:
		var angle_diff = heads_target_rotation - heads_current_rotation
		
		# Smoothly interpolate toward target
		heads_current_rotation += angle_diff * heads_effective_speed * delta
		
		# Apply to carousel (Godot will auto-normalize this visually)
		heads_carousel.rotation.y = deg_to_rad(heads_current_rotation)
		
		# Check if rotation complete
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

# ============================================================================
# HEAD ARM UPDATE (State Machine)
# ============================================================================

func _update_head_arm(delta):
	"""Update head arm position based on state"""
	match head_state:
		HeadState.IDLE:
			pass  # Nothing to update
		
		HeadState.LOWERING:
			_update_lowering(delta)
		
		HeadState.LOWERED:
			pass  # Maintain lowered position
		
		HeadState.RAISING:
			_update_raising(delta)

func _update_lowering(delta):
	"""Animate head arm lowering"""
	if lowered_arm_index == -1:
		head_state = HeadState.IDLE
		return
	
	var arm_name = "head arm_" + str(lowered_arm_index).pad_zeros(3)
	var head_arm = _find_node_recursive(heads_carousel, arm_name)
	
	if not head_arm:
		head_state = HeadState.IDLE
		return
	
	var original_rot = arm_original_rotations.get(lowered_arm_index, 0.0)
	var target_rotation = original_rot + lowered_rotation
	
	head_arm.rotation.x = lerp_angle(head_arm.rotation.x, target_rotation, arm_rotation_speed * delta)
	
	# Check if animation complete
	if abs(head_arm.rotation.x - target_rotation) < 0.01:
		head_arm.rotation.x = target_rotation
		print("Head arm fully lowered")
		head_state = HeadState.LOWERED

func _update_raising(delta):
	"""Animate head arm raising"""
	if lowered_arm_index == -1:
		head_state = HeadState.IDLE
		return
	
	var arm_name = "head arm_" + str(lowered_arm_index).pad_zeros(3)
	var head_arm = _find_node_recursive(heads_carousel, arm_name)
	
	if not head_arm:
		head_state = HeadState.IDLE
		return
	
	var original_rot = arm_original_rotations.get(lowered_arm_index, 0.0)
	var target_rotation = original_rot
	
	head_arm.rotation.x = lerp_angle(head_arm.rotation.x, target_rotation, arm_rotation_speed * delta)
	
	# Check if animation complete
	if abs(head_arm.rotation.x - target_rotation) < 0.01:
		head_arm.rotation.x = target_rotation
		lowered_arm_index = -1
		print("Head arm fully raised")
		head_state = HeadState.IDLE

# ============================================================================
# ROTATION COMMANDS
# ============================================================================

func _start_rotate_arms_left():
	"""Begin rotating arms carousel left"""
	# Can't rotate arms while head is down
	if head_state != HeadState.IDLE:
		print("Cannot rotate arms while head is lowered")
		return
	
	# Only check animation timer (allows interrupting carousel rotation)
	if arms_animation_timer > 0:
		return
	
	# Play player animation
	if player_ref:
		player_ref.play_press_animation("Push_Arms_Left")
	
	# Start animation timer
	arms_animation_timer = ANIMATION_DURATION
	
	# Wait for delay, then start rotation
	await get_tree().create_timer(arms_rotation_delay).timeout
	
	# Update position and target
	arms_current_position = (arms_current_position - 1) % 4
	arms_target_rotation -= arms_snap_angle
	is_rotating_arms = true
	
	print("Rotating arms left to position: ", arms_current_position)

func _start_rotate_arms_right():
	"""Begin rotating arms carousel right"""
	# Can't rotate arms while head is down
	if head_state != HeadState.IDLE:
		print("Cannot rotate arms while head is lowered")
		return
	
	# Only check animation timer
	if arms_animation_timer > 0:
		return
	
	# Play player animation
	if player_ref:
		player_ref.play_press_animation("Push_Arms_Right")
	
	# Start animation timer
	arms_animation_timer = ANIMATION_DURATION
	
	# Wait for delay, then start rotation
	await get_tree().create_timer(arms_rotation_delay).timeout
	
	# Update position and target
	arms_current_position = (arms_current_position + 1) % 4
	arms_target_rotation += arms_snap_angle
	is_rotating_arms = true
	
	print("Rotating arms right to position: ", arms_current_position)

func _start_rotate_heads_left():
	"""Begin rotating heads carousel left (clockwise)"""
	# Can't rotate heads while head is down
	if head_state != HeadState.IDLE:
		print("Cannot rotate heads while head is lowered")
		return
	
	# Only check animation timer
	if heads_animation_timer > 0:
		return
	
	# Check if rotation is possible
	if not can_rotate_heads_left():
		print("Cannot rotate heads left - no screens loaded")
		return
	
	# Start animation timer
	heads_animation_timer = ANIMATION_DURATION
	
	# Find next filled slot
	var target_slot = find_next_filled_slot_left(heads_current_position)
	if target_slot == -1:
		print("ERROR: No filled slots found but get_loaded_screen_count > 0")
		return
	
	# Calculate rotation steps
	var steps = (target_slot - heads_current_position + 6) % 6
	if steps == 0:
		steps = 6  # Full rotation if same slot (only 1 screen)
	
	heads_effective_speed = rotation_speed / steps
	
	print("Rotating heads left from slot ", heads_current_position, " to slot ", target_slot, " (", steps, " steps)")
	
	# Play player animation
	if player_ref:
		player_ref.play_press_animation("Push_Heads_Right")
	
	# Wait for delay, then start rotation
	await get_tree().create_timer(heads_rotation_delay).timeout
	
	# Update position and target
	heads_current_position = target_slot
	heads_target_rotation -= heads_snap_angle * steps
	is_rotating_heads = true
	
	print("Target rotation set to: ", heads_target_rotation)

func _start_rotate_heads_right():
	"""Begin rotating heads carousel right (counter-clockwise)"""
	# Can't rotate heads while head is down
	if head_state != HeadState.IDLE:
		print("Cannot rotate heads while head is lowered")
		return
	
	# Only check animation timer
	if heads_animation_timer > 0:
		return
	
	# Check if rotation is possible
	if not can_rotate_heads_right():
		print("Cannot rotate heads right - no screens loaded")
		return
	
	# Start animation timer
	heads_animation_timer = ANIMATION_DURATION
	
	# Find next filled slot
	var target_slot = find_next_filled_slot_right(heads_current_position)
	if target_slot == -1:
		print("ERROR: No filled slots found but get_loaded_screen_count > 0")
		return
	
	# Calculate rotation steps
	var steps = (heads_current_position - target_slot + 6) % 6
	if steps == 0:
		steps = 6  # Full rotation if same slot (only 1 screen)
	
	heads_effective_speed = rotation_speed / steps
	
	print("Rotating heads right from slot ", heads_current_position, " to slot ", target_slot, " (", steps, " steps)")
	
	# Play player animation
	if player_ref:
		player_ref.play_press_animation("Push_Heads_Left")
	
	# Wait for delay, then start rotation
	await get_tree().create_timer(heads_rotation_delay).timeout
	
	# Update position and target
	heads_current_position = target_slot
	heads_target_rotation += heads_snap_angle * steps
	is_rotating_heads = true
	
	print("Target rotation set to: ", heads_target_rotation)

# ============================================================================
# HEAD LOWERING COMMANDS
# ============================================================================

func _start_lower_head():
	"""Begin lowering the current head"""
	var arm_name = "head arm_" + str(heads_current_position).pad_zeros(3)
	var head_arm = _find_node_recursive(heads_carousel, arm_name)
	
	if head_arm and head_arm is MeshInstance3D:
		# Store original rotation if not already stored
		if not arm_original_rotations.has(heads_current_position):
			arm_original_rotations[heads_current_position] = head_arm.rotation.x
		
		lowered_arm_index = heads_current_position
		print("Lowering head arm: ", arm_name)
		print("Original rotation: ", rad_to_deg(arm_original_rotations[heads_current_position]))
		
		head_state = HeadState.LOWERING
	else:
		print("ERROR: Could not find head arm: ", arm_name)

func _start_raise_head():
	"""Begin raising the current head"""
	if lowered_arm_index == -1:
		return
	
	var arm_name = "head arm_" + str(lowered_arm_index).pad_zeros(3)
	print("Raising head arm: ", arm_name)
	
	head_state = HeadState.RAISING

# ============================================================================
# CONTROL STATE
# ============================================================================

func enable_controls(player = null):
	"""Enable player control of the press"""
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
	"""Disable player control of the press"""
	controls_enabled = false
	player_ref = null
	print("Press controls disabled")

# ============================================================================
# HEAD SLOT QUERIES
# ============================================================================

func get_nearest_empty_slot() -> int:
	"""Find the nearest empty slot"""
	for i in range(6):
		if head_slots[i] == null:
			return i
	return -1

func is_slot_filled(slot_index: int) -> bool:
	"""Check if a slot has a screen"""
	if slot_index < 0 or slot_index >= 6:
		return false
	return head_slots[slot_index] != null

func can_rotate_heads_left() -> bool:
	"""Check if heads can rotate left"""
	return get_loaded_screen_count() > 0

func can_rotate_heads_right() -> bool:
	"""Check if heads can rotate right"""
	return get_loaded_screen_count() > 0

func find_next_filled_slot_left(start_slot: int) -> int:
	"""Find the next filled slot going left (clockwise)"""
	for i in range(1, 7):
		var check_slot = (start_slot + i) % 6
		if is_slot_filled(check_slot):
			return check_slot
	return -1

func find_next_filled_slot_right(start_slot: int) -> int:
	"""Find the next filled slot going right (counter-clockwise)"""
	for i in range(1, 7):
		var check_slot = (start_slot - i + 6) % 6
		if is_slot_filled(check_slot):
			return check_slot
	return -1

func find_nearest_filled_slot(start_slot: int) -> int:
	"""Find the nearest filled slot in either direction"""
	for distance in range(1, 7):
		# Check clockwise
		var clockwise = (start_slot + distance) % 6
		if is_slot_filled(clockwise):
			return clockwise
		# Check counter-clockwise
		var counter = (start_slot - distance + 6) % 6
		if is_slot_filled(counter):
			return counter
	return -1

func get_loaded_screen_count() -> int:
	"""Count how many screens are loaded"""
	var count = 0
	for slot in head_slots:
		if slot != null:
			count += 1
	return count

# ============================================================================
# SCREEN MANAGEMENT
# ============================================================================

func get_front_screen() -> RigidBody3D:
	"""Returns the screen currently in front of the player"""
	var front_slot_index = heads_current_position
	
	if head_slots[front_slot_index] != null:
		return head_slots[front_slot_index]
	
	return null

func remove_front_screen() -> RigidBody3D:
	"""Removes and returns the screen in front of the player"""
	var front_slot_index = heads_current_position
	
	if head_slots[front_slot_index] == null:
		print("No screen to remove from slot: ", front_slot_index)
		return null
	
	var screen = head_slots[front_slot_index]
	head_slots[front_slot_index] = null
	
	# Remove from its current parent
	var current_parent = screen.get_parent()
	if current_parent:
		current_parent.remove_child(screen)
		print("Removed screen from: ", current_parent.name)
	else:
		print("WARNING: Screen has no parent")
	
	print("Removed screen from slot: ", front_slot_index)
	_print_slot_status()
	
	return screen

func load_screen_to_slot(screen: RigidBody3D, slot_index: int) -> bool:
	"""Load a screen into a specific slot"""
	print("=== LOADING SCREEN TO SLOT ", slot_index, " ===")
	
	if slot_index < 0 or slot_index >= 6:
		print("ERROR: Invalid slot index: ", slot_index)
		return false
	
	if head_slots[slot_index] != null:
		print("ERROR: Slot ", slot_index, " already occupied")
		return false
	
	# Store in slot array
	head_slots[slot_index] = screen
	
	# Remove from current parent
	if screen.get_parent():
		screen.get_parent().remove_child(screen)
	
	# Find the head node for this slot
	var head_name = "head_" + str(slot_index).pad_zeros(3)
	var head_node = _find_node_recursive(heads_carousel, head_name)
	
	if not head_node:
		print("ERROR: Could not find head node: ", head_name)
		return false
	
	# Add to head node
	head_node.add_child(screen)
	
	# Position using marker
	var marker_name = "ScreenSlot" + str(slot_index)
	var marker = _find_node_recursive(heads_carousel, marker_name)
	
	if marker:
		screen.position = marker.position
		screen.rotation = marker.rotation
	else:
		print("ERROR: No marker found for slot ", slot_index)
		screen.position = Vector3.ZERO
		screen.rotation = Vector3(deg_to_rad(screen_tilt_angle), 0, 0)
	
	screen.freeze = true
	
	print("Loaded screen into slot ", slot_index, " (", get_loaded_screen_count(), "/6 screens)")
	_print_slot_status()
	print("=== SCREEN LOADING COMPLETE ===")
	
	return true

# ============================================================================
# INITIALIZATION
# ============================================================================

func _get_head_slot_markers():
	"""Initialize head slot marker positions"""
	print("=== INITIALIZING HEAD SLOT MARKERS ===")
	head_slot_positions.clear()
	
	for i in range(6):
		var marker_name = "ScreenSlot" + str(i)
		var marker = _find_node_recursive(heads_carousel, marker_name)
		
		if marker:
			head_slot_positions.append(marker.global_position)
			print("✓ Found ", marker_name)
		else:
			print("✗ ", marker_name, " NOT FOUND - using calculated fallback")
			var angle = deg_to_rad(i * heads_snap_angle)
			var x = screen_radius * sin(angle)
			var z = screen_radius * cos(angle)
			var slot_pos = heads_carousel.global_position + Vector3(x, screen_height, z)
			head_slot_positions.append(slot_pos)
	
	print("=== INITIALIZATION COMPLETE: ", head_slot_positions.size(), " positions loaded ===")

func _preload_screens():
	"""Load screens into the press at startup"""
	print("=== PRELOADING SCREENS INTO PRESS ===")
	await get_tree().process_frame
	
	for i in range(min(preload_screen_count, 6)):
		var screen = preload_screen_scene.instantiate()
		if screen is RigidBody3D:
			get_tree().get_root().add_child(screen)
			if load_screen_to_slot(screen, i):
				print("Preloaded screen ", i + 1, "/", preload_screen_count)
			else:
				print("Failed to preload screen into slot ", i)
				screen.queue_free()
		else:
			print("ERROR: Preload scene is not a RigidBody3D!")
			screen.queue_free()
	
	print("=== PRELOAD COMPLETE ===")

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _find_node_recursive(node: Node, target_name: String) -> Node:
	"""Recursively search for a node by name"""
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	
	return null

func _print_slot_status():
	"""Print current slot occupation status"""
	var status = "Slot status: "
	for i in range(6):
		status += str(i) + ":" + ("✓" if head_slots[i] != null else "○") + " "
	print(status)
