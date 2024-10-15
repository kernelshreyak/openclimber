extends Node

# Constants for climbing
const CLIMB_SPEED = 2.0  # Speed for moving along the ledge
const DROP_VELOCITY = -10.0  # Velocity when dropping from the ledge

var is_climbing: bool = false  # Tracks if the player is in the climbing state
var is_grabbing_ledge: bool = false  # Tracks if the player is holding on the ledge
var ledge_direction: Vector3 = Vector3.ZERO  # Direction the player can move along the ledge

# Reference to the player node
@onready var player = preload("res://scenes/player.tscn").new() 

func grab_ledge():
	if is_grabbing_ledge:
		return
		
		
	print("grab ledge")
	is_climbing = true
	is_grabbing_ledge = true
	
	# Adjust the player's position slightly to move closer to the ledge before playing the animation
	
	var offset = Vector3(0, 0, -0.5)  # Move player backward slightly toward the ledge
	player.global_transform.origin += offset
	player.animation_player.play("LedgeGrab")  # Play the ledge grabbing animation
	player.velocity = Vector3.ZERO  # Stop the player's velocity when grabbing the ledge


func move_along_ledge(direction: float):
	if not is_grabbing_ledge:
		return

	# Moving left (-1) or right (+1) along the ledge
	# Play appropriate animation for movement
	if direction < 0:
		player.animation_player.play("LedgeMoveLeft")
	elif direction > 0:
		player.animation_player.play("LedgeMoveRight")
	else:
		if is_grabbing_ledge:
			player.animation_player.play("LedgeGrab")  # Idle while holding the ledge

func drop_from_ledge():
	if not is_grabbing_ledge:
		return

	is_climbing = false
	is_grabbing_ledge = false
	player.velocity.y = DROP_VELOCITY  # Drop the player down
	player.animation_player.play("Idle")  # Return to idle animation
