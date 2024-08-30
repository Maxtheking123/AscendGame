extends KinematicBody2D
# Configurable properties
var gravity = 1000
var minGravity = 600
var defaultGravity = 1000
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
var respawnCoordinateMap = {"9": [0, 0], "8": [45, -3985]}
var currentRespawn = "8"

var leftButton = ""

# Internal state
var playerVelocity = Vector2.ZERO
var isSliding = false
var isSlipping = false
var isInAir = false
var isDead = false
var wallJumpAvailable = true
var wallJumpTimer = 0.0
var wallJumpGraceTimer = 0.0
var wallJumpCooldown = 0.2  # Time in seconds before another wall jump can be performed
var wallJumpGracePeriod = 0.7  # Time in seconds during which the player can't grab the wall after jumping
var onLadder = false
var isClimbing = false
var isJumping = false  # Track if the player is currently in a jump
var jumpHoldTimer = 0.0  # Track how long the jump button has been held
var canJump = true  # Used for jump state control
var distance = 0.0 # Used to track distance to ground

# Nodes
onready var animatedSprite = $AnimatedSprite
onready var deathScreen = $"../Camera2D/deathScreen"


func _ready():
	# Ensure the player doesn't move at the start of the game
	isDead = false
	
	# Initialize other settings here
	wallSlideSpeedMap["default"] = defaultWallSlideSpeed
	# Any other initialization

func _physics_process(delta):
	if isDead:
		handleDeath()
		return
		
	# Debugging for finding checkpoints
	# print("playerX: ", position.x, " playerY: ", position.y)
	var isOnWall = is_on_wall()
	var isOnFloor = is_on_floor()
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
		if collision.normal.y > 0:  # Check if the collision is from above
			playerVelocity.y = 0  # Reset vertical velocity
	
	update_animation(isOnFloor, isOnWall, isSliding)
	
	# Update timers
	wallJumpTimer = max(wallJumpTimer - delta, 0)
	wallJumpGraceTimer = max(wallJumpGraceTimer - delta, 0)


func handleDeath():
	if isDead:  # Only move to the respawn point if the player is actually dead
		print("respawning")
		position = Vector2(respawnCoordinateMap[currentRespawn][0], respawnCoordinateMap[currentRespawn][1])
		isDead = false  # Reset the death state
	reset_variables()



func handle_horizontal_movement(isOnFloor: bool, delta: float):
	if isDead:
		return  # Prevent movement if the player is dead
	
	if Input.is_action_pressed("ui_left"):
		print(onLadder)
		if not isSlipping and not onLadder or (isSlipping and isInAir):
			playerVelocity.x = -runSpeed
			
		# Makes sideways movement slower on ladders
		elif onLadder:
			playerVelocity.x = (-runSpeed) / 3
			print((-runSpeed)/4, " vs ", (-runSpeed))
			
		animatedSprite.flip_h = true
	elif Input.is_action_pressed("ui_right"):
		if not isSlipping and not onLadder or (isSlipping and isInAir):
			playerVelocity.x = runSpeed
			
		# Makes sideways movement slower on ladders
		elif onLadder:
			playerVelocity.x = runSpeed/3
			
		animatedSprite.flip_h = false
	elif isOnFloor:
		var friction = get_ground_friction()
		playerVelocity.x = lerp(playerVelocity.x, 0, friction * delta)
	else:
		playerVelocity.x = 0

func handle_jump(isOnFloor: bool, isOnWall: bool, delta: float):
	if isDead:
		return  # Prevent jumping if the player is dead

	if onLadder:
		gravity = 0  # Disable gravity while on the ladder
		
		if Input.is_action_pressed("ui_up"):
			playerVelocity.y = -ladderClimbSpeed
			isClimbing = true
			update_ladder_animation()  # Update animation when moving on the ladder
		elif Input.is_action_pressed("ui_down"):
			playerVelocity.y = ladderClimbSpeed
			isClimbing = true
			update_ladder_animation()  # Update animation when moving on the ladder
		else:
			playerVelocity.y = 0
			# Pause the climbing animation if not moving on the ladder
			animatedSprite.stop()
	else:
		# If not on the ladder but still climbing, check for ladder exit condition
		if isClimbing:
			playerVelocity.y = 0
			if not onLadder:
				isClimbing = false
				gravity = defaultGravity
			else:
				gravity = 0  # Disable gravity until the player is fully off the ladder
		
		if not isSlipping and not isJumping:
			gravity = defaultGravity  # Reset gravity when not climbing
		
		if Input.is_action_just_pressed("ui_up"):
			if not isSlipping:
				if canJump:
					canJump = false
					isJumping = true
					jumpHoldTimer = 0.0
					playerVelocity.y = -jumpForce
				if isOnWall and wallJumpAvailable:
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
		else:
			isJumping = false
			gravity = defaultGravity

func update_animation(isOnFloor: bool, isOnWall: bool, isSliding: bool):
	if isDead:
		return  # Prevent any animation updates if the player is dead

	var anim = "idle"
	if isClimbing:
		anim = "climb"
	elif isSliding:
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

func reset_variables():
	# Reset player states and variables after death
	playerVelocity = Vector2.ZERO
	isSliding = false
	isSlipping = false
	isInAir = false
	wallJumpAvailable = true
	wallJumpTimer = 0.0
	wallJumpGraceTimer = 0.0
	onLadder = false
	isClimbing = false
	isJumping = false
	jumpHoldTimer = 0.0
	canJump = true
	gravity = defaultGravity
	animatedSprite.flip_h = false


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
		else:
			isSlipping = false
			playerVelocity.y = 5
	else:
		isSlipping = false
	wallJumpAvailable = true
	isJumping = false  # Reset the jumping state when on the ground
	canJump = true


func _on_Ladder_area_entered(area):
	onLadder = true
	isClimbing = true  # Start climbing when entering the ladder area
	reset_jump_state()  # Reset jump and other states when landing on a ladder

func _on_Ladder_area_exited(area):
	onLadder = false
	# Don't immediately stop climbing; let the logic in handle_jump control it
	# Only reset climbing and gravity when the player is confirmed to be off the ladder

func reset_jump_state():
	# Reset jump-related states when landing on a ladder
	isJumping = false
	canJump = true  # Allow jumping again, as if the player landed on the ground
	jumpHoldTimer = 0.0
	wallJumpTimer = 0.0  # Reset wall jump timer, but do not reset wall jump availability

	# Reset velocity and other states as necessary
	playerVelocity.y = 0
	wallJumpGraceTimer = 0.0  # Reset the wall jump grace period timer
	isSliding = false
	isSlipping = false

	# Initialize climbing animation
	update_ladder_animation()

func update_ladder_animation():
	if playerVelocity.y < 0:
		if not animatedSprite.is_playing():
			animatedSprite.play("climb")
	elif playerVelocity.y > 0:
		if not animatedSprite.is_playing():
			animatedSprite.play("climb")
	else:
		# Not moving: pause the animation
		animatedSprite.stop()

func _on_Respawn_8_body_entered():
	currentRespawn = "8"


func _on_DeathTar_body_entered(body):
	print(body.name)
	if(body.name == "Player"):
		print("died")
		isDead = true
		handleDeath()
