# Hunter's Glee Design Guidelines

What fits in Glee, and how to build it so it lasts.
These are the best practices that have worked well for the project so far.

---

## Does it fit the gamemode?

The best ideas make escaping feel even more meaningful.
Escaping is the miserable struggle at the heart of Glee.

For changes proposed to the project itself, it's worth looking at them from every angle.
Game design, balance, how players might abuse it, what it does to a round, and to the rounds after.

Money printers are a good cautionary tale.
They turned DarkRP into a money printer defense gamemode, and the RP got lost along the way.
It's worth asking whether an idea pulls players away from the struggle to escape.

This matters most for contributions directly to Glee.

### Treadmills in disguise

Some ideas quietly sign us up for more work every time something else gets added.
Those usually also mean it won't work with third party addons.

Say someone suggests an innate that detects landmines.
The first thought is a list of every landmine class.
But a "landmine" in Garry's Mod can be anything.
At most it'll have "mine" somewhere in its model or classname, and probably explode on death.
There are at least five different ways to make something explode on death, and classnames are never consistent.
The list would mean every addition after it, gets even more work.

[Sixth sense](lua/glee_shopitems/sh_sixthsense.lua) is a treadmill like this, and it's still in.
They can be added, they just need to be very worth it, like sixth sense is.

### Map treadmills

Ideas that need things placed by hand in certain maps won't be accepted.
This is the one hard rule here.

Adding a new map to a server should only ever take three steps:
1. Spawn into the map and fly around. Is it decent, or terrible?
2. Navmesh it with navmesh_optimizer, and make sure all the ladders and vents are generated. Optimize and save.
3. Load back into the map in the hunters_glee gamemode, and let it patch the map.
   If that takes too long, connect big groups of navareas. Save.

Anything that adds a fourth step is a treadmill for every server, on every map.

Say someone suggests bursting steam pipes.
They'd have to spawn randomly, on any map.
That means traces across the whole map, hunting for materials with "pipe" in the name,
and it'd still get it wrong somehow.
If an idea can't work on any map without hand placement, it doesn't fit.

---

## Where to start

Bargains and Miseries (spawnsets) are the most expandable systems.
They make great first PRs.

- Miseries: README, "Adding Spawnsets". Examples live in [lua/glee_spawnsets/](lua/glee_spawnsets/).
- Bargains and other shop items: README, "Adding Shop Items".

### Things the dead and escaped can spawn

The most valuable place to add something, and the most challenging.
Being dead is the most interesting and novel part of Glee, the ghost shop especially.

The dead shop has two kinds of item.
- **Sacrifices** can be profitable, they can make ghosts money.
- **Gifts** are ways for ghosts to apply influence.

The best of either are neutral parties, that get the living interacting.
They're also the hardest to come up with.
A Door Locker can help someone fleeing a hunter, or trap them.
Supplies help whoever gets there first. (A player, or a terminator?)
ETC.

Abuse is usually handled with cost, not hard caps.
Placing near the living, near clutter, or over and over gets more expensive.

Escaped players get **[Horrors](lua/glee_shopitems/sh_default_horrors.lua)**, on top of the rest of the dead shop.
They have the power to end or continue the round at will.
Every Horror is a reward for escaping, the most difficult part of Glee.
Horrors should reward their escaped placers with power or profit. (both at once?)

Most dead shop items are built on `screamer_crate`, see [sh_default_hauntingitems.lua](lua/glee_shopitems/sh_default_hauntingitems.lua)
and `shopHelpers.setupPlacable` in the README.

### Shop real estate

> Remove this section after the shop rewrite.

The shop is crowded right now.
Each new item, mutations included, makes the other options a little less valuable.
Bargains, Miseries and bank items don't have this problem.

### Bind real estate

Free keybinds are scarce too.
An addition that takes up a bind works best when it solves some bigger existing problem.

---

## Finding the right home for it

Glee often already has a system for what you're after.
Building on it tends to go better than a standalone autorun file.

Randomly spawning things is a good example, there are three ways:
- **Terminator events**, `lua/terminator_events/`, for rare spawns in the background.
- **The generic spawner**, `GAMEMODE:RandomlySpawnEntTbl`, for fire and forget random SENT spawns.
  See the example at the bottom of [sv_genericspawner.lua](gamemodes/hunters_glee/gamemode/modules/proceduralspawner/sv_genericspawner.lua).
- **The procedural spawner**, `GAMEMODE:addProceduralSpawnJob`, the full API the generic spawner is built on.
  It gives you real control over where and how things spawn.
  The beartrap, crate and flare spawners next to it are working examples.

Often the whole change fits in one hook, or one new folder in `gamemode/modules/`.

### Inside the gamemode, or outside it

- `gamemodes/hunters_glee/` holds Glee-specific code, and the entities that only make sense in Glee.
- `lua/` holds what should also work outside Glee.

Glee's weapons live in `lua/weapons/` so players can use them in sandbox and other gamemodes.
Support out there is limited, but the weapons themselves should work.
Some are tied to Glee's systems by design, like the tissue reclaimer, and that's fine.

### HUD and menus

Everything Glee draws on screen goes through the style system, in [lua/glee_hud/](lua/glee_hud/).
It's what gives Glee one consistent look, the HL2 HUD while alive, soulthought while dead.
A color, font or sound changed in a style changes everywhere that uses it.
High contrast mode and switching styles on death come along for free.

A hardcoded `Color()` or font opts out of all of that, and becomes one more thing to hunt down next time the look changes.

### Models and materials

New models go under `models/glee/`, and their materials under `materials/models/glee/`.

Overriding base game models, or another addon's, is best avoided.
Keeping everything under `glee/` means we rarely conflict with other addons.

It's easy to assume you can just move a model's materials to a new folder.
You can't, a model finds its materials through a path hardcoded inside the `.mdl` file, its [$cdmaterials](https://developer.valvesoftware.com/wiki/$cdmaterials).
Moving them means editing that path in the file itself,
or decompiling and recompiling the model with [Crowbar](https://developer.valvesoftware.com/wiki/Crowbar).

### File size

Every player downloads all of Glee, so every megabyte counts.
A small change or a single weapon shouldn't bring a mountain of models, materials and textures with it.
Around 1 to 5 MB per weapon is ideal.

Big additions can still be worth it, the music update was.
They just need to earn their size.

### New enemies

New enemies work best built on the terminator base, `ENT.Base = "terminator_nextbot"`.
Spawnsets, the shop, status effects and plenty more expect it.
[terminator_nextbot_infernalskeleton.lua](lua/entities/terminator_nextbot_infernalskeleton.lua) is a working example.

---

## Things that break quietly

### Prediction

Every existing weapon holds up at high ping, with no prediction errors.
It'd be great to keep that streak going.
`net_fakelag 50` in console simulates 100 ping, and is a good test.

Movement mechanics are especially fickle with prediction, so they're worth extra testing.

### Hot hooks

A hook that runs all the time costs something every frame, for every player.
`GM:Move` and its family, `Think`, `Tick`, `OnEntityCreated`, `EntityTakeDamage`, things like that.
It's worth checking whether a rarer hook can do the job.
When it really does need to be hot, keeping the work inside it small goes a long way.
Use termhunt_hands's running code as an example of correctly managed expensive logic that always runs in the background.
