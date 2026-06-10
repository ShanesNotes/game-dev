# Notes

Scratchpad for your teaching preferences and working notes.

## Environment (verified 2026-06-07)
- Godot binary: `/home/ark/.local/bin/godot` → run as `godot`
- Version: **4.6.2.stable.mono** (C# + GDScript both available)
- Open the editor: `godot` (project manager) or `godot --path projects/<name>`
- Godot projects live in `./projects/`

## Teaching preferences
- Total beginner — no prior game dev. Keep each lesson to ONE small, tangible win.
- Hobby / exploratory pace; no deadline. Don't rush ahead.
- GDScript only for now.
- Loose genre direction: top-down 2D adventure/sim (Zelda/Stardew/Pokémon feel).

## Lesson design system
- All lessons link `_lesson.css` + `_lesson.js` (in `lessons/`). USE THESE for every
  new lesson — do not inline styles.
- Aesthetic: Tiny Game Factory doctrine look — dark (#0a0d12), blueprint grid bg,
  mono headings (JetBrains Mono) + serif body (Charter), amber/cyan/green accents.
- Components: `.hero`+`.kicker`, `.win` banner, `.callout {note|warn|forbid|idea}`,
  `.defs/.def`, `.code` block (with copy button + `.kw/.fn/.var/.num/.com/.str/.type`
  token spans), `.annot/.line-note`, `.tree`, `.flow/.phase` steps, `.quiz` (buttons
  with `data-correct`), `.teacher` box, `footer`. `code.inline` + `kbd` for inline.
- `lessons/index.html` is the course map — add each new lesson to it (right arc,
  number, title, one-line description) when the lesson ships.

## Session setup
- Split screen: terminal (Claude) on the LEFT, Godot editor on the RIGHT.
- Loop: Claude explains here → user does it in Godot → report back → next step.
- Open a lesson in browser: `xdg-open ~/game-dev/lessons/<file>.html`
