extends KinematicBody2D

# Configurable properties
var gravity = 1000
var minGravity = 600
var maxGravity = 2000
var runSpeed = 300
var jumpForce = 500  # Maximum initial jump force
var wallJumpForce = 600
var maxJumpHoldTime = 0.4  # Maximum time the player can hold the jump button to increase jump height
var defaultGroundFriction = 100
var defaultWallSlideSpeed = 200
var groundFrictionMap = {"ice": 2}
var wallSlideSpeedMap = {"ice": 600}  # Dictionary to hold friction values for different wall types
var wallJumpCooldown = 0.2  # Time in seconds before another wall jump can be performed
var wallJumpGracePeriod = 0.7  # Time in seconds during which the player can't grab the wall after jumping

# Internal state
var playerVelocity = Vector2.ZERO
var isSliding = false
var wallJumpAvailable = true
var wallJumpTimer = 0.0
var wallJumpGraceTimer = 0.0
var isJumping = false  # Track if the player is currently in a jump
var jumpHoldTimer = 0.0  # Track how long the jump button has been held
var canJump = true  # Used for jump state control

# Nodes
onready var animatedSprite = $AnimatedSprite

func _ready():
	wallSlideSpeedMap["default"] = defaultWallSlideSpeed
	# Add specific wall types and their frictions if needed

func _physics_process(delta):
	var isOnWall = is_on_wall()
	var isOnFloor = is_on_floor()
	var isHoldingWall = Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")
	

	if isOnWall and isHoldingWall and not isOnFloor and wallJumpGraceTimer <= 0:
		var wallFriction = get_wall_friction()
		print(wallFriction)
		handle_wall_slide(wallFriction, delta)
	elif not isOnFloor:
		handle_fall(delta)
	else:
		handle_ground()

	handle_horizontal_movement(isOnFloor, delta)
	handle_jump(isOnFloor, isOnWall, delta)
	
	move_and_slide(playerVelocity, Vector2.UP)
	
	# Check for head collisions
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal.y > 0:  # Check if the collision is from above
			playerVelocity.y = 0  # Reset vertical velocity
	
	update_animation(isOnFloor, isOnWall, isSliding)
	
	# Update timers
	wallJumpTimer = max(wallJumpTimer - delta, 0)
	wallJumpGraceTimer = max(wallJumpGraceTimer - delta, 0)

func get_wall_friction() -> float:
	var collision = get_slide_collision(0)
	if collision:
		var collider = collision.collider
		print(collider)
		if collider.has_meta("wall_type"):
			print(collider.get_meta("wall_type"))
			return wallSlideSpeedMap.get(collider.get_meta("wall_type"), defaultWallSlideSpeed)
	return defaultWallSlideSpeed

func get_ground_friction() -> float:
	var collision = get_slide_collision(0)
	if collision:
		var collider = collision.collider
		if collider.has_meta("floor_type"):
			print(collider.get_meta("floor_type"))
			return groundFrictionMap.get(collider.get_meta("floor_type"), defaultGroundFriction)
	return defaultGroundFriction

func handle_wall_slide(wallFriction, delta):
	if not isSliding and playerVelocity.y < 0:
		playerVelocity.y = playerVelocity.y/5
	isSliding = true
	playerVelocity.y = lerp(playerVelocity.y, wallFriction, delta)

func handle_fall(delta):
	playerVelocity.y += gravity * delta
	isSliding = false

func handle_ground():
	playerVelocity.y = 5
	isSliding = false
	wallJumpAvailable = true
	isJumping = false  # Reset the jumping state when on the ground
	canJump = true  # Allow the player to jump again when on the ground

func handle_horizontal_movement(isOnFloor: bool, delta: float):
	if Input.is_action_pressed("ui_left"):
		playerVelocity.x = -runSpeed
		animatedSprite.flip_h = true
	elif Input.is_action_pressed("ui_right"):
		playerVelocity.x = runSpeed
		animatedSprite.flip_h = false
	elif isOnFloor:
		var friction = get_ground_friction()
		playerVelocity.x = lerp(playerVelocity.x, 0, friction * delta)
	else:
		playerVelocity.x = 0

func handle_jump(isOnFloor: bool, isOnWall: bool, delta: float):
	if Input.is_action_just_pressed("ui_up"):
		if canJump:
			canJump = false  # Prevent multiple jumps until grounded or other conditions met
			isJumping = true
			jumpHoldTimer = 0.0
			playerVelocity.y = -jumpForce
		print("is wall ", isOnWall)
		if isOnWall:
			if wallJumpAvailable:
				print("wallJumped")
				playerVelocity.y = -wallJumpForce
				
			# Apply horizontal force away from the wall
			playerVelocity.x = (runSpeed * (1 if not animatedSprite.flip_h else -1)) * 1.5
			wallJumpAvailable = false
			isSliding = false
			wallJumpTimer = wallJumpCooldown
			wallJumpGraceTimer = wallJumpGracePeriod

	if isJumping:
		if Input.is_action_pressed("ui_up") and jumpHoldTimer < maxJumpHoldTime:
			jumpHoldTimer += delta
			# Reduce gravity while holding the jump button to extend the jump duration
			gravity = minGravity
		elif Input.is_action_pressed("ui_down"):
			gravity = maxGravity
		else:
			isJumping = false
			gravity = 1000  # Reset gravity after jump hold time ends

func update_animation(isOnFloor: bool, isOnWall: bool, isSliding: bool):
	var anim = "idle"
	if isSliding:
		anim = "slide"
	elif not isOnFloor:
		anim = "fall"
	elif playerVelocity.x != 0 and not isOnWall and (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")):
		anim = "run"
	if animatedSprite.animation != anim:
		animatedSprite.stop()
		animatedSprite.play(anim)
