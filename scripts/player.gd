extends CharacterBody3D

@onready var Cam = $Camera3D as Camera3D
var mouse_sens = 600
var mouse_relative_x = 0
var mouse_relative_y = 0

const SPEED = 12.0
const JUMP_VELOCITY = 9
@export var max_air_jumps = 1
var air_jumps = 1

const DASH_SPEED = 50.0
const DASH_TIME = 0.6
var dash_timer = 0.0
var dash_velocity = Vector3.ZERO

var touching_wall = false


var camera_tilt = 0.0
var camera_fov = 90.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Add gravitys
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif air_jumps < max_air_jumps:
		air_jumps = max_air_jumps

	# Allow wall jump
	if not is_on_floor() and is_on_wall() and not touching_wall:
		touching_wall = true
		air_jumps += 1
	elif not is_on_floor() and not is_on_wall() and touching_wall:
		touching_wall = false
		if air_jumps > 0:
			air_jumps -= 1
	# Reset air jumps when on floor

	#send the player back to origin when falling off
	if position.y < -30:
		position = Vector3.ZERO
		velocity = Vector3.ZERO

	# Handle Jump
	if Input.is_action_just_pressed("jump") and air_jumps > 0:
		if not is_on_floor():
			if touching_wall:
				# Perform a wall jump
				var wall_normal = get_wall_normal()
				velocity = wall_normal * JUMP_VELOCITY * 9  # CURRENTLY DOESNT DO ANYTHING DUE TO MOVEMENT CODE.
				velocity.y = JUMP_VELOCITY * 0.8  # Add upward velocity
				print("WALL JUMP")
			else:
				velocity.y = JUMP_VELOCITY * 0.85
			air_jumps -= 1
		elif is_on_floor():
			velocity.y = JUMP_VELOCITY

	# Movement Input
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Dash input
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		var dash_dir = direction
		# No movement dash
		if dash_dir == Vector3.ZERO:
			dash_dir = - transform.basis.z.normalized()
			dash_velocity = dash_dir * DASH_SPEED * 0.8
		else:
			dash_velocity = dash_dir * DASH_SPEED
		dash_timer = DASH_TIME

	# Apply dash if active
	if dash_timer > 0.0 and dash_timer >= (DASH_TIME/1.5):
		dash_timer -= delta
		velocity.x = dash_velocity.x
		velocity.z = dash_velocity.z
	else:
		dash_timer = 0
		# Regular movement
		if direction or is_on_floor():
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		elif not is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	# Smooth camera tilt based on left-right input direction and velocity magnitude
	camera_tilt = clamp(-input_dir.x * velocity.length() * 0.005, -0.3, 0.3)
	Cam.rotation.z = Cam.rotation.z + (camera_tilt - Cam.rotation.z) * 0.05

	# Adjust FOV based on forward/backward input direction and velocity magnitude
	camera_fov = 90 + clamp(input_dir.y * velocity.length() * 0.2, -20, 20)  # Base FOV is 90, adjust by max ±20
	Cam.fov = Cam.fov + (camera_fov - Cam.fov) * 0.1  # Smooth transition to target FOV

	move_and_slide()

func _input(event):
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / mouse_sens
		Cam.rotation.x -= event.relative.y / mouse_sens
		Cam.rotation.x = clamp(Cam.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		mouse_relative_x = clamp(event.relative.x, -50, 50)
		mouse_relative_y = clamp(event.relative.y, -50, 10)
