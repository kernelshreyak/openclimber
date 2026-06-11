extends Node3D

const TORSO_SIZE := Vector3(0.82, 1.12, 0.46)
const HEAD_SIZE := Vector3(0.5, 0.5, 0.5)
const LIMB_THICKNESS := 0.2

var joints: Dictionary = {}
var segments: Array[Dictionary] = []
var torso_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var torso_local_position := Vector3(0.0, 1.2, 0.0)
var face_mesh: MeshInstance3D
var hair_mesh: MeshInstance3D
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
	pose_for_ground(0.0, 0.0, 0.0, true)

func pose_for_ground(forward_input: float, turn_input: float, time: float, on_floor: bool) -> void:
	var swing := sin(time * 7.0) * forward_input * 0.35
	var crouch := 0.02 if on_floor else -0.12

	position = Vector3.ZERO
	position.y = 0.44 + crouch
	torso_local_position = Vector3(0.0, 1.2, 0.0)

	_set_joint("Head", Vector3(0.0, 1.84, 0.0))
	_set_joint("LeftArmShoulder", Vector3(-0.54, 1.5, 0.0))
	_set_joint("LeftArmElbow", Vector3(-0.82, 1.1, -swing * 0.4))
	_set_joint("LeftArmWrist", Vector3(-0.7, 0.72, -swing * 0.75))
	_set_joint("LeftArmHand", Vector3(-0.64, 0.48, -swing * 0.85))
	_set_joint("RightArmShoulder", Vector3(0.54, 1.5, 0.0))
	_set_joint("RightArmElbow", Vector3(0.82, 1.1, swing * 0.4))
	_set_joint("RightArmWrist", Vector3(0.7, 0.72, swing * 0.75))
	_set_joint("RightArmHand", Vector3(0.64, 0.48, swing * 0.85))
	_set_joint("LeftLegHip", Vector3(-0.22, 0.8, 0.0))
	_set_joint("LeftLegKnee", Vector3(-0.22, 0.34, swing * 0.3))
	_set_joint("LeftLegAnkle", Vector3(-0.22, 0.0, swing * 0.18))
	_set_joint("LeftLegFoot", Vector3(-0.22, -0.14, 0.16 + swing * 0.12))
	_set_joint("RightLegHip", Vector3(0.22, 0.8, 0.0))
	_set_joint("RightLegKnee", Vector3(0.22, 0.34, -swing * 0.3))
	_set_joint("RightLegAnkle", Vector3(0.22, 0.0, -swing * 0.18))
	_set_joint("RightLegFoot", Vector3(0.22, -0.14, 0.16 - swing * 0.12))

	rotation = Vector3(0.0, 0.0, -turn_input * 0.04)
	_update_segments()

func pose_for_climb(surface_normal: Vector3, input_vec: Vector2, time: float) -> void:
	var lateral_swing := sin(time * 8.0) * 0.08
	var vertical_shift := -input_vec.y * 0.1
	var horizontal_shift := input_vec.x * 0.12 + lateral_swing

	position = Vector3.ZERO
	rotation = Vector3.ZERO
	torso_local_position = Vector3(0.0, 1.18, 0.26)

	_set_joint("Head", Vector3(0.0, 1.82, 0.12))
	_set_joint("LeftArmShoulder", Vector3(-0.54, 1.48, 0.08))
	_set_joint("LeftArmElbow", Vector3(-0.9 + horizontal_shift, 1.18 + vertical_shift, -0.34))
	_set_joint("LeftArmWrist", Vector3(-0.82 + horizontal_shift, 0.92 + vertical_shift, -0.72))
	_set_joint("LeftArmHand", Vector3(-0.74 + horizontal_shift, 0.74 + vertical_shift, -1.02))
	_set_joint("RightArmShoulder", Vector3(0.54, 1.48, 0.08))
	_set_joint("RightArmElbow", Vector3(0.9 + horizontal_shift, 1.18 - vertical_shift, -0.34))
	_set_joint("RightArmWrist", Vector3(0.82 + horizontal_shift, 0.92 - vertical_shift, -0.72))
	_set_joint("RightArmHand", Vector3(0.74 + horizontal_shift, 0.74 - vertical_shift, -1.02))
	_set_joint("LeftLegHip", Vector3(-0.28, 0.82, 0.08))
	_set_joint("LeftLegKnee", Vector3(-0.44 - horizontal_shift * 0.45, 0.54 - vertical_shift * 0.6, -0.18))
	_set_joint("LeftLegAnkle", Vector3(-0.44 - horizontal_shift * 0.35, 0.24 - vertical_shift, -0.64))
	_set_joint("LeftLegFoot", Vector3(-0.38 - horizontal_shift * 0.3, 0.02 - vertical_shift, -0.96))
	_set_joint("RightLegHip", Vector3(0.28, 0.82, 0.08))
	_set_joint("RightLegKnee", Vector3(0.44 - horizontal_shift * 0.45, 0.54 + vertical_shift * 0.6, -0.18))
	_set_joint("RightLegAnkle", Vector3(0.44 - horizontal_shift * 0.35, 0.24 + vertical_shift, -0.64))
	_set_joint("RightLegFoot", Vector3(0.38 - horizontal_shift * 0.3, 0.02 + vertical_shift, -0.96))

	_update_segments()

func get_joint(name: StringName) -> Node3D:
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

	torso_mesh = _create_cube("TorsoMesh", TORSO_SIZE, torso_local_position, Color(0.302, 0.541, 0.761))
	head_mesh = _create_cube("HeadMesh", HEAD_SIZE, Vector3(0.0, 1.84, 0.0), Color(0.945, 0.796, 0.643))
	face_mesh = _create_cube("FaceMesh", Vector3(0.34, 0.24, 0.02), Vector3(0.0, 1.84, -0.26), Color(0.13, 0.13, 0.16))
	hair_mesh = _create_cube("HairMesh", Vector3(0.54, 0.14, 0.5), Vector3(0.0, 2.02, 0.04), Color(0.22, 0.16, 0.11))
	neck_mesh = _create_cube("NeckMesh", Vector3(0.14, 0.16, 0.16), Vector3(0.0, 1.56, 0.0), Color(0.902, 0.745, 0.592))
	pelvis_mesh = _create_cube("PelvisMesh", Vector3(0.56, 0.24, 0.3), Vector3(0.0, 0.84, 0.0), Color(0.145, 0.247, 0.416))
	left_shoulder_mesh = _create_cube("LeftShoulderMesh", Vector3(0.18, 0.18, 0.18), Vector3(-0.54, 1.48, 0.0), Color(0.302, 0.541, 0.761))
	right_shoulder_mesh = _create_cube("RightShoulderMesh", Vector3(0.18, 0.18, 0.18), Vector3(0.54, 1.48, 0.0), Color(0.302, 0.541, 0.761))
	left_hand_mesh = _create_cube("LeftHandMesh", Vector3(0.16, 0.16, 0.16), Vector3(-0.64, 0.5, 0.0), Color(0.945, 0.796, 0.643))
	right_hand_mesh = _create_cube("RightHandMesh", Vector3(0.16, 0.16, 0.16), Vector3(0.64, 0.5, 0.0), Color(0.945, 0.796, 0.643))
	left_shoe_mesh = _create_cube("LeftShoeMesh", Vector3(0.22, 0.12, 0.32), Vector3(-0.22, -0.16, 0.18), Color(0.93, 0.93, 0.95))
	right_shoe_mesh = _create_cube("RightShoeMesh", Vector3(0.22, 0.12, 0.32), Vector3(0.22, -0.16, 0.18), Color(0.93, 0.93, 0.95))

	_create_joint("Head")
	_create_limb(
		["LeftArmShoulder", "LeftArmElbow", "LeftArmWrist", "LeftArmHand"],
		Color(0.949, 0.494, 0.298)
	)
	_create_limb(
		["RightArmShoulder", "RightArmElbow", "RightArmWrist", "RightArmHand"],
		Color(0.949, 0.494, 0.298)
	)
	_create_limb(
		["LeftLegHip", "LeftLegKnee", "LeftLegAnkle", "LeftLegFoot"],
		Color(0.357, 0.682, 0.408)
	)
	_create_limb(
		["RightLegHip", "RightLegKnee", "RightLegAnkle", "RightLegFoot"],
		Color(0.357, 0.682, 0.408)
	)

func _create_limb(names: Array[String], color: Color) -> void:
	for joint_name in names:
		_create_joint(joint_name)

	for index in range(names.size() - 1):
		var segment := MeshInstance3D.new()
		segment.name = "%sSegment%d" % [names[0], index]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(LIMB_THICKNESS, 1.0, LIMB_THICKNESS)
		segment.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		segment.material_override = material
		add_child(segment)
		segments.append({
			"mesh": segment,
			"from": names[index],
			"to": names[index + 1],
		})

func _create_joint(name: String) -> void:
	var joint := Node3D.new()
	joint.name = name
	add_child(joint)
	joints[name] = joint

func _create_cube(name: String, size: Vector3, mesh_position: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	add_child(mesh_instance)
	return mesh_instance

func _set_joint(name: String, local_position: Vector3) -> void:
	var joint: Node3D = joints[name]
	joint.position = local_position

func _update_segments() -> void:
	torso_mesh.position = torso_local_position
	head_mesh.position = joints["Head"].position
	face_mesh.position = joints["Head"].position + Vector3(0.0, 0.0, -HEAD_SIZE.z * 0.54)
	hair_mesh.position = joints["Head"].position + Vector3(0.0, HEAD_SIZE.y * 0.34, 0.04)
	neck_mesh.position = Vector3(0.0, torso_local_position.y + TORSO_SIZE.y * 0.55, torso_local_position.z + 0.01)
	pelvis_mesh.position = Vector3(0.0, 0.84, torso_local_position.z * 0.3)
	left_shoulder_mesh.position = joints["LeftArmShoulder"].position
	right_shoulder_mesh.position = joints["RightArmShoulder"].position
	_position_end_effector(left_hand_mesh, joints["LeftArmWrist"], joints["LeftArmHand"])
	_position_end_effector(right_hand_mesh, joints["RightArmWrist"], joints["RightArmHand"])
	_position_end_effector(left_shoe_mesh, joints["LeftLegAnkle"], joints["LeftLegFoot"], Vector3(0.22, 0.12, 0.32))
	_position_end_effector(right_shoe_mesh, joints["RightLegAnkle"], joints["RightLegFoot"], Vector3(0.22, 0.12, 0.32))

	for segment_data in segments:
		var from_joint: Node3D = joints[segment_data["from"]]
		var to_joint: Node3D = joints[segment_data["to"]]
		var direction := to_joint.position - from_joint.position
		var length := direction.length()
		if length <= 0.001:
			continue

		var mesh_instance: MeshInstance3D = segment_data["mesh"]
		var box_mesh: BoxMesh = mesh_instance.mesh
		box_mesh.size = Vector3(LIMB_THICKNESS, length, LIMB_THICKNESS)
		mesh_instance.position = from_joint.position + direction * 0.5
		mesh_instance.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))

func _position_end_effector(mesh_instance: MeshInstance3D, from_joint: Node3D, to_joint: Node3D, override_size: Vector3 = Vector3(0.16, 0.16, 0.16)) -> void:
	var direction := to_joint.position - from_joint.position
	if direction.length_squared() <= 0.001:
		return

	var box_mesh: BoxMesh = mesh_instance.mesh
	box_mesh.size = override_size
	mesh_instance.position = to_joint.position
	mesh_instance.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
