extends Node

const CLIMB_SPEED := 4.0
const SURFACE_OFFSET    := 1.02
const JUMP_PUSH := 7.0
const JUMP_LIFT := 5.5
const REGRAB_COOLDOWN := 0.3
var is_climbing := false
var surface_normal := Vector3.FORWARD
var last_collision_point := Vector3.ZERO
var active_surface: Node3D = null
var blocked_surface: Node3D = null
var regrab_cooldown := 0.0
var player

func tick(delta: float) -> void:
	regrab_cooldown = maxf(regrab_cooldown - delta, 0.0)
	if regrab_cooldown == 0.0:
		blocked_surface = null

func can_start_climb() -> bool:
	if regrab_cooldown > 0.0:
		if not _refresh_surface_contact():
			blocked_surface = null
		elif active_surface != blocked_surface:
			regrab_cooldown = 0.0
			blocked_surface = null
		else:
			return false

	return _refresh_surface_contact()

func grab_surface() -> void:
	if not _refresh_surface_contact():
		return

	is_climbing = true
	player.velocity = Vector3.ZERO
	_snap_player_to_surface()

func physics_step(delta: float, input_vec: Vector2) -> void:
	if not is_climbing:
		return

	if not _refresh_surface_contact():
		drop_from_surface()
		return

	var surface_right := surface_normal.cross(Vector3.UP)
	if surface_right.length_squared() < 0.001:
		surface_right = player.global_basis.x
	else:
		surface_right = surface_right.normalized()

	var surface_up := _surface_up()
	surface_right = -surface_right
	var motion := surface_right * input_vec.x
	motion += surface_up * -input_vec.y

	if motion.length_squared() > 0.0:
		player.global_position += motion.normalized() * CLIMB_SPEED * delta
		if not _refresh_surface_contact():
			drop_from_surface()
			return

	player.velocity = Vector3.ZERO
	_snap_player_to_surface()

func jump_from_surface() -> void:
	if not is_climbing:
		return

	_begin_release_lock()
	is_climbing = false
	active_surface = null
	player.velocity = surface_normal * JUMP_PUSH + Vector3.UP * JUMP_LIFT

func drop_from_surface() -> void:
	if not is_climbing:
		return

	_begin_release_lock()
	is_climbing = false
	active_surface = null
	player.velocity = Vector3.DOWN * 2.0

func _begin_release_lock() -> void:
	blocked_surface = active_surface
	regrab_cooldown = REGRAB_COOLDOWN

func _refresh_surface_contact() -> bool:
	player.climb_probe.force_raycast_update()
	if not player.climb_probe.is_colliding():
		active_surface = null
		return false

	var collider: Object = player.climb_probe.get_collider()
	var collider_node := collider as Node
	if collider_node == null or not collider_node.is_in_group("climbable_surface"):
		active_surface = null
		return false

	active_surface = collider_node as Node3D
	last_collision_point = player.climb_probe.get_collision_point()
	surface_normal = player.climb_probe.get_collision_normal().normalized()
	return true

func _snap_player_to_surface() -> void:
	var up := _surface_up()
	var desired_basis := Basis.looking_at(-surface_normal, up).orthonormalized()
	player.global_basis = desired_basis

	var probe_offset: Vector3 = desired_basis * player.climb_probe.position
	player.global_position = last_collision_point + surface_normal * SURFACE_OFFSET - probe_offset

func _surface_up() -> Vector3:
	var projected_up := Vector3.UP - surface_normal * Vector3.UP.dot(surface_normal)
	if projected_up.length_squared() < 0.001:
		return player.global_basis.y
	return projected_up.normalized()
