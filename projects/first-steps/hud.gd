extends CanvasLayer

## The HUD listens — it never polls. Every value arrives as a signal from the player
## or the targeted wolf, and nothing outside this script knows the HUD exists. That
## inversion is the win: delete this scene and the game still runs (Forge F3, L35).

@onready var health_bar = $UnitFrame/HealthBar
@onready var rage_bar = $UnitFrame/RageBar
@onready var name_label = $UnitFrame/NameLabel
@onready var target_frame = $TargetFrame
@onready var target_name = $TargetFrame/TargetName
@onready var target_bar = $TargetFrame/TargetHealthBar
@onready var banner = $Banner
@onready var hurt_flash = $HurtFlash
@onready var death_dim = $DeathScreen
@onready var death_label = $DeathScreen/DeathLabel
@onready var hint_strip = $HintStrip
@onready var hints = {
	"move": $HintStrip/HintMove,
	"target": $HintStrip/HintTarget,
	"attack": $HintStrip/HintAttack,
}

var _hints_done = {}
var _banner_tween: Tween
var _pulse_tween: Tween
var _low = false
var _target = null

func _ready():
	# The player adds itself to its group in _ready; defer so the whole tree exists.
	_connect_player.call_deferred()

func _connect_player():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	name_label.text = "Will  Lv %d" % player.level
	# Seed the bars from current state — one read at connect time, not a per-frame poll.
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	rage_bar.max_value = player.max_rage
	rage_bar.value = player.rage
	player.health_changed.connect(_on_player_health)
	player.rage_changed.connect(_on_player_rage)
	player.hurt.connect(flash_hurt)
	player.died.connect(show_death_screen)
	player.target_changed.connect(_on_target_changed)
	player.banner_requested.connect(show_banner)
	player.moved.connect(_complete_hint.bind("move"))
	player.attack_started.connect(_complete_hint.bind("attack"))

# --- Player frame ---------------------------------------------------------
func _on_player_health(health, max_health):
	health_bar.max_value = max_health
	var t = create_tween()
	t.tween_property(health_bar, "value", health, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_set_low_health(health > 0 and health <= max_health * 0.35)

func _on_player_rage(rage, max_rage):
	rage_bar.max_value = max_rage
	rage_bar.value = rage

# --- Target frame: follow whichever wolf the player has targeted ----------
func _on_target_changed(t):
	if is_instance_valid(_target):
		if _target.health_changed.is_connected(_on_target_health):
			_target.health_changed.disconnect(_on_target_health)
		if _target.died.is_connected(_on_target_died):
			_target.died.disconnect(_on_target_died)
	_target = t
	if is_instance_valid(t) and not t.dying:
		target_frame.visible = true
		target_name.text = "Wolf  Lv %d" % t.level
		target_bar.max_value = t.max_health
		target_bar.value = t.health
		t.health_changed.connect(_on_target_health)
		t.died.connect(_on_target_died)
		_complete_hint("target")
	else:
		target_frame.visible = false

func _on_target_health(health, max_health):
	target_bar.max_value = max_health
	var t = create_tween()
	t.tween_property(target_bar, "value", health, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_target_died():
	target_frame.visible = false
	_target = null

# --- Low-health heartbeat: a looping tween that yields to the hit-flash ----
func _set_low_health(on):
	if on == _low:
		return
	_low = on
	if _low:
		_start_pulse()
	elif _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
		hurt_flash.color.a = 0.0

func _start_pulse():
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(hurt_flash, "color:a", 0.12, 0.5).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(hurt_flash, "color:a", 0.03, 0.5).set_trans(Tween.TRANS_SINE)

# --- Tutorial hint chips: each dims once its action fires (now via signal) -
func _complete_hint(key):
	if _hints_done.has(key):
		return
	_hints_done[key] = true
	var t = create_tween()
	t.tween_property(hints[key], "modulate:a", 0.3, 0.5)
	if _hints_done.size() == hints.size():
		var f = create_tween()
		f.tween_interval(2.0)
		f.tween_property(hint_strip, "modulate:a", 0.0, 1.2)

# --- Toasts & flashes the player asks for ---------------------------------
func show_banner(text):
	if _banner_tween:
		_banner_tween.kill()
	banner.text = text
	banner.visible = true
	banner.modulate.a = 0.0
	banner.position.y = 96
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	_banner_tween.parallel().tween_property(banner, "position:y", 84.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(2.2)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(func(): banner.visible = false)

func flash_hurt():
	# Pause the heartbeat so the two never fight over hurt_flash, then resume if still low.
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	var t = create_tween()
	t.tween_property(hurt_flash, "color:a", 0.22, 0.05)
	t.tween_property(hurt_flash, "color:a", 0.0, 0.4)
	if _low:
		t.tween_callback(_start_pulse)

func show_death_screen():
	death_dim.visible = true
	var t = create_tween()
	t.tween_property(death_dim, "color:a", 0.82, 1.1)
	t.parallel().tween_property(death_label, "modulate:a", 1.0, 1.4)
	t.parallel().tween_property(death_label, "position:y", death_label.position.y - 10, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
