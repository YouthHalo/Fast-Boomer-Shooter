extends Node3D

@export var speed: float = 50.0
@onready var mesh = $"3DModel"
@onready var explosion = $ExplosionParticles
@onready var explosion_area = $ExplosionArea
@onready var hitbox = $Hitbox

var currently_blowing_up: bool = false
var direction: Vector3
var rotation_euler: Vector3

func _ready() -> void:
	look_at(global_transform.origin + direction, Vector3.UP)
	pass

func _physics_process(delta: float) -> void:
	if hitbox.get_overlapping_bodies().size() > 0 and not currently_blowing_up:
		var collider = hitbox.get_overlapping_bodies()[0]
		if collider and collider.name != "Player":
			mesh.visible = false
			explosion.emitting = true
			currently_blowing_up = true

			var explosion_radius = 8.0
			var explosion_force = 60.0
			var origin = global_transform.origin

			explosion_area.scale = Vector3.ONE * (explosion_radius / 2.0)
			explosion_area.global_transform.origin = origin

			# Apply explosion impulse
			apply_explosion_impulse(origin, explosion_force, explosion_radius)

			await get_tree().create_timer(0.5).timeout
			queue_free()
		else:
			if direction != Vector3.ZERO:
				translate(direction * speed * delta)
	else:
		if direction != Vector3.ZERO:
			translate(direction * speed * delta)

func apply_explosion_impulse(explosion_origin: Vector3, explosion_force: float, explosion_radius: float) -> void:
	for body in explosion_area.get_overlapping_bodies():
		if not (body is RigidBody3D or body is CharacterBody3D):
			continue

		var body_pos = body.global_transform.origin
		var to_body = body_pos - explosion_origin
		var distance = to_body.length()
		if distance == 0.0 or distance > explosion_radius:
			continue

		var explosion_direction = to_body.normalized()
		var falloff = 1.0 - clamp(distance / explosion_radius, 0.0, 1.0)
		var force = explosion_direction * explosion_force * falloff

		if body.name == "Player":
			force *= 0.75

		if body is RigidBody3D:
			body.apply_central_impulse(force)
		elif body is CharacterBody3D and "velocity" in body:
			body.velocity += force
			
