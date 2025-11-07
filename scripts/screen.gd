# screen.gd
class_name Screen
extends Resource

# Screen identification
var screen_id: int
var job_id: int  # Which job this screen belongs to

# Screen details
var customer_name: String  # e.g., "Bob's Gym"
var location: String  # e.g., "full_front"
var color_name: String  # e.g., "Red Ink"
var color_index: int  # Which color # for this location (1, 2, or 3)

# Status
var is_burned: bool = true  # All screens created here are already burned
var is_loaded_in_press: bool = false
