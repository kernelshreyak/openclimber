extends Area3D

# The flag at the top of a climb. Touching it plays a chime and sets off a
# burst of confetti; it re-arms once the player steps away.

const Confetti := preload("res://scripts/confetti.gd")

const CONFETTI_HEIGHT := 1.0

var _armed := true

@onready var chime_sound: AudioStreamPlayer = $ChimeSound

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not _armed or not body is CharacterBody3D:
		return

	_armed = false
	chime_sound.play()
	var confetti := Confetti.new()
	confetti.position = Vector3.UP * CONFETTI_HEIGHT
	add_child(confetti)

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_armed = true
