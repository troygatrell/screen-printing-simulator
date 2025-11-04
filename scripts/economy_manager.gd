# economy_manager.gd
extends Node

# Money tracking
var current_money: float = 500.0  # Start with $500
var daily_earnings: float = 0.0


# Daily costs
var daily_rent: float = 200.0
var daily_utilities: float = 50.0
var daily_materials: float = 100.0

# Signals
signal money_changed(new_amount: float)
signal went_bankrupt


func _ready():
	print("EconomyManager initialized with $", current_money)
	TimeManager.day_ended.connect(_on_day_ended)
	went_bankrupt.connect(_on_went_bankrupt)

func _on_went_bankrupt():
	print("GAME OVER - Showing bankruptcy screen")
	show_game_over()

func show_game_over():
	var game_over_scene = load("res://scenes/game_over_screen.tscn")  # Adjust path
	var game_over = game_over_scene.instantiate()
	
	var canvas = CanvasLayer.new()
	get_tree().root.add_child(canvas)
	canvas.add_child(game_over)
	
	get_tree().paused = true

func _on_day_ended():
	print("End of day - charging costs...")
	charge_daily_costs()

# Add money (from completing jobs)
func add_money(amount: float) -> void:
	current_money += amount
	daily_earnings += amount  # Track for end of day
	print("Added $", amount, " - Total: $", current_money)
	emit_signal("money_changed", current_money)

# Subtract money (for costs)
func subtract_money(amount: float) -> void:
	current_money -= amount
	print("Subtracted $", amount, " - Total: $", current_money)
	emit_signal("money_changed", current_money)
	
	# Check for bankruptcy
	if current_money <= 0:
		current_money = 0
		emit_signal("went_bankrupt")
		print("BANKRUPT!")


# Check if player can afford something
func can_afford(amount: float) -> bool:
	return current_money >= amount


# Get total daily operating costs
func get_daily_costs() -> float:
	return daily_rent + daily_utilities + daily_materials


# Deduct daily costs (called at end of day)
func charge_daily_costs() -> void:
	var total_cost = get_daily_costs()
	print("Charging daily costs: $", total_cost)
	subtract_money(total_cost)
	
func reset_daily_earnings():
	daily_earnings = 0.0
	
func reset():
	current_money = 500.0
	daily_earnings = 0.0
