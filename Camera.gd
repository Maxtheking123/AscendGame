extends Camera2D

# Sets camera position to player position when game is loaded
func _ready():
	var player = get_node("../Player")
	if player:
		position.y = player.position.y

func _process(delta):
	var player = get_node("../Player")
	
	if player:
		var targetPositionY = player.position.y
		
		# Calculates distance needed to move to use later to determine movement speed
		var distance = abs(position.y - targetPositionY)
		
		# Calculates speed by making it faster if the player is further from the camera
		var camMovementSpeed = distance / 200 * delta
		
		# Moves into the target position
		position.y = lerp(position.y, targetPositionY, camMovementSpeed)


func _on_tarPerson_exited(body):
	pass # Replace with function body.
