extends Area


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Area_body_entered(body: KinematicBody):
	if body.has_method("climb"):
		body.climb(true)


func _on_ClimbPoint_body_exited(body):
	if body.has_method("climb"):
		body.climb(false)
