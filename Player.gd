extends KinematicBody2D

# Configurable properties
var gravity = 1000
var minGravity = 600
var maxGravity = 2000
var minSlippSpeed = 3
var groundMaxDistance = 30
var ladderClimbSpeed = 200
var runSpeed = 300
var jumpForce = 500  # Maximum initial jump force
var wallJumpForce = 600
var maxJumpHoldTime = 0.4  # Maximum time the player can hold the jump button to increase jump height
var defaultGroundFriction = 15
var defaultWallSlideSpeed = 200
var groundFrictionMap = {"ice": 2}
var wallSlideSpeedMap = {"ice": 600}  # Dictionary to hold friction values for different wall types
var wallJumpCooldown = 0.2  # Time in seconds before another wall jump can be performed
var wallJumpGracePeriod = 0.7  # Time in seconds during which the player can't grab the wall after jumping

var leftButton = ""

# Internal state
var playerVelocity = Vector2.ZERO
var isSliding = false
var isSlipping = false
var on_ladder = false
var is_climbing = false
var isInAir = false
var wallJumpAvailable = true
var wallJumpTimer = 0.0
var wallJumpGraceTimer = 0.0
var isJumping = false  # Track if the player is currently in a jump
var jumpHoldTimer = 0.0  # Track how long the jump button has been held
var canJump = true  # Used for jump state control
var distance = 0.0 # Used to track distance to ground

# Nodes
onready var animatedSprite = $AnimatedSprite

func _ready():
	wallSlideSpeedMap["default"] = defaultWallSlideSpeed
	# Add specific wall types and their frictions if needed

func _physics_process(delta):
	var isOnWall = is_on_wall()
	var isOnFloor = is_on_floor()

	if not on_ladder:
		playerVelocity.y += gravity * delta
	else:
		gravity = 0  # No gravity while on the ladder
		if not is_climbing:
			playerVelocity.y = 0  # Stop falling when on a ladder but not climbing

	if not isOnWall and not isOnFloor:
		isInAir = true
	else:
		isInAir = false

	var isHoldingWall = Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")
	
	if isOnWall and isHoldingWall and not isOnFloor and wallJumpGraceTimer <= 0:
		var wallFriction = get_wall_friction()
		handle_wall_slide(wallFriction, delta)
	elif not isOnFloor:
		handle_fall(delta)
	else:
		handle_ground(delta)

	handle_horizontal_movement(isOnFloor, delta)
	handle_jump(isOnFloor, isOnWall, delta)

	move_and_slide(playerVelocity, Vector2.UP)

	# Check for head collisions
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal.y > 0:
			playerVelocity.y = 0

	update_animation(isOnFloor, isOnWall, isSliding)

	# Update timers
	wallJumpTimer = max(wallJumpTimer - delta, 0)
	wallJumpGraceTimer = max(wallJumpGraceTimer - delta, 0)

func get_wall_friction() -> float:
	var collision = get_slide_collision(0)
	if collision:
		var collider = collision.collider
		if collider.has_meta("wall_type"):
			return wallSlideSpeedMap.get(collider.get_meta("wall_type"), defaultWallSlideSpeed)
	return defaultWallSlideSpeed

func get_ground_friction() -> float:
	var collision = get_slide_collision(0)
	if collision:
		var collider = collision.collider
		if collider.has_meta("floor_type"):
			return groundFrictionMap.get(collider.get_meta("floor_type"), defaultGroundFriction)
	return defaultGroundFriction

func handle_wall_slide(wallFriction, delta):
	if not isSliding and playerVelocity.y < 0:
		playerVelocity.y = playerVelocity.y/5
	isSliding = true
	playerVelocity.y = lerp(playerVelocity.y, wallFriction, delta)
	print("Wall sliding with velocity: ", playerVelocity.y)  # Debugging

func _on_Ladder_body_entered(body):
	if body == self:
		on_ladder = true

func _on_Ladder_body_exited(body):
	if body == self:
		on_ladder = false

func handle_fall(delta):
	playerVelocity.y += gravity * delta
	isSliding = false

func handle_ground(delta):
	var collision = get_slide_collision(0)
	if collision and collision.normal.y < 1:
		# Slope detection and calculations
		var slope_angle = abs((acos(collision.normal.y) * 180 / PI) - 180)
		var slope_direction = Vector2(collision.normal.y, -collision.normal.x).normalized()
		
		# Check ground friction
		var groundFriction = get_ground_friction()
		
		# If friction is less than slope angle, slide.
		# For example, for ice the friction is 2 and then if the slope is 
		# more that 20, you slide.
		if abs(slope_angle) > groundFriction * 10:
			# Calculates player velocity from slipping
			playerVelocity += slope_direction * (20 - groundFriction) * delta
			# Sets the minimum speed if too low for what seems reasonable considering material factors
			if playerVelocity.y < minSlippSpeed * slope_angle * groundFriction:
				playerVelocity.y = minSlippSpeed * slope_angle * groundFriction

			isSlipping = true
			print("Slipping with velocity: ", playerVelocity)  # Debugging
		else:
			isSlipping = false
			playerVelocity.y = 5
	else:
		isSlipping = false
	wallJumpAvailable = true
	isJumping = false  # Reset the jumping state when on the ground
	canJump = true

func handle_horizontal_movement(isOnFloor: bool, delta: float):
	if Input.is_action_pressed("ui_left"):
		print("Pressing left, isSlipping: ", isSlipping)  # Debugging
		if not isSlipping or (isSlipping and isInAir):
			playerVelocity.x = -runSpeed
			print("Moving left with velocity: ", playerVelocity.x)  # Debugging
			
		animatedSprite.flip_h = true
	elif Input.is_action_pressed("ui_right"):
		print("Pressing right, isSlipping: ", isSlipping)  # Debugging
		if not isSlipping or (isSlipping and isInAir):
			playerVelocity.x = runSpeed
			print("Moving right with velocity: ", playerVelocity.x)  # Debugging
			
		animatedSprite.flip_h = false
	elif isOnFloor:
		var friction = get_ground_friction()
		playerVelocity.x = lerp(playerVelocity.x, 0, friction * delta)
	else:
		playerVelocity.x = 0

func handle_jump(isOnFloor: bool, isOnWall: bool, delta: float):
	if on_ladder:
		if Input.is_action_pressed("ui_up"):
			playerVelocity.y = -ladderClimbSpeed
			is_climbing = true
		elif Input.is_action_pressed("ui_down"):
			playerVelocity.y = ladderClimbSpeed
			is_climbing = true
		else:
			playerVelocity.y = 0
			is_climbing = false
	else:
		is_climbing = false
		# Existing jump logic goes here
		if Input.is_action_just_pressed("ui_up"):
			if not isSlipping:
				if canJump:
					canJump = false
					isJumping = true
					jumpHoldTimer = 0.0
					playerVelocity.y = -jumpForce
				if isOnWall:
					if wallJumpAvailable:
						playerVelocity.y = -wallJumpForce
						playerVelocity.x = (runSpeed * (1 if not animatedSprite.flip_h else -1)) * 1.5
						wallJumpAvailable = false
						isSliding = false
						wallJumpTimer = wallJumpCooldown
						wallJumpGraceTimer = wallJumpGracePeriod
		if isJumping:
			if Input.is_action_pressed("ui_up") and jumpHoldTimer < maxJumpHoldTime:
				jumpHoldTimer += delta
				gravity = minGravity
			elif Input.is_action_pressed("ui_down"):
				gravity = maxGravity
			else:
				isJumping = false
				gravity = 1000

func update_animation(isOnFloor: bool, isOnWall: bool, isSliding: bool):
	var anim = "idle"
	if isSliding:
		anim = "slide"
	elif not isOnFloor:
		anim = "fall"
	elif isSlipping:
		anim = "slipping"
	elif playerVelocity.x != 0 and not isOnWall and (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")):
		anim = "run"
	if animatedSprite.animation != anim:
		animatedSprite.stop()
		animatedSprite.play(anim)


func _on_Ladder_area_entered(area):
	if area.name == "Ladder":
		on_ladder = true

func _on_Ladder_area_exited(area):
	if area.name == "Ladder":
		on_ladder = false
		is_climbing = false  # Stop climbing when leaving the ladder

