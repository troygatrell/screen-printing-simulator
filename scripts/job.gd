# job.gd
class_name Job
extends Resource

# Job identification
var job_id: int
var customer_name: String

# Job specifications
var shirt_color: Color
var artwork_texture: Texture2D
var print_location: String  # "full_front", "left_chest", "back"
var num_colors: int
var num_shirts: int
var due_date: String

# Time tracking
var due_day: int
var payment_amount: float
var is_overdue: bool = false

# Job status
var is_complete: bool = false
var shirts_printed: int = 0
