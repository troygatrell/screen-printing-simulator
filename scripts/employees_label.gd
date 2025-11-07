extends Label

func _ready():
	# Connect to economy changes
	EconomyManager.employees_changed.connect(_on_employees_changed)
	# Set initial value
	text = "Employees: %d" % [EconomyManager.num_employees]

func _on_employees_changed(new_amount: int):
	print("Employees updating to: ", new_amount)
	text = "Employees: %d" % new_amount
