extends CSGBox3D

var player_nearby: bool = false
var station_open: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var interaction_zone = $InteractionZone
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_nearby = true
		print("Press E to use screen burning station")

func _on_body_exited(body):
	if body.name == "Player":
		player_nearby = false

func _process(_delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		if not station_open:
			open_station()

func open_station():
	print("Opening screen burning station!")
	station_open = true
	
	# Load UI
	var ui_scene = load("res://scenes/screen_burning_ui.tscn")  # Adjust path!
	var ui = ui_scene.instantiate()
	
	# Add as overlay
	var canvas_layer = CanvasLayer.new()
	get_tree().root.add_child(canvas_layer)
	canvas_layer.add_child(ui)
	
	# Track when it closes
	ui.tree_exited.connect(_on_ui_closed)
	
	# Pause game
	get_tree().paused = true

func _on_ui_closed():
	station_open = false
