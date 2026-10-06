extends Area3D

# A pad that throws the player along an arc, for gaps too wide to jump. It
# aims at a child Marker3D named "Target": the player's feet arrive there
# `flight_time` seconds later. A target just in front of a climbable panel
# sends the player onto that wall.

@export var flight_time := 1.0

var _target: Node3D

@onready var arrow: Node3D = $Arrow
@onready var boost_sound: AudioStreamPlayer = $BoostSound

func _ready() -> void:
	_target = get_node_or_null("Target") as Node3D
	body_entered.connect(_on_body_entered)
	if _target == null:
		return

	# The arrow on the pad points the way the player will be thrown.
	var toward := _target.global_position - global_position
	toward.y = 0.0
	if toward.length_squared() > 0.01:
		arrow.look_at(arrow.global_position + toward, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if _target == null or not body.has_method("launch_to"):
		return

	if body.launch_to(_target.global_position, flight_time):
		boost_sound.play()
