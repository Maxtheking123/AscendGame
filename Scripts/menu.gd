extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _startButton_pressed() -> void:
	get_tree().change_scene("res://game.tscn")

func _quitButton_pressed():
	get_tree().quit()
