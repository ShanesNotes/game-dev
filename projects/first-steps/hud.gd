extends CanvasLayer

## Drives the unit frames: fills in the hero's name/level and shows a
## target frame (name + health) for whatever the player has targeted.

@onready var name_label = $UnitFrame/NameLabel
@onready var target_frame = $TargetFrame
@onready var target_name = $TargetFrame/TargetName
@onready var target_bar = $TargetFrame/TargetHealthBar

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		name_label.text = "Will  Lv %d" % player.level

func _process(_delta):
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var t = player.target
	if is_instance_valid(t) and not t.dying:
		target_frame.visible = true
		target_name.text = "Wolf  Lv %d" % t.level
		target_bar.max_value = t.max_health
		target_bar.value = t.health
	else:
		target_frame.visible = false
