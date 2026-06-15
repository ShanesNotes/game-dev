extends SceneTree
# Locks the XP/con-color formulas before Lesson 38 wires them into player state.
# Run:
#   godot --headless --path projects/first-steps --script res://tests/test_progression_table.gd

const PT = preload("res://progression_table.gd")

var _fails: int = 0


func _init() -> void:
	# §7 XP-to-next observed low-level table.
	expect_equal("XP 1->2", PT.xp_to_next(1), 400)
	expect_equal("XP 2->3", PT.xp_to_next(2), 900)
	expect_equal("XP 3->4", PT.xp_to_next(3), 1400)
	expect_equal("XP 4->5", PT.xp_to_next(4), 2100)
	expect_equal("XP 5->6", PT.xp_to_next(5), 2800)
	expect_equal("XP 6->7", PT.xp_to_next(6), 3600)
	expect_equal("XP 7->8", PT.xp_to_next(7), 4500)
	expect_equal("XP 8->9", PT.xp_to_next(8), 5400)
	expect_equal("XP 9->10", PT.xp_to_next(9), 6500)
	expect_equal("XP 10->11", PT.xp_to_next(10), 7600)
	expect_equal("XP 11->12", PT.xp_to_next(11), 8700)
	expect_equal("XP 12->13", PT.xp_to_next(12), 9800)
	expect_equal("XP formula 13->14", PT.xp_to_next(13), 11400)

	# Mob XP: base uses the player level, then applies level gap, gray, and elite rules.
	expect_equal("base XP L1", PT.base_xp(1), 50)
	expect_equal("same-level wolf", PT.mob_kill_xp(1, 1), 50)
	expect_equal("+1 wolf", PT.mob_kill_xp(1, 2), 53)
	expect_equal("+2 wolf", PT.mob_kill_xp(1, 3), 55)
	expect_equal("red cap", PT.mob_kill_xp(1, 10), 60)
	expect_equal("elite wolf", PT.mob_kill_xp(1, 1, true), 100)
	expect_equal("lower mob rounded", PT.mob_kill_xp(20, 18), 119)
	expect_equal("gray mob", PT.mob_kill_xp(20, 13), 0)

	# Con colors: +2 is still yellow; +3/+4 are orange; +5 red.
	expect_equal("con same", PT.con_color(1, 1), PT.CON_YELLOW)
	expect_equal("con +2", PT.con_color(1, 3), PT.CON_YELLOW)
	expect_equal("con +3", PT.con_color(1, 4), PT.CON_ORANGE)
	expect_equal("con +5", PT.con_color(1, 6), PT.CON_RED)
	expect_equal("gray level L20", PT.gray_level(20), 13)
	expect_equal("con gray", PT.con_color(20, 13), PT.CON_GRAY)
	expect_equal("con green", PT.con_color(20, 14), PT.CON_GREEN)
	expect_equal("ZD L20", PT.zero_difference(20), 11)

	if _fails == 0:
		print("PASS — ProgressionTable matches the pinned XP and con-color reference")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _fails)
		quit(1)


func expect_equal(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		print("  ok   %s = %s" % [label, got])
	else:
		_fails += 1
		printerr("  FAIL %s got %s, want %s" % [label, got, want])
