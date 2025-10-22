# head_slot_visualizer.gd
# Attach this to the Heads carousel node to visualize slot numbers
extends Node3D

@export var label_offset = Vector3(0, 0.5, 0) # How far above/in front of marker to place label
@export var label_size = 0.5 # Size of the number labels

func _ready():
	await get_tree().process_frame # Wait one frame for markers to be ready
	_create_slot_labels()

func _create_slot_labels():
	print("=== CREATING SLOT LABELS ===")
	
	for i in range(6):
		var marker_name = "ScreenSlot" + str(i)
		var marker = _find_node_recursive(self, marker_name)
		
		if marker:
			# Create a Label3D node
			var label = Label3D.new()
			label.text = str(i)
			label.font_size = 64
			label.pixel_size = label_size / 100.0
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.modulate = Color(1, 1, 0) # Yellow color
			label.outline_size = 8
			label.outline_modulate = Color(0, 0, 0) # Black outline
			
			# Add label to the carousel (not the marker)
			add_child(label)
			
			# Convert marker's global position to local position relative to carousel
			var local_pos = to_local(marker.global_position)
			label.position = local_pos + label_offset
			
			print("Created label for slot ", i, " at position: ", label.position)
		else:
			print("Warning: Could not find marker for slot ", i)
	
	print("=== SLOT LABELS CREATED ===")

func _find_node_recursive(node: Node, target_name: String) -> Node:
	"""Recursively search for a node by name in all descendants"""
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	
	return null
