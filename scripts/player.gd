extends CharacterBody3D

@onready var Cam = $Camera3D as Camera3D
@onready var Raycast = $Camera3D/RayCast3D as RayCast3D
@onready var GroundSlamArea = $GroundSlamArea as Area3D

var mouse_sens = 600
var mouse_relative_x = 0
var mouse_relative_y = 0

const SPEED = 12.0
const JUMP_VELOCITY = 9.0
@export var max_air_jumps = 1
var air_jumps = max_air_jumps

const DASH_SPEED = 50.0
const DASH_TIME = 0.6
var dash_timer = 0.0
@export var dash_delay = 5.0
var dash_velocity = Vector3.ZERO

var touching_wall = false
var ground_slamming = false

const MAX_WALK_SPEED = 12
const MAX_TOTAL_SPEED = 60 # feels better than 40
const MAX_MOMENTUM_SPEED = 22
const ACCEL = 50.0
const AIR_ACCEL = 5.0
const FRICTION = 50.0

var camera_tilt = 0.0
var camera_fov = 90.0

# Grappling hook variables
var grapple_hook_point = Vector3.ZERO
var is_grappling = false
var grapple_length = 0.0
var is_reeling_in = false
const GRAPPLE_RANGE = 40.0
const GRAPPLE_SPEED = 40.0
const GRAPPLE_SWING_FORCE = 15.0
const GRAPPLE_ELASTICITY = 0.3

# Visual rope using sphere dots
var rope_dots = []
const ROPE_SEGMENTS = 20

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") # 19.6 (9.8 * 2)
var slow_factor = 0.0
var groundslamheight = 0.0

@onready var projectile_scene = preload("res://scenes/projectile.tscn")

var input_dir
var direction

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Create rope dots
	create_rope_dots()

func _input(event):
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / mouse_sens
		Cam.rotation.x -= event.relative.y / mouse_sens
		Cam.rotation.x = clamp(Cam.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		mouse_relative_x = clamp(event.relative.x, -50, 50)
		mouse_relative_y = clamp(event.relative.y, -50, 10)

##move this to weapon manager later
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_inside_tree():
			var projectile = projectile_scene.instantiate()
			
			# Calculate direction manually from individual rotations
			var forward = Vector3(0, 0, -1)
			# Apply camera X rotation (pitch)
			forward = forward.rotated(Vector3.RIGHT, Cam.rotation.x)
			# Apply player Y rotation (yaw)
			forward = forward.rotated(Vector3.UP, rotation.y)
			projectile.direction = forward.normalized()

			
			# Set projectile position (using camera's global position)
			var muzzle_position = Cam.global_transform.origin + -Cam.global_transform.basis.z * 1.5
			projectile.global_transform.origin = muzzle_position # This works, but throws an error. If i fix the error, it doesn't work. To fix or ignore?

			get_tree().current_scene.add_child(projectile)


func _physics_process(delta):
	if Input.is_action_just_pressed("grapple"):
		if not is_grappling and dash_timer <= 0.0:
			attempt_grapple()
		elif is_grappling:
			attempt_grapple()
	
	if is_grappling:
		is_reeling_in = not Input.is_action_pressed("grapple")

		# Handle grappling hook physics
	if is_grappling:
		handle_grappling_physics(delta)
	
	# Update rope visual
	update_rope_visual()

	if not is_on_floor() and is_on_wall() and not touching_wall:
		touching_wall = true
		air_jumps += 1
	elif not is_on_floor() and not is_on_wall() and touching_wall:
		touching_wall = false
		if air_jumps > 0:
			air_jumps -= 1

	if Input.is_action_just_pressed("slide"):
		if is_on_floor():
			#sliding code
			pass

		else:
			velocity.y = - SPEED * 7
			velocity.x = 0
			velocity.z = 0
			ground_slamming = true
			groundslamheight = position.y
	

	if is_on_floor() and ground_slamming:
			# Impulse nearby characters and rigidbodies outwards
			var explosion_origin = GroundSlamArea.global_transform.origin
			var explosion_radius = 6
			var travel_distance = min(position.distance_to(Vector3(position.x, groundslamheight, position.z)), 10.0)
			var explosion_force = lerp(5.0, 35.0, travel_distance / 10.0)
			print("Explosion Force: ", explosion_force)
			for body in GroundSlamArea.get_overlapping_bodies():
				if body == self:
					continue
				if not (body is RigidBody3D or body is CharacterBody3D):
					continue

				var body_pos = body.global_transform.origin
				var to_body = body_pos - explosion_origin
				var distance = to_body.length()
				if distance == 0.0 or distance > explosion_radius:
					continue

				var explosion_direction = to_body.normalized()
				var falloff = 1.0 - clamp(distance / explosion_radius, 0.0, 1.0) # this feels inverted for some reason. Could just be me
				var force = explosion_direction * explosion_force * falloff

				if body is RigidBody3D:
					body.apply_central_impulse(force)
				elif body is CharacterBody3D and "velocity" in body:
					body.velocity += force
			#todo: camera effect
			ground_slamming = false
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif air_jumps < max_air_jumps:
		air_jumps = max_air_jumps
		if is_on_wall():
			velocity.y += 40
			print("Wall Jump Gravity")
		else:
			gravity = ProjectSettings.get_setting("physics/3d/default_gravity") # 19.6 (9.8 * 2)

	if is_grappling and air_jumps < max_air_jumps:
		air_jumps = max_air_jumps

	#reset position if falling off map
	if position.y < -30:
		position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO

	if Input.is_action_just_pressed("jump"):
		# Release grapple if currently grappling
		if is_grappling:
			release_grapple()
			#velocity.y = JUMP_VELOCITY * 0.8
		elif air_jumps > 0:
			ground_slamming = false
			if not is_on_floor():
				if touching_wall:
					var wall_normal = get_wall_normal()
					velocity = wall_normal * JUMP_VELOCITY * 2
					velocity.y = JUMP_VELOCITY
				else:
					velocity += direction * 10
					velocity.y = JUMP_VELOCITY * 0.85
					air_jumps -= 1
			else:
				velocity.y = JUMP_VELOCITY

	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	input_dir = Input.get_vector("left", "right", "forward", "backward")
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

#Shimmy seems to be fixed

	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		var dash_dir = direction
		if dash_dir == Vector3.ZERO:
			dash_dir = - transform.basis.z.normalized()
			dash_velocity = dash_dir * DASH_SPEED * 0.8
		else:
			if velocity.normalized().dot(dash_dir) < 0.9:
				velocity = Vector3.ZERO
			dash_velocity = dash_dir * DASH_SPEED
		dash_timer = DASH_TIME

	if dash_timer > 0.0 and dash_timer >= (DASH_TIME / 1.5):
		dash_timer -= delta
		velocity = Vector3(dash_velocity.x, velocity.y, dash_velocity.z)
		#velocity.x = dash_velocity.x
		#velocity.z = dash_velocity.z
	else:
		dash_timer = 0

		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		var speed = horizontal_velocity.length()
		if direction.length() > 0:
			var accel = ACCEL if is_on_floor() else AIR_ACCEL
			velocity += direction * accel * delta
			if is_on_floor() and horizontal_velocity.length() > SPEED:
				var clamped_hvel = Vector3(velocity.x, 0, velocity.z)
				clamped_hvel = clamped_hvel.move_toward(direction * SPEED, FRICTION * delta)
				velocity.x = clamped_hvel.x
				velocity.z = clamped_hvel.z

		if is_on_floor() and direction.length() > 0:
			if speed > 0:
				#normal slowdown
				slow_factor = 0.4
				if speed > MAX_MOMENTUM_SPEED:
					#fast slowdown
					slow_factor = 1.0
				elif speed > SPEED:
					#slow slowdown
					slow_factor = 0.7 + ((speed - SPEED) / (MAX_MOMENTUM_SPEED - SPEED))
		elif is_on_floor() and direction.length() == 0:
			if speed > SPEED:
				slow_factor = 0.8
			else:
				slow_factor = 0.6

		# --- friction fix: apply to full vector
		if is_on_floor():
			var friction_hvel = Vector3(velocity.x, 0, velocity.z)
			friction_hvel = friction_hvel.move_toward(Vector3.ZERO, FRICTION * slow_factor * delta)
			velocity.x = friction_hvel.x
			velocity.z = friction_hvel.z

	var final_hvel = Vector3(velocity.x, 0, velocity.z)
	if final_hvel.length() > MAX_TOTAL_SPEED:
		final_hvel = final_hvel.normalized() * MAX_TOTAL_SPEED
		velocity.x = final_hvel.x
		velocity.z = final_hvel.z

	camera_effects()
	move_and_slide()

func attempt_grapple():
	# Set up raycast for grappling
	Raycast.target_position = Vector3(0, 0, -GRAPPLE_RANGE)
	Raycast.force_raycast_update()
	
	if Raycast.is_colliding():
		var collider = Raycast.get_collider()
		
		var is_valid_target = false
		
		if collider is StaticBody3D:
			is_valid_target = true
		elif collider is CSGShape3D:
			is_valid_target = true
		elif collider is CharacterBody3D and collider != self:
			is_valid_target = true
		elif collider.has_method("get_class"):
			var parent_node = collider.get_parent()
			if parent_node is StaticBody3D:
				is_valid_target = true
		
		if is_valid_target:
			var was_already_grappling = is_grappling
			grapple_hook_point = Raycast.get_collision_point()
			is_grappling = true
			grapple_length = global_position.distance_to(grapple_hook_point)
			if was_already_grappling:
				print("Regrappled to: ", grapple_hook_point, " Distance: ", grapple_length)
			else:
				print("Grapple attached at: ", grapple_hook_point, " Distance: ", grapple_length)
		else:
			if is_grappling:
				print("Cannot regrapple to invalid target: ", collider.get_class() if collider.has_method("get_class") else "Unknown")
				release_grapple() # Release grapple if regrapple fails
			else:
				print("Invalid grapple target: ", collider.get_class() if collider.has_method("get_class") else "Unknown")
	else:
		if is_grappling:
			print("No regrapple target found within range")
			release_grapple() # Release grapple if regrapple misses
		else:
			print("No grapple target found within range")

func release_grapple():
	is_grappling = false
	is_reeling_in = false
	print("Grapple released")

func handle_grappling_physics(delta):
	if not is_grappling:
		return
		
	var to_hook = grapple_hook_point - global_position
	var distance_to_hook = to_hook.length()
	
	# Calculate elastic rope behavior
	var max_elastic_length = grapple_length * (1.0 + GRAPPLE_ELASTICITY)
	var rope_direction = to_hook.normalized()
	
	# If we're holding the grapple button, swing behavior
	if Input.is_action_pressed("grapple"):
		is_reeling_in = false
		
		# Swing behavior with elastic rope constraint
		if distance_to_hook > grapple_length:
			if distance_to_hook > max_elastic_length:
				# Hard constraint at maximum elastic length
				var excess_distance = distance_to_hook - max_elastic_length
				global_position += rope_direction * excess_distance * 0.95
				distance_to_hook = max_elastic_length
				to_hook = grapple_hook_point - global_position
			
			# Apply elastic force - stronger the further from rope length
			var stretch_ratio = (distance_to_hook - grapple_length) / (max_elastic_length - grapple_length)
			var elastic_force = stretch_ratio * 20.0 # Elastic force strength
			velocity += rope_direction * elastic_force * delta
			
			# Remove velocity component going away from hook if beyond elastic limit
			var velocity_toward_hook = velocity.dot(rope_direction)
			if distance_to_hook > grapple_length * 1.1 and velocity_toward_hook < 0:
				velocity -= rope_direction * velocity_toward_hook * 0.5
		
		# Apply swing forces based on input
		var swing_input = input_dir.x # Left/right input
		if swing_input != 0:
			var right_direction = - transform.basis.x # Player's right direction
			var swing_force = right_direction * swing_input * GRAPPLE_SWING_FORCE
			velocity += swing_force * delta
		
		# Apply reduced gravity while swinging
		velocity.y -= gravity * 0.3 * delta
		
	else:
		is_reeling_in = true
		
		# When reeling in, go straight toward the grapple point with limited other influences
		var reel_speed = GRAPPLE_SPEED * delta
		if distance_to_hook > 2.0:
			# Add safety margin when near walls/surfaces
			var min_rope_length = 2.0
			if is_on_wall():
				min_rope_length = 3.5 # Larger safety margin when near walls
			
			grapple_length = max(grapple_length - reel_speed, min_rope_length)
			grapple_length = min(grapple_length, distance_to_hook)
		
		# Check if we're about to clip into a wall
		if is_on_wall() and distance_to_hook < 0.5:
			print("Grapple released to prevent wall clipping")
			release_grapple()
			return
		
		# Direct movement toward grapple point with limited other velocity influences
		var target_velocity = rope_direction * GRAPPLE_SPEED * 2
		
		# Heavily dampen existing velocity to reduce swinging
		velocity *= 0.9
		
		# Set velocity 50/50 between dampened current velocity and grapple direction
		velocity = velocity.lerp(target_velocity, 0.5)
		
		# Apply minimal gravity when reeling in
		velocity.y -= gravity * 0.5 * delta

func camera_effects() -> void:
	camera_tilt = clamp(-input_dir.x * velocity.length() * 0.0025, -0.15, 0.15)
	Cam.rotation.z += (camera_tilt - Cam.rotation.z) * 0.05

	camera_fov = 90 + clamp(input_dir.y * velocity.length() * -0.1, -10, 10)
	Cam.fov += (camera_fov - Cam.fov) * 0.1

func create_rope_dots():
	# Create small sphere dots to form the rope
	for i in range(ROPE_SEGMENTS):
		var dot = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.05
		sphere_mesh.height = 0.1
		dot.mesh = sphere_mesh
		
		# Create bright white material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		material.emission_enabled = true
		material.emission = Color.WHITE
		material.flags_unshaded = true
		dot.material_override = material
		
		dot.visible = false
		add_child(dot)
		rope_dots.append(dot)

func update_rope_visual():
	if not is_grappling:
		# Hide all dots
		for dot in rope_dots:
			dot.visible = false
		return
	
	# Show and position dots along the rope
	var rope_start = Cam.global_position + (-Cam.global_transform.basis.z * 0.5) # Slightly in front of camera
	var rope_end = grapple_hook_point
	
	for i in range(ROPE_SEGMENTS):
		var t = float(i) / float(ROPE_SEGMENTS - 1) # 0 to 1
		var dot_position = rope_start.lerp(rope_end, t)
		rope_dots[i].global_position = dot_position
		rope_dots[i].visible = true
