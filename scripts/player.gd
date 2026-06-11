extends CharacterBody3D

const WALK_SPEED := 4.5
const RUN_SPEED := 7.5
const JUMP_VELOCITY := 6.0
const ROTATION_SPEED := 2.8
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
const CAMERA_FOLLOW_HEIGHT := 1.7

var animation_time := 0.0
var camera_yaw := 0.0
var camera_pitch := CAMERA_DEFAULT_PITCH
var camera_pan := Vector3.ZERO

@onready var climb_probe: RayCast3D = $ClimbProbe
@onready var climbing = $Climbing
@onready var rig = $VisualRoot
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

func _ready() -> void:
	climbing.player = self
	camera_pivot.top_level = true
	_center_camera()

func _physics_process(delta: float) -> void:
	animation_time += delta
	climbing.tick(delta)
	_sync_camera_follow()

	var climb_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if climbing.is_climbing:
		if Input.is_action_just_pressed("ui_accept"):
			climbing.jump_from_surface()
		else:
			climbing.physics_step(delta, climb_input)
		move_and_slide()
		rig.pose_for_climb(climbing.surface_normal, climb_input, animation_time)
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
		if climbing.can_start_climb():
			climbing.grab_surface()
			move_and_slide()
			rig.pose_for_climb(climbing.surface_normal, climb_input, animation_time)
			return
	else:
		_restore_upright_basis(delta)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if Input.is_action_just_pressed("camera_center"):
		_center_camera()

	var is_running := Input.is_action_pressed("run")
	var speed := RUN_SPEED if is_running else WALK_SPEED
	var forward_input := Input.get_axis("ui_down", "ui_up")
	var turn_input := Input.get_axis("ui_right", "ui_left")

	if absf(turn_input) > 0.001:
		rotate_y(turn_input * ROTATION_SPEED * delta)

	if absf(forward_input) > 0.001:
		var direction := -global_basis.z * forward_input
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED)

	move_and_slide()
	rig.pose_for_ground(forward_input, turn_input, animation_time, is_on_floor())

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

func _restore_upright_basis(delta: float) -> void:
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var target_basis := Basis.looking_at(forward, Vector3.UP).orthonormalized()
	global_basis = global_basis.slerp(target_basis, minf(1.0, delta * 10.0)).orthonormalized()
