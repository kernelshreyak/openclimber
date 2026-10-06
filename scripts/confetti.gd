extends Node3D

# A one-shot burst of low-poly confetti: flat coloured chips thrown upwards
# that tumble, flutter down and shrink away. Frees itself when done.

const PIECE_COUNT := 90
const LIFETIME := 3.2
const SHRINK_TIME := 0.6
const PIECE_SIZE := Vector3(0.16, 0.015, 0.1)
const LAUNCH_SPEED_MIN := 4.0
const LAUNCH_SPEED_MAX := 8.5
const SPREAD := 0.75
const GRAVITY := 9.0
const DRAG := 1.6
const FLUTTER_FALL_SPEED := 1.6
const SPIN_SPEED_MAX := 14.0
const COLORS: Array[Color] = [
	Color(0.95, 0.26, 0.3),
	Color(1.0, 0.8, 0.2),
	Color(0.25, 0.75, 0.45),
	Color(0.2, 0.6, 0.95),
	Color(0.7, 0.4, 0.9),
	Color(1.0, 0.55, 0.15),
]

var _age := 0.0
var _pieces: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spin_axes: Array[Vector3] = []
var _spin_speeds: Array[float] = []

func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = PIECE_SIZE

	var materials: Array[StandardMaterial3D] = []
	for color in COLORS:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.6
		materials.append(material)

	for i in PIECE_COUNT:
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.material_override = materials[i % materials.size()]
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.basis = Basis(_random_axis(), randf() * TAU)
		add_child(piece)
		_pieces.append(piece)

		var direction := (Vector3.UP + Vector3(randf_range(-SPREAD, SPREAD), 0.0, randf_range(-SPREAD, SPREAD))).normalized()
		_velocities.append(direction * randf_range(LAUNCH_SPEED_MIN, LAUNCH_SPEED_MAX))
		_spin_axes.append(_random_axis())
		_spin_speeds.append(randf_range(SPIN_SPEED_MAX * 0.3, SPIN_SPEED_MAX))

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return

	var piece_scale := Vector3.ONE * clampf((LIFETIME - _age) / SHRINK_TIME, 0.0, 1.0)
	for i in _pieces.size():
		var velocity := _velocities[i]
		velocity.y -= GRAVITY * delta
		# Air drag slows the burst, and falling chips flutter instead of dropping.
		velocity.x -= velocity.x * DRAG * delta
		velocity.z -= velocity.z * DRAG * delta
		velocity.y = maxf(velocity.y, -FLUTTER_FALL_SPEED)
		_velocities[i] = velocity

		var piece := _pieces[i]
		piece.position += velocity * delta
		piece.basis = Basis(_spin_axes[i], _spin_speeds[i] * _age).scaled(piece_scale)

func _random_axis() -> Vector3:
	var axis := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	return axis.normalized() if axis.length_squared() > 0.001 else Vector3.UP
