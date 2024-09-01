extends Node2D

var defaultSpeed = 125
var isMoving = false
var margin = 80
var hitDistance = 120
var animationDelay = 0.2  # Delay in seconds
var heightTolerance = 40  # Tolerance in pixels for height check

var animationTimer = 0.0
var isInHitRadius = false
var hasHit = false
var currentAnimation = "idle"

onready var rayCast = $RayCast2D
onready var player = $"../../Player"
onready var animatedSprite = $AnimatedSprite

func _ready():
	pass # Initialize if needed

func _process(delta):
	# Get the direction from the RayCast2D to the player
	var direction = player.global_position - rayCast.global_position
	
	# Calculate the angle using atan2
	var angle = direction.angle()
	
	# Set the RayCast2D rotation to the calculated angle
	rayCast.rotation = angle
	
	# Check if the RayCast2D is colliding with anything
	if rayCast.is_colliding():
		# Get the object the RayCast2D is colliding with
		var collider = rayCast.get_collider()
		
		# Check if the collider is the player
		if collider == player:
			move_towards_player(delta)
			handle_hit_distance(delta)
		else:
			isMoving = false
	else:
		isMoving = false
		isInHitRadius = false
		hasHit = false
	
	# Update the animation
	update_animation(delta)

func move_towards_player(delta):
	# Calculate the distance to move in the x direction
	var distance_to_move = player.global_position.x - global_position.x
	
	# Determine if the sprite should be flipped based on the direction of movement
	if distance_to_move < 0:
		animatedSprite.flip_h = true # Flip horizontally to face left
	else:
		animatedSprite.flip_h = false # No flip or face right
	
	# Move the enemy towards the player
	if distance_to_move != 0:
		isMoving = true
		# Determine the movement amount for this frame
		var move_amount = defaultSpeed * delta
		
		# If the distance to move is less than the movement amount, just move to the player
		if abs(distance_to_move) < move_amount:
			global_position.x = player.global_position.x
		else:
			# Move the enemy towards the player
			if distance_to_move > margin:
				global_position.x += move_amount
			elif distance_to_move < -margin:
				global_position.x -= move_amount
			else:
				isMoving = false
	else:
		isMoving = false

func handle_hit_distance(delta):
	# Calculate the distance between the enemy and the player
	var distance_to_player = abs(player.global_position.x - global_position.x)
	
	# Calculate the height difference between the enemy and the player
	var height_difference = abs(player.global_position.y - global_position.y)
	
	if distance_to_player <= hitDistance and height_difference <= heightTolerance:
		if not isInHitRadius:
			# Player just entered hit radius
			isInHitRadius = true
			animationTimer = animationDelay
			hasHit = false
			# Play the hit animation
			animatedSprite.play("hit")
		else:
			# Player is still in the hit radius
			if animationTimer > 0:
				animationTimer -= delta
			else:
				# Time to handle the hit
				if not hasHit:
					if player.has_method("_kill_player_other"):
						player._kill_player_other()
						hasHit = true
	else:
		# Player has left the hit radius or height tolerance
		isInHitRadius = false
		hasHit = false
		animationTimer = 0.0

func update_animation(delta):
	# Determine the target animation
	var targetAnimation = "idle"
	if isMoving:
		targetAnimation = "move"
	
	# Check if the animation needs to be updated
	if currentAnimation != targetAnimation:
		# Set animation timer to delay
		animationTimer = animationDelay
		# Stop the current animation and play the new one
		animatedSprite.stop()
		animatedSprite.play(targetAnimation)
		# Update the current animation state
		currentAnimation = targetAnimation

	# Update the animation timer
	if animationTimer > 0:
		animationTimer -= delta
	else:
		# If animation timer is done and no movement, ensure idle animation is set
		if !isMoving and currentAnimation != "idle":
			animatedSprite.play("idle")
			currentAnimation = "idle"
