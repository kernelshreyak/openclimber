extends Node3D

const TORSO_SIZE := Vector3(0.62, 0.46, 0.36)
const WAIST_SIZE := Vector3(0.5, 0.32, 0.3)
const HEAD_SIZE := Vector3(0.42, 0.42, 0.42)
const PELVIS_HEIGHT := 0.9
const HAND_SIZE := Vector3(0.15, 0.17, 0.11)
const SHOE_SIZE := Vector3(0.2, 0.32, 0.13)

const SKIN_COLOR := Color(0.93, 0.76, 0.62)
const HAIR_COLOR := Color(0.2, 0.14, 0.1)
const EYE_COLOR := Color(0.1, 0.1, 0.13)
const SHIRT_COLOR := Color(0.13, 0.55, 0.6)
const PANTS_COLOR := Color(0.2, 0.22, 0.28)
const BELT_COLOR := Color(0.1, 0.11, 0.14)
const SHOE_COLOR := Color(0.96, 0.78, 0.22)
const CHALK_BAG_COLOR := Color(0.56, 0.36, 0.76)

# Player origin is at the feet; the rig's soles sit this far below its origin.
const ROOT_HEIGHT := 0.08
const POSE_BLEND_SPEED := 22.0
const UPPER_ARM_LENGTH := 0.37
const FOREARM_LENGTH := 0.36
const THIGH_LENGTH := 0.42
const SHIN_LENGTH := 0.42

var materials: Dictionary = {}
var target_joints: Dictionary = {}
var target_root := Vector3(0.0, ROOT_HEIGHT, 0.0)
var target_rotation := Vector3.ZERO
var target_torso := Vector3(0.0, 1.5, 0.0)
var last_pose_time := -1.0
var gait_phase := 0.0

var joints: Dictionary = {}
var segments: Array[Dictionary] = []
var torso_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var torso_local_position := Vector3(0.0, 1.5, 0.0)
var neck_mesh: MeshInstance3D
var pelvis_mesh: MeshInstance3D
var left_shoulder_mesh: MeshInstance3D
var right_shoulder_mesh: MeshInstance3D
var left_hand_mesh: MeshInstance3D
var right_hand_mesh: MeshInstance3D
var left_shoe_mesh: MeshInstance3D
var right_shoe_mesh: MeshInstance3D

func _ready() -> void:
	_build_rig()
	pose_for_ground(0.0, 0.0)

func pose_for_ground(speed_ratio: float, time: float) -> void:
	# `amount` fades the gait in from standing; `run` blends the walk into a
	# run: longer stride, high knees, bent pumping arms, forward lean, bounce.
	var amount := clampf(speed_ratio, 0.0, 1.0)
	var run := clampf((speed_ratio - 1.0) / 0.5, 0.0, 1.0)
	if last_pose_time >= 0.0:
		gait_phase = fmod(gait_phase + clampf(time - last_pose_time, 0.0, 0.1) * lerpf(8.5, 13.5, run) * amount, TAU)

	var bounce := absf(sin(gait_phase)) * lerpf(0.02, 0.07, run) * amount
	target_root = Vector3(0.0, ROOT_HEIGHT - 0.05 * run * amount + bounce, 0.0)
	target_rotation = Vector3(-lerpf(0.05, 0.26, run) * amount, 0.0, 0.0)
	target_torso = Vector3(0.0, 1.5, 0.0)
	_set_joint("Head", Vector3(0.0, 2.0, lerpf(0.0, 0.04, run * amount)))

	for side: float in [-1.0, 1.0]:
		var phase := gait_phase if side < 0.0 else gait_phase + PI
		var forward := sin(phase) * amount
		# The foot is off the ground while it travels forward.
		var swing := maxf(0.0, cos(phase)) * amount

		var reach := forward * lerpf(0.3, 0.5, run)
		var lift := swing * lerpf(0.14, 0.44, run)
		var knee_drive := swing * lerpf(0.06, 0.34, run)
		var heel_trail := swing * run * 0.16
		var ankle := Vector3(0.15, 0.04 + lift, 0.02 - reach + heel_trail)
		_set_leg(
			side,
			Vector3(0.15, 0.84, 0.0),
			Vector3(0.15, 0.44 + lift * 0.5, -0.03 - reach * 0.5 - knee_drive),
			ankle,
			ankle + Vector3(0.0, -0.075 - heel_trail * 0.4, -0.12)
		)

		# Arms counter the legs. Walking they hang and swing; running the
		# elbows lock at a right angle and the fists pump from hip to chest.
		var arm := -forward
		var walk_swing := Vector3(0.0, 0.0, -arm * 0.34)
		var pump := -arm * 0.26
		var fist_rise := maxf(0.0, arm) * 0.2
		_set_arm(
			side,
			Vector3(0.43, 1.6, 0.0),
			(Vector3(0.5, 1.24, 0.03) + walk_swing * 0.45).lerp(Vector3(0.52, 1.27, 0.1 + pump * 0.8), run),
			(Vector3(0.47, 0.9, -0.03) + walk_swing).lerp(Vector3(0.46, 1.2 + fist_rise, -0.22 + pump), run),
			(Vector3(0.47, 0.78, -0.05) + walk_swing * 1.15).lerp(Vector3(0.44, 1.24 + fist_rise * 1.3, -0.33 + pump), run)
		)

	_apply_pose(time)

func pose_for_air(vertical_velocity: float, time: float) -> void:
	# 1 while rising (arms reaching up, one knee driven up), 0 while falling
	# (arms spread for balance, legs reaching for the ground).
	var rising := clampf(vertical_velocity / 7.0 * 0.5 + 0.5, 0.0, 1.0)

	target_root = Vector3(0.0, ROOT_HEIGHT, 0.0)
	target_rotation = Vector3(lerpf(0.1, -0.22, rising), 0.0, 0.0)
	target_torso = Vector3(0.0, 1.5, 0.0)
	_set_joint("Head", Vector3(0.0, 2.0, lerpf(-0.06, 0.02, rising)))

	var shoulder := Vector3(0.43, 1.6, 0.0)
	var elbow := Vector3(0.78, 1.5, 0.02).lerp(Vector3(0.6, 1.78, -0.22), rising)
	var wrist := Vector3(1.04, 1.62, -0.08).lerp(Vector3(0.56, 2.12, -0.38), rising)
	var hand := Vector3(1.14, 1.68, -0.1).lerp(Vector3(0.55, 2.24, -0.43), rising)
	_set_arm(-1.0, shoulder, elbow, wrist, hand)
	_set_arm(1.0, shoulder, elbow, wrist, hand)

	var hip := Vector3(0.15, 0.84, 0.0)
	_set_leg(
		-1.0, hip,
		Vector3(0.18, 0.48, -0.16).lerp(Vector3(0.16, 0.62, -0.36), rising),
		Vector3(0.2, 0.12, -0.02).lerp(Vector3(0.16, 0.3, -0.12), rising),
		Vector3(0.2, 0.03, -0.1).lerp(Vector3(0.16, 0.2, -0.2), rising)
	)
	_set_leg(
		1.0, hip,
		Vector3(0.2, 0.46, -0.06).lerp(Vector3(0.16, 0.46, 0.02), rising),
		Vector3(0.22, 0.1, 0.1).lerp(Vector3(0.16, 0.14, 0.3), rising),
		Vector3(0.22, 0.0, 0.03).lerp(Vector3(0.16, 0.02, 0.36), rising)
	)

	_apply_pose(time)

func pose_for_climb(grips: Array[Dictionary], time: float) -> void:
	# The hands and feet are pinned to their grips (left hand, right hand, left
	# foot, right foot, in world space); the body hangs between them and the
	# elbows and knees are solved to fit.
	var blend := _blend_factor(time)
	target_root = Vector3(0.0, ROOT_HEIGHT, 0.0)
	target_rotation = Vector3.ZERO
	position = position.lerp(target_root, blend)
	rotation = rotation.lerp(target_rotation, blend)

	var to_local := global_transform.affine_inverse()
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for grip in grips:
		points.append(to_local * (grip["position"] as Vector3))
		normals.append((to_local.basis * (grip["normal"] as Vector3)).normalized())

	# The torso shifts towards the grips, mostly following the hands.
	var hands_x := (points[0].x + points[1].x) * 0.5
	var feet_x := (points[2].x + points[3].x) * 0.5
	var shift := lerpf(feet_x, hands_x, 0.65) * 0.6
	target_torso = Vector3(shift, 1.5, -0.24)
	torso_local_position = torso_local_position.lerp(target_torso, blend)
	_set_joint("Head", Vector3(shift * 1.1, 2.0, -0.18))
	var head: Node3D = joints["Head"]
	head.position = head.position.lerp(target_joints["Head"], blend)

	for index in 4:
		var side := -1.0 if index % 2 == 0 else 1.0
		var grip_point := points[index]
		var normal := normals[index]
		if index < 2:
			var shoulder := torso_local_position + Vector3(side * 0.43, 0.1, 0.0)
			var hand := grip_point + normal * 0.06
			var wrist := hand + normal * 0.06 + Vector3.DOWN * 0.12
			var elbow := _solve_bend(shoulder, wrist, UPPER_ARM_LENGTH, FOREARM_LENGTH, Vector3(side * 0.7, -0.7, 0.45))
			_pin_limb("LeftArm" if side < 0.0 else "RightArm", ["Shoulder", "Elbow", "Wrist", "Hand"], [shoulder, elbow, wrist, hand])
		elif not grips[index]["attached"]:
			# Nothing under this foot: the leg hangs, trailing the body's sway.
			var prefix := "LeftLeg" if side < 0.0 else "RightLeg"
			var sway := Vector3(sin(time * 2.2 + side) * 0.03, 0.0, 0.0)
			var hang_hip := torso_local_position + Vector3(side * 0.15, -0.66, 0.02)
			_set_joint(prefix + "Hip", hang_hip)
			_set_joint(prefix + "Knee", hang_hip + Vector3(side * 0.02, -0.41, -0.06) + sway * 0.5)
			_set_joint(prefix + "Ankle", hang_hip + Vector3(side * 0.03, -0.8, 0.06) + sway)
			_set_joint(prefix + "Foot", hang_hip + Vector3(side * 0.03, -0.9, -0.02) + sway)
			for suffix: String in ["Hip", "Knee", "Ankle", "Foot"]:
				var joint: Node3D = joints[prefix + suffix]
				joint.position = joint.position.lerp(target_joints[prefix + suffix], blend)
		else:
			var hip := torso_local_position + Vector3(side * 0.15, -0.66, 0.02)
			var foot := grip_point + normal * 0.17
			var ankle := grip_point + normal * 0.3 + Vector3.UP * 0.06
			var knee := _solve_bend(hip, ankle, THIGH_LENGTH, SHIN_LENGTH, Vector3(side, 0.25, 0.35))
			_pin_limb("LeftLeg" if side < 0.0 else "RightLeg", ["Hip", "Knee", "Ankle", "Foot"], [hip, knee, ankle, foot])

	_update_segments()

func pose_for_mantle(time: float) -> void:
	# Pressing down on the ledge with one knee coming up over it.
	target_root = Vector3(0.0, ROOT_HEIGHT, 0.0)
	target_rotation = Vector3(-0.4, 0.0, 0.0)
	target_torso = Vector3(0.0, 1.5, -0.06)
	_set_joint("Head", Vector3(0.0, 2.0, -0.1))

	for side: float in [-1.0, 1.0]:
		_set_arm(side, Vector3(0.43, 1.6, -0.06), Vector3(0.62, 1.42, 0.08), Vector3(0.52, 1.1, -0.22), Vector3(0.5, 0.98, -0.28))
	_set_leg(-1.0, Vector3(0.15, 0.84, 0.0), Vector3(0.17, 0.44, -0.06), Vector3(0.17, 0.06, 0.1), Vector3(0.17, -0.03, 0.02))
	_set_leg(1.0, Vector3(0.15, 0.84, 0.0), Vector3(0.24, 0.78, -0.4), Vector3(0.24, 0.42, -0.3), Vector3(0.24, 0.34, -0.4))

	_apply_pose(time)

func get_joint(name: String) -> Node3D:
	return joints.get(name)

func get_limb_joints(prefix: String) -> Array[Node3D]:
	var limb_joints: Array[Node3D] = []
	for suffix in ["Shoulder", "Elbow", "Wrist", "Hand"]:
		if joints.has(prefix + suffix):
			limb_joints.append(joints[prefix + suffix])
	for suffix in ["Hip", "Knee", "Ankle", "Foot"]:
		if joints.has(prefix + suffix):
			limb_joints.append(joints[prefix + suffix])
	return limb_joints

func _build_rig() -> void:
	if not joints.is_empty():
		return

	torso_mesh = _create_cube("TorsoMesh", TORSO_SIZE, torso_local_position, SHIRT_COLOR)
	head_mesh = _create_cube("HeadMesh", HEAD_SIZE, Vector3(0.0, 2.0, 0.0), SKIN_COLOR)
	neck_mesh = _create_cube("NeckMesh", Vector3(0.16, 0.14, 0.16), Vector3(0.0, 1.76, 0.0), SKIN_COLOR)
	pelvis_mesh = _create_cube("PelvisMesh", Vector3(0.52, 0.24, 0.32), Vector3(0.0, PELVIS_HEIGHT, 0.0), PANTS_COLOR)
	left_shoulder_mesh = _create_cube("LeftShoulderMesh", Vector3(0.2, 0.2, 0.22), Vector3(-0.43, 1.6, 0.0), SHIRT_COLOR)
	right_shoulder_mesh = _create_cube("RightShoulderMesh", Vector3(0.2, 0.2, 0.22), Vector3(0.43, 1.6, 0.0), SHIRT_COLOR)
	left_hand_mesh = _create_cube("LeftHandMesh", HAND_SIZE, Vector3(-0.47, 0.78, 0.0), SKIN_COLOR)
	right_hand_mesh = _create_cube("RightHandMesh", HAND_SIZE, Vector3(0.47, 0.78, 0.0), SKIN_COLOR)
	left_shoe_mesh = _create_cube("LeftShoeMesh", SHOE_SIZE, Vector3(-0.15, -0.035, -0.1), SHOE_COLOR)
	right_shoe_mesh = _create_cube("RightShoeMesh", SHOE_SIZE, Vector3(0.15, -0.035, -0.1), SHOE_COLOR)

	# Details ride along with the part they are attached to. The face is on -Z.
	_create_cube("Waist", WAIST_SIZE, Vector3(0.0, -0.36, 0.0), SHIRT_COLOR, torso_mesh)
	_create_cube("HairTop", Vector3(0.46, 0.12, 0.46), Vector3(0.0, 0.22, 0.02), HAIR_COLOR, head_mesh)
	_create_cube("HairBack", Vector3(0.46, 0.3, 0.1), Vector3(0.0, 0.04, 0.2), HAIR_COLOR, head_mesh)
	_create_cube("HairFringe", Vector3(0.46, 0.07, 0.06), Vector3(0.0, 0.13, -0.2), HAIR_COLOR, head_mesh)
	_create_cube("LeftEye", Vector3(0.06, 0.08, 0.02), Vector3(-0.09, 0.0, -0.215), EYE_COLOR, head_mesh)
	_create_cube("RightEye", Vector3(0.06, 0.08, 0.02), Vector3(0.09, 0.0, -0.215), EYE_COLOR, head_mesh)
	_create_cube("Belt", Vector3(0.54, 0.06, 0.34), Vector3(0.0, 0.1, 0.0), BELT_COLOR, pelvis_mesh)
	_create_cube("ChalkBag", Vector3(0.18, 0.22, 0.14), Vector3(0.0, -0.04, 0.22), CHALK_BAG_COLOR, pelvis_mesh)

	_create_joint("Head")
	_create_limb(
		["LeftArmShoulder", "LeftArmElbow", "LeftArmWrist", "LeftArmHand"],
		[SHIRT_COLOR, SKIN_COLOR, SKIN_COLOR],
		[0.17, 0.14, 0.12]
	)
	_create_limb(
		["RightArmShoulder", "RightArmElbow", "RightArmWrist", "RightArmHand"],
		[SHIRT_COLOR, SKIN_COLOR, SKIN_COLOR],
		[0.17, 0.14, 0.12]
	)
	_create_limb(
		["LeftLegHip", "LeftLegKnee", "LeftLegAnkle", "LeftLegFoot"],
		[PANTS_COLOR, PANTS_COLOR, SHOE_COLOR],
		[0.23, 0.19, 0.13]
	)
	_create_limb(
		["RightLegHip", "RightLegKnee", "RightLegAnkle", "RightLegFoot"],
		[PANTS_COLOR, PANTS_COLOR, SHOE_COLOR],
		[0.23, 0.19, 0.13]
	)

func _create_limb(names: Array[String], colors: Array[Color], thicknesses: Array[float]) -> void:
	for joint_name in names:
		_create_joint(joint_name)

	for index in range(names.size() - 1):
		var segment := MeshInstance3D.new()
		segment.name = "%sSegment%d" % [names[0], index]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(thicknesses[index], 1.0, thicknesses[index])
		segment.mesh = mesh
		segment.material_override = _material_for(colors[index])
		add_child(segment)
		segments.append({
			"mesh": segment,
			"from": names[index],
			"to": names[index + 1],
			"thickness": thicknesses[index],
		})

func _create_joint(name: String) -> void:
	var joint := Node3D.new()
	joint.name = name
	add_child(joint)
	joints[name] = joint

func _material_for(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		materials[color] = material
	return materials[color]

func _create_cube(name: String, size: Vector3, mesh_position: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material_for(color)
	mesh_instance.position = mesh_position
	parent.add_child(mesh_instance)
	return mesh_instance

func _set_joint(name: String, local_position: Vector3) -> void:
	target_joints[name] = local_position

func _blend_factor(time: float) -> float:
	var blend := 1.0
	if last_pose_time >= 0.0:
		blend = 1.0 - exp(-clampf(time - last_pose_time, 0.0, 0.1) * POSE_BLEND_SPEED)
	last_pose_time = time
	return blend

# Places a limb's joints exactly, with no blending, so a gripping hand or foot
# never drifts off its hold.
func _pin_limb(prefix: String, suffixes: Array[String], points: Array[Vector3]) -> void:
	for index in suffixes.size():
		var joint_name := prefix + suffixes[index]
		target_joints[joint_name] = points[index]
		(joints[joint_name] as Node3D).position = points[index]

# Two-bone IK: the middle joint (elbow or knee) for a limb from `root` to
# `tip`, bending towards `pole`. An out-of-reach tip gives a straight limb.
func _solve_bend(root: Vector3, tip: Vector3, upper_length: float, lower_length: float, pole: Vector3) -> Vector3:
	var to_tip := tip - root
	var distance := to_tip.length()
	if distance < 0.001:
		return root + pole.normalized() * upper_length
	var direction := to_tip / distance
	if distance >= upper_length + lower_length:
		return root + to_tip * (upper_length / (upper_length + lower_length))

	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var out := sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var bend := pole - direction * pole.dot(direction)
	if bend.length_squared() < 0.0001:
		bend = direction.cross(Vector3.RIGHT)
	return root + direction * along + bend.normalized() * out

# Limb points are given for the right side and mirrored for the left.
# `offset` moves the whole limb past the root joint, which gets `root_offset`;
# the middle joint follows by `mid_follow`.
func _set_arm(side: float, shoulder: Vector3, elbow: Vector3, wrist: Vector3, hand: Vector3, offset := Vector3.ZERO, root_offset := Vector3.ZERO, mid_follow := 0.45) -> void:
	var prefix := "LeftArm" if side < 0.0 else "RightArm"
	var mirror := Vector3(side, 1.0, 1.0)
	_set_joint(prefix + "Shoulder", shoulder * mirror + root_offset)
	_set_joint(prefix + "Elbow", elbow * mirror + offset * mid_follow)
	_set_joint(prefix + "Wrist", wrist * mirror + offset)
	_set_joint(prefix + "Hand", hand * mirror + offset)

func _set_leg(side: float, hip: Vector3, knee: Vector3, ankle: Vector3, foot: Vector3, offset := Vector3.ZERO, root_offset := Vector3.ZERO, mid_follow := 0.5) -> void:
	var prefix := "LeftLeg" if side < 0.0 else "RightLeg"
	var mirror := Vector3(side, 1.0, 1.0)
	_set_joint(prefix + "Hip", hip * mirror + root_offset)
	_set_joint(prefix + "Knee", knee * mirror + offset * mid_follow)
	_set_joint(prefix + "Ankle", ankle * mirror + offset)
	_set_joint(prefix + "Foot", foot * mirror + offset)

# Ease every joint towards its target so switching pose (ground, air, climb,
# mantle) blends instead of snapping.
func _apply_pose(time: float) -> void:
	var blend := _blend_factor(time)
	position = position.lerp(target_root, blend)
	rotation = rotation.lerp(target_rotation, blend)
	torso_local_position = torso_local_position.lerp(target_torso, blend)
	for joint_name: String in target_joints:
		var joint: Node3D = joints[joint_name]
		joint.position = joint.position.lerp(target_joints[joint_name], blend)

	_update_segments()

func _update_segments() -> void:
	torso_mesh.position = torso_local_position
	head_mesh.position = joints["Head"].position
	neck_mesh.position = (torso_local_position + Vector3.UP * TORSO_SIZE.y * 0.5 + head_mesh.position) * 0.5
	pelvis_mesh.position = Vector3(torso_local_position.x, PELVIS_HEIGHT, torso_local_position.z)
	left_shoulder_mesh.position = joints["LeftArmShoulder"].position
	right_shoulder_mesh.position = joints["RightArmShoulder"].position
	_position_end_effector(left_hand_mesh, joints["LeftArmWrist"], joints["LeftArmHand"])
	_position_end_effector(right_hand_mesh, joints["RightArmWrist"], joints["RightArmHand"])
	_position_end_effector(left_shoe_mesh, joints["LeftLegAnkle"], joints["LeftLegFoot"], SHOE_SIZE)
	_position_end_effector(right_shoe_mesh, joints["RightLegAnkle"], joints["RightLegFoot"], SHOE_SIZE)

	for segment_data in segments:
		var from_joint: Node3D = joints[segment_data["from"]]
		var to_joint: Node3D = joints[segment_data["to"]]
		var direction := to_joint.position - from_joint.position
		var length := direction.length()
		if length <= 0.001:
			continue

		var mesh_instance: MeshInstance3D = segment_data["mesh"]
		var box_mesh: BoxMesh = mesh_instance.mesh
		var thickness: float = segment_data["thickness"]
		# Overlap neighbouring segments slightly so bent joints do not show gaps.
		box_mesh.size = Vector3(thickness, length + thickness * 0.5, thickness)
		mesh_instance.position = from_joint.position + direction * 0.5
		mesh_instance.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))

func _position_end_effector(mesh_instance: MeshInstance3D, from_joint: Node3D, to_joint: Node3D, override_size: Vector3 = HAND_SIZE) -> void:
	var direction := to_joint.position - from_joint.position
	if direction.length_squared() <= 0.001:
		return

	var box_mesh: BoxMesh = mesh_instance.mesh
	box_mesh.size = override_size
	mesh_instance.position = to_joint.position
	mesh_instance.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
