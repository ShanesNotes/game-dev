extends CharacterBody2D

@export var speed = 120
@export var melee_range = 40.0
@export var swing_damage = 2
@export var max_health = 12
@export var level = 1

var health = max_health

@onready var sprite = $Sprite2D
@onready var swing_timer = $SwingTimer
@onready var health_bar = $HealthBar
@onready var level_label = $LevelLabel

var target = null
var spawn = Vector2.ZERO

const DAMAGE_NUMBER = preload("res://damage_number.tscn")

func _ready():
	spawn = global_position
	health_bar.max_value = max_health
	health_bar.value = health
	level_label.text = "Lv" + str(level)

func _physics_process(_delta):
	if target != null:
		if global_position.distance_to(target.global_position) > melee_range:
			velocity = (target.global_position - global_position).normalized() * speed
		else:
			velocity = Vector2.ZERO
	else:
		if global_position.distance_to(spawn) > 4.0:
			velocity = (spawn - global_position).normalized() * speed
		else:
			velocity = Vector2.ZERO
	move_and_slide()
	face_target()

func take_damage(amount, is_crit = false):
	health -= amount
	if health < 0: health = 0
	health_bar.value = health
	if is_crit:
		spawn_number(amount, Color.YELLOW, 28)   # loud
	else:
		spawn_number(amount, Color.WHITE, 18)
	if health == 0:
		queue_free()

func spawn_number(amount, color, size = 18):
	var n = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(n)
	n.global_position = global_position + Vector2(-8, -30)
	n.show_text(str(amount), color, size)

func _on_aggro_area_body_entered(body):
	if body.is_in_group("player"):
		target = body
		swing_timer.start()

func _on_aggro_area_body_exited(body):
	if body.is_in_group("player"):
		target = null
		swing_timer.stop()

func _on_swing_timer_timeout():
	if target != null and global_position.distance_to(target.global_position) <= melee_range + 16:
		target.take_damage(swing_damage, self)   # pass self as the attacker

func face_target():
	var face_x = velocity.x
	if target != null:
		face_x = target.global_position.x - global_position.x
	if face_x != 0:
		sprite.flip_h = face_x < 0

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().get_first_node_in_group("player").set_target(self)

func set_targeted(on):
	sprite.modulate = Color(1, 0.85, 0.4) if on else Color.WHITE
