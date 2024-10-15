extends CharacterBody3D

# Constants for player speed, jump, and rotation
const WALK_SPEED = 5.0
const RUN_SPEED = 20.0
const JUMP_VELOCITY = 5.5
const ROTATION_SPEED = 5.0  # Speed at which the player rotates smoothly

var _move_vec: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_jumping: bool = false
var is_near_ledge: bool = false  # Tracks if the player is near a ledge

@onready var animation_player = $AnimationPlayer
@onready var raycast_top = $RayCast3D  # RayCast for detecting ledges
@onready var climbing_script = preload("res://scripts/climbing.gd").new()  # Load the climbing script

func _ready():
	climbing_script.player = self  # Pass reference to the player in climbing script
	raycast_top.enabled = true  # Enable the raycast

func _physics_process(delta: float) -> void:
	# Add gravity if the player is not on the floor and not climbing
	if not is_on_floor() and not climbing_script.is_climbing:
		velocity += get_gravity() * delta

	# Check if the RayCast is colliding with a ledge
	check_ledge_collision()

	if climbing_script.is_grabbing_ledge:
		handle_ledge_movement()

	# Handle jump input (if not climbing)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not climbing_script.is_climbing:
		velocity.y = JUMP_VELOCITY

	# Get input direction (WASD or arrow keys)
	_move_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(_move_vec.x, 0, _move_vec.y)  # Fix for forward/backward direction

	# Handle running input
	is_running = Input.is_action_pressed("run")
	var speed = RUN_SPEED if is_running else WALK_SPEED

	# Apply movement if there's input
	if direction.length() > 0 and not climbing_script.is_climbing:
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
	if climbing_script.is_grabbing_ledge:
		return
	# Handle keyboard rotation (left/right keys)
	if Input.is_action_pressed("ui_left"):
		rotate_y(ROTATION_SPEED * delta)  # Rotate left
	elif Input.is_action_pressed("ui_right"):
		rotate_y(-ROTATION_SPEED * delta)  # Rotate right

# Handle ledge movement (moving left or right on the ledge)
func handle_ledge_movement():
	if Input.is_action_pressed("ui_left"):
		print("move left on ledge")
		climbing_script.move_along_ledge(-1)  # Move left
	elif Input.is_action_pressed("ui_right"):
		climbing_script.move_along_ledge(1)  # Move right
	else:
		climbing_script.move_along_ledge(0)

	# Drop from ledge
	if Input.is_action_pressed("ui_down"):
		climbing_script.drop_from_ledge()

# Check if the RayCast is colliding with the ledge
func check_ledge_collision():
	if raycast_top.is_colliding():
		
		var collider = raycast_top.get_collider()
		
		# Check if the collider is a ledge (by comparing it with its type or name)
		if collider.name == "LedgeStaticBody":
			is_near_ledge = true  # Set this to true if a ledge is detected
			if Input.is_action_pressed("ui_accept"):
				climbing_script.grab_ledge()
		else:
			is_near_ledge = false
	else:
		is_near_ledge = false

# Play animation based on movement and jumping state
func play_animation(direction: Vector3):
	if not is_on_floor():
		if velocity.y > 0:
			animation_player.play("Jumping", -1, 1.5)  # Jumping animation plays faster
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
