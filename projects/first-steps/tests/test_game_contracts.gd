extends SceneTree
# Verifies the explicit gameplay contract wrapper used between actors.
# Run:
#   godot --headless --path projects/first-steps --script res://tests/test_game_contracts.gd

const GameContracts = preload("res://game_contracts.gd")

var _fails: int = 0


class DummyActor extends Node2D:
	var equipped: bool = false
	var announcement: String = ""
	var damage_amount: int = 0
	var damage_context: Variant = null
	var selected_target: Node2D = null
	var targeted: bool = false

	func equip_sword() -> void:
		equipped = true

	func announce(text: String) -> void:
		announcement = text

	func take_damage(amount: int, context: Variant = null) -> void:
		damage_amount = amount
		damage_context = context

	func set_target(target: Node2D) -> void:
		selected_target = target

	func set_targeted(on: bool) -> void:
		targeted = on


func _init() -> void:
	var actor: DummyActor = DummyActor.new()
	actor.name = "DummyActor"
	root.add_child(actor)

	var target: Node2D = Node2D.new()
	target.name = "Target"
	root.add_child(target)

	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	actor.add_child(camera)

	GameContracts.equip_sword(actor)
	expect("equip_sword contract", actor.equipped)
	GameContracts.announce(actor, "Sword equipped")
	expect_equal("announce contract", actor.announcement, "Sword equipped")
	GameContracts.damage_enemy(actor, 8, true)
	expect_equal("damage_enemy amount", actor.damage_amount, 8)
	expect_equal("damage_enemy crit context", actor.damage_context, true)
	GameContracts.damage_player(actor, 2, target)
	expect_equal("damage_player amount", actor.damage_amount, 2)
	expect_equal("damage_player source", actor.damage_context, target)
	GameContracts.set_target(actor, target)
	expect_equal("set_target contract", actor.selected_target, target)
	GameContracts.set_targeted(actor, true)
	expect("set_targeted contract", actor.targeted)
	expect_equal("player_camera contract", GameContracts.player_camera(actor), camera)

	if _fails == 0:
		print("PASS — gameplay contracts route actor calls explicitly")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _fails)
		quit(1)


func expect(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		printerr("  FAIL %s" % label)


func expect_equal(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		print("  ok   %s = %s" % [label, got])
	else:
		_fails += 1
		printerr("  FAIL %s got %s, want %s" % [label, got, want])
