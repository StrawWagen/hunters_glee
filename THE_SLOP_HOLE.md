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
- **Build it the way Glee already builds that kind of thing.** If something similar exists, make sure you don't miss the lessons of the past.
  Each choice in it was likely made for a reason, so learn the reason, not just the shape.
  For example, shop items, music and spawnsets are all loaded from `lua/glee_*/` the same way.
  [sv_shopgobbler.lua](gamemodes/hunters_glee/gamemode/modules/shopitems/sv_shopgobbler.lua) and the other loaders explain why in comments.
- **Never fully trust a name or a comment.** Read the function, and what it calls.
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

## gmod_admin_cleanup and autorefresh

Glee is ideally developed without restarting the session.
Restarting means reloading all lua for every change, depending on hardware and addon count, this can take ages.

### gmod_admin_cleanup is Glee's reload button

Changed a shop item, misery, role etc? Run `gmod_admin_cleanup`, not a restart.
When you hand a change to your contributor to test, that's the step you give them.

Anything that's loaded using the "gobbling" pattern will re-gobble on gmod_admin_cleanup
- **Shop items**, from `lua/glee_shopitems/`.
- **Miseries**, from `lua/glee_spawnsets/`, gobbled and baked again, and the running one starts fresh.
- **Roles**, from `lua/glee_spawnsetroles/`.
- **Music**, from `lua/glee_music/`.

Then the whole gamemode sets up again, players included.
Every entity the map didn't spawn is removed, and the map's own come back fresh.

- **Saving one of those files does nothing on its own, on purpose.** The gobblers use `CompileFile`, not `include`.
  That's so saving a shop item doesn't autorefresh the whole gamemode, see [sv_shopgobbler.lua](gamemodes/hunters_glee/gamemode/modules/shopitems/sv_shopgobbler.lua).
  The "Gobbled late" warning is telling you to run `gmod_admin_cleanup`, don't work around it.
- **Anything new and extensible should reload the same way.** Load it like the gobblers do, so `gmod_admin_cleanup` picks it up.
  A registry built once when its file loads goes stale, and only a restart fixes it.
- **Make it a real fresh start.** Lua state isn't touched, tables, timers and hooks all carry on.
  State that outlives the entities leaks into the next test.
  Reset it on `glee_post_realcleanupmap`, like the rescue heli's timer in [sv_rescuehelicall.lua](lua/glee_flight/rescueheli/sv_rescuehelicall.lua).
  Not `PostCleanupMap`, Glee's round reset cleans up the map too, so that runs every round.
- **Tables of entities end up holding removed ones.** Store per entity state on the entity, it goes when the entity does.
  If it has to be a table, use weak keys, or clear it on cleanup.

### Autorefresh

For everything else, like entities, weapons and the gamemode's own files, saving is enough.
Autorefresh runs the saved file again, top to bottom, with everything already spawned still around.

- **File level `local` state starts over.** Whatever it was tracking gets forgotten, and the stuff already spawned breaks.
  Keep that state on a table that survives the reload, and take a local to it.
  Like [sv_rtm.lua](gamemodes/hunters_glee/gamemode/modules/spawnset/vote/sv_rtm.lua):
  ```lua
  local RTM = GM.glee_RTM or {}
  GM.glee_RTM = RTM
  ```
  It's all over Glee, on `GM`, or on `terminator_Extras` for files outside the gamemode.
- **The local is there for speed, where speed matters.** `GAMEMODE.glee_RTM` is two table lookups, every time it runs.
  `RTM` is a local, and costs next to nothing.
  In a hook that runs constantly, like `EntityFireBullets` or `Think`, that adds up.
  In code that runs once a round, or when someone buys something, it doesn't.
  There, reading `GAMEMODE.glee_RTM` directly is fine, and one less thing to keep track of.
  If you do take a local, empty the table in place, never swap in a new one, or the local is left holding the old table.

---

## HUD and menus

Draw through the style system, never with hardcoded colors, fonts or sounds (rare exceptions are acceptable, but should be earned).
Why it matters is in DESIGN_GUIDELINES.md, "HUD and menus".

- **Panels:** build from the `glee_` panels in [lua/vgui/](lua/vgui/). They pick up their style from their parent.
- **Everything else:** get a handle with `terminator_Extras.glee_Style( "hl2" )`, and ask it for roles.
  `handle:Color`, `handle:Font`, `handle:Metric`, `handle:Draw`, `handle:PlaySound`.
  [cl_stylehandle.lua](lua/glee_hud/cl_stylehandle.lua) explains handles, [cl_style.lua](lua/glee_hud/cl_style.lua) explains styles.
- **Use the roles that are already there.** A role names what something means, not where it's drawn.
  `text` is Glee talking, `alert` is "needs you now". Map what you're building onto those.
  How faint something is belongs in your drawing code, as a share of the role's alpha, not in a new colour.
- **Wanting a new role is a warning sign.** If you catch yourself porting a colour or a font into a style, stop and ask:
  why am I building something that doesn't match Glee's look? How do I make it fit the minimalist language already here?
  Turning your own palette into roles doesn't get rid of a single literal, it just moves them.
  Every style but hl2 then draws your feature in hl2's colours, and the look stops being one look.
- **A new role is a last resort**, for a meaning Glee has no word for yet.
  Add it to [cl_hl2.lua](lua/glee_hud/styles/cl_hl2.lua), the base every style inherits from, and give the other styles their own take on it.

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

## Looping sounds on weapons

```lua
function SWEP:StopHum()
    if self.glee_hum then
        self.glee_hum:Stop()
    end
    self.glee_hum = nil
end

-- every tick
function SWEP:UpdateHum()
    if not self:ShouldHum() then
        self:StopHum()
        return
    end
    if self.glee_hum and self.glee_hum:IsPlaying() then return end

    self:StopHum()
    self.glee_hum = CreateSound( self, humPath )
    self.glee_hum:Play()
end
```

A looping sound plays until something stops it.
Not when the weapon is holstered, dropped or removed, and never on its own.
A missed stop is a sound stuck in someone's ears for the rest of the round, so Glee's weapons stop loops militantly.

The [tissue reclaimer](lua/weapons/glee_tissue_reclaimer/cl_draw.lua) is the one to copy, it's built like [the heavy turret's](lua/entities/glee_heavyturret/shared.lua) hums.

- **Every tick, work out what should be playing, and make it so.** Don't start a loop on one event and trust another to stop it.
  `WantedLoops` says what should be going, `UpdateLoopSounds` starts, retunes or stops to match.
- **Restart anything that isn't playing.** The engine drops loops out from under you, `stopsound` for one.
  `IsPlaying()` coming back false means build a fresh one.
- **Stopping and forgetting go together.** One stop function stops the sound and nils the field, so the next check starts clean.
- **Call it from every way the weapon goes quiet.** `Holster`, `OnDrop`, `OwnerChanged`, `OnRemove`, and having nothing to do.
  Like `KillSound` in [the tau cannon](lua/weapons/termhunt_taucannon/shared.lua#L238), and `KillSizzle` in [the AR3](lua/weapons/termhunt_ar3.lua#L222).
- **A loop made on the owner is on the player, not the weapon.** `CreateSound( owner, ... )` doesn't care that the weapon is gone.
  The tau cannon and AR3 back their stop up with a `CallOnRemove` on the weapon.
- **Loops other players hear go clientside.** A serverside loop only reaches whoever was in earshot when it started.
  Clientside, nothing else stops the loop on a kit somebody stopped holding.
  So a `Think` [checks every held kit](lua/weapons/glee_tissue_reclaimer/cl_draw.lua#L393), and stops any that were sounding last time but aren't held now.
- **Retune only on a change.** Each `ChangePitch` or `ChangeVolume` starts its slide over.
- **`sound.PlayFile` loops are their own thing.** For a hum on its own channel, like the goggles'.
  When the file runs out the channel stops, `GetState()` is `GMOD_CHANNEL_STOPPED`, start it again.
  It loads in the background, so don't start a second while the first is loading, and check it's still wanted when it arrives.
  [glee_nvg_base/cl_init.lua](lua/weapons/glee_nvg_base/cl_init.lua#L260) does both.

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

## Status effects

Anything a player has for a while is a status effect. An item's ongoing effect, a bargain, a debuff.
README.md, "Status Effects", has the API. These are the parts that trip people up.

- **Hooks and timers go through the effect.** `self:Hook`, `self:HookOnce`, `self:Timer`, never a file level `hook.Add`.
  Removing the effect removes them.
- **Both just make a hook.** It fires for everything that runs it, not only whoever has the effect.
  Check inside the hook that you've got the right target.
- **`self:Hook` makes one per effect.** Ten players with it, ten hooks. Check the target against `owner`.
- **`self:HookOnce` makes one, as long as anything has the effect.** Only the first effect's function is added, every later one's is thrown away.
  So `owner`, `self` and setup's locals belong to whoever got it first, and they may not even have it anymore.
  Check the target with `ply:HasStatusEffect( name )` instead, and get its own effect with `ply:GetStatusEffect( name )`.
  Like `mecha_legs` in [sh_default_innate.lua](lua/glee_shopitems/sh_default_innate.lua).
- **Pick `HookOnce` for hooks that fire constantly.** Think, footsteps, drawing. `Hook` for rare ones.
- **Players keep effects through death.** Unless `self:SetPlyRemoveOnDeath( true )`.
  NPCs always lose them, because they're removed when they die.
- **`GiveStatusEffect` runs setup, then hands back the effect.** Anything you set on it afterwards isn't there during setup, only in later hooks and timers.

Clientside is its own registration, `RegisterStatusEffect` again inside `if CLIENT then`.
Effects are only given on the server, the client's copy sets up and tears down as the server's comes and goes.
See [cl_statuseffects.lua](gamemodes/hunters_glee/gamemode/modules/statuseffects/cl_statuseffects.lua).

- **Setup runs for every entity with the effect, not just you.** HUD stuff checks `LocalPlayer() ~= owner` first.
- **The client's effect is its own copy.** Anything set on the server's effect isn't on it, network what the client needs yourself.
- **`HasStatusEffect` works everywhere.** Even for effects with no client registration, it reads a networked bool.
  `GetStatusEffect` only returns something when the client registered the effect too.

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

## Other addons' entities

```lua
SWEP.SpecialInteractions = {
    ["evil_fungus"] = {
        find = function( tr ) ... end,
        primaryAttack = function( wep, ent, tr ) ... end,
    },
}
```

Glee handles another mod's entities with a table keyed by classname, each entry saying what to do with that class.
The mod never has to be installed.
A key is only a classname, nothing loads the other addon, and an entry for a class that never spawns does nothing.

- **Check before you touch.** Every entry checks the other addon's globals, fields and methods exist before using them.
  `EvilCrawler and ent.GetAct and ...`, never straight to `ent:GetAct()`. Their addon updates without asking you.
- **Add an entry, not a branch.** A new mod's entity is a new key in the table, not an `if class == ...` in the middle of the code.
- **What it's drawn as isn't what it is.** Custom meshes are common. The model can be a stand-in, the evil crawler's is a popcan.
  Traces hit what it collides with, which can be far smaller than what's drawn.
- **It won't be an NPC or a nextbot.** `IsNPC`, `IsNextBot` and `Health` checks miss most custom creatures, they track being alive their own way.

The ones to copy:
- [The tissue reclaimer's SpecialInteractions](lua/weapons/glee_tissue_reclaimer/shared.lua#L519), what its click does to them.
- `otherAlive` beside `terminator_Extras.glee_IsAliveThing`, in [sh_glee_functions.lua](lua/autorun/sh_glee_functions.lua), what counts as alive for the goggles.

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
