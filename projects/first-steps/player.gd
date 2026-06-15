extends CharacterBody2D

@export var speed = 200
@export var max_health = 30
@export var level = 1
@export var attack_damage = 4
@export var attack_range = 60.0
@export var weapon_speed = 2.0
@export var base_crit = 5.0
@export var max_rage = 100
@export var rage_decay = 1.0      # rage per second out of combat

var rage = 0.0
var health = max_health
var target = null
var has_sword = false
var facing = "down"
var no_weapon_cooldown = 0.0
var dying = false

@onready var anim = $AnimatedSprite2D
@onready var health_bar = get_node("../../HUD/UnitFrame/HealthBar")
@onready var swing_timer = $SwingTimer
@onready var sword = $Sword
@onready var rage_bar = get_node("../../HUD/UnitFrame/RageBar")
@onready var slash_arc = $SlashArc
@onready var foot_dust = $FootDust
@onready var camera = $Camera2D
@onready var hud = get_node("../../HUD")

const DAMAGE_NUMBER = preload("res://damage_number.tscn")
const SPARK = preload("res://assets/spark.png")
const SWORD_REST_DEGREES = 0.0   # 25-degree rest pose is baked into sword_held.png
# The swing is pre-rotated in the art pipeline too — four frames from rest to
# full extension. Stepping textures keeps every texel on the pixel grid.
const SWING_FRAMES = [
	preload("res://assets/sword_held.png"),
	preload("res://assets/sword_swing_1.png"),
	preload("res://assets/sword_swing_2.png"),
	preload("res://assets/sword_swing_3.png"),
]
var _swing_tween: Tween

func _ready():
	add_to_group("player")            # so any wolf can find us
	swing_timer.wait_time = weapon_speed
	health_bar.max_value = max_health
	health_bar.value = health
	rage_bar.max_value = max_rage
	rage_bar.value = rage
	sword.rotation_degrees = SWORD_REST_DEGREES

func _physics_process(delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	update_animation(direction)
	foot_dust.emitting = direction != Vector2.ZERO
	no_weapon_cooldown = maxf(no_weapon_cooldown - delta, 0.0)
	if Input.is_action_just_pressed("target_next"):
		target_nearest_wolf()
	if Input.is_action_just_pressed("attack"):
		start_auto_attack()
	if swing_timer.is_stopped() and rage > 0:
		add_rage(-rage_decay * delta)   # out of combat -> drain

	# Abilities go here later, e.g.:
	# if Input.is_action_just_pressed("ability_1"): cast_fireball()

func target_nearest_wolf():
	var best = null
	var best_dist = INF
	for w in get_tree().get_nodes_in_group("wolves"):
		if w == target:
			continue
		var d = global_position.distance_to(w.global_position)
		if d < best_dist:
			best_dist = d
			best = w
	if best:
		set_target(best)

func set_target(new_target):
	if is_instance_valid(target):
		target.set_targeted(false)   # un-highlight the old one
	target = new_target
	target.set_targeted(true)        # highlight the new one
	Sfx.play("ping", -8.0)

func equip_sword():
	has_sword = true
	sword.visible = true
	sword.rotation_degrees = SWORD_REST_DEGREES
	update_sword_pose()

func start_auto_attack():
	if not has_sword:
		if no_weapon_cooldown == 0.0:
			no_weapon_cooldown = 2.5
			spawn_text_over(self, "No weapon!", Color.GRAY)
			hud.show_banner("Find the sword — follow the road north!")
		return
	if is_instance_valid(target) and swing_timer.is_stopped():
		swing()                 # immediate first hit
		swing_timer.start()     # then keep swinging on the tick

func _on_swing_timer_timeout():
	swing()

func swing_sword():
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
	var s = create_tween()
	s.tween_property(slash_arc, "scale", Vector2(1.1, 1.1), 0.1)
	s.parallel().tween_property(slash_arc, "modulate:a", 0.0, 0.16)
	s.tween_callback(func(): slash_arc.visible = false)

func _set_swing_frame(i: float):
	sword.texture = SWING_FRAMES[clampi(roundi(i), 0, SWING_FRAMES.size() - 1)]

func swing():
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
func lunge_toward(point: Vector2):
	var dir = (point - global_position).normalized()
	var t = create_tween()
	t.tween_property(anim, "position", dir * 5.0, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(anim, "position", Vector2.ZERO, 0.14)

# Turn the standing pose toward a point (movement animation wins while walking).
func face_toward(point: Vector2):
	var d = point - global_position
	if abs(d.x) > abs(d.y):
		facing = "right" if d.x > 0 else "left"
	else:
		facing = "down" if d.y > 0 else "up"
	if velocity == Vector2.ZERO:
		anim.animation = "walk_" + facing
		anim.stop()
		anim.frame = 0
	update_sword_pose()

func attack(t):
	var roll = randf() * 100.0
	var miss = miss_chance(t)
	var dodge = dodge_chance(t)
	var parry = parry_chance(t)
	var glancing = glancing_chance(t)
	var crit = crit_chance(t)
	if roll < miss:
		spawn_text_over(t, "Miss", Color.GRAY)
		Sfx.play("miss", -8.0)
	elif roll < miss + dodge:
		spawn_text_over(t, "Dodge", Color.CYAN)
		Sfx.play("miss", -8.0)
	elif roll < miss + dodge + parry:
		spawn_text_over(t, "Parry", Color.ORANGE)
		Sfx.play("miss", -6.0)
	elif roll < miss + dodge + parry + glancing:
		spawn_text_over(t, "Glancing", Color.GRAY)
		var dmg = roundi(glancing_damage(t))
		t.take_damage(dmg)
		gain_rage_dealing(dmg, false)
		Sfx.play("hit", -6.0)
	elif roll < miss + dodge + parry + glancing + crit:
		var dmg = attack_damage * 2
		t.take_damage(dmg, true)
		gain_rage_dealing(dmg, true)
		spawn_sparks(t.global_position, Color(1.0, 0.85, 0.3), 10)
		shake_camera(4.0)
		Sfx.play("crit", -2.0)
		hit_stop()
	else:
		t.take_damage(attack_damage)
		gain_rage_dealing(attack_damage, false)
		spawn_sparks(t.global_position, Color(1, 1, 1), 5)
		Sfx.play("hit", -4.0)

# A heartbeat of frozen time sells the crit.
func hit_stop():
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0

func spawn_text_over(t, s, color):
	var n = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(n)
	n.global_position = t.global_position + Vector2(-8, -30)
	n.show_text(s, color)

func take_damage(amount, from = null):
	if dying:
		return
	health -= amount
	if health < 0: health = 0
	var bt = create_tween()
	bt.tween_property(health_bar, "value", health, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("hurt", -4.0)
	hud.flash_hurt()
	spawn_number(amount, Color(1.0, 0.36, 0.22))   # hot red-orange — reads on dirt and grass alike
	gain_rage_taking(amount)      # getting hit builds rage too
	if is_instance_valid(from):       # hit by an enemy -> engage it
		if not is_instance_valid(target):
			set_target(from)          # no target = retaliate attacker
		if swing_timer.is_stopped():
			swing_timer.start()
	if health == 0:
		die()

# --- Attack table: outcome chances (one roll, walked in attack()) ---
func crit_chance(t):
	var c = base_crit - (t.level - level)   # -1% per level the target is above you
	return max(c, 0.0)                       # never below 0

func dodge_chance(t):
	var gap = max(t.level - level, 0)
	return 5.0 + gap * 0.5        # +0.5% per level above you

func parry_chance(t):
	var gap = max(t.level - level, 0)
	return 5.0 + gap * 3.0        # scales hard: +3 = 14% (front only)

func miss_chance(t):
	var delta = (t.level - level) * 5    # target defense skill − your weapon skill
	return 5.0 + delta * 0.1            # exact for our level range (gap ≤ 2)

func glancing_chance(t):
	var gap = t.level - level
	if gap <= 0:
		return 0.0                     # no glancing vs equal/lower level
	return 10.0 + gap * 10.0          # +1 = 20%, +2 = 30%

func glancing_damage(t):
	var skill_diff = (t.level - level) * 5
	var low = clampf(1.3 - 0.05 * skill_diff, 0.01, 0.91)
	var high = clampf(1.2 - 0.03 * skill_diff, 0.2, 0.99)
	return attack_damage * randf_range(low, high)

# --- Rage ---
func conversion_value():
	return 0.0091107836 * level * level + 3.225598133 * level + 4.2652911

func add_rage(amount):
	rage = clampf(rage + amount, 0, max_rage)
	rage_bar.value = rage

func gain_rage_dealing(damage, is_crit):
	var f = 7.0 if is_crit else 3.5
	add_rage(7.5 * damage / conversion_value() + f * weapon_speed / 2.0)

func gain_rage_taking(damage):
	add_rage(2.5 * damage / conversion_value())

func spawn_sparks(at: Vector2, color: Color, count: int):
	var p = CPUParticles2D.new()
	p.texture = SPARK
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.35
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color = color
	p.z_index = 30
	get_parent().add_child(p)
	p.global_position = at + Vector2(0, -10)
	p.emitting = true
	p.finished.connect(p.queue_free)

func shake_camera(strength: float):
	var t = create_tween()
	for i in 4:
		var off = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		t.tween_property(camera, "offset", off, 0.04)
	t.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func spawn_number(amount, color):
	var n = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(n)
	n.global_position = global_position + Vector2(-8, -30)
	n.setup(amount, color)

func die():
	dying = true
	set_physics_process(false)
	foot_dust.emitting = false
	swing_timer.stop()
	Sfx.play("death")
	hud.show_death_screen()
	var t = create_tween()
	t.tween_property(anim, "modulate:a", 0.0, 0.9)
	t.parallel().tween_property(sword, "modulate:a", 0.0, 0.9)
	get_tree().create_timer(2.4).timeout.connect(get_tree().reload_current_scene)

func update_animation(direction):
	if direction == Vector2.ZERO:
		anim.stop()
		anim.frame = 0   # settle on the standing pose, not mid-stride
		return
	if abs(direction.x) > abs(direction.y):
		facing = "right" if direction.x > 0 else "left"
	else:
		facing = "down" if direction.y > 0 else "up"
	anim.play("walk_" + facing)
	update_sword_pose()

# The held sword follows the hand: right side when facing right/down,
# mirrored to the left hand when facing left, tucked behind the body
# when facing away.
func update_sword_pose():
	if not has_sword:
		return
	match facing:
		"right":
			sword.position = Vector2(10, 2)
			sword.flip_h = false
			sword.show_behind_parent = false
		"left":
			sword.position = Vector2(-10, 2)
			sword.flip_h = true
			sword.show_behind_parent = false
		"down":
			sword.position = Vector2(9, 3)
			sword.flip_h = false
			sword.show_behind_parent = false
		"up":
			sword.position = Vector2(-9, 0)
			sword.flip_h = true
			sword.show_behind_parent = true
