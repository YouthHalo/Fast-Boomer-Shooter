extends Control
@onready var fps_label = $RichTextLabel
@onready var dash_particles = $GPUParticles2D
@onready var player = $".."

func _process(_delta):
	if player and player.has_method("get_velocity"):
		fps_label.text = "FPS: %d VEL: %s" % [Engine.get_frames_per_second(), str(abs(player.velocity.x) + abs(player.velocity.z))]
	else:
		fps_label.text = "FPS: %d VEL: N/A" % Engine.get_frames_per_second()

	if Input.is_action_just_pressed("dash") and player.dash_timer <= 0.0:
		dash_particles.emitting = true
