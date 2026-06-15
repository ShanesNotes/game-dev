extends CharacterBody2D

# Announced for the HUD's target frame, so the HUD never has to poll the wolf.
signal health_changed(health: int, max_health: int)
signal died

const GameContracts = preload("res://game_contracts.gd")

@export var speed: float = 120.0
@export var melee_range: float = 40.0
@export var swing_damage: int = 2
@export var max_health: int = 12
@export var level: int = 1

var health: int = max_health
var dying: bool = false
var target: Node2D = null
var spawn: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var swing_timer: Timer = $SwingTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var aggro_mark: Sprite2D = $AggroMark
@onready var target_ring: Sprite2D = $TargetRing
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("wolves")
	spawn = global_position
	health_bar.max_value = max_health
	health_bar.value = health


func _physics_process(_delta: float) -> void:
	if dying:
		return
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) > melee_range:
			velocity = (target.global_position - global_position).normalized() * speed
		else:
			velocity = Vector2.ZERO
	else:
		target = null
		if global_position.distance_to(spawn) > 4.0:
			velocity = (spawn - global_position).normalized() * speed
		else:
			velocity = Vector2.ZERO
	move_and_slide()
	face_target()
	if sprite.animation != &"attack" or not sprite.is_playing():
		sprite.play(&"walk" if velocity.length() > 4.0 else &"idle")


func take_damage(amount: int, is_crit: bool = false) -> void:
	if dying:
		return
	health -= amount
	if health < 0:
		health = 0
	health_changed.emit(health, max_health)
	var bar_tween: Tween = create_tween()
	bar_tween.tween_property(health_bar, "value", health, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_crit:
		CombatFX.damage_number(self, amount, Color.YELLOW, 28)   # loud
	else:
		CombatFX.damage_number(self, amount, Color.WHITE, 18)
	flash_hit()
	CombatFX.blood(global_position)
	if health == 0:
		die()


func flash_hit() -> void:
	sprite.modulate = Color(1, 0.35, 0.35)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)


func die() -> void:
	dying = true
	died.emit()
	Sfx.play_at("yelp", global_position, -2.0)
	collision_shape.set_deferred("disabled", true)
	health_bar.visible = false
	aggro_mark.visible = false
	target_ring.visible = false
	var death_tween: Tween = create_tween()
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	death_tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.3), 0.35)
	death_tween.parallel().tween_property(sprite, "position:y", 8.0, 0.35)
	death_tween.tween_callback(queue_free)


func _on_aggro_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not dying:
		target = body
		swing_timer.start()
		Sfx.play_at("growl", global_position, -3.0)
		aggro_mark.visible = true
		aggro_mark.scale = Vector2(0.3, 0.3)
		var aggro_tween: Tween = create_tween()
		aggro_tween.tween_property(aggro_mark, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		aggro_tween.tween_interval(0.8)
		aggro_tween.tween_property(aggro_mark, "modulate:a", 0.0, 0.2)
		aggro_tween.tween_callback(_hide_aggro_mark)


func _hide_aggro_mark() -> void:
	aggro_mark.visible = false
	aggro_mark.modulate.a = 1.0


func _on_aggro_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = null
		swing_timer.stop()


func _on_swing_timer_timeout() -> void:
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= melee_range + 16.0:
		sprite.play(&"attack")
		Sfx.play_at("bite", global_position, -4.0)
		GameContracts.damage_player(target, swing_damage, self)   # pass self as the attacker


func face_target() -> void:
	var face_x: float = velocity.x
	if is_instance_valid(target):
		face_x = target.global_position.x - global_position.x
	if face_x != 0.0:
		sprite.flip_h = face_x > 0.0   # art faces left; flip to face right


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player: Node = get_tree().get_first_node_in_group("player")
		if player != null:
			GameContracts.set_target(player, self)


func set_targeted(on: bool) -> void:
	target_ring.visible = on
