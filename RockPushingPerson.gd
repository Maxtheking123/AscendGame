extends Node2D

var speed = 100
var rotateSpeed = 1.5
var startPositionX = 0
var endPositionX = -1600

onready var rock = $"../rock"
onready var parent = $".."

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	rock.rotate(-rotateSpeed * delta)
	parent.position.x -= speed * delta
	if parent.position.x <= endPositionX:
		parent.position.x = startPositionX
