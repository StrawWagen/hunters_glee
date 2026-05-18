# Hunter's Glee

A **PVPVE survival gamemode** for Garry's Mod.

It's you (and your friends?) versus a variety of relentless enemies. Get close to hunting NPCs to earn score, then spend it all in the shop on weapons, beartraps, innate upgrades, and more.

Collect skulls from dead enemies and players to purchase rare, heavy weapons.
Or even to eventually escape...

But it gets better: **the fun really begins when you die**. As a ghost, you unlock a whole new shop selection. Lock doors, place traps for your friends, or build a tempting supply room rigged with explosive barrels!

Spawn. Buy. Escape? or Die.

> 🎮 [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2848253104)

---

## Project Structure

```
hunters_glee/
├── gamemodes/hunters_glee/gamemode/   # Core gamemode logic
├── lua/
│   ├── glee_shopitems/                # Shop item definitions (auto-loaded)
│   ├── glee_spawnsets/                # Enemy spawnset definitions (auto-loaded)
│   ├── entities/                      # Custom entities
│   ├── weapons/                       # Custom weapons
│   └── effects/                       # Visual effects
├── materials/                         # Textures and UI assets
├── models/                            # 3D models
└── sound/                             # Audio files
```

---

## Contributing

Hunter's Glee is designed to be extensible. The two main ways to add content are **shop items** and **spawnsets**.

### Adding Shop Items

Shop items are defined in `lua/glee_shopitems/`. Files are auto-loaded based on their prefix:
- `sh_` - Shared (runs on both client and server)
- `sv_` - Server only
- `cl_` - Client only

You can split logic between client and server.
Just variables starting with sv( svOnPurchaseFunc ) have to be defined on server!

#### Minimal Example

```lua
-- lua/glee_shopitems/sh_my_items.lua

local shopHelpers = GAMEMODE.shopHelpers

local items = {
    ["my_item_id"] = {
        name = "My Item",
        desc = "A description of what this item does.",
        shCost = 50,
        tags = { "ITEMS", "Weapon" },  -- Category tag, and misc tag (see below)
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,  -- Buyable during preparation
            GAMEMODE.ROUND_ACTIVE,    -- Buyable during the hunt
        },
        shPurchaseCheck = shopHelpers.aliveCheck,  -- Must be alive to buy
        svOnPurchaseFunc = function( purchaser )
            -- Server-side logic when purchased
            -- use the purchaseWeapon helper
            -- it gives the ply the weapon if they dont have it, 
            -- or gives them ammo if they already have it,
            -- and plays a sound!
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_smg1",
                ammoType = "SMG1",
                purchaseClips = 2,      -- Extra Clips given on first purchase
                resupplyClips = 4,      -- Clips given on repurchase
                confirmSoundWeight = 1, -- sound intensity
            } )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )
```

#### Shop Item Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Display name in the shop |
| `desc` | ✅ | Description (string or function) |
| `shCost` | ✅ | Cost in score (negative = gives score) |
| `tags` | ✅ | Category tags as indexed table, Capitalized tags define the item's categories (e.g., `{"ITEMS", "Weapon"}`) |
| `purchaseTimes` | ✅ | When purchasable: `ROUND_INACTIVE`, `ROUND_ACTIVE` |
| `svOnPurchaseFunc` | ✅ | Server function called on purchase: `function(purchaser, itemId)` |
| `shSkullCost` | ❌ | Skull cost. Accepts number or function. Zero is ignored. Negative gives skulls on purchase |
| `shPurchaseCheck` | ❌ | Validation function(s): `function(purchaser) -> bool, reason` |
| `markup` | ❌ | Price multiplier during active hunt |
| `markupPerPurchase` | ❌ | Additional markup per purchase |
| `cooldown` | ❌ | Seconds between purchases (`math.huge` = once per round) |
| `weight` | ❌ | Sort order within category (lower = higher) |
| `shCanShowInShop` | ❌ | Visibility function: `function(purchaser) -> bool` |
| `costDecorative` | ❌ | Fake, decorative cost. Accepts string, number, tables of strings, functions. Overrides `shSkullCost`, and `shCost` |
| `unpurchaseableReason` | ❌ | Custom denial string. Only used if the item has the `unpurchaseable` tag |
| `identifier` | ❌ | Auto-generated. The item's unique key |

#### Category Tags

Items appear in categories based on their first matching tag:

| Tag | Category | Visibility |
|-----|----------|------------|
| `ITEMS` | Items | Alive players |
| `INNATE` | Innate | Alive players |
| `BARGAINS` | Bargains | Alive players |
| `DEADSACRIFICES` | Sacrifices | Dead players |
| `DEADGIFTS` | Gifts | Dead players |
| `BANK` | Bank | All players |

Additional descriptive tags (e.g., `"Weapon"`, `"Utility"`) don't affect categorization.

Some other tags automatically apply special properties to items:

- `unpurchaseable`
    - Causes the item to be completely unpurchaseable, but doesn't hide it from the shop.
    - Good for using a shop slot to display information rather than provide an item.
    - Adding the `unpurchaseableReason` field to the item will let you override the fail reason string.

#### Shopping Helper Functions

`GAMEMODE.shopHelpers` provides common utilities:

```lua
shopHelpers.aliveCheck( purchaser )      -- Returns true if alive
shopHelpers.deadCheck( purchaser )     -- Returns true if dead
shopHelpers.isCheats()                 -- Returns true if sv_cheats is on
shopHelpers.purchaseWeapon( purchaser, {
    class = "weapon_smg1",
    ammoType = "SMG1",
    purchaseClips = 2,      -- Clips given on first purchase
    resupplyClips = 4,      -- Clips given on repurchase
    confirmSoundWeight = 1, -- Gun cock sound intensity
} )
```

### Shopping Hooks

Additional ways to control access to shop items.

- `allow`, `failReason` = `glee_shop_canshow`( `ply`, `itemData` )
  - Return `false`, `failReason` to block the item from showing.
  - Behaves similarly to `shCanShowInShop`, but called on a global scale and with reference to the item.
- `allow`, `failReason` = `glee_shop_canpurchase`( `ply`, `itemData` )
  - Return `false`, `failReason` to block the item from being purchased.
  - Behaves similarly to `shPurchaseCheck`, but called on a global scale and with reference to the item.
- `newDescription` = `glee_shop_itemdescription`( `ply`, `itemData`, `description` )
  - Return `newDescription`, to override the item description.
  - Remember, only one hook listener can return non-nil at a time!

Example:

```lua
hook.Add( "glee_shop_canshow", "i_really_hate_debuffs", function( ply, itemData )
    if itemData.tags.Debuff then return false, "Debuffs are LAME" end

end )

```


---

### Adding Spawnsets

Spawnsets are the #1 way to change up the hunt.
They're defined in `lua/glee_spawnsets/` and auto-loaded.
Third party addons can define their own spawnsets, they just have to be in the right spot.

#### Spawnset Example A: Your first spawnset

```lua
-- lua/glee_spawnsets/my_spawnset.lua

local mySpawnSet = {
    name = "my_spawnset",                       -- Unique identifier
    prettyName = "My Custom Mode",              -- Display name
    description = "It's my mode, it's custom!", -- Description, best used as a "hint" that teases the spawnset's content
    
    -- Use "default" to inherit base values, or "default*2" for multipliers
    -- Difficulty is very dynamic, so it's best to use "default" or multipliers of it,
    -- unless you know what you're doing. 
    difficultyPerMin = "default",
    waveInterval = "default",
    startingBudget = "default",
    maxSpawnCount = 4, -- 4 is pretty low, easy
    
    spawns = {
        {
            name = "hunter",                           -- Unique spawn identifier
            prettyName = "A Hunter",                   -- Display name
            class = "terminator_nextbot_snail",        -- Entity class to spawn
            spawnType = "hunter",                      -- Spawn algorithm type, only "hunter" is supported
            difficultyCost = { 10, 15 },               -- Cost range (random)
            countClass = "terminator_nextbot_snail*",  -- Pattern for counting (* = wildcard)
            minCount = { 1 },                          -- Always maintain this many
        },
        {
            hardRandomChance = { 5, 20 },              -- Only pick this x% of waves
            name = "hunter",
            prettyName = "A Scary Hunter",
            class = "terminator_nextbot",              -- Spawns the "overcharged" terminator
            spawnType = "hunter",
            difficultyCost = { 25, 50 },
            difficultyNeeded = { 50, 100 }             -- only consider spawning this after 5 - 10 minutes
            countClass = "terminator_nextbot_snail*",
            maxCount = { 1 },                          -- Never exceed this many
        },
    },
}

table.insert( GLEE_SPAWNSETS, mySpawnSet )
```

#### Spawnset Values

I had a problem when developing this.
Each round was feeling the same,
and I was updating spawnset values all over the place.
My solution? Dynamic values.

Values can be:
- `"nil"` -- Use base spawnset value
- `"default"` - Explicity use base spawnset value
- `"default*N"` - Multiply base value by N
- `{ min, max }` - Random value in range is chosen at the start of each round.
- `Direct number` - 8, 10, 11.25, etc ( not recommended, random value in range is much more fun )

#### Spawnset Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Unique identifier, should match filename |
| `prettyName` | ✅ | Display name for voting/UI |
| `description` | ✅ | Description shown to players |
| `spawns` | ✅ | THE indexed table of potential spawns ( see below ) |
| `difficultyPerMin` | ❌ | How fast difficulty scales |
| `waveInterval` | ❌ | Time between spawn waves, skipped if all hunters are cleared |
| `diffBumpWhenWaveKilled` | ❌ | Difficulty boost when wave cleared |
| `startingBudget` | ❌ | Initial spawn budget |
| `spawnCountPerDifficulty` | ❌ | Spawns per difficulty point |
| `startingSpawnCount` | ❌ | Initial spawn count |
| `maxSpawnCount` | ❌ | Hard cap on enemy count |
| `maxSpawnDist` | ❌ | Hard cap on the dynamically marching spawn distance |
| `roundStartSound` | ❌ | Sound on round start |
| `roundEndSound` | ❌ | Sound on round end |
| `genericSpawnerRate` | ❌ | Crate/item spawn rate multiplier |
| `chanceToBeVotable` | ❌ | Percent chance to appear in !rtm vote, 0-100, accepts float |

#### .spawns Entries

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Unique identifier for this spawn entry |
| `prettyName` | ✅ | Display name |
| `class` | ✅ | Entity class to spawn |
| `spawnType` | ✅ | Spawning algorithm type, only supports `"hunter"` presently |
| `difficultyCost` | ✅ | Budget cost to spawn |
| `countClass` | ✅ | Class pattern for counting ( `*` = wildcard ) |
| `difficultyNeeded` | ❌ | Difficulty threshold needed to start spawning | 
| `minCount` | ❌ | Minimum maintained count |
| `maxCount` | ❌ | Maximum allowed count |
| `hardRandomChance` | ❌ | percent chance to even consider |
| `preSpawnedFuncs` | ❌ | Functions called before hunter:Spawn() : `function(spawnData, npc)` |
| `postSpawnedFuncs` | ❌ | Functions called after hunter:Spawn() : `function(spawnData, npc)` |
| `isBoss` | ❌ | `true` marks as boss; `false` opts out of auto-detection. When the boss is killed, all alive players escape. Auto-detected when `spawnSet.maxSpawnCount <= 1` (highest `difficultyCost` entry becomes boss). |

#### Spawnset Example B: Functions on spawn!

```lua
-- lua/glee_spawnsets/the_true_machine.lua

local function applySynthflesh( spawnData, npc )
    npc:SetMaterial( "phoenix_storms/wire/pcb_red" )

end

local function announceArrival( spawnData, npc )
    huntersGlee_Announce( player.GetAll(), 100, 10, "The facade is gone.\nOnly the machine remains." )

end

local trueHorror = {
    name = "the_true_machine",
    prettyName = "The True Machine",
    description = "They've stopped pretending to be human.",
    difficultyPerMin = "default*1.5",
    waveInterval = "default",
    startingBudget = "default",
    maxSpawnCount = 6,
    chanceToBeVotable = 10,
    
    spawns = {
        {
            name = "synthflesh_terminator",
            prettyName = "Synthflesh Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 12, 18 },
            countClass = "terminator_nextbot_snail*",
            minCount = { 1 },
            postSpawnedFuncs = { applySynthflesh, announceArrival }, -- run both of these after the ent's :Spawn is called
        },
    },
}

table.insert( GLEE_SPAWNSETS, trueHorror )
```

---

## Round States

Referenced throughout the codebase:

| Constant | Value | Description |
|----------|-------|-------------|
| `GAMEMODE.ROUND_INVALID` | -1 | Missing navmesh |
| `GAMEMODE.ROUND_SETUP` | 0 | Initial setup |
| `GAMEMODE.ROUND_ACTIVE` | 1 | Hunt in progress |
| `GAMEMODE.ROUND_INACTIVE` | 2 | Preparation phase |
| `GAMEMODE.ROUND_LIMBO` | 3 | Displaying winners |

---

## License

See [LICENSE](LICENSE) for details.

---

*Hunter's Glee is a passion project: a fantastic testbed for new ideas and always a great laugh. Contributions welcome!*