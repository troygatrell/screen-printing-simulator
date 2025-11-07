extends Label

func _ready():
	# Update the label every frame
	pass

func _process(_delta):
	text = "Day %d - %s" % [TimeManager.current_day, TimeManager.get_time_string()]
