@tool
extends "res://scripts/box_body.gd"
class_name ClimbableSurface

func _ready() -> void:
	add_to_group("climbable_surface")
	if material == null:
		material = preload("res://materials/climbable.tres")
	super()
