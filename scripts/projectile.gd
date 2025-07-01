extends Node3D

@export var speed: float = 5.0
@onready var raycast = $RayCast3D

var direction: Vector3
var rotation_euler: Vector3

func _ready() -> void:
	# Use the provided Euler rotation if available
	if rotation_euler != Vector3.ZERO:
		rotation = rotation_euler
	# Otherwise try to orient using look_at
	elif direction != Vector3.ZERO:
		print("oh no")
		look_at(global_transform.origin + direction, Vector3.UP)

func _process(delta: float) -> void:
	if direction != Vector3.ZERO:
		# Move the projectile in the direction
		translate(direction * speed * delta)
	if raycast.is_colliding():
		queue_free()
