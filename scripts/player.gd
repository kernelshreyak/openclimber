extends CharacterBody3D

# Constants for player speed, jump, and rotation
const WALK_SPEED = 5.0
const RUN_SPEED = 20.0
const JUMP_VELOCITY = 5.5
const ROTATION_SPEED = 5.0  # Speed at which the player rotates smoothly
const MIN_PITCH = -90  # Min camera pitch (look down limit)
const MAX_PITCH = 75   # Max camera pitch (look up limit)

var _move_vec: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_jumping: bool = false

@onready var animation_player = $AnimationPlayer
@onready var camera = $Camera3D  # Assuming there's a Camera3D node under the player

func _physics_process(delta: float) -> void:
	# Add gravity if the player is not on the floor.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump input
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get input direction (WASD or arrow keys)
	_move_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(_move_vec.x, 0, _move_vec.y)  # Fix for forward/backward direction

	# Handle running input
	is_running = Input.is_action_pressed("run")
	var speed = RUN_SPEED if is_running else WALK_SPEED

	# Apply movement if there's input
	if direction.length() > 0:
		direction = direction.normalized()
		move_player(direction, speed, delta)
	else:
		# Decelerate when no input is provided
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

	# Play animations based on movement and state
	play_animation(direction)
	
	handle_keyboard_rotation(delta)

	# Move the player
	move_and_slide()

# Move player based on direction and speed
func move_player(direction: Vector3, speed: float, _delta: float):
	# Calculate the movement vector based on the player's current rotation
	var forward = -transform.basis.z
	var right = transform.basis.x
	var movement = (forward * direction.z + right * direction.x).normalized()

	# Update velocity based on movement direction
	velocity.x = movement.x * speed
	velocity.z = movement.z * speed

# Smoothly rotate the player toward the movement direction
func handle_keyboard_rotation(delta: float):
	# Handle keyboard rotation (left/right keys)
	if Input.is_action_pressed("ui_left"):
		rotate_y(ROTATION_SPEED * delta)  # Rotate left
	elif Input.is_action_pressed("ui_right"):
		rotate_y(-ROTATION_SPEED * delta)  # Rotate right


# Play animation based on movement and jumping state
func play_animation(direction: Vector3):
	if not is_on_floor():
		if velocity.y > 0:
			animation_player.play("Jumping",-1,1.5)  # Jumping animation plays faster
		elif velocity.y < 0:
			animation_player.play("Falling")
	else:
		if direction.length() > 0:
			if direction.z > 0:  # Moving backward (negative Z direction)
				animation_player.play("WalkBack")
			elif is_running:
				animation_player.play("Running")
			else:
				animation_player.play("Walking")
		else:
			animation_player.play("Idle")
