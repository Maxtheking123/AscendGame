extends StaticBody2D

var floatiness = 5
var playerOn = false
var defaultY = 0
var bobbing_speed = 10
var bobbing_amount = 20

func _ready():
	defaultY = position.y

func _physics_process(delta):
	if playerOn:
		var targetY = defaultY + bobbing_amount
		position.y = lerp(position.y, targetY, bobbing_speed * delta)
	else:
		position.y = lerp(position.y, defaultY, bobbing_speed * delta)
	#print(defaultY - position.y)

func _on_Area2D_body_entered(body):
	if body.name == "Player":
		playerOn = true

func _on_Area2D_body_exited(body):
	if body.name == "Player":
		playerOn = false
