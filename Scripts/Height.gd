extends RichTextLabel

onready var player = $"../../../Player"

# Called when the node enters the scene tree for the first time.
func _ready():
	# Ensure BBCode parsing is enabled.
	bbcode_enabled = true
	# Debug print to verify camera node.
	print("Camera Node: ", player)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if player:
		# Uses chatgpts info that according to Dante, hell is 6371 km under the surface
		var bottomOfHell = 6371
		var topOfHellInGame = -36855
		
		# Normalizes height, flips it, rounds it and negates to get correct measurements for below surface
		var normalized_y_position = player.position.y / topOfHellInGame
		var y_position = -round(abs(1 - normalized_y_position) * bottomOfHell)
		
		# Create the rich text string with formatted y position.
		# Set the rich text content to the RichTextLabel.
		text = "height: " + str(y_position) + "km"
	else:
		print("Camera node is not assigned.")
