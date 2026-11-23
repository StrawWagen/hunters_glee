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

## Player spawns

`PlayerSpawn` runs on every `ply:Spawn()`, including ones that aren't a new life.
`glee_EarnedPlayerSpawn` runs only on the first spawn after a death, or after joining.
It's fired from `GM:PlayerSpawn` in [sv_player.lua](gamemodes/hunters_glee/gamemode/sv_player.lua).

- **`glee_EarnedPlayerSpawn`, for a new life.** Handing out items, resetting per-life state, rolling something fresh.
  Like `glee_spawnweapons` in [sv_spawnweapons.lua](gamemodes/hunters_glee/gamemode/modules/spawnset/runtime/sv_spawnweapons.lua), or the tumor in [sh_default_bargains.lua](lua/glee_shopitems/sh_default_bargains.lua).
  On `PlayerSpawn`, these would hand out twice, or reset mid-life.
- **`PlayerSpawn`, for re-applying what every spawn wipes.** Model, speed, bone manips, open menus.
  Like `big_head`, also in sh_default_bargains.lua.
  On `glee_EarnedPlayerSpawn`, these would quietly fall off after a spawn that wasn't a new life.

Both run before `GM:PlayerSpawn` sets the model and loadout, and before the player is moved to their spawn point.
Anything that depends on those waits a tick, like `big_head` does.

---

## Stacking modifiers

Max health, run speed and bone manips are shared by everything that changes them.
Each source sets its own keyed entry, and the result is all of them combined.
Setting the value directly gets overwritten, or overwrites someone else's.
README.md, "Stacking modifiers", lists them all.

- **Pick a key only your feature uses.** Two sources on one key overwrite each other.
- **Take your entry off when you're done.** Entries live on the entity, and survive death.
- **Max health:** `DoMaxHealthMul` and friends, never `SetMaxHealth` on players.
  Base health comes from the playermodel's size, don't assume 100.
- **Run speed:** `DoSpeedModifier`, never `SetRunSpeed`.
  `DoSpeedClamp` is an offset from the default speed, not an absolute max.
  Run speed isn't top speed, sprinting on [the hands](lua/weapons/termhunt_hands/shared.lua) goes up to 200 past it.
- **Bones:** `ApplyBoneScaleManip` and friends, server only.
  Plain `ManipulateBone*` calls are overridden, and every one of them shares the `"default"` key.
  So setting a bone back to scale 1 only clears `"default"`, every other key's entry stays on it.
  Clientside, `ManipulateBone*` is the engine's, nothing is keyed.
- **These only exist in the gamemode.** lua/weapons and lua/entities load outside it too.
  Code there that can run in sandbox needs a fallback, like [termhunt_divine_chosen](lua/weapons/termhunt_divine_chosen/shared.lua).

---

## Engine calls Glee has its own version of

The engine's call still works, but skips something Glee relies on.

- **Healing:** `ply:AddHealth( amount, reason )`, or `AddOverhealableHealth` to go past max.
  A bare `SetHealth` heal skips `glee_blockaddhealth`, which some bargains use to stop healing.
  Taking health from someone to give it to someone else? Check `CanAddHealth` first.
  All three are in [sv_player.lua](gamemodes/hunters_glee/gamemode/sv_player.lua).
- **Setting health yourself:** set `ply.glee_LastSetHealthReason` alongside it, it's how a debugger finds who did it.
- **Fire:** `ent:Ignite( length, radius, attacker, inflictor )`.
  Naming who lit it is how guilt, summoner relief and the killfeed credit fire kills.
  Without one, the flame has to guess, see [sv_blamedfire.lua](gamemodes/hunters_glee/gamemode/modules/blame/sv_blamedfire.lua).
- **Dropping weapons:** `ply:DropWeaponKeepAmmo( wep )`, or `DropActiveWeaponKeepAmmo`, which has the guards.
  A plain `DropWeapon` leaves the ammo behind with the player, instead of in the weapon.
  See [sv_weapondropper.lua](gamemodes/hunters_glee/gamemode/modules/weapondropper/sv_weapondropper.lua).
- **Stripping weapons:** `StripWeapons` runs `glee_PreStripWeapons` first.
  Hook that for anything that should leave the player's hands, instead of vanishing with them.

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
