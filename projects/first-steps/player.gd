extends CharacterBody2D

# The player announces; the HUD listens. The player holds NO reference to the HUD,
# so the HUD scene can be deleted and the game still runs (Forge F3, L35).
signal health_changed(health: int, max_health: int)
signal rage_changed(rage: float, max_rage: int)
signal hurt
signal died
signal target_changed(target: Node2D)
signal banner_requested(text: String)
signal moved
signal attack_started

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_UP: StringName = &"move_up"
const ACTION_MOVE_DOWN: StringName = &"move_down"
const ACTION_TARGET_NEXT: StringName = &"target_next"
const ACTION_ATTACK: StringName = &"attack"

const FACING_RIGHT: String = "right"
const FACING_LEFT: String = "left"
const FACING_DOWN: String = "down"
const FACING_UP: String = "up"
const ANIM_WALK_RIGHT: StringName = &"walk_right"
const ANIM_WALK_LEFT: StringName = &"walk_left"
const ANIM_WALK_DOWN: StringName = &"walk_down"
const ANIM_WALK_UP: StringName = &"walk_up"

const SWORD_REST_DEGREES: float = 0.0   # 25-degree rest pose is baked into sword_held.png
# The swing is pre-rotated in the art pipeline too — four frames from rest to
# full extension. Stepping textures keeps every texel on the pixel grid.
const SWING_FRAMES: Array[Texture2D] = [
	preload("res://assets/sword_held.png"),
	preload("res://assets/sword_swing_1.png"),
	preload("res://assets/sword_swing_2.png"),
	preload("res://assets/sword_swing_3.png"),
]

@export var speed: float = 200.0
@export var max_health: int = 30
@export var level: int = 1
@export var attack_damage: int = 4
@export var attack_range: float = 60.0
@export var weapon_speed: float = 2.0
@export var base_crit: float = 5.0
@export var max_rage: int = 100
@export var rage_decay: float = 1.0      # rage per second out of combat

var rage: float = 0.0
var health: int = max_health
var target: Node2D = null
var has_sword: bool = false
var facing: String = FACING_DOWN
var no_weapon_cooldown: float = 0.0
var dying: bool = false

var _swing_tween: Tween = null
var _announced_move: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var swing_timer: Timer = $SwingTimer
@onready var sword: Sprite2D = $Sword
@onready var slash_arc: Sprite2D = $SlashArc
@onready var foot_dust: CPUParticles2D = $FootDust
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")            # so any wolf can find us
	swing_timer.wait_time = weapon_speed
	sword.rotation_degrees = SWORD_REST_DEGREES


func _unhandled_input(event: InputEvent) -> void:
	if dying:
		return
	if event.is_action_pressed(ACTION_TARGET_NEXT):
		target_nearest_wolf()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_ATTACK):
		start_auto_attack()
		get_viewport().set_input_as_handled()

	# More one-shot abilities belong here later, e.g.:
	# if event.is_action_pressed(&"ability_1"): cast_fireball()


func _physics_process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector(ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_UP, ACTION_MOVE_DOWN)
	velocity = direction * speed
	move_and_slide()
	update_animation(direction)
	foot_dust.emitting = direction != Vector2.ZERO
	if not _announced_move and direction != Vector2.ZERO:
		_announced_move = true
		moved.emit()
	no_weapon_cooldown = maxf(no_weapon_cooldown - delta, 0.0)
	if swing_timer.is_stopped() and rage > 0.0:
		add_rage(-rage_decay * delta)   # out of combat -> drain


func target_nearest_wolf() -> void:
	var best: Node2D = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group("wolves"):
		if node is not Node2D:
			continue
		var wolf: Node2D = node as Node2D
		if wolf == target or not _is_wolf(wolf):
			continue
		var distance: float = global_position.distance_to(wolf.global_position)
		if distance < best_dist:
			best_dist = distance
			best = wolf
	if best != null:
		set_target(best)


func set_target(new_target: Node2D) -> void:
	if is_instance_valid(target):
		_set_targeted(target, false)   # un-highlight the old one
	target = new_target
	if target == null:
		target_changed.emit(null)
		return
	_set_targeted(target, true)        # highlight the new one
	Sfx.play("ping", -8.0)
	target_changed.emit(target)


# A line for the HUD's banner toast. Anyone (the sword pickup) can ask the player
# to announce something without ever touching the HUD.
func announce(text: String) -> void:
	banner_requested.emit(text)


func equip_sword() -> void:
	has_sword = true
	sword.visible = true
	sword.rotation_degrees = SWORD_REST_DEGREES
	update_sword_pose()


func start_auto_attack() -> void:
	if not has_sword:
		if no_weapon_cooldown == 0.0:
			no_weapon_cooldown = 2.5
			CombatFX.text_over(self, "No weapon!", Color.GRAY)
			banner_requested.emit("Find the sword — follow the road north!")
		return
	if is_instance_valid(target) and swing_timer.is_stopped():
		swing()                 # immediate first hit
		swing_timer.start()     # then keep swinging on the tick
		attack_started.emit()


func _on_swing_timer_timeout() -> void:
	swing()


func swing_sword() -> void:
	# Animate an index, not an angle: each frame is pre-rotated in the art,
	# so the blade stays crisp mid-arc. flip_h mirrors the frames for free
	# when the sword is in the left hand.
	if _swing_tween:
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.tween_method(_set_swing_frame, 0.0, 3.0, 0.08)   # slash out
	_swing_tween.tween_method(_set_swing_frame, 3.0, 0.0, 0.12)   # and settle back to rest
	# white swoosh flashed along the cut, aimed at the target (15° steps keep it crisp)
	if is_instance_valid(target):
		slash_arc.rotation = snappedf((target.global_position - global_position).angle(), TAU / 24.0)
	slash_arc.visible = true
	slash_arc.modulate.a = 0.9
	slash_arc.scale = Vector2(0.6, 0.6)
	var slash_tween: Tween = create_tween()
	slash_tween.tween_property(slash_arc, "scale", Vector2(1.1, 1.1), 0.1)
	slash_tween.parallel().tween_property(slash_arc, "modulate:a", 0.0, 0.16)
	slash_tween.tween_callback(func() -> void: slash_arc.visible = false)


func _set_swing_frame(i: float) -> void:
	sword.texture = SWING_FRAMES[clampi(roundi(i), 0, SWING_FRAMES.size() - 1)]


func swing() -> void:
	if not is_instance_valid(target):
		swing_timer.stop()
		target = null
		sword.texture = SWING_FRAMES[0]   # settle back to the rest pose
		return
	face_toward(target.global_position)
	swing_sword()
	lunge_toward(target.global_position)
	if global_position.distance_to(target.global_position) <= attack_range:
		Sfx.play("swing", -4.0)
		attack(target)        # in range -> roll the table
	else:
		Sfx.play("miss", -10.0)


# Brief body lean into the strike (visual only — the body doesn't move).
func lunge_toward(point: Vector2) -> void:
	var dir: Vector2 = (point - global_position).normalized()
	var lunge_tween: Tween = create_tween()
	lunge_tween.tween_property(anim, "position", dir * 5.0, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lunge_tween.tween_property(anim, "position", Vector2.ZERO, 0.14)


# Turn the standing pose toward a point (movement animation wins while walking).
func face_toward(point: Vector2) -> void:
	var delta_to_point: Vector2 = point - global_position
	if abs(delta_to_point.x) > abs(delta_to_point.y):
		facing = FACING_RIGHT if delta_to_point.x > 0.0 else FACING_LEFT
	else:
		facing = FACING_DOWN if delta_to_point.y > 0.0 else FACING_UP
	if velocity == Vector2.ZERO:
		anim.animation = _facing_animation()
		anim.stop()
		anim.frame = 0
	update_sword_pose()


func attack(t: Node2D) -> void:
	var roll: float = randf() * 100.0
	var target_level: int = _combat_level(t)
	var miss: float = CombatTable.miss_chance(level, target_level)
	var dodge: float = CombatTable.dodge_chance(level, target_level)
	var parry: float = CombatTable.parry_chance(level, target_level)
	var glancing: float = CombatTable.glancing_chance(level, target_level)
	var crit: float = CombatTable.crit_chance(level, target_level, base_crit)
	if roll < miss:
		CombatFX.text_over(t, "Miss", Color.GRAY)
		Sfx.play("miss", -8.0)
	elif roll < miss + dodge:
		CombatFX.text_over(t, "Dodge", Color.CYAN)
		Sfx.play("miss", -8.0)
	elif roll < miss + dodge + parry:
		CombatFX.text_over(t, "Parry", Color.ORANGE)
		Sfx.play("miss", -6.0)
	elif roll < miss + dodge + parry + glancing:
		CombatFX.text_over(t, "Glancing", Color.GRAY)
		var glancing_damage: int = roundi(CombatTable.glancing_damage(attack_damage, level, target_level))
		_apply_target_damage(t, glancing_damage)
		gain_rage_dealing(glancing_damage, false)
		Sfx.play("hit", -6.0)
	elif roll < miss + dodge + parry + glancing + crit:
		var crit_damage: int = attack_damage * 2
		_apply_target_damage(t, crit_damage, true)
		gain_rage_dealing(crit_damage, true)
		CombatFX.sparks(t.global_position, Color(1.0, 0.85, 0.3), 10)
		shake_camera(4.0)
		Sfx.play("crit", -2.0)
		hit_stop()
	else:
		_apply_target_damage(t, attack_damage)
		gain_rage_dealing(attack_damage, false)
		CombatFX.sparks(t.global_position, Color(1, 1, 1), 5)
		Sfx.play("hit", -4.0)


# A heartbeat of frozen time sells the crit.
func hit_stop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0


func take_damage(amount: int, from: Node2D = null) -> void:
	if dying:
		return
	health -= amount
	if health < 0:
		health = 0
	health_changed.emit(health, max_health)
	hurt.emit()
	Sfx.play("hurt", -4.0)
	CombatFX.damage_number(self, amount, Color(1.0, 0.36, 0.22))   # hot red-orange — reads on dirt and grass alike
	gain_rage_taking(amount)      # getting hit builds rage too
	if _is_wolf(from):       # hit by an enemy -> engage it
		if not is_instance_valid(target):
			set_target(from)          # no target = retaliate attacker
		if swing_timer.is_stopped():
			swing_timer.start()
	if health == 0:
		die()


# --- Attack table & rage formulas now live in combat_table.gd (CombatTable) so
# they can be unit-tested headless (see tests/test_combat_table.gd). attack()
# above calls CombatTable.*; the player keeps only what touches node state. ---
func add_rage(amount: float) -> void:
	rage = clampf(rage + amount, 0.0, float(max_rage))
	rage_changed.emit(rage, max_rage)


func gain_rage_dealing(damage: int, is_crit: bool) -> void:
	add_rage(CombatTable.rage_from_dealing(damage, weapon_speed, is_crit, level))


func gain_rage_taking(damage: int) -> void:
	add_rage(CombatTable.rage_from_taking(damage, level))


func shake_camera(strength: float) -> void:
	var camera_tween: Tween = create_tween()
	for _i in 4:
		var offset: Vector2 = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		camera_tween.tween_property(camera, "offset", offset, 0.04)
	camera_tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)


func die() -> void:
	dying = true
	set_physics_process(false)
	foot_dust.emitting = false
	swing_timer.stop()
	Sfx.play("death")
	died.emit()
	var death_tween: Tween = create_tween()
	death_tween.tween_property(anim, "modulate:a", 0.0, 0.9)
	death_tween.parallel().tween_property(sword, "modulate:a", 0.0, 0.9)
	get_tree().create_timer(2.4).timeout.connect(func() -> void: get_tree().reload_current_scene(), CONNECT_ONE_SHOT)


func update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		anim.stop()
		anim.frame = 0   # settle on the standing pose, not mid-stride
		return
	if abs(direction.x) > abs(direction.y):
		facing = FACING_RIGHT if direction.x > 0.0 else FACING_LEFT
	else:
		facing = FACING_DOWN if direction.y > 0.0 else FACING_UP
	anim.play(_facing_animation())
	update_sword_pose()


# The held sword follows the hand: right side when facing right/down,
# mirrored to the left hand when facing left, tucked behind the body
# when facing away.
func update_sword_pose() -> void:
	if not has_sword:
		return
	match facing:
		FACING_RIGHT:
			sword.position = Vector2(10, 2)
			sword.flip_h = false
			sword.show_behind_parent = false
		FACING_LEFT:
			sword.position = Vector2(-10, 2)
			sword.flip_h = true
			sword.show_behind_parent = false
		FACING_DOWN:
			sword.position = Vector2(9, 3)
			sword.flip_h = false
			sword.show_behind_parent = false
		FACING_UP:
			sword.position = Vector2(-9, 0)
			sword.flip_h = true
			sword.show_behind_parent = true


func _is_wolf(node: Node) -> bool:
	return is_instance_valid(node) and node.is_in_group("wolves")


func _combat_level(actor: Node) -> int:
	return int(actor.get("level"))


func _apply_target_damage(actor: Node, amount: int, is_crit: bool = false) -> void:
	if actor.has_method("take_damage"):
		actor.call("take_damage", amount, is_crit)


func _set_targeted(actor: Node, on: bool) -> void:
	if actor.has_method("set_targeted"):
		actor.call("set_targeted", on)


func _facing_animation() -> StringName:
	match facing:
		FACING_RIGHT:
			return ANIM_WALK_RIGHT
		FACING_LEFT:
			return ANIM_WALK_LEFT
		FACING_UP:
			return ANIM_WALK_UP
		_:
			return ANIM_WALK_DOWN
