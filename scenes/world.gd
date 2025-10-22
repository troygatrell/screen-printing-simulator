# process_debugger.gd
# Attach this to a Node in your main scene temporarily
extends Node

var frame_count = 0
var report_interval = 60  # Report every 60 frames (1 second at 60fps)

func _ready():
	print("=== PROCESS TIME DEBUGGER ACTIVE ===")
	print("Monitoring all _process functions in the scene...")

func _process(_delta):
	frame_count += 1
	
	if frame_count >= report_interval:
		frame_count = 0
		_report_scene_stats()

func _report_scene_stats():
	print("\n=== SCENE STATISTICS ===")
	
	# Count different node types
	var stats = {
		"Total Nodes": 0,
		"Node3D": 0,
		"RigidBody3D": 0,
		"CharacterBody3D": 0,
		"AnimationPlayer": 0,
		"AnimationTree": 0,
		"Area3D": 0,
		"CollisionShape3D": 0,
		"MeshInstance3D": 0,
		"Camera3D": 0,
		"Light3D": 0,
	}
	
	_count_nodes(get_tree().root, stats)
	
	print("Node counts:")
	for key in stats.keys():
		print("  ", key, ": ", stats[key])
	
	# Memory usage
	var memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	print("Memory: ", "%.1f MB" % memory_mb)
	
	# Object count
	var objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	print("Total Objects: ", objects)
	
	print("=========================\n")

func _count_nodes(node: Node, stats: Dictionary):
	stats["Total Nodes"] += 1
	
	var type = node.get_class()
	if type in stats:
		stats[type] += 1
	
	for child in node.get_children():
		_count_nodes(child, stats)
