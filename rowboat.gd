extends Node2D


var respawnPositionX = -100
var boatSpeed = 100
var endPosition = 1600

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if position.x < endPosition:
		position.x += boatSpeed * delta
	else:
		position.x = respawnPositionX
