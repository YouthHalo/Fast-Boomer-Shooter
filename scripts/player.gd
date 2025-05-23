extends CharacterBody3D

@onready var Cam = $Camera3D as Camera3D
var mouse_sens = 600
var mouse_relative_x = 0
var mouse_relative_y = 0

const SPEED = 12.0
const JUMP_VELOCITY = 9
@export var max_air_jumps = 1
var air_jumps = max_air_jumps

const DASH_SPEED = 50.0
const DASH_TIME = 0.6
var dash_timer = 0.0
var dash_velocity = Vector3.ZERO

var touching_wall = false

const MAX_WALK_SPEED = 12
const MAX_TOTAL_SPEED = 50
const MAX_MOMENTUM_SPEED = 22
const ACCEL = 50.0
const AIR_ACCEL = 2.0
const FRICTION = 50.0

var camera_tilt = 0.0
var camera_fov = 90.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / mouse_sens
		Cam.rotation.x -= event.relative.y / mouse_sens
		Cam.rotation.x = clamp(Cam.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		mouse_relative_x = clamp(event.relative.x, -50, 50)
		mouse_relative_y = clamp(event.relative.y, -50, 10)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif air_jumps < max_air_jumps:
		air_jumps = max_air_jumps

	if not is_on_floor() and is_on_wall() and not touching_wall:
		touching_wall = true
		air_jumps += 1
	elif not is_on_floor() and not is_on_wall() and touching_wall:
		touching_wall = false
		if air_jumps > 0:
			air_jumps -= 1

	if position.y < -30:
		position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO

	if Input.is_action_just_pressed("jump") and air_jumps > 0:
		if not is_on_floor():
			if touching_wall:
				var wall_normal = get_wall_normal()
				velocity = wall_normal * JUMP_VELOCITY * 2
			velocity.y = JUMP_VELOCITY * 0.85
			air_jumps -= 1
		elif is_on_floor():
			velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		var dash_dir = direction
		if dash_dir == Vector3.ZERO:
			dash_dir = -transform.basis.z.normalized()
			dash_velocity = dash_dir * DASH_SPEED * 0.8
		else:
			if velocity.normalized().dot(dash_dir) < 0.9:
				velocity = Vector3.ZERO
			dash_velocity = dash_dir * DASH_SPEED
		dash_timer = DASH_TIME

	if dash_timer > 0.0 and dash_timer >= (DASH_TIME / 1.5):
		dash_timer -= delta
		velocity.x = dash_velocity.x
		velocity.z = dash_velocity.z
	else:
		dash_timer = 0

		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		if direction.length() > 0:
			var accel = ACCEL if is_on_floor() else AIR_ACCEL
			velocity += direction * accel * delta

			if is_on_floor() and horizontal_velocity.length() > SPEED:
				velocity.x = move_toward(velocity.x, direction.x * SPEED, FRICTION * delta)
				velocity.z = move_toward(velocity.z, direction.z * SPEED, FRICTION * delta)
		else:
			if is_on_floor():
				var speed = horizontal_velocity.length()
				if speed > 0:
					var slow_factor = 1.0
					print("normal slowdown")
					if speed > MAX_MOMENTUM_SPEED:
						slow_factor = 2.5
						print("fast slowdown")
					elif speed > SPEED:
						slow_factor = 2 + ((speed - SPEED) / (MAX_MOMENTUM_SPEED - SPEED)) * 1.5
						print("slow slowdown")
					velocity.x = move_toward(velocity.x, 0, FRICTION * slow_factor * delta)
					velocity.z = move_toward(velocity.z, 0, FRICTION * slow_factor * delta)

	var hvel = Vector3(velocity.x, 0, velocity.z)
	if hvel.length() > MAX_TOTAL_SPEED:
		hvel = hvel.normalized() * MAX_TOTAL_SPEED
		velocity.x = hvel.x
		velocity.z = hvel.z

	camera_tilt = clamp(-input_dir.x * velocity.length() * 0.005, -0.3, 0.3)
	Cam.rotation.z += (camera_tilt - Cam.rotation.z) * 0.05

	camera_fov = 90 + clamp(input_dir.y * velocity.length() * -0.2, -20, 20)
	Cam.fov += (camera_fov - Cam.fov) * 0.1
	move_and_slide()
