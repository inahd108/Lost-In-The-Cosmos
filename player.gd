extends CharacterBody2D

## Movement settings (you can tweak these in the Inspector)
@export var speed := 300.00
@export var acceleration := 1500.00
@export var friction := 2200.0
@export var jump_velocity := -600.00
@export var coyote_time := 0.1       # grace period to still jump after walking off a ledge
@export var jump_buffer_time := 0.1  # pressing jump just before landing still counts

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var coyote_timer := 0.0
var jump_buffer_timer := 0.0


func _physics_process(delta: float) -> void:
	# Gravity
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		velocity.y += gravity * delta
		coyote_timer -= delta

	# Remember a jump press for a moment
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Jump
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Let go of jump early for a shorter hop
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.5

	# Left / right
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	update_animation(direction)
	move_and_slide()


func update_animation(direction: float) -> void:
	if direction != 0.0:
		anim.flip_h = direction < 0.0
		anim.play("running_right")
	else:
		anim.play("idle")
