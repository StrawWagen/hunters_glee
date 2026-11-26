# Contributing to Hunter's Glee

Thanks for wanting to help!

Have an idea? Read [DESIGN_GUIDELINES.md](DESIGN_GUIDELINES.md) first, it covers what fits in Glee.
Want to add content? The [README](README.md) documents miseries, shop items and status effects.
Using an AI agent? Point it at [THE_SLOP_HOLE.md](THE_SLOP_HOLE.md) too.
AI-written PRs get held to a higher bar, so keep them small, and make sure you understand every line.

---

## Open a draft PR early

A draft PR with a rough idea and a few lines of code is a great place to start.
Conflicts and structure questions are easy to sort out early,
and much harder after hours of work are built on top of them.

---

## Code style

Glee doesn't strictly follow a style guide,
but the [CFC GLua style guidelines](https://github.com/CFC-Servers/cfc_glua_style_guidelines) are a good reference.
When in doubt, match the code around you.
Run [glualint](https://github.com/FPtje/GLuaFixer) with `glualint lint <files>` on what you touched.
It picks up the settings in [glualint.json](glualint.json) automatically.

A few things specific to Glee:
- **Mirror `send.txt`.** Every gamemode file sent with `AddCSLuaFile` (`cl_` and `sh_`) also goes in
  [gamemodes/hunters_glee/send.txt](gamemodes/hunters_glee/send.txt), grouped with its module.
  `sv_` files don't.
- **`NetworkVar( "Type", "Name" )`, no slot numbers.**
  Entities derived from `terminator_nextbot` are the exception, they keep their slots.
- **Status effects use `effect:Hook` / `effect:HookOnce`**, not a file-level `hook.Add`.
  That way the hook goes away with the effect.

---

## Before you mark it ready

- [ ] Tested in-game, in the hunters_glee gamemode
- [ ] Weapons and movement tested with `net_fakelag 50`, no prediction errors
- [ ] `glualint lint` is relatively clean on the files you touched
- [ ] `send.txt` updated for new client files
- [ ] README updated if you changed an extension point
