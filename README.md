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
│   ├── glee_spawnsets/                # Enemy spawnset(misery) definitions (auto-loaded)
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
| `shPurchaseCheck` | ❌ | Validation function(s): `function(purchaser) -> bool, reason`, must return true for purchase to be allowed |
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
  - Use this hook if you want to programatically make, all items with X tag not purchasable, etc. 
  - DONT use this to define when a single item will be purchasable. Use `shopItem.shPurchaseCheck` to manage that.
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

### Status Effects

A status effect is a named bundle of hooks and timers living on one player.
It's the best way to modify player stats, behaviour.
Used by innate items, spawn protection, etc.
The point is teardown: you never have to remember the hook identifiers or timer names you made, removing the effect removes all of them.

Register the effect once at load time, then hand it out at runtime:

```lua
if SERVER then
    GAMEMODE:RegisterStatusEffect( "caffeinated",
        function( self, owner ) -- setup
            owner:DoSpeedModifier( "caffeinated", 100 ) -- speed boost

            self:Timer( "the_jitters", 3, 0, function() -- play a random sound on em
                owner:EmitSound( "buttons/blip1.wav", 60, math.random( 90, 130 ) )

            end )

            -- example of statusEffect:Hook, creates a hook for everyone with this statuseffect
            self:Hook( "PlayerSay", function( speaker, text )
                if speaker ~= owner then return end -- every effect gets a hook

                return string.upper( text ) .. "!!!"

            end )

            -- example of statusEffect:HookOnce, creates only 1 hook, cleans it up when nobody has the status effect anymore
            self:HookOnce( "PlayerFootstep", function( ply )
                if not ply:HasStatusEffect( "caffeinated" ) then return end -- only one hook exists, owner is useless

                ply:EmitSound( "buttons/blip1.wav", 50, 140 )

            end )
        end,
        function( _, owner ) -- teardown, optional
            owner:DoSpeedModifier( "caffeinated", nil ) -- back to normal speed

        end
    )

    ply:GiveStatusEffect( "caffeinated" )
end
```

The timer and both hooks are removed for you when the effect is. Only write a teardown
func for things you didn't make through `self`, like that speed modifier.

`Hook` gives every affected player their own copy of the hook, which is why it can filter
on `owner`. `HookOnce` adds a single hook no matter how many players have the effect, so
prefer it for anything that fires a lot. The catch is you have to check `ply:HasStatusEffect`
since owner is useless with HookOnce.

#### Giving and Removing

Effects can only be given on the **server**, but you can check for them anywhere.

```lua
-- server
if SERVER then
    local effect = ply:GiveStatusEffect( "caffeinated" ) -- returns the effect object
    effect.cupsDrank = 1 -- it's just a table, can pass stuff to the effect

end

-- shared
ply:HasStatusEffect( "caffeinated" )

GAMEMODE:GetAllPlayersWithStatusEffect( "caffeinated" )
GAMEMODE:GetAllPlayersWithAStatusEffect( { "caffeinated", "decaffeinated" } ) -- any of these

-- server
if SERVER then
    ply:RemoveStatusEffect( "caffeinated" )

end
```

#### Inside setup/teardown

| Method | Description |
|--------|-------------|
| `self:Hook( hookName, func )` | A `hook.Add` scoped to this effect. The identifier is made for you, don't pass one |
| `self:HookOnce( hookName, func )` | Same, but hooks only once no matter how many players have the effect |
| `self:Timer( timerName, delay, reps, func )` | A `timer.Create` scoped to this effect. `reps` of 0 is infinite |
| `self:TimerRemove( timerName )` | Kill one of this effect's timers early |
| `self:SetRemoveOnDeath( bool )` | **Server only.** Strip the effect when the owner dies. Default is to persist |
| `self:GetOwner()` | The player. Same as the `owner` argument |

Effects are also torn down automatically on disconnect and on round change.

#### Clientside

Status effects are *always* networked to players.
Defining them again on CLIENT lets you add extra, clientside behaviour

##### Clientside Example A: Messing with the HUD

```lua
if CLIENT then
    GAMEMODE:RegisterStatusEffect( "caffeinated",
        function( self, owner )
            -- this is hud stuff
            -- just don't setup the hooks if we aren't the one with the effect
            if LocalPlayer() ~= owner then return end

            -- use self:Hook, this is an expensive hook,
            -- but we're not gonna be hooking it more than once 
            self:Hook( "HUDShouldDraw", function( element )
                if element ~= "CHudCrosshair" then return end
                if not LocalPlayer() then return end

                return false

            end )
        end
    )
end
```

##### Clientside Example B: Seeing effects on other players

```lua
if CLIENT then
    GAMEMODE:RegisterStatusEffect( "caffeinated",
        function( self, _owner )
            local twitching = {}

            self:HookOnce( "PrePlayerDraw", function( ply )
                if not ply:HasStatusEffect( "caffeinated" ) then return end
                twitching[ply] = true

                local shudder = 1 + math.random() * 0.3
                render.SetColorModulation( shudder, shudder, shudder )

            end )
            self:HookOnce( "PostPlayerDraw", function( ply )
                if not twitching[ply] then return end -- did we brighten this one?
                twitching[ply] = nil

                render.SetColorModulation( 1, 1, 1 )

            end )
        end
    )
end
```

A client registration is entirely optional, plenty of effects are server-only. You can
also register with no funcs at all ( like channel_666 ), if you just want a flag other code can check.

---

### Adding Spawnsets

Spawnsets(Miseries) are the #1 way to change up the hunt.
They're defined in `lua/glee_spawnsets/` and auto-loaded.
Third party addons can define their own spawnsets, they just have to be in the right spot.

#### Spawnset Example A: Your first spawnset

```lua
-- lua/glee_spawnsets/my_spawnset.lua

local mySpawnSet = {
    name = "my_spawnset",                           -- Unique identifier
    prettyName = "My Custom Misery",                -- Display name
    description = "It's my misery, it's custom!",   -- Description, best used as a "hint" that teases the spawnset's content
    
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

Number values can be:
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
| `roundEarlyStartSound` | ❌ | Alt start sound, played 10s before start, only plays if roundStartSound is "" |
| `genericSpawnerRate` | ❌ | Crate/item spawn rate multiplier |
| `chanceToBeVotable` | ❌ | Percent chance to appear in !rtm vote, 0-100, accepts float |
| `chanceToBeVotableWhenHard` | ❌ | Percent chance to appear in !rtm when this misery's escape multiplier >1.5x, for making spawnsets fade into the background when they no longer challenge the host |

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