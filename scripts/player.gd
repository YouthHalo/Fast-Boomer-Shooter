extends CharacterBody3D

@onready var Cam = $Camera3D as Camera3D
var mouse_sens = 600
var mouse_relative_x = 0
var mouse_relative_y = 0

const SPEED = 12.0
const JUMP_VELOCITY = 9
@export var max_air_jumps = 1
var air_jumps = 1

const DASH_SPEED = 60.0
const DASH_TIME = 0.15
var dash_timer = 0.0
var dash_velocity = Vector3.ZERO

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif is_on_floor() and air_jumps < max_air_jumps:
		air_jumps = 2

	# Handle Jump
	if Input.is_action_just_pressed("jump") and air_jumps > 0:
		if not is_on_floor():
			velocity.y = JUMP_VELOCITY * 0.8
			air_jumps -= 1
		elif is_on_floor():
			velocity.y = JUMP_VELOCITY

	# Movement Input
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Dash input
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		var dash_dir = direction
		if dash_dir == Vector3.ZERO:
			dash_dir = -transform.basis.z.normalized()
		dash_velocity = dash_dir * DASH_SPEED
		dash_timer = DASH_TIME

	# Apply dash if active
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity.x = dash_velocity.x
		velocity.z = dash_velocity.z
	else:
		# Regular movement
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	# Smooth camera tilt
	if input_dir.x != 0:
		Cam.rotation.z = Cam.rotation.z + (-input_dir.x * 0.1 - Cam.rotation.z) * 0.1
	else:
		Cam.rotation.z = Cam.rotation.z + (0 - Cam.rotation.z) * 0.1

	move_and_slide()

func _input(event):
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / mouse_sens
		Cam.rotation.x -= event.relative.y / mouse_sens
		Cam.rotation.x = clamp(Cam.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		mouse_relative_x = clamp(event.relative.x, -50, 50)
		mouse_relative_y = clamp(event.relative.y, -50, 10)
