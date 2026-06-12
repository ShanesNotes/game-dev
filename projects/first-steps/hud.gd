extends CanvasLayer

## Drives the unit frames, banner toasts, hurt/death feedback, and the
## tutorial hint chips (each dims once its action has been performed).

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
var _pulse_t = 0.0

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		name_label.text = "Will  Lv %d" % player.level

func _process(delta):
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_update_target_frame(player)
	_update_low_health_pulse(player, delta)
	_update_hints(player)

func _update_target_frame(player):
	var t = player.target
	if is_instance_valid(t) and not t.dying:
		target_frame.visible = true
		target_name.text = "Wolf  Lv %d" % t.level
		target_bar.max_value = t.max_health
		target_bar.value = lerpf(target_bar.value, t.health, 0.25)
	else:
		target_frame.visible = false

# Soft red heartbeat overlay when health runs low.
func _update_low_health_pulse(player, delta):
	if player.dying:
		return
	if player.health > 0 and player.health <= player.max_health * 0.35:
		_pulse_t += delta * 5.0
		hurt_flash.color.a = maxf(hurt_flash.color.a, 0.06 + 0.05 * sin(_pulse_t))

func _update_hints(player):
	if not _hints_done.has("move") and Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
		_complete_hint("move")
	if not _hints_done.has("target") and is_instance_valid(player.target):
		_complete_hint("target")
	if not _hints_done.has("attack") and player.has_sword and not player.swing_timer.is_stopped():
		_complete_hint("attack")

func _complete_hint(key):
	_hints_done[key] = true
	var t = create_tween()
	t.tween_property(hints[key], "modulate:a", 0.3, 0.5)
	if _hints_done.size() == hints.size():
		var f = create_tween()
		f.tween_interval(2.0)
		f.tween_property(hint_strip, "modulate:a", 0.0, 1.2)

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
	var t = create_tween()
	t.tween_property(hurt_flash, "color:a", 0.22, 0.05)
	t.tween_property(hurt_flash, "color:a", 0.0, 0.4)

func show_death_screen():
	death_dim.visible = true
	var t = create_tween()
	t.tween_property(death_dim, "color:a", 0.82, 1.1)
	t.parallel().tween_property(death_label, "modulate:a", 1.0, 1.4)
	t.parallel().tween_property(death_label, "position:y", death_label.position.y - 10, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
