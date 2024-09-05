extends KinematicBody2D

# Configurable properties
var gravity = 1000
var minGravity = 600
var defaultGravity = 1000
var horizontalWindGravity = 0
var maxGravity = 2000
var sinkSpeed = 100
var windVelocity = 0
var windModifier = 30
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
var respawnCoordinateMap = {"9": [0, 0], "8": [45, -3985], "7": [133, -7340], "6": [-140, -11900]}
var currentRespawn = "8"

enum State {SINKING, INAIR, WALKING, CLIMBING, SLIDING, IDLE, INWIND}


var state = State.IDLE

# Internal state
var playerVelocity = Vector2.ZERO
var windDirection = Vector2.ZERO
var isSliding = false
var isSlipping = false
var isInWind = false
var isInAir = false
var isDead = false
var isInWater = false
var isOnWall = false
var isOnFloor = false
var wallJumpAvailable = true
var wallJumpTimer = 0.0
var wallJumpGraceTimer = 0.0
var wallJumpCooldown = 0.0  # Time in seconds before another wall jump can be performed
var wallJumpGracePeriod = 0.7  # Time in seconds during which the player can't grab the wall after jumping
var FloatingThingExitTimer = 0.0
var FloatingThingCooldown = 0.5
var onLadder = false
var isClimbing = false
var isJumping = false  # Track if the player is currently in a jump
var jumpHoldTimer = 0.0  # Track how long the jump button has been held
var canJump = true  # Used for jump state control
var distance = 0.0 # Used to track distance to ground
var isOnFloatingThing = false
var debugRespawnPosition = [0, 0] # Used to quick respawn during testing

# Nodes
onready var animatedSprite = $AnimatedSprite
onready var deathScreen = $"../Camera2D/deathScreen"
onready var collisionShape = $CollisionShape2D  # Reference to CollisionShape2D node

func _ready():
	isDead = false
	wallSlideSpeedMap["default"] = defaultWallSlideSpeed
	debugRespawnPosition = position

func _physics_process(delta):
	#print(position)
	if Input.is_action_pressed("debugRespawn"):
		position = debugRespawnPosition
	if (position.x > 880) or (position.x < -950):
		_kill_player_other()
	if isOnFloatingThing:
		FloatingThingExitTimer += delta
		if FloatingThingExitTimer > FloatingThingCooldown:
			isOnFloatingThing = false
	else:
		FloatingThingExitTimer = 0.0
		
	if isDead:
		handle_death()
		return

	update_state(delta)
	move_and_slide(playerVelocity, Vector2.UP)
	check_head_collision()  # Now this method is called

	update_animation()

	wallJumpTimer = max(wallJumpTimer - delta, 0)
	wallJumpGraceTimer = max(wallJumpGraceTimer - delta, 0)

func update_state(delta):
	match state:
		State.SINKING:
			state_sinking(delta)
		State.INAIR:
			state_inair(delta)
		State.WALKING:
			state_walking(delta)
		State.CLIMBING:
			state_climbing(delta)
		State.SLIDING:
			state_sliding(delta)
		State.IDLE:
			state_idle(delta)
		State.INWIND:
			state_in_wind(delta)
	
	# Debug output
	print(state)


func state_sinking(delta):
	playerVelocity.y += gravity * delta
	handle_jump(false, false, delta)
	if not isInWater:
		state = State.INAIR

func state_inair(delta):
	handle_fall(delta)
	isOnWall = is_on_wall()
	isOnFloor = is_on_floor()

	handle_jump(isOnFloor, isOnWall, delta)
	handle_horizontal_movement(isOnFloor, delta)
	if isOnFloor:
		state = State.IDLE  # Transition to IDLE instead of WALKING
	elif isOnWall and (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")):
		state = State.SLIDING
	elif onLadder:
		state = State.CLIMBING

func state_walking(delta):
	handle_horizontal_movement(true, delta)
	handle_jump(true, false, delta)
	handle_ground(delta)
	
	if not is_on_floor():
		state = State.INAIR
	elif onLadder:
		state = State.CLIMBING
	elif playerVelocity.x == 0 and not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right"):
		state = State.IDLE  # Transition to idle if not moving

func state_idle(delta):
	handle_jump(true, false, delta)  # This will now handle resetting canJump when on the floor
	handle_horizontal_movement(true, delta)
	
	if isJumping:
		state = State.INAIR
	elif playerVelocity.x != 0 and (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")):
		state = State.WALKING
	elif onLadder:
		state = State.CLIMBING
	elif not is_on_floor():
		state = State.INAIR  # Ensure we handle cases where the player falls
	elif is_on_floor():
		canJump = true
		wallJumpAvailable = true



func state_climbing(delta):
	handle_jump(false, false, delta)
	handle_horizontal_movement(false, delta)

	if not onLadder:
		state = State.INAIR

func state_sliding(delta):
	if wallJumpTimer <= 0:
		var wallFriction = get_wall_friction()
		handle_jump(false, true, delta)

		if is_on_wall() and not is_on_floor():
			var isPushingTowardsWall = (Input.is_action_pressed("ui_left") and animatedSprite.flip_h) or (Input.is_action_pressed("ui_right") and not animatedSprite.flip_h)
			if isPushingTowardsWall and wallJumpTimer <= 0:
				isSliding = true
				handle_wall_slide(wallFriction, delta)
			else:
				isSliding = false
				if is_on_floor():
					state = State.WALKING
				else:
					state = State.INAIR
		else:
			isSliding = false
			if is_on_floor():
				state = State.WALKING
			else:
				state = State.INAIR

func state_in_wind(delta):
	handle_fall(delta)
	handle_jump(false, false, delta)

	# Debugging output
	print("State: INWIND")
	print("Player Velocity: ", playerVelocity)
	
	# Calculate wind force
	var windForce = windVelocity.x * windDirection.x * windModifier * 0.5
	
	# Apply wind force with input-based control
	if Input.is_action_pressed("ui_left"):
		# Moving left
		if windDirection.x < 0:
			print("wind right")
			# Wind is blowing right
			playerVelocity.x = 0  # Stop moving left if wind is blowing right
		else:
			print("wind right")
			# Wind is blowing left
			playerVelocity.x = lerp(playerVelocity.x, -runSpeed, 0.1) - windForce
		animatedSprite.flip_h = true
	elif Input.is_action_pressed("ui_right"):
		# Moving right
		if windDirection.x < 0:
			print("wind right")
			# Wind is blowing right
			playerVelocity.x = lerp(playerVelocity.x, runSpeed, 0.1) - windForce
		else:
			print("wind right")
			# Wind is blowing left
			playerVelocity.x = 0  # Stop moving right if wind is blowing left
		animatedSprite.flip_h = false
	else:
		# No horizontal input
		playerVelocity.x = lerp(playerVelocity.x, 0, 0.1)






func handle_death():
	position = Vector2(respawnCoordinateMap[currentRespawn][0], respawnCoordinateMap[currentRespawn][1])
	isDead = false
	reset_variables()



func handle_horizontal_movement(isOnFloor: bool, delta: float):
	if isDead:
		return

	if Input.is_action_pressed("ui_left"):
		if not isSlipping and not onLadder or (isSlipping and isInAir):
			playerVelocity.x = -runSpeed
		elif onLadder:
			playerVelocity.x = (-runSpeed) / 3
		animatedSprite.flip_h = true
	elif Input.is_action_pressed("ui_right"):
		if not isSlipping and not onLadder or (isSlipping and isInAir):
			playerVelocity.x = runSpeed
		elif onLadder:
			playerVelocity.x = runSpeed/3
		animatedSprite.flip_h = false
	elif isOnFloor:
		var friction = get_ground_friction()
		playerVelocity.x = lerp(playerVelocity.x, 0, friction * delta)
	elif state == State.INWIND:
		playerVelocity.x = playerVelocity.x
	else:
		playerVelocity.x = 0

func handle_jump(isOnFloor: bool, isOnWall: bool, delta: float):

	if isDead:
		return

	if onLadder:
		gravity = 0
		if Input.is_action_pressed("ui_up"):
			playerVelocity.y = -ladderClimbSpeed
			isClimbing = true
			update_ladder_animation()
		elif Input.is_action_pressed("ui_down"):
			playerVelocity.y = ladderClimbSpeed
			isClimbing = true
			update_ladder_animation()
		else:
			playerVelocity.y = 0
			animatedSprite.stop()
		return

	if isClimbing:
		isClimbing = false
		gravity = defaultGravity
		playerVelocity.y = 0
		return

	if not isSlipping and not isJumping and not isInWater:
		gravity = defaultGravity

		# Execute jump
		if Input.is_action_just_pressed("ui_up"):
			isOnWall = is_on_wall()
			# print("canJump ",canJump," isOnWall ",isOnWall," wallJumpAvailable ",wallJumpAvailable," wallJumpTimer ",wallJumpTimer)
			if canJump and not isOnWall:
				canJump = false
				isJumping = true
				jumpHoldTimer = 0.0
				playerVelocity.y = -jumpForce
				if not isInWind:
					state = State.INAIR
				else:
					state = State.INWIND
			elif isOnWall and wallJumpAvailable and wallJumpTimer <= 0:
				playerVelocity.y = -wallJumpForce
				playerVelocity.x = (runSpeed * (1 if not animatedSprite.flip_h else -1)) * 1.5
				isSliding = false
				wallJumpAvailable = false
				wallJumpTimer = wallJumpCooldown
				wallJumpGraceTimer = wallJumpGracePeriod
				print("wallJumpAvailable ", wallJumpAvailable, " wallJumpTimer ",wallJumpTimer, " wallJumpGraceTimer ", wallJumpGraceTimer)
				if not isInWind:
					state = State.INAIR
				else:
					state = State.INWIND

	if isJumping:
		if Input.is_action_pressed("ui_up") and jumpHoldTimer < maxJumpHoldTime:
			jumpHoldTimer += delta
			gravity = minGravity
			if not isInWind:
				state = State.INAIR
			else:
				state = State.INWIND
		else:
			isJumping = false
			gravity = defaultGravity

	if isOnFloor and not isJumping and not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right"):
		state = State.IDLE




# Add the missing method here
func check_head_collision():
	# Check for head collisions
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal.y > 0:  # Check if the collision is from above
			playerVelocity.y = 0  # Reset vertical velocity

func update_animation():
	if isDead:
		return

	var anim = "idle"
	if state == State.CLIMBING:
		anim = "climb"
	elif state == State.SLIDING:
		anim = "slide"
	elif state == State.INAIR and not isOnFloatingThing:
		anim = "fall"
	elif state == State.SINKING:
		anim = "sinking"
	elif state == State.INWIND:
		anim = "fall"
	elif playerVelocity.x != 0 and (state == State.WALKING or state == State.INAIR):
		anim = "run"
	
	if animatedSprite.animation != anim:
		animatedSprite.stop()
		animatedSprite.play(anim)


func reset_variables():
	playerVelocity = Vector2.ZERO
	isSliding = false
	isSlipping = false
	isInAir = false
	isInWater = false
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
		playerVelocity.y /= 5
	isSliding = true
	playerVelocity.y = lerp(playerVelocity.y, wallFriction, delta)


func handle_fall(delta, floating = false):
	if not isInWater:
		# Apply vertical gravity
		playerVelocity.y += gravity * delta
	
		# Apply constant horizontal wind force if in wind state
		if state == State.INWIND and not is_on_floor():
			var windSpeed = windVelocity.x * -windDirection.x * windModifier
			# Cap the horizontal speed to prevent continuous acceleration
			if abs(playerVelocity.x) > abs(windSpeed):
				playerVelocity.x = windSpeed
			else:
				# Use delta to apply wind force gradually
				playerVelocity.x = lerp(playerVelocity.x, windSpeed, delta * 4)
		elif is_on_floor():
			isOnFloor = true
			state = State.IDLE
	else:
		playerVelocity.y += (sinkSpeed / 2) * delta
	
	if not floating:
		isSliding = false
		canJump = false





func handle_ground(delta):
	var collision = get_slide_collision(0)
	if collision and collision.normal.y < 1:
		isSliding = false
		if isInWater:
			_kill_player_other()

		var slope_angle = abs((acos(collision.normal.y) * 180 / PI) - 180)
		var slope_direction = Vector2(collision.normal.y, -collision.normal.x).normalized()
		
		var groundFriction = get_ground_friction()
		
		if abs(slope_angle) > groundFriction * 10:
			playerVelocity += slope_direction * (20 - groundFriction) * delta
			if playerVelocity.y < minSlippSpeed * slope_angle * groundFriction:
				playerVelocity.y = minSlippSpeed * slope_angle * groundFriction
			isSlipping = true
		else:
			isSlipping = false
			if playerVelocity.y > 5:
				playerVelocity.y = 5
	else:
		isSlipping = false
	wallJumpAvailable = true
	canJump = true

func _on_Ladder_area_entered(area):
	onLadder = true
	isClimbing = true
	reset_jump_state()

func _on_Ladder_area_exited(area):
	onLadder = false

func reset_jump_state():
	isJumping = false
	canJump = true
	jumpHoldTimer = 0.0
	wallJumpTimer = 0.0
	playerVelocity.y = 0
	wallJumpGraceTimer = 0.0
	isSliding = false
	isSlipping = false
	update_ladder_animation()

func update_ladder_animation():
	if playerVelocity.y < 0:
		if not animatedSprite.is_playing():
			animatedSprite.play("climb")
	elif playerVelocity.y > 0:
		if not animatedSprite.is_playing():
			animatedSprite.play("climb")
	else:
		animatedSprite.stop()

func _on_Respawn_body_entered(body, sender):
	if body.name == "Player":
		if int(sender) < int(currentRespawn):
			currentRespawn = sender

func _kill_player_from_touching(body):
	if body.name == "Player":
		isDead = true
		handle_death()

func _kill_player_other():
	isDead = true
	handle_death()

func _on_floating_thing_entered(body):
	if body.name == "Player":
		isOnFloatingThing = true
		FloatingThingExitTimer = 0.0

func _on_floating_thing_exited(body):
	if body.name == "Player":
		FloatingThingExitTimer = FloatingThingCooldown

func _water_exited(body):
	if body.name == "Player":
		isInWater = false

func _water_entered(body):
	if body.name == "Player":
		isInWater = true
		playerVelocity.y = sinkSpeed


func _on_wind_entered(body, wind_dir: Vector2, wind_velocity: Vector2):
	if body.name == "Player":
		windDirection = wind_dir
		windVelocity = wind_velocity
		state = State.INWIND
		isInWind = true
		print("Entered wind: ", windDirection, windVelocity)

func _on_wind_exited(body):
	if body.name == "Player":
		windDirection = Vector2.ZERO
		windVelocity = 0
		state = State.INAIR
		isInWind = false
		print("Exited wind")
