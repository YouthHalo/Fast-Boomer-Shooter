extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = get_tree().paused


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause") and not get_tree().paused:
		get_tree().paused = not get_tree().paused
		visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif Input.is_action_just_pressed("pause") and get_tree().paused:
		get_tree().paused = not get_tree().paused
		visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
