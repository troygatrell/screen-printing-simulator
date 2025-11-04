extends Label

func _ready():
	# Connect to economy changes
	EconomyManager.money_changed.connect(_on_money_changed)
	# Set initial value
	text = "$%.2f" % EconomyManager.current_money

func _on_money_changed(new_amount: float):
	print("Money label updating to: $", new_amount)
	text = "$%.2f" % new_amount
