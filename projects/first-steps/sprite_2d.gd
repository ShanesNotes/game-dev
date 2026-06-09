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

@onready var anim = $AnimatedSprite2D
@onready var health_bar = get_node("../HUD/HealthBar")
@onready var swing_timer = $SwingTimer
@onready var sword = $Sword
@onready var rage_bar = get_node("../HUD/RageBar")

const DAMAGE_NUMBER = preload("res://damage_number.tscn")

func _ready():
	add_to_group("player")            #so any wolf can find us
	swing_timer.wait_time = weapon_speed
	health_bar.max_value = max_health
	health_bar.value = health
	rage_bar.max_value = max_rage
	rage_bar.value = rage

func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	update_animation(direction)
	if Input.is_action_just_pressed("attack"):
		start_auto_attack()
	if swing_timer.is_stopped() and rage > 0:
		add_rage(-rage_decay * delta)   # out of combat -> drain

	# Abilities go here later, e.g.:
	# if Input.is_action_just_pressed("ability_1"): cast_fireball()
	
func set_target(new_target):
	if is_instance_valid(target):
		target.set_targeted(false)   # un-highlight the old one
	target = new_target
	target.set_targeted(true)        # highlight the new one

func equip_sword():
	sword.visible = true
	
func start_auto_attack():
	if is_instance_valid(target) and swing_timer.is_stopped():
		swing()                 # immediate first hit
		swing_timer.start()     # then keep swinging on the tick

func _on_swing_timer_timeout():
	swing()

func swing_sword():
	var t = create_tween()
	t.tween_property(sword, "rotation_degrees", -40, 0.08)   # slash across
	t.tween_property(sword, "rotation_degrees", 35, 0.12)    # back to rest
	
func swing():
	if not is_instance_valid(target):
		swing_timer.stop()
		target = null
		return
	swing_sword()
	if global_position.distance_to(target.global_position) <= attack_range:
		attack(target)        # in range -> roll the table

func attack(t):
	var roll = randf() * 100.0
	var miss = miss_chance(t)
	var dodge = dodge_chance(t)
	var parry = parry_chance(t)
	var glancing = glancing_chance(t)
	var crit = crit_chance(t)
	if roll < miss:
		spawn_text_over(t, "Miss", Color.GRAY)
	elif roll < miss + dodge:
		spawn_text_over(t, "Dodge", Color.CYAN)
	elif roll < miss + dodge + parry:
		spawn_text_over(t, "Parry", Color.ORANGE)
	elif roll < miss + dodge + parry + glancing:
		spawn_text_over(t, "Glancing", Color.GRAY)
		var dmg = roundi(glancing_damage(t))
		t.take_damage(dmg)
		gain_rage_dealing(dmg, false)
	elif roll < miss + dodge + parry + glancing + crit:
		var dmg = attack_damage * 2
		t.take_damage(dmg, true)
		gain_rage_dealing(dmg, true)
	else:
		t.take_damage(attack_damage)
		gain_rage_dealing(attack_damage, false)
		
func spawn_text_over(t, s, color):
	var n = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(n)
	n.global_position = t.global_position + Vector2(-8, -30)
	n.show_text(s, color)
		
func take_damage(amount, from = null):
	health -= amount
	if health < 0: health = 0
	health_bar.value = health
	spawn_number(amount, Color.RED)
	gain_rage_taking(amount)      # getting hit builds rage too
	if is_instance_valid(from):       # hit by an enemy -> engage it
		if not is_instance_valid(target):
			set_target(from)          #no target = retaliate attacker
		if swing_timer.is_stopped():
			swing_timer.start()        
	if health == 0:
		die()
		
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
