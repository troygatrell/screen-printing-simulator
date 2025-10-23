# player.gd

extends CharacterBody3D

#region Export Variables
@export var speed: int
@export var gravity = 9.8
@export var camera_smooth_speed = 5
@export var rotation_speed = 10.0
@export var cart_collision_size = Vector3(1.0, 1.5, 1.0)
@export var cart_collision_position = Vector3(0, 0.75, -1.2)
@export var screen_collision_size = Vector3(0.6, 0.8, 0.8)
@export var screen_collision_position = Vector3(0, 1.5, -0.8)
#endregion

#region Cart Pushing State Variables
var handle_in_range = null
var pushed_cart = null
var original_cart_collision_layer = 0
var original_cart_collision_mask = 0
#endregion

#region Screen Carrying State
var screen_in_range = null
var carried_screen = null
var original_screen_collision_layer = 0
var original_screen_collision_mask = 0
#endregion

#region Screen Rack State
var screen_rack_in_range = null
var transitioning_from_rack = false
var rack_exit_target_position = Vector3.ZERO
var rack_exit_target_rotation = Vector3.ZERO

#endregion

#region Print Mode State
var in_print_mode = false
var current_print_zone = null
var print_mode_camera_target = Vector3.ZERO
var transitioning_to_print = false
var transitioning_from_print = false
var exit_target_position = Vector3.ZERO
var exit_target_rotation = Vector3.ZERO
var print_target_position = Vector3.ZERO
var print_target_rotation = Vector3.ZERO
#endregion

#region Extended Collision
var extended_collision = null
#endregion

#region Node References
@onready var camera = get_viewport().get_camera_3d()
@onready var initial_camera_offset = camera.global_position - global_position
@onready var camera_offset = initial_camera_offset
@onready var animation_tree = $Model/AnimationTree
@onready var animation_state = animation_tree.get("parameters/playback")
@onready var grab_zone = $GrabZone
#endregion

func _ready():
	grab_zone.area_entered.connect(_on_grab_zone_area_entered)
	grab_zone.area_exited.connect(_on_grab_zone_area_exited)
	
	add_to_group("player")

func _unhandled_input(event):
	# Check for Shift+E to remove screen from press
	if event.is_action_pressed("interact") and Input.is_action_pressed("shift-modifier"):
		if in_print_mode and not carried_screen:
			_remove_screen_from_head()
			return
	
	if event.is_action_pressed("interact"):
		print("Interact pressed")
		print("State: in_print_mode=", in_print_mode, " carried_screen=", carried_screen)
		
		# Exit print mode or load screen
		if in_print_mode:
			if carried_screen:
				_load_screen_to_head()
				return
			# Start transition out of print mode
			in_print_mode = false
			transitioning_from_print = true
			# Move player backwards
			exit_target_rotation = global_rotation + Vector3(0, PI, 0)
			exit_target_position = global_position + global_transform.basis.z * 0.5
			animation_state.travel("Walk")
			print("Starting exit transition")
			return
		
		# Screen rack interaction: store screen
		if screen_rack_in_range and carried_screen:
			_store_screen_to_rack()
			return
			
		if screen_rack_in_range and not carried_screen:
			_retrieve_screen_from_rack()
			return
		
		# Cart release
		if pushed_cart:
			if extended_collision:
				remove_child(extended_collision)
				extended_collision.queue_free()
				extended_collision = null
			pushed_cart.collision_layer = original_cart_collision_layer
			pushed_cart.collision_mask = original_cart_collision_mask
			var cart_zones = get_tree().get_nodes_in_group("cart_zones")
			for zone in cart_zones:
				if zone.is_cart_in_snap_range(pushed_cart):
					zone.snap_cart_to_zone(pushed_cart)
					break
			pushed_cart.linear_velocity = Vector3.ZERO
			pushed_cart.angular_velocity = Vector3.ZERO
			pushed_cart.freeze = false
			pushed_cart = null
			print("Released cart")
			return
		
		# Cart grab
		if handle_in_range:
			pushed_cart = handle_in_range.get_parent()
			original_cart_collision_layer = pushed_cart.collision_layer
			original_cart_collision_mask = pushed_cart.collision_mask
			pushed_cart.collision_layer = 0
			pushed_cart.collision_mask = 0
			pushed_cart.freeze = true
			pushed_cart.linear_velocity = Vector3.ZERO
			pushed_cart.angular_velocity = Vector3.ZERO
			_create_extended_collision()
			print("Grabbed cart")
			return
		
		# Screen pickup (allow even if in print zone, just not in print mode yet)
		if screen_in_range and not carried_screen:
			print("Picking up screen")
			_pickup_screen()
			return
		
		# Screen drop (only if NOT in print zone or print mode)
		var print_zones = get_tree().get_nodes_in_group("print_zones")
		var in_print_zone = false
		for zone in print_zones:
			if zone.is_player_in_zone():
				in_print_zone = true
				break
		
		if carried_screen and not in_print_zone and not screen_rack_in_range:
			print("Can't drop screen here! Must be at press or screen rack")
			return
		
		# Enter print zone (allow even if carrying screen)
# Enter print zone (allow even if carrying screen)
		if in_print_zone:
			for zone in print_zones:
				if zone.is_player_in_zone():
					current_print_zone = zone
					print_target_position = zone.global_position + zone.snap_offset
					print_target_rotation = zone.snap_rotation
			
				# Remove extended collision BEFORE transitioning if carrying screen
				if carried_screen and extended_collision:
					remove_child(extended_collision)
					extended_collision.queue_free()
					extended_collision = null
					print("Removed extended collision before print transition")
			
				transitioning_to_print = true
				if carried_screen:
					animation_state.travel("Walk_Screen")
				else:
					animation_state.travel("Walk")
				print("=== STARTING TRANSITION ===")
				print("Current position: ", global_position)
				print("Target position: ", print_target_position)
				print("Distance: ", global_position.distance_to(print_target_position))
				print("Entered print mode")
			
			return
func _create_extended_collision(collision_type: String = "cart"):
	extended_collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	if collision_type == "screen":
		box_shape.size = screen_collision_size
		extended_collision.shape = box_shape
		extended_collision.position = screen_collision_position
	else:  # default to cart
		box_shape.size = cart_collision_size
		extended_collision.shape = box_shape
		extended_collision.position = cart_collision_position
	
	add_child(extended_collision)	
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Smooth transition to print position
	if transitioning_to_print:
		print("TRANSITIONING - Distance: ", global_position.distance_to(print_target_position))
		global_position = global_position.lerp(print_target_position, 3.0 * delta)
		global_rotation = global_rotation.lerp(print_target_rotation, 3.0 * delta)
		velocity = Vector3.ZERO
		if global_position.distance_to(print_target_position) < 0.15:
			transitioning_to_print = false
			in_print_mode = true
			global_position = print_target_position
			global_rotation = print_target_rotation
			animation_state.travel("Idle")
			current_print_zone.apply_camera_zoom()
			print_mode_camera_target = current_print_zone.get_camera_target_position()
			var press = get_tree().get_first_node_in_group("press")
			if press:
				press.enable_controls(self)
			
			# If carrying a screen, load it after transition completes
			if carried_screen:
				_load_screen_to_head()
				print("Screen loaded")
			print("Entered print mode")
	# Smooth transition when leaving print mode
	elif transitioning_from_print:
		global_position = global_position.lerp(exit_target_position, 3.0 * delta)
		global_rotation = global_rotation.lerp(exit_target_rotation, 3.0 * delta)
		velocity = Vector3.ZERO
		if global_position.distance_to(exit_target_position) < 0.15:
			transitioning_from_print = false
			global_position = exit_target_position
			animation_state.travel("Idle")
			if current_print_zone:
				current_print_zone.restore_camera_zoom()
			var press = get_tree().get_first_node_in_group("press")
			if press:
				press.disable_controls()
			current_print_zone = null
			print("Exit transition complete")
	# Smooth transition when leaving screen rack
	elif transitioning_from_rack:
		global_position = global_position.lerp(rack_exit_target_position, 3.0 * delta)
		global_rotation = global_rotation.lerp(rack_exit_target_rotation, 3.0 * delta)
		velocity = Vector3.ZERO
		if global_position.distance_to(rack_exit_target_position) < 0.15:
			transitioning_from_rack = false
			global_position = rack_exit_target_position
			animation_state.travel("Idle_Screen")
			print("Rack exit transition complete")
	elif not in_print_mode:
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction = (camera.transform.basis.z * input_dir.y + camera.transform.basis.x * input_dir.x).normalized()
		direction.y = 0
		
		if not pushed_cart:
			if direction:
				if carried_screen:
					animation_state.travel("Walk_Screen")
				else:
					animation_state.travel("Walk")
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
				var target_basis = Transform3D().looking_at(direction, Vector3.UP).basis
				transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)
			else:
				if carried_screen:
					animation_state.travel("Idle_Screen")
				else:
					animation_state.travel("Idle")
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
		else:
			var push_input = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
			var turn_input = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
			
			if push_input != 0:
				rotate_y(turn_input * rotation_speed * 0.3 * delta)
			
			if push_input != 0:
				animation_state.travel("Push")
				var push_direction = -global_transform.basis.z
				velocity = push_direction * push_input * (speed * 0.5)
			else:
				animation_state.travel("Idle")
				velocity = Vector3.ZERO
	else:
		velocity = Vector3.ZERO

	move_and_slide()
	
	if pushed_cart:
		var cart_offset = -global_transform.basis.z * 1.2
		pushed_cart.global_position = global_position + cart_offset
		pushed_cart.global_rotation = global_rotation + Vector3(0, PI, 0)
	
	if carried_screen:
		carried_screen.position = Vector3(0, 0.5, -0.25)
		carried_screen.rotation = Vector3(deg_to_rad(-30), 0, 0)

	var camera_target_position
	var camera_speed = camera_smooth_speed
	
	if in_print_mode:
		camera_target_position = print_mode_camera_target
		camera_speed = 5.0
	else:
		camera_target_position = global_position + camera_offset
	
	camera.global_position = camera.global_position.lerp(camera_target_position, camera_speed * delta)

func play_press_animation(anim_name: String):
	animation_state.travel(anim_name)

func _pickup_screen():
	# Store original collision settings
	original_screen_collision_layer = carried_screen.collision_layer
	original_screen_collision_mask = carried_screen.collision_mask
	
	# Disable screen collision
	carried_screen.collision_layer = 0
	carried_screen.collision_mask = 0
	
	carried_screen = screen_in_range.get_parent()
	carried_screen.freeze = true
	carried_screen.linear_velocity = Vector3.ZERO
	carried_screen.angular_velocity = Vector3.ZERO
	carried_screen.get_parent().remove_child(carried_screen)
	add_child(carried_screen)
	carried_screen.position = Vector3(0, 1.2, -0.5)
	carried_screen.rotation = Vector3.ZERO
	_create_extended_collision("screen")
	print("Created extended collision for screen")
	print("Picked up screen")

func _drop_screen():
	if not carried_screen:
		return
	var screen_transform = carried_screen.global_transform
	remove_child(carried_screen)
	get_tree().get_root().add_child(carried_screen)
	carried_screen.global_transform = screen_transform
	carried_screen.freeze = false
	if extended_collision:
		remove_child(extended_collision)
		extended_collision.queue_free()
		extended_collision = null
	# Restore screen collision
	carried_screen.collision_layer = original_cart_collision_layer
	carried_screen.collision_mask = original_cart_collision_mask
	carried_screen = null
	print("Dropped screen")

func _store_screen_to_rack():
	print("=== _store_screen_to_rack called ===")
	
	if not carried_screen:
		print("ERROR: No screen being carried!")
		return
	
	if not screen_rack_in_range:
		print("ERROR: No screen rack in range!")
		return
	
	# Restore screen collision BEFORE storing it
	carried_screen.collision_layer = original_screen_collision_layer
	carried_screen.collision_mask = original_screen_collision_mask
	
	# Store the screen in the rack
	if screen_rack_in_range.load_screen_to_rack(carried_screen):
		# Remove extended collision
		if extended_collision:
			remove_child(extended_collision)
			extended_collision.queue_free()
			extended_collision = null
		
		carried_screen = null
		print("Successfully stored screen in rack")
	else:
		print("Failed to store screen in rack (rack may be full)")

func _retrieve_screen_from_rack():
	print("=== _retrieve_screen_from_rack called ===")
	
	if not screen_rack_in_range:
		print("ERROR: No screen rack in range!")
		return
	
	if carried_screen:
		print("ERROR: Already carrying a screen!")
		return
	
	# Get the first filled slot
	var slot_index = screen_rack_in_range.get_nearest_filled_slot()
	
	if slot_index == -1:
		print("Rack is empty!")
		return
	
	# Remove screen from rack
	var screen = screen_rack_in_range.remove_screen_from_rack(slot_index)
	
	if not screen:
		print("Failed to retrieve screen from rack")
		return
	
	# Store original collision settings from the SCREEN (not carried_screen yet!)
	original_screen_collision_layer = screen.collision_layer
	original_screen_collision_mask = screen.collision_mask
	
	# Disable screen collision
	screen.collision_layer = 0
	screen.collision_mask = 0
	
	# Pick up screen immediately
	add_child(screen)
	screen.position = Vector3(0, 1.2, -0.5)
	screen.rotation = Vector3.ZERO
	screen.freeze = true
	carried_screen = screen
	print("Screen picked up from rack")
	
	_create_extended_collision("screen")
	print("Created extended collision for screen")
	
	# Start transition (rotate and walk backwards WITH screen)
	transitioning_from_rack = true
	rack_exit_target_rotation = global_rotation + Vector3(0, PI, 0)
	rack_exit_target_position = global_position + global_transform.basis.z * 0.5
	animation_state.travel("Walk_Screen")
	print("Starting rack exit transition with screen")

func _load_screen_to_head():
	print("=== _load_screen_to_head called ===")
	print("carried_screen: ", carried_screen)
	
	if not carried_screen:
		print("ERROR: No screen being carried!")
		return
	
	# Get the press
	var press = get_tree().get_first_node_in_group("press")
	print("Press found: ", press)
	
	if not press:
		print("ERROR: Press not found!")
		return
	
	# Find nearest empty slot
	var slot_index = press.get_nearest_empty_slot()
	print("Empty slot index: ", slot_index)
	
	if slot_index == -1:
		print("All head slots are full!")
		return
	
	# Remove extended collision
	if extended_collision:
		remove_child(extended_collision)
		extended_collision.queue_free()
		extended_collision = null
		print("Removed extended collision")
	
	# Restore original screen collision before loading it
	carried_screen.collision_layer = original_screen_collision_layer
	carried_screen.collision_mask = original_screen_collision_mask
	
	# Load the screen
	print("Attempting to load screen to slot ", slot_index)
	if press.load_screen_to_slot(carried_screen, slot_index):
		carried_screen = null
		print("Successfully loaded screen to head")
	else:
		print("Failed to load screen to head")
		
func _remove_screen_from_head():
	print("=== _remove_screen_from_head called ===")
	
	# Get the press
	var press = get_tree().get_first_node_in_group("press")
	
	if not press:
		print("ERROR: Press not found!")
		return
	
	# Remove the front screen
	var screen = press.remove_front_screen()
	
	if not screen:
		print("No screen to remove")
		return
	
	# Store original collision settings from the SCREEN (not carried_screen yet!)
	original_screen_collision_layer = screen.collision_layer
	original_screen_collision_mask = screen.collision_mask
	
	# Disable screen collision
	screen.collision_layer = 0
	screen.collision_mask = 0
	
	# Add screen to player
	add_child(screen)
	screen.position = Vector3(0, 1.2, -0.5)
	screen.rotation = Vector3.ZERO
	screen.freeze = true
	carried_screen = screen
	print("Screen removed and added to player")
	
	_create_extended_collision("screen")
	print("Created extended collision for screen")
	
	# Exit print mode
	in_print_mode = false
	transitioning_from_print = true
	exit_target_rotation = global_rotation + Vector3(0, PI, 0)
	exit_target_position = global_position + global_transform.basis.z * 0.5
	animation_state.travel("Walk_Screen")
	if current_print_zone:
		current_print_zone.restore_camera_zoom()
	if press:
		press.disable_controls()
	current_print_zone = null
	print("Starting exit transition with screen")

func _on_grab_zone_area_entered(area):
	print("GrabZone detected: ", area.name)
	if area.is_in_group("carts"):
		handle_in_range = area
		print("Cart handle in range")
	elif area.is_in_group("screens"):
		screen_in_range = area
		print("Screen in range!")
	elif area.is_in_group("screen_racks"):
		screen_rack_in_range = area.get_parent()
		print("Screen rack in range!")

func _on_grab_zone_area_exited(area):
	if area == handle_in_range:
		handle_in_range = null
		print("Cart handle left range")
	elif area == screen_in_range:
		screen_in_range = null
		print("Screen left range")
	elif area.is_in_group("screen_racks") and area.get_parent() == screen_rack_in_range:
		screen_rack_in_range = null
		print("Screen rack left range")
