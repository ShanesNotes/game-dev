# WoW Combat & Progression Values (Classic / Vanilla 1.12)

**Purpose:** single source of truth for the WoW-accurate numbers behind the combat,
rage, XP, and ability lessons (roadmap lessons ~20–33). Each combat/XP lesson cites
this file instead of re-deriving values. Target version: **Vanilla 1.12 / WoW Classic
2019 ("Classic Era")**. Player class fantasy = **Warrior** (sword auto-attack + rage +
Heroic Strike).

> **How to read this:** the **Canonical** value is what Vanilla used. **In our game**
> notes translate it to our low-level Warrior-vs-wolves context. **⚠ Flags** record where
> sources disagreed — we picked one and said why.

---

## 0. The core idea — the one-roll attack table

Every white (auto-attack) melee swing is resolved by **ONE** d100 roll (0–99), not
several. All possible outcomes are laid into a single 0–100 line as contiguous bands, in
this **priority order**; whatever roll-space is left at the end is an ordinary hit:

```
Miss → Dodge → Parry → Glancing → Block → Crit → Crushing → Hit
```

- Percentages are **absolute** (a 5% dodge = 5% of *all* swings, not 5% of non-misses).
- If the bands sum past 100%, the **lowest-priority** outcomes get "pushed off the
  table" (hits first, then crushing, then crits → the "crit cap" idea).
- **Player attacking a mob** can roll: Miss, Dodge, Parry, Glancing, Crit, Hit.
  (No block unless the mob has a shield; **no crushing** — players can't crush.)
- **Mob attacking the player** can roll: Miss, Dodge, Parry, Block, Crit, Crushing, Hit.
  (**No glancing** — creatures don't glance.)

⚠ **Flag:** my original prompt had Block before Glancing; the Vanilla wikis unanimously
put **Glancing before Block**. Order above is corrected. Source:
<https://warcraft.wiki.gg/wiki/Attack_table>, <https://vanilla-wow-archive.fandom.com/wiki/Attack_table>

**In our game:** we build this table literally — one `randf() * 100` roll, walk the
bands in order, first band the roll lands in wins. This is the spine of lessons 21–24.

---

## 1. Attack speed & global cooldown

| Thing | Canonical (1.12) | Source |
|---|---|---|
| White swing interval | = weapon **Speed** stat, in seconds (no haste) | [onlyfarms](https://onlyfarms.gg/wiki/world-of-warcraft/attack-timer) |
| 1H sword speed range | ~1.5s (fastest) to ~2.8s (slowest) | [wowhead classic](https://www.wowhead.com/classic/items/weapons/one-handed-swords) |
| Worn Shortsword (warrior starter) | **1.9** (Classic Era) | [wowhead item=25](https://www.wowhead.com/classic/item=25/worn-shortsword) |
| Global cooldown (warrior) | **1.5s, fixed** (not reduced by haste in Vanilla) | [vanilla-wow](https://vanilla-wow-archive.fandom.com/wiki/Cooldown) |
| Haste effect | `swing = Speed / (1 + haste%)`, multiple haste stacks multiplicatively | [warcraft.wiki](https://warcraft.wiki.gg/wiki/Attack_speed) |

- **On next swing** abilities (**Heroic Strike**, Cleave) are **OFF the GCD** — they
  queue and *replace* your next white swing rather than firing instantly.
- ⚠ **Flag:** warcraft.wiki.gg lists Worn Shortsword as 2.6 (a later retail re-stat). For
  1.12 use **1.9**. We'll use **2.0s** as a clean generic 1H starter speed.

**In our game:** the player's swing timer = weapon speed (~2.0s). Abilities (future
Heroic Strike) sit on a 1.5s GCD *except* Heroic Strike which is off-GCD / next-swing.

---

## 2. Skill, level, and the Δ that drives everything

- Mob **Defense Skill = mobLevel × 5**
- Player **max Weapon Skill = playerLevel × 5**
- **Δ (skill gap) = DefenseSkill − WeaponSkill = (mobLevel − playerLevel) × 5**

So a mob one level above you = Δ of 5; a +3 "boss" = Δ of 15. This single Δ feeds the
miss, dodge, and glancing numbers below. Source:
<https://github.com/magey/classic-warrior/wiki/Attack-table>

---

## 3. Miss

```
If Δ ≤ 10:   miss% = 5 + Δ × 0.1            ← exact; this is all our game ever reaches
If Δ > 10:   contested — see note below
```
The **Δ ≤ 10 branch is exact and uncontroversial** (every per-point step is +0.1%). Once
Δ > 10 (a 3+ level gap, i.e. a "boss"), Vanilla applies a steeper per-point penalty **plus
a flat ~1% "hit suppression"** (the first 1% of +hit gear is eaten) — producing the
discontinuous jump to the famous **~8–9% vs a +3 boss**. ⚠ The exact closed form is
**debated** (sources land between 8% and 9%; the simple "5 + Δ×0.2 − 1" undershoots), so
don't hardcode a Δ>10 formula — just know the +3 case is "specially nasty."

| Target (L60 player, 300 skill) | Δ | Miss % |
|---|---|---|
| Same level | 0 | **5.0%** |
| +1 | 5 | **5.5%** |
| +2 | 10 | **6.0%** |
| +3 (boss) | 15 | **9.0%** |

- **Dual-wield** adds a flat **+19%** white-swing miss to *each* weapon. (Not relevant —
  we use a single 1H sword.)
- Sources: [magey/classic-warrior](https://github.com/magey/classic-warrior/wiki/Attack-table),
  [classic-wow-archive Hit](https://classic-wow-archive.fandom.com/wiki/Hit)

**In our game:** `miss% = 5 + Δ × 0.1` for Δ ≤ 10 covers every fight we'll have
(player vs wolves within ~2 levels). We'll implement the Δ>10 branch too for correctness
but won't usually hit it.

---

## 4. Dodge / Parry / Block (mob avoiding the player)

| Outcome | Same-level | Scaling vs higher mobs | Notes |
|---|---|---|---|
| **Dodge** | 5% | **+0.5% per mob level above you** → +3 = 6.5% | Blizzard Classic model |
| **Parry** | 5% | jumps hard: **+3 boss = 14%** (not linear) | **front only**; from behind = 0 |
| **Block** | 5% | scales like dodge | only if mob has a shield + faces you; subtracts a **flat block value**, not a % |

- **Parry-haste:** a successful parry advances the *parrier's* swing timer by ~40% (a
  mob parrying you speeds up its next swing). Why melee attack from behind.
- ⚠ **Flag (dodge scaling):** two models exist — Blizzard's 2019 "+0.5%/level" vs the old
  "+0.04% per defense point" (gives ~5.6% at +3). **We use Blizzard's +0.5%/level** (it's
  the Classic-authoritative one). Parry's non-linear +3=14% is also Blizzard's stated
  value; +1/+2 aren't officially published (model ~8%/~11% if needed, flagged uncertain).
- Sources: [mstsage Blizzard clarification](https://www.mstsage.com/articles/2019/05/29/parry-dodge-miss-block-and-crit-issues-in-world-of-warcraft-classic-beta/),
  [vanilla-wow Parry](https://vanilla-wow-archive.fandom.com/wiki/Parry)

**In our game:** wolves have no shield → **no block** when we attack them. They get
dodge (+0.5%/lvl) and parry (front-only). When a *wolf* attacks the *player*, the player
can dodge/parry/block (if we give the player a shield later) — see §6.

---

## 5. Crit

| Thing | Canonical (1.12) | Source |
|---|---|---|
| Melee crit damage | **200%** (double) — *spell crit is 150% in Vanilla* | [wowpedia](https://wowpedia.fandom.com/wiki/Critical_strike) |
| Agility → crit | **~20 agility per 1% crit** at L60 (varies by level/class; ~7.7 agi/1% at L19) | [vanilla-wow Attributes](https://vanilla-wow-archive.fandom.com/wiki/Attributes) |
| Base crit | ~**5%** innate | same |
| Crit suppression | **−1% crit per mob level above you**; +3 boss also loses ~1.8% aura crit → **~4.8% total** vs a +3 boss | [magey](https://github.com/magey/classic-warrior/wiki/Attack-table) |

- ⚠ **Flag:** the extra ~1.8% "aura suppression" (→4.8% total vs +3) is the best-supported
  community figure but **contested** / not officially confirmed. The clean **−1%/level**
  is solid; treat the aura part as approximate.

**In our game:** give the player a base ~5% crit; we can scale crit off a simple
`agility` stat later, or keep it flat early. Crit suppression = subtract 1% per wolf
level above the player. Crits deal **2× damage** and show **big yellow numbers** (reuses
the L16 damage-number scene).

---

## 6. Glancing & Crushing (the "tougher/weaker foe" feel)

**Glancing blows** — *only when the player attacks a higher-level mob* (white hits only;
unavoidable; can't crit; not reducible by +hit):
- Chance = `10% + 2% × (mobDefense − weaponSkillCap)` = **+10% per mob level above you**.
  Same-level 0% · +1 = 20% · +2 = 30% · +3 = 40%.
- Damage factor randomized between a low and high end (depends on Δ). At +3 (Δ=15):
  low `1.3 − 0.05×15 = 0.55`, high `1.2 − 0.03×15 = 0.75` → glancing deals **55–75% of
  normal, avg ~65% (≈35% penalty)**.
- Source: [warcraft.wiki Glancing blow](https://warcraft.wiki.gg/wiki/Glancing_blow)

**Crushing blows** — *only when a mob attacks the player* (mobs ≥ enough levels above):
- Damage = **150%** of a normal hit.
- Chance ≈ `(min(defenseGap, 20)) × 2% − 15%` → **+3 mob ≈ 15%**, +4 ≈ 25%, +5 ≈ 35%.
- ⚠ **Flag:** warcraft.wiki says crushing needs "more than 4 levels" (bosses can't),
  but the 20-point-minimum formula makes a +3 boss crush at **15%**, which matches actual
  Classic raid behavior (tanks stack avoidance to push crushes off the table). **We use
  15% at +3.**
- Sources: [warcraft.wiki Crushing blow](https://warcraft.wiki.gg/wiki/Crushing_blow),
  [wowwiki-archive](https://wowwiki-archive.fandom.com/wiki/Crushing_blow)

**In our game:** glancing makes a *higher-level* wolf chip your DPS (great for "this wolf
is too tough" feel); crushing makes a *much higher-level* wolf hit you scary-hard. Both
are pure level-gap drama — the payoff of the level system.

---

## 7. XP & leveling

**XP required to reach the next level** — use the **observed in-game table** (the closed
form is imperfect at low levels):

| Level | XP to next | Level | XP to next |
|---:|---:|---:|---:|
| 1→2 | 400 | 7→8 | 4,500 |
| 2→3 | 900 | 8→9 | 5,400 |
| 3→4 | 1,400 | 9→10 | 6,500 |
| 4→5 | 2,100 | 10→11 | 7,600 |
| 5→6 | 2,800 | 11→12 | 8,700 |
| 6→7 | 3,600 | 12→13 | 9,800 |

Formula (for reference): `XP(L) = (8×L + Diff(L)) × (45 + 5L)` rounded to nearest 100,
where `Diff(L)=0` for L≤28. Total 1→60 = 4,084,700 XP. Source:
[wowpedia Experience to level](https://wowpedia.fandom.com/wiki/Experience_to_level)

**Mob kill XP:**
- Base (mob = your level) = `5 × mobLevel + 45`.
- Higher mob (up to +4): `× (1 + 0.05 × (mobLevel − charLevel))`.
- Lower mob: `× (1 − (charLevel − mobLevel) / ZD)` until it's gray (ZD: 5 at low levels).
- **Elite = 2×** normal.
- **Con colors:** red ≥ +5 · orange +3/+4 · yellow ±2 · green −3..gray · **gray = 0 XP**.
- Source: [warcraft.wiki Mob experience](https://warcraft.wiki.gg/wiki/Mob_experience)

**Rested XP:** **200%** kill XP while rested; accrues 5% of a level per 8h logged out
(faster in inns), cap 150% of a level.

**In our game:** start the player at **level 1**, wolves around **level 1–3**. Killing a
L1 wolf = `5×1+45 = 50` XP; a L3 wolf (orange, +2 over a L1 player → use the +mod) gives
a bit more. The two starter quests + ~a dozen wolf kills should ding the player to the
level that unlocks Heroic Strike. We'll use the table above for level thresholds.

---

## 8. Rage

| Thing | Canonical (1.12) | Source |
|---|---|---|
| Max rage | **100** (starts at 0 out of combat) | [warcraft.wiki Rage](https://warcraft.wiki.gg/wiki/Rage) |
| Out-of-combat decay | ~**1 rage/sec** (loosely documented) | [noobtoboss](https://noobtoboss.com/wow-classic-warrior-rage-guide/) |
| Conversion value C | `C = 0.0091107836·L² + 3.225598133·L + 4.2652911` (L60 → ~230.6) | [Marrow's Compendium](https://bookdown.org/marrowwar/marrow_compendium/abilities.html) |
| Rage from dealing dmg | `rage = 7.5·d / C + (f·s)/2` | same |
| Rage from taking dmg | `rage = 2.5·d / C` | same |

Hit factor `f`: main-hand normal **3.5**, MH crit **7.0**, off-hand normal 1.75, OH crit
3.5. (`d` = damage dealt, `s` = weapon speed.) Slow weapons make more rage per swing
(the `f·s/2` term) — rage was not normalized in Vanilla.

- ⚠ **Flags:** dealer coefficient is **7.5** (not 3.75/the "15/(4C)" variant). C = **230.6
  at L60** is the Vanilla value; ignore the 453.3 figure (that's TBC). Decay ~1/sec is
  loosely sourced.

**In our game:** at low level C is small (e.g. L1 ≈ 7.5, L5 ≈ 20), so the *same* formula
naturally gives lots of rage per hit early — convenient. Rage bar 0–100, gain on
dealing/taking damage, decays out of combat. Powers Heroic Strike.

---

## 9. Heroic Strike (the unlockable skill)

- **Off the GCD**, **"on next swing"**: queues and *replaces* your next white auto-attack
  with a stronger hit; cancellable; uses the normal attack table (can miss/dodge/crit).
- **Cost: 15 rage** (all ranks). Bonus damage is a **flat add on top of weapon damage**.
- The replaced swing yields **no normal white rage** (so effective cost ≈ 15 + the rage
  that swing would have made — it's a rage *dump*). ⚠ Contested but dominant interpretation.

| Rank | Learned at level | Rage | Flat bonus dmg |
|---:|---:|---:|---:|
| 1 | 1 | 15 | +11 |
| 2 | 8 | 15 | +21 |
| 3 | 16 | 15 | +32 |
| 4 | 24 | 15 | +44 |
| 5 | 32 | 15 | +58 |
| 6 | 40 | 15 | +80 |
| 7 | 48 | 15 | +111 |
| 8 | 56 | 15 | +138 |
| 9 | 60 | 15 | +157 |

Source: [classicdb spell=78](https://classicdb.ch/?spell=78),
[warcraft.wiki Heroic Strike](https://warcraft.wiki.gg/wiki/Heroic_Strike)

**In our game:** the player learns **Heroic Strike Rank 1 (+11 flat dmg, 15 rage)** at the
level reached after the two starter quests. Off-GCD, replaces the next swing, deals
weapon damage + 11, rolls on the attack table. The first real *ability*.

---

## Open decisions to lock when we get there
- Player & wolf exact **levels** (suggest player L1, wolves L1–3) — sets every Δ above.
- Whether the player ever carries a **shield** (enables player block + the crush-immunity
  fantasy) or stays 1H-sword-only.
- How **agility/crit** scales early (flat 5% vs a real agility stat).
- Whether to model **rest XP** at all (probably skip — no logout in our game).
