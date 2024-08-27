extends KinematicBody2D

var gravity = 10
var playerVelocity = Vector2.ZERO # Sets velocity to 0, 0
var playerAcceleration = Vector2.ZERO # Sets acceleration to 0, 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_Timer_timeout():
	print(str($Timer.wait_time) + " seconds")

func _physics_process(delta):
	# Apply gravity to the acceleration
	playerAcceleration.y += gravity * delta

	# Update the velocity with the acceleration
	playerVelocity += playerAcceleration * delta

	# Apply the velocity to the player movement
	playerVelocity = move_and_slide(playerVelocity)

	# Print the current velocity for debugging
	print(playerVelocity)
