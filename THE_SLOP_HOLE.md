# The Slop Hole

How to work in this codebase, for AI agents.
Read [CONTRIBUTING.md](CONTRIBUTING.md) and [DESIGN_GUIDELINES.md](DESIGN_GUIDELINES.md) first.

Most slop isn't bad code.
It's confident code built on a guess, and changes nobody asked for.

AI-written PRs get held to a higher bar.
They tend to be bigger and less focused than ones a human wrote by hand, and every line costs review time.
Keep the PR small, and about one thing.

Your contributor owns the PR, and should understand every line in it.
Most questions are theirs to answer.
Questions only the maintainer can answer, like whether an idea fits, are what the draft PR is for.

---

## Investigate before you build

- **Check whether it already exists.** Glee is big, and the thing you're about to write is often already here.
  Grep for it before designing anything.
- **Build it the way Glee already builds that kind of thing.** If something similar exists, copy how it works.
  Each choice in it was likely made for a reason, so learn the reason, not just the shape.
  For example, shop items, music and spawnsets are all loaded from `lua/glee_*/` the same way.
  [sv_shopgobbler.lua](gamemodes/hunters_glee/gamemode/modules/shopitems/sv_shopgobbler.lua) and the other loaders explain why in comments.
- **Never trust a name or a comment.** Read the function, and what it calls.
  Names were picked before the code finished changing, and comments go stale.
- **Find every call site before changing a signature.** Half a function's contract is how it's used.
- **Public functions and hooks are probably used by other people's addons.**
  Renaming a `GAMEMODE` function or a hook breaks them, and grep can't find those callers.
  Inside the repo, rename every call site rather than leaving an alias behind.
- **When three things work one way and a fourth doesn't, the fourth may have earned it.**
  Find out why before "fixing" it.

---

## Stay in scope

- **Touch only what your change needs.** No drive-by restyling, no fixing old code to match a rule you just read.
  Plenty of older code predates these rules, and rewriting it buries your real change in a huge diff.
- **Clean up what your own change made redundant.** A wrapper that's now one line, a flag nothing reads.
- **Code that looks unfinished may be in progress.** The shop is getting rewritten, for one.
  Ask in the draft PR before building on top of it.
- **Raise bugs you find, rather than fixing them on the side.** Trace each one end to end first.
  A confirmed bug is worth a short note in the PR, with a file and line.
  A guessed one costs more review time than it saves.

---

## Verify

- **Verify fixes, yours included.** A partial fix looks finished, which makes it worse than none.
- **Lint with `glualint`, not editor diagnostics.**
- **Hot paths run for every player, every frame.** Find the enclosing loop or hook before judging what a line costs.

---

## HUD and menus

Draw through the style system, never with hardcoded colors, fonts or sounds.
Why it matters is in DESIGN_GUIDELINES.md, "HUD and menus".

- **Panels:** build from the `glee_` panels in [lua/vgui/](lua/vgui/). They pick up their style from their parent.
- **Everything else:** get a handle with `terminator_Extras.glee_Style( "hl2" )`, and ask it for roles.
  `handle:Color`, `handle:Font`, `handle:Metric`, `handle:Draw`, `handle:PlaySound`.
  [cl_stylehandle.lua](lua/glee_hud/cl_stylehandle.lua) explains handles, [cl_style.lua](lua/glee_hud/cl_style.lua) explains styles.
- **Missing a role?** Add it to [cl_hl2.lua](lua/glee_hud/styles/cl_hl2.lua), the base every style inherits from.
  Don't reach for a `Color()` literal instead.

---

## Clientside models

Visuals stuck onto entities go through MyExtraModels, from the terminator addon.
See [its README](../terminator-hunter/README.md#entmyextramodels).
It's built on `ClientsideModel`, and was built with its limitations in mind.
It does all the messy parts for you, so read it before writing a `ClientsideModel` call yourself.

- **On an entity class:** set `ENT.MyExtraModels`, like [glee_heavyturret](lua/entities/glee_heavyturret/shared.lua).
- **On a weapon or viewmodel:** `terminator_Extras.DrawMyExtraModels` from its draw hooks, like [the tissue reclaimer](lua/weapons/glee_tissue_reclaimer/cl_beams.lua).
- **On a status effect's owner:** status effects already have this built in.
  `data.extraModels` in [cl_statuseffects.lua](gamemodes/hunters_glee/gamemode/modules/statuseffects/cl_statuseffects.lua),
  or `statusEffect:AddExtraModel` in [sh_statuseffectbase.lua](gamemodes/hunters_glee/gamemode/modules/statuseffects/sh_statuseffectbase.lua) when the model depends on the owner.

---

## Moving a model's materials under glee/

New materials belong under `materials/models/glee/`, see DESIGN_GUIDELINES.md, "Models and materials".
Moving the files there isn't enough, two kinds of file point at the old folder.

The recommended way is to have your contributor decompile and recompile the model with [Crowbar](https://developer.valvesoftware.com/wiki/Crowbar), pointing it at the new folder.
Editing the files directly, below, is an optional, experimental alternative.
Either way, the `.vmt` files still need repointing.

**The `.mdl`.** Its material folders are the last readable strings in the file.
`grep -aoE "[[:print:]]{4,}" model.mdl | tail` shows them:

```
ammo_crate_diff                       <- material names, leave these
models\props_downtown\ammo_crate\     <- the folder, relative to materials/
```

The `.mdl` finds its data by byte offsets, so the new folder can't be longer than the old one.
Pad a shorter one with null bytes, keeping the trailing backslash.
`models\glee\` is short, so this usually fits, `models\glee\ammo_crate\` is ten characters shorter here.
If it doesn't fit, pick a shorter folder name, or fall back to Crowbar.

**Every `.vmt`.** Each names its textures by path, like `$basetexture` and `$bumpmap`.
Repoint the ones you moved.
Some point at textures from the base game, or elsewhere, leave those be.

Then load the model in game.
A purple and black checkerboard means something is still pointing at the old folder.

---

## Comments

Ask of every comment: does this tell the reader something the code doesn't?

Worth a line:
- An invariant a future edit could quietly break.
- The why behind something that looks wrong, for whoever might undo it.
- Meaning for a bare number.

Not worth a line:
- Narrating your diff, like "changed X to Y" or "now uses Z". It means nothing once merged.
- Restating what the next line does.

When a function does need documenting, use the block in
[sh_statuseffectbase.lua](gamemodes/hunters_glee/gamemode/modules/statuseffects/sh_statuseffectbase.lua), like on `statusEffect:Hook`.
Most functions don't need one.

---

## Words

- **Shop item descriptions are tightly focused.** Don't edit one to mention a niche part of an item unless asked.
- **Never write "survivors".** Not in code, comments, docs or PR text. Players are Souls, they are Temporarily Bodied when alive.
- **Gameplay rules you're given are the whole rule.** Raise edge cases, don't invent extra restrictions.
