extends Camera2D

# Exported variables with unique names
export var camera_smoothing_speed: float = 5.0
export var camera_min_y: float = -10000  # Minimum Y-coordinate for camera
export var camera_max_y: float = 10000   # Maximum Y-coordinate for camera
export var camera_min_x: float = -10000  # Minimum X-coordinate for camera (optional)
export var camera_max_x: float = 10000   # Maximum X-coordinate for camera (optional)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Get the player node using its path relative to the current node
	var player = get_node("../Player")
	
	if player:
		# Desired camera position on the Y-axis
		var target_position_y = player.position.y
		
		# Smoothly interpolate the camera's position on the Y-axis
		var smooth_y = lerp(position.y, target_position_y, camera_smoothing_speed * delta)
		position.y = clamp(smooth_y, camera_min_y, camera_max_y)
		
		# Optional: Clamp X position if you want to restrict horizontal movement
		position.x = clamp(position.x, camera_min_x, camera_max_x)
