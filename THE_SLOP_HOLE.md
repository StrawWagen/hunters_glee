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
