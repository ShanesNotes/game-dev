class_name CombatTable
# The Vanilla-1.12 attack table, in one place.
#
# Every white (auto-attack) swing is resolved by ONE d100 roll walked through
# contiguous bands: Miss -> Dodge -> Parry -> Glancing -> Crit -> Hit.
# These functions return the *size* of each band (an absolute % of all swings).
#
# They are deliberately PURE: no node state, no `self`, just numbers in -> numbers
# out. That is what lets tests/test_combat_table.gd verify them headless with the
# game closed. Every formula cites reference/wow-combat-values.md (§ numbers below);
# never re-derive these from vibes.

const BASE_CRIT := 5.0    # §5: ~5% innate melee crit
const CRIT_MULTIPLIER := 2.0  # §5: melee crits deal 200% (double)

# Δ (skill gap) = (targetLevel − attackerLevel) × 5.  §2 — drives miss/glancing.
static func skill_delta(attacker_level: int, target_level: int) -> int:
	return (target_level - attacker_level) * 5

# §3: miss% = 5 + Δ×0.1 (exact for Δ ≤ 10, i.e. targets within 2 levels — every
# fight this game has). The Δ>10 "boss" branch is intentionally not modeled.
static func miss_chance(attacker_level: int, target_level: int) -> float:
	return 5.0 + skill_delta(attacker_level, target_level) * 0.1

# §4: 5% base + 0.5% per level the target is above you (Blizzard Classic model).
static func dodge_chance(attacker_level: int, target_level: int) -> float:
	var gap := maxi(target_level - attacker_level, 0)
	return 5.0 + gap * 0.5

# §4: 5% base, scales hard (+3 = 14%); modeled as +3% per level above. Front only.
static func parry_chance(attacker_level: int, target_level: int) -> float:
	var gap := maxi(target_level - attacker_level, 0)
	return 5.0 + gap * 3.0

# §6: 0% vs equal/lower level; +10% per level above (only when YOU hit up).
static func glancing_chance(attacker_level: int, target_level: int) -> float:
	var gap := target_level - attacker_level
	if gap <= 0:
		return 0.0
	return 10.0 + gap * 10.0

# §5: base crit − 1% per level the target is above you (crit suppression), floored at 0.
static func crit_chance(attacker_level: int, target_level: int, base_crit := BASE_CRIT) -> float:
	return max(base_crit - (target_level - attacker_level), 0.0)

# §6: glancing damage factor band [low, high]. At +3 (Δ=15) -> ~0.55..0.75 of normal.
static func glancing_band(attacker_level: int, target_level: int) -> Vector2:
	var skill_diff := skill_delta(attacker_level, target_level)
	var low := clampf(1.3 - 0.05 * skill_diff, 0.01, 0.91)
	var high := clampf(1.2 - 0.03 * skill_diff, 0.2, 0.99)
	return Vector2(low, high)

# A rolled glancing hit. (Pure band above is the testable part; this adds the roll.)
static func glancing_damage(attack_damage: float, attacker_level: int, target_level: int) -> float:
	var band := glancing_band(attacker_level, target_level)
	return attack_damage * randf_range(band.x, band.y)

# --- Rage (§8) -------------------------------------------------------------
# Conversion value C grows with level; at L60 ≈ 230.6, at L1 ≈ 7.5.
static func conversion_value(level: int) -> float:
	return 0.0091107836 * level * level + 3.225598133 * level + 4.2652911

# rage = 7.5·d / C + (f·s)/2.  Hit factor f: 3.5 normal main-hand, 7.0 on a crit.
static func rage_from_dealing(damage: float, weapon_speed: float, is_crit: bool, level: int) -> float:
	var f := 7.0 if is_crit else 3.5
	return 7.5 * damage / conversion_value(level) + f * weapon_speed / 2.0

# rage = 2.5·d / C.  Getting hit builds rage too.
static func rage_from_taking(damage: float, level: int) -> float:
	return 2.5 * damage / conversion_value(level)
