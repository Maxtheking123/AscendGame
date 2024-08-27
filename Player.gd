extends KinematicBody2D

var gravity = 1500 # Adjusted gravity
var walkSpeed = 200
var jumpForce = 500 # Adjusted jump force
var playerVelocity = Vector2.ZERO

onready var animatedSprite = $AnimatedSprite
onready var animationPlayer = $AnimationPlayer

func _ready():
	pass

func _on_Timer_timeout():
	print(str($Timer.wait_time) + " seconds")

func _physics_process(delta):
	# Apply gravity to the player velocity
	if not is_on_floor():
		playerVelocity.y += gravity * delta
	else:
		playerVelocity.y = 0

	# Handle horizontal movement
	if Input.is_action_pressed("ui_left"):
		playerVelocity.x = -walkSpeed
		animatedSprite.flip_h = true  # Flip sprite to face left
		if is_on_floor():
			animatedSprite.play("walk")
		else: 
			animatedSprite.play("fall")
	elif Input.is_action_pressed("ui_right"):
		playerVelocity.x = walkSpeed
		animatedSprite.flip_h = false  # Face sprite to the right
		if is_on_floor():
			animatedSprite.play("walk")
		else: 
			animatedSprite.play("fall")
	else:
		playerVelocity.x = 0
		if is_on_floor():
			animatedSprite.play("idle")  # Play idle animation when not moving

	# Handle jumping (only allow jumping if on the ground)
	if is_on_floor() and Input.is_action_pressed("ui_up"):
		playerVelocity.y = -jumpForce
		animatedSprite.play("jump")  # Play jump animation

	# Move the player and slide along surfaces
	playerVelocity = move_and_slide(playerVelocity, Vector2.UP)
	
	# Set fall animation if not on floor and not jumping
	if not is_on_floor() and playerVelocity.y > 0:
		animatedSprite.play("fall")
