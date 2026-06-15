extends RefCounted
# Runtime gameplay contracts in one place.
#
# The project is intentionally GDScript-only and avoids hard dependencies on
# editor-refreshed global class names. These helpers keep cross-actor calls
# explicit, named, and noisy if a required method disappears.

const METHOD_EQUIP_SWORD: StringName = &"equip_sword"
const METHOD_ANNOUNCE: StringName = &"announce"
const METHOD_TAKE_DAMAGE: StringName = &"take_damage"
const METHOD_SET_TARGET: StringName = &"set_target"
const METHOD_SET_TARGETED: StringName = &"set_targeted"
const CAMERA_PATH: NodePath = ^"Camera2D"


static func equip_sword(actor: Node) -> void:
	if _requires_method(actor, METHOD_EQUIP_SWORD):
		actor.call(METHOD_EQUIP_SWORD)


static func announce(actor: Node, text: String) -> void:
	if _requires_method(actor, METHOD_ANNOUNCE):
		actor.call(METHOD_ANNOUNCE, text)


static func damage_enemy(actor: Node, amount: int, is_crit: bool = false) -> void:
	if _requires_method(actor, METHOD_TAKE_DAMAGE):
		actor.call(METHOD_TAKE_DAMAGE, amount, is_crit)


static func damage_player(actor: Node, amount: int, source: Node2D) -> void:
	if _requires_method(actor, METHOD_TAKE_DAMAGE):
		actor.call(METHOD_TAKE_DAMAGE, amount, source)


static func set_target(actor: Node, target: Node2D) -> void:
	if _requires_method(actor, METHOD_SET_TARGET):
		actor.call(METHOD_SET_TARGET, target)


static func set_targeted(actor: Node, on: bool) -> void:
	if _requires_method(actor, METHOD_SET_TARGETED):
		actor.call(METHOD_SET_TARGETED, on)


static func player_camera(actor: Node) -> Camera2D:
	if not is_instance_valid(actor):
		push_error("Player camera contract received an invalid actor")
		return null
	var camera: Camera2D = actor.get_node_or_null(CAMERA_PATH) as Camera2D
	if camera == null:
		push_error("Player camera contract requires child node %s on %s" % [CAMERA_PATH, actor.get_path()])
	return camera


static func _requires_method(actor: Node, method: StringName) -> bool:
	if not is_instance_valid(actor):
		push_error("Gameplay contract %s received an invalid actor" % method)
		return false
	if not actor.has_method(method):
		push_error("%s must implement gameplay contract method %s" % [actor.get_path(), method])
		return false
	return true
