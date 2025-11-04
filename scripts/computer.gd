extends MeshInstance3D

var player_nearby: bool = false

@onready var screen_mesh = $Screen
@onready var terminal_viewport = $Screen/TerminalViewport
var terminal_open: bool = false
var current_overlay_terminal = null  # Track the overlay terminal

func _ready():
	# Allow computer to process even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect the interaction zone signals
	var interaction_zone = $InteractionZone
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_nearby = true
		print("Press E to use computer")

func _on_body_exited(body):
	if body.name == "Player":
		player_nearby = false
		print("Left computer area")

func _process(_delta):
	if player_nearby:
		if Input.is_action_just_pressed("interact"):
			print("E pressed!")
			if not terminal_open:
				print("Calling open_terminal")
				open_terminal()
			else:
				print("Terminal already open")

func setup_screen_material():
	var viewport_texture = terminal_viewport.get_texture()
	
	var material = StandardMaterial3D.new()
	material.albedo_texture = viewport_texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.emission_enabled = true
	material.emission_texture = viewport_texture
	material.emission_energy_multiplier = 0.8
	
	screen_mesh.material_override = material

func open_terminal():
	print("Opening terminal!")
	
	# Load terminal scene
	var terminal_scene = load("res://scenes/desktop_terminal.tscn")
	var terminal_overlay = terminal_scene.instantiate()
	
	# Add overlay version
	var canvas_layer = CanvasLayer.new()
	get_tree().root.add_child(canvas_layer)
	canvas_layer.add_child(terminal_overlay)
	
	# Connect to know when terminal closes
	terminal_overlay.tree_exited.connect(_on_terminal_closed)
	
	# Pause game
	get_tree().paused = true
	terminal_open = true

func _on_terminal_closed():
	print("Terminal was closed")
	terminal_open = false
