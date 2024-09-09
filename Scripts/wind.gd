# Script for the wind Area2D
extends Area2D

func _ready():
	connect("body_entered", self, "_on_area_body_entered")
	connect("body_exited", self, "_on_area_body_exited")

func _on_area_body_entered(body):
	if body.name == "Player":
		print("Player entered wind area")
		var wind_info = find_wind_info()
		var wind_direction = wind_info["direction"]
		var wind_velocity = wind_info["velocity"]
		body._on_wind_entered(body, wind_direction, wind_velocity)

func _on_area_body_exited(body):
	if body.name == "Player":
		print("Player exited wind area")
		body._on_wind_exited(body)


# Function to find both wind direction and velocity
func find_wind_info() -> Dictionary:
	var wind_info = {}
	for sibling in get_parent().get_children():
		if sibling is CPUParticles2D:
			wind_info["direction"] = -sibling.direction.normalized()  # Negate to push the player
			wind_info["velocity"] = Vector2(sibling.initial_velocity, 0)  # Assuming horizontal wind movement
			return wind_info
	# Return default values if no CPUParticles2D is found
	wind_info["direction"] = Vector2.ZERO
	wind_info["velocity"] = Vector2.ZERO
	return wind_info

