extends KinematicBody2D

# Configurable properties
var gravity = 1500
var walkSpeed = 200
var jumpForce = 500
var wallSlideSpeed = 200
var defaultWallSlideFriction = 0.1
var wallFrictionMap = {}  # Dictionary to hold friction values for different wall types
var wallJumpCooldown = 0.2  # Time in seconds before another wall jump can be performed
var wallJumpGracePeriod = 0.7  # Time in seconds during which the player can't grab the wall after jumping

# Internal state
var playerVelocity = Vector2.ZERO
var isSliding = false
var wallJumpAvailable = true
var wallJumpTimer = 0.0
var wallJumpGraceTimer = 0.0

# Nodes
onready var animatedSprite = $AnimatedSprite

func _ready():
	wallFrictionMap["default"] = defaultWallSlideFriction
	# Add specific wall types and their frictions if needed

func _physics_process(delta):
	var isOnWall = is_on_wall()
	var isOnFloor = is_on_floor()
	var isHoldingWall = Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")
	
	var wallFriction = get_wall_friction()

	if isOnWall and isHoldingWall and wallJumpGraceTimer <= 0:
		handle_wall_slide(wallFriction)
	elif not isOnFloor:
		handle_fall(delta)
	else:
		handle_ground()

	handle_horizontal_movement()
	handle_jump(isOnFloor, isOnWall)

	move_and_slide(playerVelocity, Vector2.UP)
	update_animation(isOnFloor, isOnWall, isSliding)

	# Update timers
	wallJumpTimer = max(wallJumpTimer - delta, 0)
	wallJumpGraceTimer = max(wallJumpGraceTimer - delta, 0)

func get_wall_friction() -> float:
	var collision = get_slide_collision(0)
	if collision:
		var collider = collision.collider
		if collider.has_meta("wall_type"):
			return wallFrictionMap.get(collider.get_meta("wall_type"), defaultWallSlideFriction)
	return defaultWallSlideFriction

func handle_wall_slide(wallFriction):
	if not isSliding:
		playerVelocity.y = 0
	isSliding = true
	playerVelocity.y = lerp(playerVelocity.y, wallSlideSpeed, wallFriction)

func handle_fall(delta):
	var gravityModifier = max(-(playerVelocity.y - 190) / 20000 + 0.3, 0.0001)
	playerVelocity.y += gravity * delta * gravityModifier
	isSliding = false

func handle_ground():
	playerVelocity.y = 0
	isSliding = false
	wallJumpAvailable = true

func handle_horizontal_movement():
	if Input.is_action_pressed("ui_left"):
		playerVelocity.x = -walkSpeed
		animatedSprite.flip_h = true
	elif Input.is_action_pressed("ui_right"):
		playerVelocity.x = walkSpeed
		animatedSprite.flip_h = false
	else:
		playerVelocity.x = 0

func handle_jump(isOnFloor: bool, isOnWall: bool):
	if Input.is_action_pressed("ui_up"):
		if isOnFloor:
			playerVelocity.y = -jumpForce
		elif isOnWall and wallJumpAvailable and wallJumpTimer <= 0 and wallJumpGraceTimer <= 0:
			playerVelocity.y = -jumpForce
			# Apply horizontal force away from the wall
			playerVelocity.x = (walkSpeed * (1 if not animatedSprite.flip_h else -1)) * 1.5
			wallJumpAvailable = false
			isSliding = false
			wallJumpTimer = wallJumpCooldown
			wallJumpGraceTimer = wallJumpGracePeriod

func update_animation(isOnFloor: bool, isOnWall: bool, isSliding: bool):
	var anim = "idle"
	if isSliding:
		anim = "slide"
	elif not isOnFloor:
		anim = "fall"
	elif playerVelocity.x != 0:
		anim = "walk"
	if animatedSprite.animation != anim:
		animatedSprite.stop()
		animatedSprite.play(anim)
