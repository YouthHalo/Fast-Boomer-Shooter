extends Node3D

@export var speed: float = 5.0
@onready var raycast = $RayCast3D
@onready var mesh = $"3DModel"
@onready var explosion = $GPUParticles3D

var direction: Vector3
var rotation_euler: Vector3

func _ready() -> void:
	look_at(global_transform.origin + direction, Vector3.UP)
	mesh.rotation = Vector3.FORWARD
	mesh.rotate(Vector3.RIGHT, -PI)
	# Align the mesh so its local Y axis points in the direction of travel
	pass

func _process(delta: float) -> void:
	if direction != Vector3.ZERO and not raycast.is_colliding():
		# Move the projectile in the direction
		translate(direction * speed * delta)
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider:
			print("Hit: ", collider.name)
		mesh.visible = false
		explosion.restart()
		explosion.emitting = true
		print("KABOOM!")
		raycast.enabled = false
		await get_tree().create_timer(0.5).timeout  # Adjust the delay as needed
		
		#explosion code here
		queue_free()
