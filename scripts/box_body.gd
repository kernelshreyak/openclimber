@tool
extends StaticBody3D

# A solid box whose collision and mesh are built from `size`, so course pieces
# can be resized without scaling the node.

@export var size := Vector3(2.0, 2.0, 2.0):
	set(value):
		size = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()

var _collision: CollisionShape3D
var _mesh: MeshInstance3D

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return

	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.shape = BoxShape3D.new()
		add_child(_collision)
		_mesh = MeshInstance3D.new()
		_mesh.mesh = BoxMesh.new()
		add_child(_mesh)

	(_collision.shape as BoxShape3D).size = size
	(_mesh.mesh as BoxMesh).size = size
	_mesh.material_override = material
