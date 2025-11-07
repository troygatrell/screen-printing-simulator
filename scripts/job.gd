# job.gd
class_name Job
extends Resource

# Job identification
var job_id: int
var customer_name: String

# Job specifications
var shirt_color: Color
var artwork_texture: Texture2D

# CHANGED: Each location has its own color count
# Array of dictionaries: [{location: "full_front", colors: 3}, {location: "sleeve", colors: 1}]
var print_locations: Array[Dictionary] = []

# REMOVED: var num_colors: int (we don't need this anymore - it's per location now)

var num_shirts: int
var due_date: String

# Time tracking
var due_day: int
var payment_amount: float
var is_overdue: bool = false

# Job status
var is_complete: bool = false
var shirts_printed: int = 0
