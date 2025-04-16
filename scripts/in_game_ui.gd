extends Control
@onready var fps_label = $RichTextLabel
@onready var player = $".."

func _process(_delta):
	if player and player.has_method("get_velocity"):
		fps_label.text = "FPS: %d VEL: %s" % [Engine.get_frames_per_second(), str(player.get_velocity())]
	else:
		fps_label.text = "FPS: %d VEL: N/A" % Engine.get_frames_per_second()
