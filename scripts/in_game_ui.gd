extends Control
@onready var fps_label = $RichTextLabel

func _process(_delta):
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
