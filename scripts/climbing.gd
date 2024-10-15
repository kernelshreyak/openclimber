extends Node

# Constants for climbing
const CLIMB_SPEED = 2.0  # Speed for moving along the ledge
const DROP_VELOCITY = -10.0  # Velocity when dropping from the ledge
const LEDGE_JUMP_VELOCITY = 5.0  # Velocity when jumping from the ledge
const LEDGE_MOVE_VELOCITY = Vector3(.02,0,0)  # Velocity when jumping from the ledge

var is_climbing: bool = false  # Tracks if the player is in the climbing state
var is_grabbing_ledge: bool = false  # Tracks if the player is holding on the ledge
var ledge_direction: Vector3 = Vector3.ZERO  # Direction the player can move along the ledge

var offset_adjusted_ledge_grab: bool = false  # Tracks if the ledge position was adjusted

# Reference to the player node
@onready var player = preload("res://scenes/player.tscn").new()

func grab_ledge():
	if is_grabbing_ledge:
		return

	print("grab ledge")
	player.velocity = Vector3.ZERO  # Stop the player's velocity when grabbing the ledge
	is_climbing = true
	is_grabbing_ledge = true
	
	# Adjust the player's position slightly to move closer to the ledge before playing the animation
	if not offset_adjusted_ledge_grab:
		player.player_skeleton.global_transform.origin += Vector3(0, -0.65, -0.5)
	offset_adjusted_ledge_grab = true
	player.animation_player.play("LedgeGrab")  # Play the ledge grabbing animation
	

func move_along_ledge(direction: float):
	if not is_grabbing_ledge:
		return

	# Moving left (-1) or right (+1) along the ledge and (0) to stay hanged on ledge
	# Play appropriate animation for movement
	if direction < 0:
		player.global_transform.origin += LEDGE_MOVE_VELOCITY
		player.animation_player.play("LedgeMoveLeft")
	elif direction > 0:
		player.global_transform.origin -= LEDGE_MOVE_VELOCITY
		player.animation_player.play("LedgeMoveRight")
	else:
		player.animation_player.play("HangingIdle")

func drop_from_ledge():
	if not is_grabbing_ledge:
		return
	print("drop_from_ledge")
	player.player_skeleton.global_transform.origin = player.global_transform.origin
	is_climbing = false
	is_grabbing_ledge = false
	offset_adjusted_ledge_grab = false
	player.velocity.y = DROP_VELOCITY  # Drop the player down
	player.animation_player.play("Idle")  # Return to idle animation

func jump_from_ledge(direction: Vector3):
	if not is_grabbing_ledge:
		return

	print("jump from ledge")
	
	# Perform a jump from the ledge to the desired direction (up, left, right, or diagonally)
	player.velocity = direction.normalized() * LEDGE_JUMP_VELOCITY  # Apply jump velocity
	
	is_climbing = false
	is_grabbing_ledge = false
	offset_adjusted_ledge_grab = false

	# Play appropriate jump animation based on direction
	if direction.y > 0:
		player.animation_player.play("LedgeHopUp")
	else:
		player.animation_player.play("Jumping")  # Generic jump animation
