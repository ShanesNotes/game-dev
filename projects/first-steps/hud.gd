extends CanvasLayer

## The HUD listens — it never polls. Every value arrives as a signal from the player
## or the targeted wolf, and nothing outside this script knows the HUD exists. That
## inversion is the win: delete this scene and the game still runs (Forge F3, L35).

const HINT_MOVE: StringName = &"move"
const HINT_TARGET: StringName = &"target"
const HINT_ATTACK: StringName = &"attack"
const SIGNAL_HEALTH_CHANGED: StringName = &"health_changed"
const SIGNAL_RAGE_CHANGED: StringName = &"rage_changed"
const SIGNAL_HURT: StringName = &"hurt"
const SIGNAL_DIED: StringName = &"died"
const SIGNAL_TARGET_CHANGED: StringName = &"target_changed"
const SIGNAL_BANNER_REQUESTED: StringName = &"banner_requested"
const SIGNAL_MOVED: StringName = &"moved"
const SIGNAL_ATTACK_STARTED: StringName = &"attack_started"

@onready var health_bar: TextureProgressBar = $UnitFrame/HealthBar
@onready var rage_bar: TextureProgressBar = $UnitFrame/RageBar
@onready var name_label: Label = $UnitFrame/NameLabel
@onready var target_frame: NinePatchRect = $TargetFrame
@onready var target_name: Label = $TargetFrame/TargetName
@onready var target_bar: TextureProgressBar = $TargetFrame/TargetHealthBar
@onready var banner: Label = $Banner
@onready var hurt_flash: ColorRect = $HurtFlash
@onready var death_dim: ColorRect = $DeathScreen
@onready var death_label: Label = $DeathScreen/DeathLabel
@onready var hint_strip: ColorRect = $HintStrip
@onready var hints: Dictionary[StringName, Label] = {
	HINT_MOVE: $HintStrip/HintMove as Label,
	HINT_TARGET: $HintStrip/HintTarget as Label,
	HINT_ATTACK: $HintStrip/HintAttack as Label,
}

var _hints_done: Dictionary[StringName, bool] = {}
var _banner_tween: Tween = null
var _pulse_tween: Tween = null
var _low: bool = false
var _target: Node2D = null


func _ready() -> void:
	# The player adds itself to its group in _ready; defer so the whole tree exists.
	_connect_player.call_deferred()


func _connect_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	name_label.text = "Will  Lv %d" % int(player.get("level"))
	# Seed the bars from current state — one read at connect time, not a per-frame poll.
	health_bar.max_value = int(player.get("max_health"))
	health_bar.value = int(player.get("health"))
	rage_bar.max_value = int(player.get("max_rage"))
	rage_bar.value = float(player.get("rage"))
	player.connect(SIGNAL_HEALTH_CHANGED, _on_player_health)
	player.connect(SIGNAL_RAGE_CHANGED, _on_player_rage)
	player.connect(SIGNAL_HURT, flash_hurt)
	player.connect(SIGNAL_DIED, show_death_screen)
	player.connect(SIGNAL_TARGET_CHANGED, _on_target_changed)
	player.connect(SIGNAL_BANNER_REQUESTED, show_banner)
	player.connect(SIGNAL_MOVED, _complete_hint.bind(HINT_MOVE))
	player.connect(SIGNAL_ATTACK_STARTED, _complete_hint.bind(HINT_ATTACK))


# --- Player frame ---------------------------------------------------------
func _on_player_health(health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	var health_tween: Tween = create_tween()
	health_tween.tween_property(health_bar, "value", health, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_set_low_health(health > 0 and health <= max_health * 0.35)


func _on_player_rage(rage: float, max_rage: int) -> void:
	rage_bar.max_value = max_rage
	rage_bar.value = rage


# --- Target frame: follow whichever wolf the player has targeted ----------
func _on_target_changed(new_target: Node2D) -> void:
	if is_instance_valid(_target):
		if _target.is_connected(SIGNAL_HEALTH_CHANGED, _on_target_health):
			_target.disconnect(SIGNAL_HEALTH_CHANGED, _on_target_health)
		if _target.is_connected(SIGNAL_DIED, _on_target_died):
			_target.disconnect(SIGNAL_DIED, _on_target_died)
	_target = new_target
	if is_instance_valid(new_target) and not bool(new_target.get("dying")):
		target_frame.visible = true
		target_name.text = "Wolf  Lv %d" % int(new_target.get("level"))
		target_bar.max_value = int(new_target.get("max_health"))
		target_bar.value = int(new_target.get("health"))
		new_target.connect(SIGNAL_HEALTH_CHANGED, _on_target_health)
		new_target.connect(SIGNAL_DIED, _on_target_died)
		_complete_hint(HINT_TARGET)
	else:
		target_frame.visible = false


func _on_target_health(health: int, max_health: int) -> void:
	target_bar.max_value = max_health
	var target_tween: Tween = create_tween()
	target_tween.tween_property(target_bar, "value", health, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_target_died() -> void:
	target_frame.visible = false
	_target = null


# --- Low-health heartbeat: a looping tween that yields to the hit-flash ----
func _set_low_health(on: bool) -> void:
	if on == _low:
		return
	_low = on
	if _low:
		_start_pulse()
	elif _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
		hurt_flash.color.a = 0.0


func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(hurt_flash, "color:a", 0.12, 0.5).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(hurt_flash, "color:a", 0.03, 0.5).set_trans(Tween.TRANS_SINE)


# --- Tutorial hint chips: each dims once its action fires (now via signal) -
func _complete_hint(key: StringName) -> void:
	if _hints_done.has(key) or not hints.has(key):
		return
	_hints_done[key] = true
	var hint_tween: Tween = create_tween()
	hint_tween.tween_property(hints[key], "modulate:a", 0.3, 0.5)
	if _hints_done.size() == hints.size():
		var fade_tween: Tween = create_tween()
		fade_tween.tween_interval(2.0)
		fade_tween.tween_property(hint_strip, "modulate:a", 0.0, 1.2)


# --- Toasts & flashes the player asks for ---------------------------------
func show_banner(text: String) -> void:
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
	_banner_tween.tween_callback(func() -> void: banner.visible = false)


func flash_hurt() -> void:
	# Pause the heartbeat so the two never fight over hurt_flash, then resume if still low.
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	var hurt_tween: Tween = create_tween()
	hurt_tween.tween_property(hurt_flash, "color:a", 0.22, 0.05)
	hurt_tween.tween_property(hurt_flash, "color:a", 0.0, 0.4)
	if _low:
		hurt_tween.tween_callback(_start_pulse)


func show_death_screen() -> void:
	death_dim.visible = true
	var death_tween: Tween = create_tween()
	death_tween.tween_property(death_dim, "color:a", 0.82, 1.1)
	death_tween.parallel().tween_property(death_label, "modulate:a", 1.0, 1.4)
	death_tween.parallel().tween_property(death_label, "position:y", death_label.position.y - 10.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
