extends Node3D

@export var speed: float = 50.0
@onready var mesh = $"3DModel"
@onready var explosion = $ExplosionParticles
@onready var explosion_area = $ExplosionArea
@onready var hitbox = $Hitbox
@onready var explosion_sound = $ExplosionSound

var currently_blowing_up: bool = false
var direction: Vector3
var rotation_euler: Vector3
var lifetime: float = 0.0
var max_lifetime: float = 10.0

func _ready() -> void:
	# look_at(global_transform.origin + direction, Vector3.UP) THIS WAS WHY THE FUCKING BULLET WAS FLYING AT FUCKED UP ANGLES OMG
	pass

func _physics_process(delta: float) -> void:
	if currently_blowing_up or not is_inside_tree():
		return
	
	lifetime += delta
	if lifetime >= max_lifetime:
		explode()
		return
	
	# Use raycast for proper collision detection
	if direction != Vector3.ZERO:
		var space_state = get_world_3d().direct_space_state
		if not space_state:
			return
			
		var ray_length = speed * delta
		var query = PhysicsRayQueryParameters3D.create(
			global_transform.origin,
			global_transform.origin + direction * ray_length
		)
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var collider = result.collider
			if collider and collider.name != "Player":
				# Move to collision point before exploding
				# global_transform.origin = result.position ## Messes with hitting objects, will not use
				explode()
				return
		
		# Move the projectile
		translate(direction * speed * delta)

func explode() -> void:
	if currently_blowing_up:
		return
	
	currently_blowing_up = true
	
	if not is_inside_tree():
		return
		
	print("BOOM")
	mesh.visible = false
	explosion.emitting = true
	
	# Add random variance to explosion sound
	explosion_sound.pitch_scale = randf_range(0.8, 1.2)
	explosion_sound.play()

	var explosion_radius = 8.0
	var explosion_force = 60.0
	var origin = global_transform.origin

	explosion_area.scale = Vector3.ONE * (explosion_radius / 2.0)
	explosion_area.global_transform.origin = origin

	apply_explosion_impulse(origin, explosion_force, explosion_radius)

	await get_tree().create_timer(0.5).timeout
	if is_inside_tree():
		queue_free()

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
