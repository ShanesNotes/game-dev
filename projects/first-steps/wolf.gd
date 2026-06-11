extends CharacterBody2D

@export var speed = 120
@export var melee_range = 40.0
@export var swing_damage = 2
@export var max_health = 12
@export var level = 1

var health = max_health

@onready var sprite = $AnimatedSprite2D
@onready var swing_timer = $SwingTimer
@onready var health_bar = $HealthBar
@onready var aggro_mark = $AggroMark
@onready var target_ring = $TargetRing

const BLOOD = preload("res://assets/soft_dot.png")

var dying = false

var target = null
var spawn = Vector2.ZERO

const DAMAGE_NUMBER = preload("res://damage_number.tscn")

func _ready():
	add_to_group("wolves")
	spawn = global_position
	health_bar.max_value = max_health
	health_bar.value = health

func _physics_process(_delta):
	if dying:
		return
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
	if sprite.animation != "attack" or not sprite.is_playing():
		sprite.play("walk" if velocity.length() > 4.0 else "idle")

func take_damage(amount, is_crit = false):
	if dying:
		return
	health -= amount
	if health < 0: health = 0
	health_bar.value = health
	if is_crit:
		spawn_number(amount, Color.YELLOW, 28)   # loud
	else:
		spawn_number(amount, Color.WHITE, 18)
	flash_hit()
	spawn_blood()
	if health == 0:
		die()

func flash_hit():
	sprite.modulate = Color(1, 0.35, 0.35)
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.18)

func spawn_blood():
	var p = CPUParticles2D.new()
	p.texture = BLOOD
	p.amount = 6
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.4
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	p.color = Color(0.72, 0.13, 0.1)
	p.z_index = 30
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, -8)
	p.emitting = true
	p.finished.connect(p.queue_free)

func die():
	dying = true
	$CollisionShape2D.set_deferred("disabled", true)
	health_bar.visible = false
	aggro_mark.visible = false
	target_ring.visible = false
	var t = create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.3), 0.35)
	t.parallel().tween_property(sprite, "position:y", 8.0, 0.35)
	t.tween_callback(queue_free)

func spawn_number(amount, color, size = 18):
	var n = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(n)
	n.global_position = global_position + Vector2(-8, -30)
	n.show_text(str(amount), color, size)

func _on_aggro_area_body_entered(body):
	if body.is_in_group("player") and not dying:
		target = body
		swing_timer.start()
		aggro_mark.visible = true
		aggro_mark.scale = Vector2(0.3, 0.3)
		var t = create_tween()
		t.tween_property(aggro_mark, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.8)
		t.tween_property(aggro_mark, "modulate:a", 0.0, 0.2)
		t.tween_callback(_hide_aggro_mark)

func _hide_aggro_mark():
	aggro_mark.visible = false
	aggro_mark.modulate.a = 1.0

func _on_aggro_area_body_exited(body):
	if body.is_in_group("player"):
		target = null
		swing_timer.stop()

func _on_swing_timer_timeout():
	if target != null and global_position.distance_to(target.global_position) <= melee_range + 16:
		sprite.play("attack")
		target.take_damage(swing_damage, self)   # pass self as the attacker

func face_target():
	var face_x = velocity.x
	if target != null:
		face_x = target.global_position.x - global_position.x
	if face_x != 0:
		sprite.flip_h = face_x > 0   # art faces left; flip to face right

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().get_first_node_in_group("player").set_target(self)

func set_targeted(on):
	target_ring.visible = on
