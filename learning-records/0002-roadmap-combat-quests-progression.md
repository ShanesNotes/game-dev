# 0002 — Roadmap: Combat Depth, Quests & Progression

**Date:** 2026-06-08 · status: **planning** (lessons done one at a time)

Big content/systems arc requested after L18. Picks up the WoW-Elwynn throughline: the
player is now effectively a **Warrior** (sword auto-attack + rage + Heroic Strike).

## Decisions locked (user choices)
- **Combat fidelity:** FULL Classic 1.12 — real one-roll attack table, weapon-skill vs
  defense, glancing & crushing blows, exact level-gap formulas. Values pinned in
  [`reference/wow-combat-values.md`](../reference/wow-combat-values.md).
- **Ability resource:** Warrior + **Rage** (build by fighting; Heroic Strike costs rage,
  off-GCD next-swing).
- **Inventory:** **real inventory UI** (bag panel, slots, icons, stacks) — not just counts.
- **Research:** done up front as a spike → the reference doc above; every combat/XP/rage
  lesson cites it.

## Two structural dependencies
1. **A `level` stat** underpins both the combat level-gap scaling AND the "ding → learn a
   skill" payoff. Introduced early (L20); the XP lesson (L26) makes it actually grow.
2. **Items/inventory** underpins pelts (quest drop), the gathered resource, and the chest.
   One inventory lesson (L27) unlocks chest + gather + the kill-quest turn-in.

## Proposed lesson sequence (19–33 · single win each · order/size adjustable)

### Polish (easy re-entry)
- **19 · Sword-wielding animation** — player visibly holds/swings the sword. Pure visual.

### Combat depth (cite the reference doc)  ★ the user's biggest ask
- **20 · Attack speed & GCD** — swing timer = weapon Speed (~2.0s); 1.5s GCD concept; add
  `level` to player & wolves; set wolf levels (≈1–3).
- **21 · Hit or miss (the one-roll table)** — single d100 roll; base 5% miss + Δ-based
  level-gap miss; "Miss!" floating text. Introduces the table spine with miss vs hit.
- **22 · Critical strikes** — crit chance (~5% base), 200% damage, crit suppression vs
  higher-level wolves; big yellow crit numbers.
- **23 · Avoidance** — dodge & parry (wolf avoiding you), front-only parry, +0.5%/level
  dodge scaling; "Dodge!/Parry!" text. Table now miss→dodge→parry→crit→hit.
- **24 · Glancing blows** — completes the *player's* attack table: a Glancing band before
  Crit (only vs higher-level targets; `10% + 10%/level`, reduced damage 55–99% by gap).
  Pure "punching above your weight" drama. **Deferred (explained, not coded — would be dead
  code at our levels):** crushing blows (need a +3/+4 gap; wolves are ≤+2) and the
  *mob-side* table (the wolf rolling your dodge/parry/block when it bites) — a mirror of
  L21–24, to add when the player gets a shield / we want defensive depth.

### Progression
- **25 · Rage** — rage bar 0–100, generation from dealing/taking damage (the C formula),
  out-of-combat decay. Foundation for abilities.
- **26 · XP & leveling** — XP from kills (mob-XP formula + con colors), the XP-to-level
  table, ding + a stat bump. Level now drives the combat scaling from L20–24.

### Items & world
- **27 · Items & real inventory UI** — item data + a bag panel (slots, icons, stacks).
  Wolves drop **pelts** on death into the bag. (Biggest UI lesson.)
  - **Refactor parked here (decided L19):** replace the L19 hardcoded `sword.visible = true`
    with a data-driven equipment slot — a `WeaponData` Resource (texture, damage,
    attack_speed, name) + `var equipped_weapon` on the player; the held sprite reads its
    texture/stats from the equipped weapon, and `equip_sword()` generalises to
    `equip(weapon_data)` (visible = `equipped_weapon != null`). Kept simple until now per
    YAGNI — the second weapon is what triggers the refactor.
- **28 · Lootable chest** — interact prompt → loot item(s) into the bag.
- **29 · Gather node** — a harvestable resource node → into the bag.

### Quests
- **30 · Wizard quest-giver + dialogue** — NPC you walk up to; dialogue box; accept quest.
- **31 · Quest tracking & turn-in** — "slay 5 wolves (pelts)" + "gather X" objectives
  auto-update; turn in → XP reward → **ding** the level that unlocks the skill.

### Payoff
- **32 · Heroic Strike** — first learned ability at the dinged level: off-GCD, replaces
  next swing, 15 rage, +flat damage, rolls on the attack table.
- **33 · Whirlwind (the AoE ability)** — the multi-target swing, kept *separate* from the
  single-target white auto-attack: a `Hitbox` Area2D + `add_to_group("enemies")` +
  `get_overlapping_bodies()` filtered by group → damages every wolf in range at once.
  Costs rage, on the GCD. (This is the AoE originally sketched for L18, correctly moved
  to its own Warrior ability.)

Then the original next story leg remains: **travel north to the cabin** (scene transition).

## Notes
- Numbered 19–33 here (15 lessons); granularity may shift as we build (e.g. 23/24 could
  split or merge). We do them **one at a time**.
- Open per-lesson decisions (player/wolf exact levels, shield-or-not, agility/crit
  scaling, skip rest-XP) are listed at the bottom of the reference doc.
