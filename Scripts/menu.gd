extends Control

var can_cancel: bool = false
var delay = 0.5

func _ready():
	yield(get_tree().create_timer(delay), "timeout")
	can_cancel = true

func _process(delta):
	if can_cancel and Input.is_action_pressed("ui_cancel"):
		get_tree().change_scene("res://game.tscn")

func _startButton_pressed() -> void:
	get_tree().change_scene("res://game.tscn")

func _quitButton_pressed():
	get_tree().quit()
