extends SceneTree
# The repo's first test. Runs headless, game closed:
#   godot --headless --path projects/first-steps --script res://tests/test_combat_table.gd
#
# It asserts the extracted CombatTable against the cited numbers in
# reference/wow-combat-values.md. If a balance edit ever breaks a researched
# value, this goes red in the terminal instead of silently shipping.
#
# We preload the module rather than rely on the global `class_name` so the test
# runs even before the editor has refreshed its class cache.

const CT = preload("res://combat_table.gd")

var _fails := 0

func _init() -> void:
	# Player is L1 throughout; vary the target's level to walk the Δ table.
	# §3 Miss — 5 + Δ×0.1, Δ = (tgt−atk)×5
	expect("miss same-level", CT.miss_chance(1, 1), 5.0)
	expect("miss +1 (Δ=5)",   CT.miss_chance(1, 2), 5.5)
	expect("miss +2 (Δ=10)",  CT.miss_chance(1, 3), 6.0)

	# §4 Dodge — 5% + 0.5%/level above
	expect("dodge same-level", CT.dodge_chance(1, 1), 5.0)
	expect("dodge +3",         CT.dodge_chance(1, 4), 6.5)

	# §4 Parry — 5% base, +3%/level above (+3 = 14%)
	expect("parry same-level", CT.parry_chance(1, 1), 5.0)
	expect("parry +3",         CT.parry_chance(1, 4), 14.0)

	# §6 Glancing — 0 vs equal/lower; +10%/level above
	expect("glancing same-level", CT.glancing_chance(1, 1), 0.0)
	expect("glancing +1",         CT.glancing_chance(1, 2), 20.0)
	expect("glancing +2",         CT.glancing_chance(1, 3), 30.0)
	expect("glancing +3",         CT.glancing_chance(1, 4), 40.0)

	# §5 Crit — base 5%, −1%/level above (suppression)
	expect("crit same-level", CT.crit_chance(1, 1), 5.0)
	expect("crit +1",         CT.crit_chance(1, 2), 4.0)
	expect("crit floored",    CT.crit_chance(1, 8), 0.0)

	# §6 Glancing damage band — at +3 (Δ=15): low 0.55, high 0.75
	var band: Vector2 = CT.glancing_band(1, 4)
	expect("glancing band low",  band.x, 0.55)
	expect("glancing band high", band.y, 0.75)

	# §8 Rage conversion value C — L1 ≈ 7.5, L60 ≈ 230.6
	expect("conversion L1",  CT.conversion_value(1), 7.5, 0.05)
	expect("conversion L60", CT.conversion_value(60), 230.6, 0.1)

	if _fails == 0:
		print("PASS — all combat-table values match wow-combat-values.md")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _fails)
		quit(1)

func expect(label: String, got: float, want: float, tol := 0.001) -> void:
	if abs(got - want) <= tol:
		print("  ok   %-22s = %s" % [label, got])
	else:
		_fails += 1
		printerr("  FAIL %-22s got %s, want %s" % [label, got, want])
