extends Node

const SURFACE_OFFSET := 0.5
const JUMP_PUSH := 6.0
const JUMP_LIFT := 7.5
const REGRAB_COOLDOWN := 0.3

# Climbing is driven by four grips. Each hand and foot holds a fixed point on
# the surface; input makes one limb at a time reach for a new hold, and the
# body is pulled after the grips by a spring instead of being moved directly.
# The hands carry the climber: where there is nothing under the feet they come
# off and the body hangs from the hands alone.
# Limb order: left hand, right hand, left foot, right foot.
const LIMB_JOINTS: Array[String] = ["LeftArmHand", "RightArmHand", "LeftLegFoot", "RightLegFoot"]
# Where each limb rests relative to the body, in player-local x/y on the wall.
const LIMB_HOMES: Array[Vector2] = [Vector2(-0.34, 1.6), Vector2(0.34, 1.6), Vector2(-0.26, 0.25), Vector2(0.26, 0.25)]
# Reach order while moving: right hand, left foot, left hand, right foot.
const STEP_ORDER: Array[int] = [1, 2, 0, 3]
const HAND_COUNT := 2
# A hold may be closer to the body's centre line than the limb's resting spot,
# which is what lets both hands share a narrow strip.
const GRIP_NARROWING: Array[float] = [1.0, 0.5, 0.1]
const STEP_LEAD := 0.36
const STEP_LEAD_FRACTIONS: Array[float] = [1.0, 0.66, 0.33]
const MIN_STEP := 0.05
const STEP_TIME := 0.08
const GRAB_REACH_TIME := 0.16
const STEP_LIFT := 0.12
const REHOME_DISTANCE := 0.15
const FOOT_MAX_STRETCH := 0.35
# A foot with no hold ahead lets go once it trails the body by this much.
const FOOT_MAX_LAG := 0.12
const GRIP_PROBE_DEPTH := 0.4
const INPUT_THRESHOLD := 0.3

const BODY_STIFFNESS := 140.0
const BODY_DAMPING := 18.0
# The body sags a little while a limb is reaching, and hangs lower on straight
# arms when both feet are off the wall.
const BODY_SAG := 0.03
const HANG_DROP := 0.2
const HANG_STEP_SLOWDOWN := 1.4

const MANTLE_TIME := 0.7
const MANTLE_INSET := 0.4
const FLOOR_REACH := 0.5

var is_climbing := false
var is_mantling := false
var surface_normal := Vector3.FORWARD
var last_collision_point := Vector3.ZERO
var regrab_cooldown := 0.0
var locked_until_floor := false
var mantle_progress := 0.0
var mantle_from := Transform3D.IDENTITY
var mantle_to := Transform3D.IDENTITY
var body_velocity := Vector2.ZERO
var limbs: Array[Limb] = []
var player

class Limb:
	var home := Vector2.ZERO
	var is_hand := false
	# Feet let go where there is nothing to stand on; hands always hold.
	var attached := true
	var anchor := Vector3.ZERO
	var normal := Vector3.BACK
	var from := Vector3.ZERO
	var duration := 0.1
	# 1 while planted; below 1 the limb is in the air reaching for `anchor`.
	var progress := 1.0

	func is_planted() -> bool:
		return attached and progress >= 1.0

	func is_moving() -> bool:
		return attached and progress < 1.0

	func current_position() -> Vector3:
		if progress >= 1.0:
			return anchor
		var t := smoothstep(0.0, 1.0, progress)
		return from.lerp(anchor, t) + normal * sin(t * PI) * STEP_LIFT

func tick(delta: float) -> void:
	regrab_cooldown = maxf(regrab_cooldown - delta, 0.0)

func notify_floor() -> void:
	locked_until_floor = false

func is_hanging() -> bool:
	return is_climbing and not limbs.is_empty() and not limbs[2].attached and not limbs[3].attached

func can_start_climb() -> bool:
	if regrab_cooldown > 0.0 or locked_until_floor:
		return false
	return _probe_surface()

func grab_surface() -> void:
	if not _probe_surface():
		return

	is_climbing = true
	player.velocity = Vector3.ZERO
	_face_surface()
	_reach_for_surface()

func physics_step(delta: float, input_vec: Vector2) -> void:
	if not is_climbing:
		return

	_align_to_hands()
	for limb in limbs:
		limb.progress = minf(limb.progress + delta / limb.duration, 1.0)

	var xform: Transform3D = player.global_transform
	_update_feet(xform)
	# Hanging from the hands alone, the arms go straight: the hands rest higher
	# above the body.
	var hand_raise := Vector2(0.0, HANG_DROP if is_hanging() else 0.0)
	for index in HAND_COUNT:
		limbs[index].home = LIMB_HOMES[index] + hand_raise

	var direction := Vector2(input_vec.x, -input_vec.y)
	if direction.length() < INPUT_THRESHOLD:
		_rehome_limbs(xform)
	else:
		var pace := clampf(direction.length(), 0.5, 1.0)
		direction = direction.normalized()
		if not _reach_towards(xform, direction, pace):
			# Nothing left to hold in that direction: top out or step off.
			if not _any_limb_moving():
				if direction.y > 0.5 and _available_lead(xform, Vector2(0.0, 1.0)) <= 0.0 and _try_start_mantle():
					return
				if direction.y < -0.5 and _available_lead(xform, Vector2(0.0, -1.0)) <= 0.0 and _floor_below():
					_release()
					return
			_rehome_limbs(xform)

	_pull_body(delta)
	player.velocity = Vector3.ZERO

# World-space grip of each limb, for the rig to reach to.
func get_grips() -> Array[Dictionary]:
	var grips: Array[Dictionary] = []
	for limb in limbs:
		grips.append({"position": limb.current_position(), "normal": limb.normal, "attached": limb.attached})
	return grips

func mantle_step(delta: float) -> void:
	mantle_progress = minf(mantle_progress + delta / MANTLE_TIME, 1.0)
	# Rise to the ledge height first, then move in over it.
	var rise := smoothstep(0.0, 0.65, mantle_progress)
	var push := smoothstep(0.4, 1.0, mantle_progress)
	var from := mantle_from.origin
	var to := mantle_to.origin
	player.global_position = Vector3(lerpf(from.x, to.x, push), lerpf(from.y, to.y, rise), lerpf(from.z, to.z, push))
	player.global_basis = mantle_from.basis.slerp(mantle_to.basis, push).orthonormalized()
	player.velocity = Vector3.ZERO

	if mantle_progress >= 1.0:
		is_mantling = false

func jump_from_surface() -> void:
	if not is_climbing:
		return

	_release()
	regrab_cooldown = REGRAB_COOLDOWN
	player.velocity = surface_normal * JUMP_PUSH + Vector3.UP * JUMP_LIFT

	# Turn away from the wall so the jump carries on in the facing direction.
	var away := Vector3(surface_normal.x, 0.0, surface_normal.z)
	if away.length_squared() > 0.01:
		player.global_basis = Basis.looking_at(away.normalized(), Vector3.UP)

func drop_from_surface() -> void:
	if not is_climbing:
		return

	_release()
	locked_until_floor = true
	player.velocity = Vector3.DOWN * 3.0

func _release() -> void:
	is_climbing = false
	player.velocity = Vector3.ZERO

# Looks for a climbable surface in front of the upper chest, to start a climb.
func _probe_surface() -> bool:
	player.climb_probe.force_raycast_update()
	if not player.climb_probe.is_colliding():
		return false

	var collider := player.climb_probe.get_collider() as Node
	if collider == null or not collider.is_in_group("climbable_surface"):
		return false

	last_collision_point = player.climb_probe.get_collision_point()
	surface_normal = player.climb_probe.get_collision_normal().normalized()
	return true

# Turns the body to face the probed surface, at climbing distance from it.
func _face_surface() -> void:
	var facing := Basis.looking_at(-surface_normal, _surface_up()).orthonormalized()
	player.global_basis = facing
	var probe_offset: Vector3 = facing * player.climb_probe.position
	player.global_position = last_collision_point + surface_normal * SURFACE_OFFSET - probe_offset

# While climbing, the hands define the wall: the body faces along their grip
# normals and keeps its distance from the surface they are holding.
func _align_to_hands() -> void:
	var normal := Vector3.ZERO
	for index in HAND_COUNT:
		normal += limbs[index].normal
	if normal.length_squared() < 0.01:
		return
	surface_normal = normal.normalized()
	player.global_basis = Basis.looking_at(-surface_normal, _surface_up()).orthonormalized()

	var origin: Vector3 = player.global_position
	var depth := 0.0
	for index in HAND_COUNT:
		depth += (limbs[index].anchor - origin).dot(surface_normal)
	player.global_position = origin + surface_normal * (depth / HAND_COUNT + SURFACE_OFFSET)

func _surface_up() -> Vector3:
	var projected_up := Vector3.UP - surface_normal * Vector3.UP.dot(surface_normal)
	if projected_up.length_squared() < 0.001:
		return player.global_basis.y
	return projected_up.normalized()

# On grabbing, every limb reaches from where it is to a hold near its resting
# spot. Hands search in towards the grabbed point if the surface ends short;
# feet with nothing under them are left hanging.
func _reach_for_surface() -> void:
	var xform: Transform3D = player.global_transform
	var grabbed := _local_point(xform.affine_inverse(), last_collision_point)
	limbs.clear()
	body_velocity = Vector2.ZERO
	for index in LIMB_HOMES.size():
		var limb := Limb.new()
		limb.home = LIMB_HOMES[index]
		limb.is_hand = index < HAND_COUNT
		limb.anchor = last_collision_point
		limb.normal = surface_normal

		var grip := {}
		if limb.is_hand:
			for step in 5:
				grip = _find_grip(xform, limb.home.lerp(grabbed, step / 4.0))
				if not grip.is_empty():
					break
		else:
			grip = _find_grip(xform, limb.home)
			limb.attached = not grip.is_empty()
		if not grip.is_empty():
			limb.anchor = grip["position"]
			limb.normal = grip["normal"]

		var joint: Node3D = player.rig.get_joint(LIMB_JOINTS[index])
		limb.from = joint.global_position
		limb.duration = GRAB_REACH_TIME
		limb.progress = 0.0
		limbs.append(limb)

# Feet come off when the body has moved too far from their hold, and step back
# on as soon as there is surface under them again.
func _update_feet(xform: Transform3D) -> void:
	var to_local := xform.affine_inverse()
	for index in range(HAND_COUNT, limbs.size()):
		var limb := limbs[index]
		if limb.attached:
			if limb.is_planted() and _local_point(to_local, limb.anchor).distance_to(limb.home) > FOOT_MAX_STRETCH:
				limb.attached = false
		elif not _any_limb_moving():
			var grip := _find_grip(xform, limb.home)
			if not grip.is_empty():
				var joint: Node3D = player.rig.get_joint(LIMB_JOINTS[index])
				limb.attached = true
				limb.from = joint.global_position
				limb.anchor = grip["position"]
				limb.normal = grip["normal"]
				limb.duration = GRAB_REACH_TIME
				limb.progress = 0.0

# Sends the limb that is furthest behind to a new hold ahead of the body.
# Returns false when no limb can make progress in that direction.
func _reach_towards(xform: Transform3D, direction: Vector2, pace: float) -> bool:
	var lead := _available_lead(xform, direction)
	if lead <= 0.0 and absf(direction.x) > 0.01 and absf(direction.y) > 0.01:
		# Blocked diagonally: carry on along whichever axis is still open.
		for axis: Vector2 in [Vector2(signf(direction.x), 0.0), Vector2(0.0, signf(direction.y))]:
			lead = _available_lead(xform, axis)
			if lead > 0.0:
				direction = axis
				break
	if lead <= 0.0:
		return false
	if _any_limb_moving():
		return true

	var to_local := xform.affine_inverse()
	var best: Limb = null
	var best_grip := {}
	var best_gain := MIN_STEP
	for index in STEP_ORDER:
		var limb := limbs[index]
		if not limb.attached:
			continue
		var grip := _find_grip(xform, limb.home + direction * lead)
		if grip.is_empty():
			# Hands always have a hold here (the lead was checked for them), so
			# this is a foot whose surface has run out. Rather than anchoring
			# the body, it comes off and hangs until there is footing again.
			if (_local_point(to_local, limb.anchor) - limb.home).dot(direction) < -FOOT_MAX_LAG:
				limb.attached = false
			continue
		var gain := (_local_point(to_local, grip["position"]) - _local_point(to_local, limb.anchor)).dot(direction)
		if gain > best_gain:
			best = limb
			best_grip = grip
			best_gain = gain
	if best == null:
		return false

	# Shimmying along on the hands alone is slower than climbing on all four.
	_step_limb(best, best_grip, STEP_TIME / pace * (HANG_STEP_SLOWDOWN if is_hanging() else 1.0))
	return true

# How far ahead the hands may reach so that both still land on a surface.
func _available_lead(xform: Transform3D, direction: Vector2) -> float:
	for fraction in STEP_LEAD_FRACTIONS:
		var lead := STEP_LEAD * fraction
		var hands_hold := true
		for index in HAND_COUNT:
			if _find_grip(xform, limbs[index].home + direction * lead).is_empty():
				hands_hold = false
				break
		if hands_hold:
			return lead
	return 0.0

# With no input, limbs left stretched out step back to a resting position.
func _rehome_limbs(xform: Transform3D) -> void:
	if _any_limb_moving():
		return

	var to_local := xform.affine_inverse()
	var furthest: Limb = null
	var furthest_grip := {}
	var furthest_distance := REHOME_DISTANCE
	for limb in limbs:
		if not limb.attached:
			continue
		var grip := _find_grip(xform, limb.home)
		if grip.is_empty():
			continue
		var distance := _local_point(to_local, limb.anchor).distance_to(_local_point(to_local, grip["position"]))
		if distance > furthest_distance:
			furthest = limb
			furthest_grip = grip
			furthest_distance = distance
	if furthest != null:
		_step_limb(furthest, furthest_grip, STEP_TIME)

func _step_limb(limb: Limb, grip: Dictionary, duration: float) -> void:
	limb.from = limb.anchor
	limb.anchor = grip["position"]
	limb.normal = grip["normal"]
	limb.duration = duration
	limb.progress = 0.0

# The planted limbs carry the body: it is sprung towards the spot where they
# would all be at rest, so it surges as each hold is taken rather than gliding.
func _pull_body(delta: float) -> void:
	var xform: Transform3D = player.global_transform
	var to_local := xform.affine_inverse()
	var offset := Vector2.ZERO
	var planted := 0
	var reaching := 0
	for limb in limbs:
		if limb.is_planted():
			offset += _local_point(to_local, limb.anchor) - limb.home
			planted += 1
		elif limb.is_moving():
			reaching += 1
	if planted == 0:
		return

	offset /= planted
	offset.y -= BODY_SAG * reaching
	body_velocity += (offset * BODY_STIFFNESS - body_velocity * BODY_DAMPING) * delta
	player.global_position += (xform.basis.x * body_velocity.x + xform.basis.y * body_velocity.y) * delta

func _any_limb_moving() -> bool:
	for limb in limbs:
		if limb.is_moving():
			return true
	return false

func _local_point(to_local: Transform3D, world_point: Vector3) -> Vector2:
	var local := to_local * world_point
	return Vector2(local.x, local.y)

# The hold nearest a player-local wall position, trying closer to the body's
# centre line when there is no surface straight ahead of it.
func _find_grip(xform: Transform3D, local_point: Vector2) -> Dictionary:
	for narrowing in GRIP_NARROWING:
		var grip := _grip_at(xform, Vector2(local_point.x * narrowing, local_point.y))
		if not grip.is_empty():
			return grip
	return {}

func _grip_at(xform: Transform3D, local_point: Vector2) -> Dictionary:
	var from := xform * Vector3(local_point.x, local_point.y, 0.0)
	var to := from - xform.basis.z * (SURFACE_OFFSET + GRIP_PROBE_DEPTH)
	var hit := _ray(from, to)
	if hit.is_empty():
		return {}
	var collider := hit["collider"] as Node
	if collider == null or not collider.is_in_group("climbable_surface"):
		return {}
	return hit

func _floor_below() -> bool:
	var origin: Vector3 = player.global_position
	var hit := _ray(origin + Vector3.UP * 0.2, origin + Vector3.DOWN * FLOOR_REACH)
	return not hit.is_empty() and (hit["normal"] as Vector3).y > 0.7

# At the top edge: look for standing room on top of the wall and pull up onto it.
func _try_start_mantle() -> bool:
	var inward := Vector3(-surface_normal.x, 0.0, -surface_normal.z)
	if inward.length_squared() < 0.01:
		return false
	inward = inward.normalized()

	var hands := (limbs[0].anchor + limbs[1].anchor) * 0.5
	var above_ledge := hands + inward * MANTLE_INSET + Vector3.UP * 0.7
	var hit := _ray(above_ledge, above_ledge + Vector3.DOWN * 1.4)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return false

	var stand_point: Vector3 = hit["position"]
	var stand_basis := Basis.looking_at(inward, Vector3.UP)
	if not _body_fits(Transform3D(stand_basis, stand_point + Vector3.UP * 0.1)):
		return false

	is_climbing = false
	is_mantling = true
	mantle_progress = 0.0
	mantle_from = player.global_transform
	mantle_to = Transform3D(stand_basis, stand_point)
	player.velocity = Vector3.ZERO
	return true

func _body_fits(body_transform: Transform3D) -> bool:
	var shape_node: CollisionShape3D = player.collision_shape
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = body_transform * shape_node.transform
	query.exclude = [player.get_rid()]
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	return space.intersect_shape(query, 1).is_empty()

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	return space.intersect_ray(query)
