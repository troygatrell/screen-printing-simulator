# print_zone.gd - OPTIMIZED VERSION
extends Area3D

# Snap position and rotation for the player
@export var snap_offset = Vector3(0, 0, 0)
@export var snap_rotation = Vector3(0, 0, 0)

# Camera settings for print mode
@export var camera_focus_point: Vector3
@export var camera_zoom_distance = 5.0
@export var use_press_node = true
@export var press_node_path: NodePath = ""
@export var camera_distance_multiplier = 0.6
@export var orthographic_size_multiplier = 0.5

# Performance optimization
const ZOOM_SPEED = 5.0
const ZOOM_THRESHOLD = 0.01  # Stop zooming when this close to target

# Cached references
var camera: Camera3D = null
var initial_camera_offset: Vector3 = Vector3.ZERO
var original_camera_size: float = 0.0
var target_camera_size: float = 0.0
var is_zooming: bool = false
var player_in_zone = null

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Add to group
	add_to_group("print_zones")
	
	# Cache camera reference
	camera = get_viewport().get_camera_3d()
	
	# Store initial offsets
	var player = get_tree().get_first_node_in_group("player")
	if player and camera:
		initial_camera_offset = camera.global_position - player.global_position
		
		# Store original camera size for orthographic cameras
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			original_camera_size = camera.size

func _on_body_entered(body):
	# Only CharacterBody3D is the player
	if body is CharacterBody3D:
		player_in_zone = body

func _on_body_exited(body):
	if body == player_in_zone:
		player_in_zone = null

func snap_player_to_zone(player):
	"""Snaps the player to the printing position"""
	if player:
		player.global_position = global_position + snap_offset
		player.global_rotation = snap_rotation
		player.velocity = Vector3.ZERO

func is_player_in_zone() -> bool:
	return player_in_zone != null

func _process(delta):
	# Only run when actively zooming
	if not is_zooming:
		return
	
	# Cache check - don't get camera every frame
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return
	
	# Only process orthographic cameras
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		is_zooming = false
		return
	
	# Lerp toward target size
	var size_difference = abs(camera.size - target_camera_size)
	
	# Stop zooming when close enough (performance optimization)
	if size_difference < ZOOM_THRESHOLD:
		camera.size = target_camera_size
		is_zooming = false
		set_process(false)  # Disable _process when not needed
		return
	
	# Smooth zoom
	camera.size = lerp(camera.size, target_camera_size, ZOOM_SPEED * delta)

func apply_camera_zoom():
	"""Apply zoom effect for orthographic cameras"""
	if not camera:
		camera = get_viewport().get_camera_3d()
	
	if camera and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		target_camera_size = original_camera_size * orthographic_size_multiplier
		is_zooming = true
		set_process(true)  # Enable _process only when zooming

func restore_camera_zoom():
	"""Restore original camera zoom"""
	if not camera:
		camera = get_viewport().get_camera_3d()
	
	if camera and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		target_camera_size = original_camera_size
		is_zooming = true
		set_process(true)  # Enable _process only when zooming

func get_camera_target_position() -> Vector3:
	"""Returns the position where the camera should be in print mode"""
	
	# Try to automatically find and focus on the Press node
	if use_press_node:
		var press_node = null
		
		# First, try the specified path
		if not press_node_path.is_empty():
			press_node = get_node_or_null(press_node_path)
		
		# If no path or path failed, search for "Press" in the scene
		if press_node == null:
			press_node = get_tree().get_first_node_in_group("press")
			
			# Fallback to find_child if group doesn't exist
			if press_node == null:
				press_node = get_tree().get_root().find_child("Press", true, false)
		
		# If we found the press, use its position
		if press_node != null:
			var press_position = press_node.global_position
			return press_position + initial_camera_offset
	
	# Use manual focus point (fallback)
	var focus_point = global_position + camera_focus_point
	return focus_point + Vector3(0, camera_zoom_distance * 0.5, camera_zoom_distance)
