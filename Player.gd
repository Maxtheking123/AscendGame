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
var defaultGroundSound = preload("res://Assets/sounds/Step_rock.wav")
var sounds = {
	"jump": preload("res://Assets/sounds/Jump.wav"),
	"grass": preload("res://Assets/sounds/Step_grass.wav"),
	"rock": preload("res://Assets/sounds/Step_rock.wav"),
	"water": preload("res://Assets/sounds/Step_water.wav"),
	"underwater": preload("res://Assets/sounds/Swim_Submerged.wav"),
	"land": preload("res://Assets/sounds/Landing.wav"),
}
var groundSoundMap = {"ice": sounds["water"], "grass": sounds["grass"], "rock": sounds["rock"]}
var groundFrictionMap = {"ice": 2}
var wallSlideSpeedMap = {"ice": 600}  # Dictionary to hold friction values for different wall types
var respawnCoordinateMap = {"9": [0, 0], "8": [45, -3985], "7": [133, -7340], "6": [-140, -11900], "5": [-74, -17376], "4": [659, -21646], "3": [57, -25144], "2": [51, -29524], "1": [77, -32880]}
var currentRespawn = "9"

enum State {SINKING, INAIR, WALKING, CLIMBING, SLIDING, IDLE, INWIND, GAMEOVER}


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
var animation_delay = 2.5  # Delay before starting the player scaling
var GameoverTimer = 0.0  # Track the time passed since the game over state started
var onLadder = false
var isClimbing = false
var isJumping = false  # Track if the player is currently in a jump
var jumpHoldTimer = 0.0  # Track how long the jump button has been held
var canJump = true  # Used for jump state control
var distance = 0.0 # Used to track distance to ground
var isOnFloatingThing = false
var debugRespawnPosition = [0, 0] # Used to quick respawn during testing
var debug = false

var soundEffectsVolume = 1.0  # Volume control variable
var currentSound = ""  # Track the current sound being played

# Nodes
onready var animatedSprite = $AnimatedSprite
onready var deathScreen = $"../Camera2D/deathScreen"
onready var collisionShape = $CollisionShape2D  # Reference to CollisionShape2D node
onready var gate1 = $"../objectAbovePlayer/Image-removebg-preview"
onready var gate2 = $"../objectAbovePlayer/Image-removebg-preview4"
onready var fade_rect = $"../Camera2D/fadeRect"
onready var audioPlayer = $AudioStreamPlayer2D

func _ready():
	isDead = false
	wallSlideSpeedMap["default"] = defaultWallSlideSpeed
	debugRespawnPosition = position
	audioPlayer.volume_db = linear2db(soundEffectsVolume)  # Set initial volume

func _physics_process(delta):
	#print(position)
	if debug == true:
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
	if state == State.GAMEOVER:
		state_gameOver(delta)
	else:
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
	elif playerVelocity.x != 0 and (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") and not isSlipping):
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
	
	# Calculate wind force
	var windForce = windVelocity.x * windDirection.x * windModifier * 0.5
	
	# Apply wind force with input-based control
	if Input.is_action_pressed("ui_left"):
		# Moving left
		if windDirection.x < 0:
			# Wind is blowing right
			playerVelocity.x = 0  # Stop moving left if wind is blowing right
		else:
			# Wind is blowing left
			playerVelocity.x = lerp(playerVelocity.x, -runSpeed, 0.1) - windForce
		animatedSprite.flip_h = true
	elif Input.is_action_pressed("ui_right"):
		# Moving right
		if windDirection.x < 0:
			# Wind is blowing right
			playerVelocity.x = lerp(playerVelocity.x, runSpeed, 0.1) - windForce
		else:
			# Wind is blowing left
			playerVelocity.x = 0  # Stop moving right if wind is blowing left
		animatedSprite.flip_h = false
	else:
		# No horizontal input
		playerVelocity.x = lerp(playerVelocity.x, 0, 0.1)


# Declare variables to track elapsed time for delay

func state_gameOver(delta):
	playerVelocity.x = 0
	
	# Makes sure there is some gravity
	playerVelocity.y = 100

	var gate2targetPosX = 182
	var gate2targetScaleX = 0.376
	var gate1targetPosX = -252.25
	var gate1targetScaleX = 0.376
	
	var gameoverAnimationSpeed = 2
	
	# Update the time elapsed
	GameoverTimer += delta

	# Gate animations (play immediately)
	if GameoverTimer >= 0:
		# Move gate1 towards target position
		var gate1_pos = gate1.position
		gate1_pos.x = lerp(gate1_pos.x, gate1targetPosX, gameoverAnimationSpeed * delta)
		gate1.position = gate1_pos

		# Scale gate1 towards target scale
		var gate1_scale = gate1.scale
		gate1_scale.x = lerp(gate1_scale.x, gate1targetScaleX, gameoverAnimationSpeed * delta)
		gate1.scale = gate1_scale

		# Move gate2 towards target position
		var gate2_pos = gate2.position
		gate2_pos.x = lerp(gate2_pos.x, gate2targetPosX, gameoverAnimationSpeed * delta)
		gate2.position = gate2_pos

		# Scale gate2 towards target scale
		var gate2_scale = gate2.scale
		gate2_scale.x = lerp(gate2_scale.x, gate2targetScaleX, gameoverAnimationSpeed * delta)
		gate2.scale = gate2_scale

	# Delay before starting the player scaling animation
	if GameoverTimer >= animation_delay:
		# Scale player to (1.2, 1.2) with linear interpolation
		var player_scale = scale
		player_scale.x = lerp(player_scale.x, 1.2, gameoverAnimationSpeed * delta)
		player_scale.y = lerp(player_scale.y, 1.2, gameoverAnimationSpeed * delta)
		scale = player_scale

	# Fade the screen to white with delay
	if GameoverTimer >= animation_delay:
		var fade_color = fade_rect.modulate
		fade_color.a = lerp(fade_color.a, 1.0, gameoverAnimationSpeed * delta)  # Fade to fully opaque
		fade_rect.modulate = fade_color


	
	


func handle_death():
	position = Vector2(respawnCoordinateMap[currentRespawn][0], respawnCoordinateMap[currentRespawn][1])
	isDead = false
	reset_variables()




func handle_horizontal_movement(isOnFloor: bool, delta: float):
	if isDead:
		return

	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
		if not isSlipping and not onLadder or (isSlipping and isInAir):
			playerVelocity.x = -runSpeed if Input.is_action_pressed("ui_left") else runSpeed
		elif onLadder:
			playerVelocity.x = (-runSpeed / 3) if Input.is_action_pressed("ui_left") else (runSpeed / 3)

		animatedSprite.flip_h = Input.is_action_pressed("ui_left")

		# Play sound if it's not already playing
		if not audioPlayer.playing and is_on_floor():
			var sound = get_ground_sound()  # Get the sound path
			audioPlayer.stream = sound
			audioPlayer.volume_db = linear2db(soundEffectsVolume)  # Adjust volume dynamically
			audioPlayer.play()
			currentSound = "walking"  # Track the current sound

	elif isOnFloor:
		var friction = get_ground_friction()
		playerVelocity.x = lerp(playerVelocity.x, 0, friction * delta)

		# Stop the walking sound if player is stopping
		if currentSound == "walking" and audioPlayer.playing:
			audioPlayer.stop()
			currentSound = ""  # Reset current sound

	elif state == State.INWIND:
		playerVelocity.x = playerVelocity.x  # No sound changes in wind state
	else:
		playerVelocity.x = 0

		# Stop the walking sound if player is not moving
		if currentSound == "walking" and audioPlayer.playing:
			audioPlayer.stop()
			currentSound = ""  # Reset current sound





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

		if Input.is_action_just_pressed("ui_up"):
			if canJump and not isOnWall:
				canJump = false
				isJumping = true
				jumpHoldTimer = 0.0
				playerVelocity.y = -jumpForce
				if not isInWind:
					state = State.INAIR
				else:
					state = State.INWIND
				play_sound(sounds["jump"])
			elif isOnWall and wallJumpAvailable and wallJumpTimer <= 0:
				playerVelocity.y = -wallJumpForce
				playerVelocity.x = (runSpeed * (1 if not animatedSprite.flip_h else -1)) * 1.5
				isSliding = false
				wallJumpAvailable = false
				wallJumpTimer = wallJumpCooldown
				wallJumpGraceTimer = wallJumpGracePeriod
				if not isInWind:
					state = State.INAIR
				else:
					state = State.INWIND
				play_sound(sounds["jump"])

	if isJumping:
		if Input.is_action_pressed("ui_up") and jumpHoldTimer < maxJumpHoldTime:
			jumpHoldTimer += delta
			gravity = minGravity
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
	elif state == State.GAMEOVER:
		anim = "gameOver"
	
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

func get_ground_sound():
	var collision = get_slide_collision(0)
	if collision:
		var collider = collision.collider
		if collider.has_meta("floor_type"):
			return groundSoundMap.get(collider.get_meta("floor_type"), defaultGroundSound)
	return defaultGroundSound

func handle_wall_slide(wallFriction, delta):
	if not isSliding and playerVelocity.y < 0:
		playerVelocity.y /= 5
	isSliding = true
	playerVelocity.y = lerp(playerVelocity.y, wallFriction, delta)


func handle_fall(delta, floating = false):
	isSlipping = false
	if not isInWater:
		playerVelocity.y += gravity * delta

		if state == State.INWIND and not is_on_floor():
			var windSpeed = windVelocity.x * -windDirection.x * windModifier
			if abs(playerVelocity.x) > abs(windSpeed):
				playerVelocity.x = windSpeed
			else:
				playerVelocity.x = lerp(playerVelocity.x, windSpeed, delta * 4)
		# Play landing sound if on the floor
		if is_on_floor():
			# Makes sure you are falling fast enough to make a sound
			if playerVelocity.y > 600:
				play_sound(sounds["land"])
				
			isOnFloor = true
	else:
		playerVelocity.y += (sinkSpeed / 2) * delta

	if not floating:
		isSliding = false
		canJump = false

func play_sound(sound):
	audioPlayer.stream = sound
	audioPlayer.volume_db = linear2db(soundEffectsVolume)  # Adjust volume dynamically
	audioPlayer.play()

	audioPlayer.play()


func handle_ground(delta):
	var collision = get_slide_collision(0)
	if collision and collision.normal.y < 1:
		isSliding = false
		if isInWater:
			_kill_player_other()

		var slope_angle = abs((acos(collision.normal.y) * 180 / PI) - 180)
		var slope_normal = collision.normal.normalized()
		
		# Rotate the velocity based on the slope's angle
		var slope_direction = Vector2(slope_normal.y, -slope_normal.x).normalized()
		if abs(slope_direction.angle()) > 20:
			print(playerVelocity)
			playerVelocity = playerVelocity.rotated(slope_direction.angle())
			print(playerVelocity)

		# Friction logic
		var groundFriction = get_ground_friction()
		
		if abs(slope_angle) > groundFriction * 10:
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

func _on_wind_exited(body):
	if body.name == "Player":
		windDirection = Vector2.ZERO
		windVelocity = 0
		state = State.INAIR
		isInWind = false


func handle_gameOver(body):
	if body.name == "Player":
		state = State.GAMEOVER
