extends Node2D


var startPositionX = 1000
var endPositionX = -700


func _process(delta):
	print(position.x)
	if position.x <= endPositionX:
		position.x = startPositionX
