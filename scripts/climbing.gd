extends Node

# Constants for climbing
const CLIMB_SPEED = 2.0  # Speed for moving along the ledge
const DROP_VELOCITY = -10.0  # Velocity when dropping from the ledge
const LEDGE_JUMP_VELOCITY = 7.0  # Velocity when jumping from the ledge
const LEDGE_MOVE_VELOCITY = Vector3(.02,0,0)  # Velocity when moving left and right on ledge
const LEDGE_HOPUP_VELOCITY = Vector3(0,0.02,0)  # Velocity when hopping up on ledge

var is_climbing: bool = false  # Tracks if the player is in the climbing state
var is_grabbing_ledge: bool = false  # Tracks if the player is holding on the ledge
var ledge_direction: Vector3 = Vector3.ZERO  # Direction the player can move along the ledge

# Reference to the player node
@onready var player = preload("res://scenes/player.tscn").new()

func grab_ledge():
	if is_grabbing_ledge:
		return

	print("grab ledge")
	player.velocity = Vector3.ZERO  # Stop the player's velocity when grabbing the ledge
	is_climbing = true
	is_grabbing_ledge = true
	
	adjust_climber_body()

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

func hop_up_ledge(direction: float):
	if not is_grabbing_ledge:
		return

	# Moving up (-1) up the ledge and (0) to stay hanged on ledge
	# Play appropriate animation for movement
	if direction > 0:
		player.global_transform.origin += LEDGE_HOPUP_VELOCITY
		#player.animation_player.play("LedgeHopUp")
	else:
		player.animation_player.play("HangingIdle")

func drop_from_ledge():
	if not is_grabbing_ledge:
		return
	print("drop_from_ledge")
	player.player_skeleton.global_transform.origin = player.global_transform.origin
	set_not_climbing()
	adjust_climber_body()
	
	player.velocity.y = DROP_VELOCITY  # Drop the player down
	player.animation_player.play("Idle")  # Return to idle animation

func jump_from_ledge(direction: Vector3):
	if not is_grabbing_ledge:
		return

	print("jump from ledge")
	
	# Perform a jump from the ledge to the desired direction (up, left, right, or diagonally)
	player.velocity = direction.normalized() * LEDGE_JUMP_VELOCITY  # Apply jump velocity
	
	set_not_climbing()
	
	# Play appropriate jump animation based on direction
	player.animation_player.play("Jumping")  # Generic jump animation
	adjust_climber_body()

func set_not_climbing():
	is_climbing = false
	is_grabbing_ledge = false
		
# Adjust and align the skeleton and collision shape as per climbing conditions
func adjust_climber_body():
	if is_grabbing_ledge and player.player_top_colliding_with == "LedgeStaticBody":
		# Rotate the player to face the ledge, aligning the player's forward vector with the ledge normal
		var ledge_normal = player.raycast_top.get_collision_normal()
		var ledge_rotation = player.global_transform.basis
		ledge_rotation = Basis().looking_at(ledge_normal, Vector3.UP)
		player.global_transform.basis = ledge_rotation
		
		
		# Adjust the skeleton position slightly below the ledge to match the player's body
		player.player_skeleton.global_transform.origin = player.global_transform.origin - Vector3(0,0.65,0)
	else:
		player.player_skeleton.global_transform.origin = player.global_transform.origin
