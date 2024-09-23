extends KinematicBody2D

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
var jumpForce = 500
var wallJumpForce = 600
var maxJumpHoldTime = 0.4
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
var wallSlideSpeedMap = {"ice": 600}
var respawnCoordinateMap = {"9": [0, 0], "8": [45, -3985], "7": [133, -7340], "6": [-140, -11900], "5": [-74, -17376], "4": [659, -21646], "3": [57, -25144], "2": [51, -29524], "1": [77, -32880]}
var currentRespawn = "9"

var gate2startPosX = 313.907
var gate2startScaleX = 1
var gate1startPosX = 44.496
var gate1startScaleX = 1

enum State {SINKING, INAIR, WALKING, CLIMBING, SLIDING, IDLE, INWIND, GAMEOVER}
var state = State.IDLE

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
var wallJumpCooldown = 0.0
var wallJumpGracePeriod = 0.7 
var FloatingThingExitTimer = 0.0
var FloatingThingCooldown = 0.5
var animation_delay = 2.5
var GameoverTimer = 0.0
var onLadder = false
var isClimbing = false
var isJumping = false 
var jumpHoldTimer = 0.0
var canJump = true
var distance = 0.0
var isOnFloatingThing = false
var debugRespawnPosition = [0, 0]
var debug = false

var soundEffectsVolume = 1.0
var currentSound = ""

onready var animatedSprite = $AnimatedSprite
onready var collisionShape = $CollisionShape2D
onready var gate1 = $"../objectAbovePlayer/Image-removebg-preview"
onready var gate2 = $"../objectAbovePlayer/Image-removebg-preview4"
onready var fade_rect = $"../Camera2D/fadeRect"
onready var audioPlayer = $AudioStreamPlayer2D

onready var autosaveTimer = Timer.new()
const SAVE_FILE_PATH = "user://AscendSaveFile.save"

func _ready():
	isDead = false
	wallSlideSpeedMap["default"] = defaultWallSlideSpeed
	debugRespawnPosition = position
	if not debug:
		_load_high_score(SAVE_FILE_PATH)
	
	autosaveTimer.wait_time = 3
	autosaveTimer.one_shot = false 
	add_child(autosaveTimer)
	autosaveTimer.connect("timeout", self, "_on_autosave_timeout")
	autosaveTimer.start()

func _on_autosave_timeout():
	"""
	description: Handles the autosave timer, saving the player's progress every 15 seconds.
	params: None
	"""
	if is_on_floor():
		_save_state()
		print("Autosaved at position:", position)

func _load_high_score(file_path: String) -> void:
	"""
	description: Loads the player's saved position and state from the save file.
	params: file_path (String): The path to the save file.
	"""
	var saveFile = File.new()
	
	if saveFile.file_exists(file_path):
		saveFile.open(file_path, File.READ)
		var saveInfo = saveFile.get_var()  # Assuming the data is stored as an array
		saveFile.close()
		
		if saveInfo != null:
			# Apply the saved data
			position.x = saveInfo[0]
			position.y = saveInfo[1]
			state = saveInfo[2]
			currentRespawn = saveInfo[3]			
	else:
		print("No save file found at", file_path)
		
	
func _save_state() -> void:
	"""
	description: Saves the player's current position and state to the save file.
	params: None
	"""
	var saveFile = File.new()
	var saveInfo = [position.x, position.y, state, currentRespawn]
	saveFile.open(SAVE_FILE_PATH, File.WRITE)
	saveFile.store_var(saveInfo)
	saveFile.close()

func _physics_process(delta):
	if Input.is_action_pressed("ui_cancel"):
		_save_state()
		get_tree().change_scene("res://menu.tscn")
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
	check_head_collision() 

	update_animation()

	wallJumpTimer = max(wallJumpTimer - delta, 0)
	wallJumpGraceTimer = max(wallJumpGraceTimer - delta, 0)

func update_state(delta):
	"""
	description: Updates the player's state based on the current state and game conditions.
	params: delta: time passed since last frame
	"""
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


func state_sinking(delta):
	"""
	description: Handles the sinking state when the player is in water.
	params: delta: The time passed since the last frame.
	"""
	playerVelocity.y += gravity * delta
	handle_jump(false, false, delta)
	if not isInWater:
		state = State.INAIR

func state_inair(delta):
	"""
	description: Manages the player's state while in the air, including handling falls and wall interactions.
	params: delta: time passed since last frame
	"""
	handle_fall(delta)
	isOnWall = is_on_wall()
	isOnFloor = is_on_floor()

	handle_jump(isOnFloor, isOnWall, delta)
	handle_horizontal_movement(isOnFloor, delta)
	if isOnFloor:
		state = State.IDLE 
	elif isOnWall and (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")):
		state = State.SLIDING
	elif onLadder:
		state = State.CLIMBING

func state_walking(delta):
	"""
	description: Handles player movement when walking on the ground.
	params: delta: time passed since last frame
	"""
	handle_horizontal_movement(true, delta)
	handle_jump(true, false, delta)
	handle_ground(delta)
	
	if not is_on_floor():
		state = State.INAIR
	elif onLadder:
		state = State.CLIMBING
	elif playerVelocity.x == 0 and not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right"):
		state = State.IDLE

func state_idle(delta):
	"""
	description: Manages the idle state, including transitioning to other states like walking or jumping.
	params: delta: time passed since last frame
	"""
	handle_jump(true, false, delta) 
	handle_horizontal_movement(true, delta)
	
	if isJumping:
		state = State.INAIR
	elif playerVelocity.x != 0 and (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") and not isSlipping):
		state = State.WALKING
	elif onLadder:
		state = State.CLIMBING
	elif not is_on_floor():
		state = State.INAIR 
	elif is_on_floor():
		canJump = true
		wallJumpAvailable = true



func state_climbing(delta):
	"""
	description: Handles movement while climbing ladders.
	params: delta: time passed since last frame
	"""
	handle_jump(false, false, delta)
	handle_horizontal_movement(false, delta)

	if not onLadder:
		state = State.INAIR

func state_sliding(delta):
	"""
	description: Manages the player’s movement while sliding down walls.
	params: delta: time passed since last frame
	"""
	if wallJumpTimer <= 0:
		var wallFriction = get_wall_friction()
		handle_jump(false, true, delta)

		if is_on_wall() and not is_on_floor():
			var isPushingTowardsWall = (Input.is_action_pressed("ui_left") and animatedSprite.flip_h) or (Input.is_action_pressed("ui_right") and not animatedSprite.flip_h)
			if isPushingTowardsWall and wallJumpTimer <= 0:
				isSliding = true
				handle_wall_slide(wallFriction, delta)

				# Apply wind force while sliding
				if state == State.INWIND:
					playerVelocity.x += windVelocity.x * windDirection.x * windModifier * delta
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
	"""
	description: Handles player movement and behavior while in strong wind conditions.
	params: delta: time passed since last frame
	"""
	
	handle_fall(delta)
	handle_jump(false, false, delta)

	var windForce = windVelocity.x * windDirection.x * windModifier * 0.5

	if Input.is_action_pressed("ui_left"):
		if windDirection.x < 0:
			playerVelocity.x = 0
		else:
			playerVelocity.x = lerp(playerVelocity.x, -runSpeed, 0.1) - windForce
		animatedSprite.flip_h = true
	elif Input.is_action_pressed("ui_right"):
		if windDirection.x < 0:
			playerVelocity.x = lerp(playerVelocity.x, runSpeed, 0.1) - windForce
		else:
			playerVelocity.x = 0
		animatedSprite.flip_h = false
	else:
		playerVelocity.x = lerp(playerVelocity.x, 0, 0.1)

	# Check if the player is moving towards the wall and touching it
	isOnWall = is_on_wall()
	if isOnWall:
		var isPushingTowardsWall = (Input.is_action_pressed("ui_left") and animatedSprite.flip_h) or (Input.is_action_pressed("ui_right") and not animatedSprite.flip_h)

		if isPushingTowardsWall:
			# Transition to sliding state if pushing against the wall
			state = State.SLIDING

func state_gameOver(delta):
	"""
	description: Manages the game over state animation and timer.
	params: delta: time passed since last frame
	"""
	playerVelocity.x = 0
	
	playerVelocity.y = 100

	var gate2targetPosX = 182
	var gate2targetScaleX = 0.376
	var gate1targetPosX = -252.25
	var gate1targetScaleX = 0.376
	
	var gameoverAnimationSpeed = 2
	
	GameoverTimer += delta

	if GameoverTimer >= 0:
		var gate1_pos = gate1.position
		gate1_pos.x = lerp(gate1_pos.x, gate1targetPosX, gameoverAnimationSpeed * delta)
		gate1.position = gate1_pos

		var gate1_scale = gate1.scale
		gate1_scale.x = lerp(gate1_scale.x, gate1targetScaleX, gameoverAnimationSpeed * delta)
		gate1.scale = gate1_scale

		var gate2_pos = gate2.position
		gate2_pos.x = lerp(gate2_pos.x, gate2targetPosX, gameoverAnimationSpeed * delta)
		gate2.position = gate2_pos

		var gate2_scale = gate2.scale
		gate2_scale.x = lerp(gate2_scale.x, gate2targetScaleX, gameoverAnimationSpeed * delta)
		gate2.scale = gate2_scale

	if GameoverTimer >= animation_delay:
		var player_scale = scale
		player_scale.x = lerp(player_scale.x, 1.2, gameoverAnimationSpeed * delta)
		player_scale.y = lerp(player_scale.y, 1.2, gameoverAnimationSpeed * delta)
		scale = player_scale

	if GameoverTimer >= animation_delay:
		var fade_color = fade_rect.modulate
		fade_color.a = lerp(fade_color.a, 1.0, gameoverAnimationSpeed * delta)
		fade_rect.modulate = fade_color



func handle_death():
	"""
	description: Handles resetting the player’s position and state upon death.
	params: None
	"""
	position = Vector2(respawnCoordinateMap[currentRespawn][0], respawnCoordinateMap[currentRespawn][1])
	isDead = false
	reset_variables()




func handle_horizontal_movement(isOnFloor: bool, delta: float):
	"""
	description: Controls horizontal movement, including player speed, friction, and sound effects.
	params: isOnFloor (bool): Whether the player is on the ground. delta (float): The time passed since the last frame.
	"""
	if isDead:
		return

	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
		if not isSlipping and not onLadder or (isSlipping and isInAir):
			playerVelocity.x = -runSpeed if Input.is_action_pressed("ui_left") else runSpeed
		elif onLadder:
			playerVelocity.x = (-runSpeed / 3) if Input.is_action_pressed("ui_left") else (runSpeed / 3)

		animatedSprite.flip_h = Input.is_action_pressed("ui_left")

		if not audioPlayer.playing and is_on_floor():
			var sound = get_ground_sound() 
			audioPlayer.stream = sound
			audioPlayer.play()
			currentSound = "walking" 

	elif isOnFloor:
		var friction = get_ground_friction()
		playerVelocity.x = lerp(playerVelocity.x, 0, friction * delta)

		if currentSound == "walking" and audioPlayer.playing:
			audioPlayer.stop()
			currentSound = "" 

	elif state == State.INWIND:
		playerVelocity.x = playerVelocity.x 
	else:
		playerVelocity.x = 0

		if currentSound == "walking" and audioPlayer.playing:
			audioPlayer.stop()
			currentSound = "" 





func handle_jump(isOnFloor: bool, isOnWall: bool, delta: float):
	"""
	description: Handles player jumping, including jump force, wall jumps, and state transitions.
	params: isOnFloor (bool): Whether the player is on the ground. isOnWall (bool): Whether the player is on a wall. delta (float): The time passed since the last frame.
	"""
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




func check_head_collision():
	"""
	description: Checks if the player is colliding with something above and resets vertical velocity if so.
	params: None
	"""
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal.y > 0:  
			playerVelocity.y = 0 

func update_animation():
	"""
	description: Updates the player's animation based on the current state and velocity.
	params: None
	"""
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
	"""
	description: Resets player variables to default, often used after respawning or when resetting the game state.
	params: None
	"""
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
	
	scale.x = 2
	scale.y = 2
	
	gate1.position.x = gate1startPosX
	gate1.scale.x = gate1startScaleX
	gate2.position.x = gate2startPosX
	gate2.scale.x = gate2startScaleX



func restart_game():
	currentRespawn = "9"
	state = State.IDLE
	handle_death()
	var fade_color = fade_rect.modulate
	fade_color.a = 0
	fade_rect.modulate = fade_color
	_save_state()
	

func get_wall_friction() -> float:
	"""
	description: Retrieves the friction value for the current wall the player is in contact with.
	return: float: The friction value for the wall.
	"""
	var collision = get_slide_collision(0)
	if collision:
		var collider = collision.collider
		if collider.has_meta("wall_type"):
			return wallSlideSpeedMap.get(collider.get_meta("wall_type"), defaultWallSlideSpeed)
	return defaultWallSlideSpeed

func get_ground_friction() -> float:
	"""
	description: Retrieves the friction value for the current ground surface.
	return: float: The friction value for the ground.
	"""
	var collision = get_slide_collision(0)
	if collision:
		var collider = collision.collider
		if collider.has_meta("floor_type"):
			return groundFrictionMap.get(collider.get_meta("floor_type"), defaultGroundFriction)
	return defaultGroundFriction

func get_ground_sound():
	"""
	description: Retrieves the appropriate sound for the current ground surface.
	return: Sound: The sound to be played when moving on the ground.
	"""
	var collision = get_slide_collision(0)
	if collision:
		var collider = collision.collider
		if collider.has_meta("floor_type"):
			return groundSoundMap.get(collider.get_meta("floor_type"), defaultGroundSound)
	return defaultGroundSound

func handle_wall_slide(wallFriction, delta):
	"""
	description: Handles player sliding down walls, adjusting velocity based on friction.
	params: wallFriction (float): The friction of the wall. delta (float): The time passed since the last frame.
	"""
	if not isSliding and playerVelocity.y < 0:
		playerVelocity.y /= 5
	isSliding = true
	playerVelocity.y = lerp(playerVelocity.y, wallFriction, delta)


func handle_fall(delta, floating = false):
	"""
	description: Manages the player's fall, including gravity and wind interactions.
	params: delta: time passed since last frame floating (bool): Whether the player is on a floating object.
	"""
	
	isSlipping = false
	if not isInWater:
		playerVelocity.y += gravity * delta
		if (state == State.INWIND or isInWind) and not is_on_floor():
			var windSpeed = windVelocity.x * -windDirection.x * windModifier
			if abs(playerVelocity.x) > abs(windSpeed):
				playerVelocity.x = windSpeed
			else:
				playerVelocity.x = lerp(playerVelocity.x, windSpeed, delta * 4)
			state = State.INWIND
		if is_on_floor():
			if playerVelocity.y > 600:
				play_sound(sounds["land"])
			isOnFloor = true
			state = State.IDLE
	else:
		playerVelocity.y += (sinkSpeed / 2) * delta

	if not floating:
		isSliding = false
		canJump = false

func play_sound(sound):
	"""
	description: Plays a sound effect.
	params: sound (AudioStream): The sound to be played.
	"""
	audioPlayer.stream = sound
	audioPlayer.play()

	audioPlayer.play()


func handle_ground(delta):
	"""
	description: Handles player-ground interactions, including slipping and friction on slopes.
	params: delta: time passed since last frame
	"""
	var collision = get_slide_collision(0)
	if collision and collision.normal.y < 1:
		isSliding = false
		if isInWater:
			_kill_player_other()

		var slope_angle = abs((acos(collision.normal.y) * 180 / PI) - 180)
		var slope_normal = collision.normal.normalized()
		
		var slope_direction = Vector2(slope_normal.y, -slope_normal.x).normalized()
		if abs(slope_direction.angle()) > 20:
			playerVelocity = playerVelocity.rotated(slope_direction.angle())

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
	"""
	description: Triggered when the player enters a ladder area, enabling climbing.
	params: area (Area2D): The ladder area the player has entered.
	"""
	onLadder = true
	isClimbing = true
	reset_jump_state()

func _on_Ladder_area_exited(area):
	"""
	description: Triggered when the player exits a ladder area, disabling climbing.
	params: area (Area2D): The ladder area the player has exited.
	"""
	onLadder = false

func reset_jump_state():
	"""
	description: Resets jump-related variables, such as timers and velocity, when needed.
	params: None
	"""
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
	"""
	description: Updates the climbing animation when the player is on a ladder.
	params: None
	"""
	if playerVelocity.y < 0:
		if not animatedSprite.is_playing():
			animatedSprite.play("climb")
	elif playerVelocity.y > 0:
		if not animatedSprite.is_playing():
			animatedSprite.play("climb")
	else:
		animatedSprite.stop()

func _on_Respawn_body_entered(body, sender):
	"""
	description: Triggered when the player enters a respawn area, updating the current respawn point.
	params: body: The node that touched the Area2D sender (String): The respawn point identifier.
	"""
	if body.name == "Player":
		if int(sender) < int(currentRespawn):
			currentRespawn = sender

func _kill_player_from_touching(body):
	"""
	description: Kills the player when certain objects are touched, triggering a respawn.
	params: body: The node that touched the Area2D
	"""
	if body.name == "Player":
		isDead = true
		handle_death()

func _kill_player_other():
	"""
	description: Kills the player for other reasons, such as falling off the map, and triggers a respawn.
	params: None
	"""
	isDead = true
	handle_death()

func _on_floating_thing_entered(body):
	"""
	description: Triggered when the player enters a floating object's area, enabling floating mechanics.
	params: body: The node that touched the Area2D
	"""
	if body.name == "Player":
		isOnFloatingThing = true
		FloatingThingExitTimer = 0.0

func _on_floating_thing_exited(body):
	"""
	description: Triggered when the player exits a floating object's area, disabling floating mechanics.
	params: body: The node that touched the Area2D
	"""
	if body.name == "Player":
		FloatingThingExitTimer = FloatingThingCooldown

func _water_exited(body):
	"""
	description: Triggered when the player exits water, updating water-related states.
	params: body: The node that touched the Area2D
	"""
	if body.name == "Player":
		isInWater = false

func _water_entered(body):
	"""
	description: Triggered when the player enters water, updating water-related states and behavior.
	params: body: The node that touched the Area2D
	"""
	if body.name == "Player":
		isInWater = true
		playerVelocity.y = sinkSpeed


func _on_wind_entered(body, wind_dir: Vector2, wind_velocity: Vector2):
	"""
	description: Triggered when the player enters a wind area, applying wind effects to the player.
	params: body: The node that touched the Area2D wind_dir (Vector2): The direction of the wind. wind_velocity (Vector2): The velocity of the wind.
	"""
	if body.name == "Player":
		windDirection = wind_dir
		windVelocity = wind_velocity
		state = State.INWIND
		isInWind = true

func _on_wind_exited(body):
	"""
	description: Triggered when the player exits a wind area, removing wind effects.
	params: body: The node that touched the Area2D
	"""
	if body.name == "Player":
		windDirection = Vector2.ZERO
		windVelocity = 0
		state = State.INAIR
		isInWind = false


func handle_gameOver(body):
	"""
	description: Triggered when the game ends, transitioning the player to the game over state.
	params: body: The node that touched the Area2D
	"""
	if body.name == "Player":
		state = State.GAMEOVER


func _on_play_again_down():
	"""
	description: Triggered when you press the restart button, restarting the game.
	"""
	restart_game()

func _on_quit_down():
	"""
	description: Triggered when you press the quit button, quits the game.
	"""
	get_tree().quit()
