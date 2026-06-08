extends CharacterBody2D

@export var speed = 200
@export var max_health = 30
@export var attack_damage = 4
@export var attack_range = 60.0
var health = max_health
var target = null

@onready var anim = $AnimatedSprite2D
@onready var health_bar = get_node("../HUD/HealthBar")
@onready var swing_timer = $SwingTimer

const DAMAGE_NUMBER = preload("res://damage_number.tscn")

func _ready():
	health_bar.max_value = max_health
	health_bar.value = health

func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	update_animation(direction)

	if Input.is_action_just_pressed("attack"):
		start_auto_attack()

	# Abilities go here later, e.g.:
	# if Input.is_action_just_pressed("ability_1"): cast_fireball()

func start_auto_attack():
	if not is_instance_valid(target):
		target = get_node_or_null("../Wolf")   # nearest enemy (one wolf for now)
	if is_instance_valid(target) and swing_timer.is_stopped():
		swing()                 # immediate first hit
		swing_timer.start()     # then keep swinging on the tick

func _on_swing_timer_timeout():
	swing()

func swing():
	if not is_instance_valid(target):     # target dead/gone -> stop
		swing_timer.stop()
		target = null
		return
	if global_position.distance_to(target.global_position) <= attack_range:
		target.take_damage(attack_damage)

func take_damage(amount, from = null):
	health -= amount
	if health < 0: health = 0
	health_bar.value = health
	spawn_number(amount, Color.RED)
	if is_instance_valid(from):       # hit by an enemy -> engage it
		target = from
		if swing_timer.is_stopped():
			swing_timer.start()
	if health == 0:
		die()
		
func spawn_number(amount, color):
	var n = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(n)
	n.global_position = global_position + Vector2(-8, -30)
	n.setup(amount, color)
	
func die():
	print("- Memory Eternal -")
	get_tree().reload_current_scene()

func update_animation(direction):
	if direction == Vector2.ZERO:
		anim.stop()
		return
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0: anim.play("walk_right")
		else: anim.play("walk_left")
	else:
		if direction.y > 0: anim.play("walk_down")
		else: anim.play("walk_up")
