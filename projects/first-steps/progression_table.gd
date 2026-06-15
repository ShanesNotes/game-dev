class_name ProgressionTable
# XP and con-color math for the upcoming progression arc.
#
# Deliberately pure and not yet wired into player.gd: G012 prepares the seam for
# Lesson 38 without secretly adding an XP system. When the learner builds XP,
# player state/HUD/ding feedback can call these tested functions.
#
# Sources are pinned in reference/wow-combat-values.md §7.

const CON_GRAY: StringName = &"gray"
const CON_GREEN: StringName = &"green"
const CON_YELLOW: StringName = &"yellow"
const CON_ORANGE: StringName = &"orange"
const CON_RED: StringName = &"red"
const SUPPORTED_XP_TABLE_MAX_LEVEL: int = 28

const XP_TO_NEXT_TABLE: Dictionary = {
	1: 400,
	2: 900,
	3: 1400,
	4: 2100,
	5: 2800,
	6: 3600,
	7: 4500,
	8: 5400,
	9: 6500,
	10: 7600,
	11: 8700,
	12: 9800,
}


static func xp_to_next(level: int) -> int:
	if level < 1 or level > SUPPORTED_XP_TABLE_MAX_LEVEL:
		return 0
	if XP_TO_NEXT_TABLE.has(level):
		return int(XP_TO_NEXT_TABLE[level])
	# For 13-28 the pinned reference uses Diff(level)=0, rounded to nearest 100.
	return _round_nearest_hundred((8 * level) * (45 + 5 * level))


static func base_xp(player_level: int) -> int:
	if player_level < 1:
		return 0
	return player_level * 5 + 45


static func mob_kill_xp(player_level: int, mob_level: int, elite: bool = false) -> int:
	if player_level < 1 or mob_level < 1:
		return 0
	if con_color(player_level, mob_level) == CON_GRAY:
		return 0

	var xp: float = float(base_xp(player_level))
	if mob_level > player_level:
		# Red mobs cap at the +4 orange multiplier until the course has a reason
		# to model skull/boss exceptions.
		var high_gap: int = mini(mob_level - player_level, 4)
		xp *= 1.0 + 0.05 * high_gap
	elif mob_level < player_level:
		xp *= 1.0 - float(player_level - mob_level) / float(zero_difference(player_level))

	if elite:
		xp *= 2.0
	return maxi(roundi(xp), 0)


static func con_color(player_level: int, mob_level: int) -> StringName:
	if player_level < 1 or mob_level < 1:
		return CON_GRAY
	var gap: int = mob_level - player_level
	if mob_level <= gray_level(player_level):
		return CON_GRAY
	if gap >= 5:
		return CON_RED
	if gap >= 3:
		return CON_ORANGE
	if gap >= -2:
		return CON_YELLOW
	return CON_GREEN


static func gray_level(player_level: int) -> int:
	if player_level <= 0:
		return 0
	if player_level <= 5:
		return 0
	if player_level <= 49:
		return player_level - floori(float(player_level) / 10.0) - 5
	if player_level == 50:
		return 40
	if player_level <= 59:
		return player_level - floori(float(player_level) / 5.0) - 1
	return player_level - 9


static func zero_difference(player_level: int) -> int:
	if player_level <= 7:
		return 5
	if player_level <= 9:
		return 6
	if player_level <= 11:
		return 7
	if player_level <= 15:
		return 8
	if player_level <= 19:
		return 9
	if player_level <= 29:
		return 11
	if player_level <= 39:
		return 12
	if player_level <= 44:
		return 13
	if player_level <= 49:
		return 14
	if player_level <= 54:
		return 15
	if player_level <= 59:
		return 16
	return 17


static func _round_nearest_hundred(value: int) -> int:
	return roundi(float(value) / 100.0) * 100
