# end_of_day_summary.gd
extends Control

@onready var day_label = $SummaryPanel/ContentContainer/DayLabel
@onready var earned_label = $SummaryPanel/ContentContainer/EarnedLabel
@onready var costs_label = $SummaryPanel/ContentContainer/CostsLabel
@onready var profit_label = $SummaryPanel/ContentContainer/ProfitLabel
@onready var total_label = $SummaryPanel/ContentContainer/TotalLabel
@onready var continue_button = $SummaryPanel/ContentContainer/ContinueButton

var daily_earnings: float = 0.0
var daily_costs: float = 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(_on_continue_pressed)
	update_display()


func set_summary_data(day: int, earned: float, costs: float, total_money: float):
	daily_earnings = earned
	daily_costs = costs
	
	day_label.text = "Day %d Complete" % day
	earned_label.text = "Earned: $%.2f" % earned
	costs_label.text = "Costs: -$%.2f" % costs
	
	var profit = earned - costs
	profit_label.text = "Profit: $%.2f" % profit
	
	# Color profit green or red
	if profit >= 0:
		profit_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		profit_label.add_theme_color_override("font_color", Color.RED)
	
	total_label.text = "Total Money: $%.2f" % total_money


func update_display():
	# Default display if no data set yet
	pass


func _on_continue_pressed():
	# Close this summary
	get_tree().paused = false
	queue_free()
