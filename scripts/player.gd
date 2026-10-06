extends CharacterBody3D

const InputSetup := preload("res://scripts/input_setup.gd")

const WALK_SPEED := 4.5
const RUN_SPEED := 8.0
const JUMP_VELOCITY := 8.6
const AIR_JUMP_VELOCITY := 8.0
const MAX_AIR_JUMPS := 1
# Default gravity feels floaty for a platformer; falling is heavier still.
const GRAVITY_SCALE := 2.3
const FALL_GRAVITY_SCALE := 3.0
const TURN_SPEED := 12.0
const CAMERA_STICK_SPEED := 2.6
const CAMERA_ROTATE_SPEED := 0.01
const CAMERA_PAN_SPEED := 0.01
const CAMERA_ZOOM_STEP := 0.45
const CAMERA_ZOOM_MIN := 3.0
const CAMERA_ZOOM_MAX := 9.0
const CAMERA_PITCH_MIN := deg_to_rad(-65.0)
const CAMERA_PITCH_MAX := deg_to_rad(15.0)
const CAMERA_DEFAULT_PITCH := deg_to_rad(-14.0)
const CAMERA_PAN_X_LIMIT := 2.5
const CAMERA_PAN_Z_LIMIT := 2.5
const CAMERA_PAN_Y_MIN := 0.8
const CAMERA_PAN_Y_MAX := 3.0
const CAMERA_FOLLOW_HEIGHT := 1.4
# Landings slower than this are silent; faster than the hard speed (a drop of
# about 4 m) the thud is deeper and louder.
const LAND_SOUND_MIN_SPEED := 5.0
const HARD_LANDING_SPEED := 16.0
const LAND_VOLUME_DB := 6.0
const HARD_LANDING_VOLUME_DB := 10.0
const HARD_LANDING_PITCH := 0.75
const AIR_JUMP_PITCH := 1.25

var animation_time := 0.0
var air_jumps_left := MAX_AIR_JUMPS
var airborne := false
# Set while flying from a boost pad: the arc is not steered or slowed until
# the player lands or grabs a wall.
var launched := false
var camera_yaw := 0.0
var camera_pitch := CAMERA_DEFAULT_PITCH
var camera_pan := Vector3.ZERO

@onready var climb_probe: RayCast3D = $ClimbProbe
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var climbing = $Climbing
@onready var rig = $VisualRoot
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var jump_sound: AudioStreamPlayer = $JumpSound
@onready var land_sound: AudioStreamPlayer = $LandSound

func _ready() -> void:
	InputSetup.ensure()
	climbing.player = self
	camera_pivot.top_level = true
	_center_camera()

func _physics_process(delta: float) -> void:
	animation_time += delta
	climbing.tick(delta)
	_update_camera_look(delta)

	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var jump_pressed := Input.is_action_just_pressed("jump")

	if climbing.is_climbing:
		# Holding a wall restores the air jump.
		air_jumps_left = MAX_AIR_JUMPS
		if jump_pressed:
			climbing.jump_from_surface()
			_play_jump_sound(1.0)
			jump_pressed = false
		elif Input.is_action_just_pressed("climb_drop"):
			climbing.drop_from_surface()
		else:
			climbing.physics_step(delta, move_input)

	if climbing.is_mantling:
		climbing.mantle_step(delta)
		rig.pose_for_mantle(animation_time)
		_sync_camera_follow()
		return

	if climbing.is_climbing:
		rig.pose_for_climb(climbing.get_grips(), animation_time)
		_sync_camera_follow()
		return

	# Movement is relative to the camera; the character turns to face it.
	var move_direction := Basis.from_euler(Vector3(0.0, camera_yaw, 0.0)) * Vector3(move_input.x, 0.0, move_input.y)
	# In a boosted flight the character faces where it is going, so it grabs
	# the wall it is thrown at.
	_turn_upright_towards(Vector3(velocity.x, 0.0, velocity.z) if launched else move_direction, delta)

	if is_on_floor():
		climbing.notify_floor()
		air_jumps_left = MAX_AIR_JUMPS
		if jump_pressed:
			velocity.y = JUMP_VELOCITY
			_play_jump_sound(1.0)
	else:
		if jump_pressed and air_jumps_left > 0:
			air_jumps_left -= 1
			velocity.y = AIR_JUMP_VELOCITY
			_play_jump_sound(AIR_JUMP_PITCH)
		var gravity_scale := GRAVITY_SCALE if velocity.y > 0.0 or launched else FALL_GRAVITY_SCALE
		velocity += get_gravity() * gravity_scale * delta
		if climbing.can_start_climb():
			launched = false
			climbing.grab_surface()
			rig.pose_for_climb(climbing.get_grips(), animation_time)
			_sync_camera_follow()
			return

	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	if not launched:
		if move_direction.length_squared() > 0.0001:
			velocity.x = move_direction.x * speed
			velocity.z = move_direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED)
			velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED)

	var fall_speed := -velocity.y
	move_and_slide()

	if is_on_floor():
		if airborne:
			_play_landing_sound(fall_speed)
		airborne = false
		launched = false
		rig.pose_for_ground(Vector2(velocity.x, velocity.z).length() / WALK_SPEED, animation_time)
	else:
		airborne = true
		rig.pose_for_air(velocity.y, animation_time)
	_sync_camera_follow()

# Throws the player along an arc that brings the feet to `target` after
# `flight_time` seconds. Returns false if the player is busy on a wall.
func launch_to(target: Vector3, flight_time: float) -> bool:
	if climbing.is_climbing or climbing.is_mantling:
		return false

	var gravity := get_gravity() * GRAVITY_SCALE
	velocity = (target - global_position) / flight_time - gravity * flight_time * 0.5
	launched = true
	return true

func _play_jump_sound(pitch: float) -> void:
	jump_sound.pitch_scale = pitch
	jump_sound.play()

func _play_landing_sound(fall_speed: float) -> void:
	if fall_speed < LAND_SOUND_MIN_SPEED:
		return

	var hard := fall_speed >= HARD_LANDING_SPEED
	land_sound.volume_db = HARD_LANDING_VOLUME_DB if hard else LAND_VOLUME_DB
	land_sound.pitch_scale = HARD_LANDING_PITCH if hard else 1.0
	land_sound.play()

func _update_camera_look(delta: float) -> void:
	if Input.is_action_just_pressed("camera_center"):
		_center_camera()

	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length_squared() > 0.0:
		camera_yaw -= look.x * CAMERA_STICK_SPEED * delta
		camera_pitch = clampf(camera_pitch - look.y * CAMERA_STICK_SPEED * delta, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
		_update_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			camera_yaw -= event.relative.x * CAMERA_ROTATE_SPEED
			camera_pitch = clamp(camera_pitch - event.relative.y * CAMERA_ROTATE_SPEED, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
			_update_camera_transform()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var pan_basis := Basis.from_euler(Vector3(0.0, camera_yaw, 0.0))
			var right := pan_basis.x
			var up := Vector3.UP
			camera_pan += (-right * event.relative.x + up * event.relative.y) * CAMERA_PAN_SPEED
			camera_pan.x = clamp(camera_pan.x, -CAMERA_PAN_X_LIMIT, CAMERA_PAN_X_LIMIT)
			camera_pan.z = clamp(camera_pan.z, -CAMERA_PAN_Z_LIMIT, CAMERA_PAN_Z_LIMIT)
			camera_pan.y = clamp(camera_pan.y, CAMERA_PAN_Y_MIN, CAMERA_PAN_Y_MAX)
			_update_camera_transform()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = maxf(CAMERA_ZOOM_MIN, spring_arm.spring_length - CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = minf(CAMERA_ZOOM_MAX, spring_arm.spring_length + CAMERA_ZOOM_STEP)

func _sync_camera_follow() -> void:
	var yaw_basis := Basis.from_euler(Vector3(0.0, camera_yaw, 0.0))
	camera_pivot.global_position = global_position + Vector3.UP * CAMERA_FOLLOW_HEIGHT + yaw_basis * camera_pan

func _center_camera() -> void:
	var facing := (-global_basis.z).normalized()
	camera_yaw = atan2(facing.x, facing.z) + PI
	camera_pitch = CAMERA_DEFAULT_PITCH
	camera_pan = Vector3.ZERO
	_update_camera_transform()
	_sync_camera_follow()

func _update_camera_transform() -> void:
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0.0)

func _turn_upright_towards(move_direction: Vector3, delta: float) -> void:
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	if move_direction.length_squared() > 0.0001:
		forward = move_direction
	forward = forward.normalized()

	var weight := minf(1.0, delta * TURN_SPEED)
	if global_basis.y.dot(Vector3.UP) > 0.999:
		# Already upright: turn about the vertical axis only, so a full
		# about-face never tips the body over.
		var target_yaw := atan2(-forward.x, -forward.z)
		global_basis = Basis.from_euler(Vector3(0.0, lerp_angle(global_rotation.y, target_yaw, weight), 0.0))
	else:
		var target_basis := Basis.looking_at(forward, Vector3.UP)
		global_basis = global_basis.orthonormalized().slerp(target_basis, weight).orthonormalized()
