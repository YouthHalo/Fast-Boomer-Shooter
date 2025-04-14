extends CharacterBody3D

#@onready var gunRay = $Head/Camera3d/RayCast3d as RayCast3D
@onready var Cam = $Camera3D as Camera3D
var mouse_sens = 600
var mouse_relative_x = 0
var mouse_relative_y = 0

const SPEED = 12.0
const JUMP_VELOCITY = 9
@export var max_air_jumps = 1
var air_jumps = 1


# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

func _ready():
	#Captures mouse and stops rgun from hitting yourself
	#gunRay.add_exception(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif is_on_floor() and air_jumps < max_air_jumps:
		air_jumps = 2

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and air_jumps > 0:
		if not is_on_floor():
			velocity.y = JUMP_VELOCITY * 0.8
			air_jumps -= 1
		elif is_on_floor():
			velocity.y = JUMP_VELOCITY
		
	# Handle Shooting
	#if Input.is_action_just_pressed("Shoot"):
	#	shoot()
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if input_dir.x != 0:
		Cam.rotation.z = Cam.rotation.z + (-input_dir.x * 0.1 - Cam.rotation.z) * 0.1
	else:
		Cam.rotation.z = Cam.rotation.z + (0 - Cam.rotation.z) * 0.1
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _input(event):
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / mouse_sens
		Cam.rotation.x -= event.relative.y / mouse_sens
		Cam.rotation.x = clamp(Cam.rotation.x, deg_to_rad(-90), deg_to_rad(90) )
		mouse_relative_x = clamp(event.relative.x, -50, 50)
		mouse_relative_y = clamp(event.relative.y, -50, 10)


"""
func shoot():
	if not gunRay.is_colliding():
		return
	var bulletInst = _bullet_scene.instantiate() as Node3D
	bulletInst.set_as_top_level(true)
	get_parent().add_child(bulletInst)
	bulletInst.global_transform.origin = gunRay.get_collision_point() as Vector3
	bulletInst.look_at((gunRay.get_collision_point()+gunRay.get_collision_normal()),Vector3.BACK)
	print(gunRay.get_collision_point())
	print(gunRay.get_collision_point()+gunRay.get_collision_normal())
"""
