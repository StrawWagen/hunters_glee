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
├── gamemodes/hunters_glee/
│   ├── gamemode/                      # Core gamemode logic
│   │   ├── init.lua / cl_init.lua     # Entry points, include the sv_ / cl_ modules in order
│   │   ├── shared.lua                 # Round states, includes the sh_ modules
│   │   ├── lib/                       # Generic helpers used everywhere
│   │   ├── player_class/              # The player class and its taunts
│   │   └── modules/                   # One folder (or file) per concern
│   │       ├── shop/                  # Shop GUI, purchasing, categories, cooldowns
│   │       ├── shopitems/             # Loads and verifies lua/glee_shopitems, shopHelpers
│   │       ├── spawnset/              # Spawnset loading, voting, bosses, !rtm
│   │       ├── proceduralspawner/     # Crates, beartraps, flares, vehicles, etc
│   │       ├── statuseffects/         # The status effect system
│   │       ├── banking/               # Bank and envoy
│   │       ├── escaping/              # Escaping and its rewards
│   │       ├── music/                 # Loads lua/glee_music, triggers tracks
│   │       ├── clhud/                 # HUD elements
│   │       ├── contextmenu_widgets/   # Context menu desktop: settings, taunts, etc
│   │       ├── firsttimeplayers/      # Tutorial and spawn protection
│   │       ├── lessons/               # Hints taught during play
│   │       ├── panic/                 # Panic, and what a racing heart does to your view
│   │       ├── ...                    # Smaller systems, each in its own folder
│   │       └── sv_*.lua, cl_*.lua     # Single file systems
│   ├── entities/                      # Gamemode-only entities and weapons
│   └── send.txt                       # Clientside files, mirrors AddCSLuaFile
├── lua/
│   ├── glee_shopitems/                # Shop item definitions (auto-loaded)
│   ├── glee_sethelpers/               # Addon-defined spawnset helpers (auto-loaded)
│   ├── glee_spawnsets/                # Enemy spawnset(misery) definitions (auto-loaded)
│   ├── glee_music/                    # Music track definitions (auto-loaded)
│   ├── glee_hud/                      # HUD drawing, fonts, and the swappable HUD styles
│   ├── glee_actions/                  # For when players need to choose between an entity's actions
│   ├── glee_carrying/                 # Carrying big entities as weapons, and the use wheel
│   ├── glee_wearing/                  # Wearables, goggles and the like, one SWEP and hooks each
│   ├── glee_turrets/                  # The shop's turrets: names, ammo, recharging
│   ├── autorun/                       # Loaded by gmod itself, so it runs outside the gamemode too
│   ├── entities/                      # Custom entities
│   ├── weapons/                       # Custom weapons
│   ├── vgui/                          # Custom panels
│   └── effects/                       # Visual effects
├── materials/                         # Textures and UI assets
├── models/                            # 3D models
├── particles/                         # Particle systems
├── resource/                          # Fonts, sent to clients automatically
└── sound/                             # Audio files
```

---

## Extending

Want to send a PR? See [CONTRIBUTING.md](CONTRIBUTING.md).

Hunter's Glee is designed to be extensible. The two main ways to add content are **shop items** and **spawnsets** (Miseries).

### Adding Shop Items

Shop items are defined in [lua/glee_shopitems/](lua/glee_shopitems/). Files are auto-loaded based on their prefix:
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
| `tags` | ✅ | Indexed table of tag strings. The ALL CAPS ones are the categories (e.g., `{"ITEMS", "Weapon"}`) |
| `purchaseTimes` | ✅ | When purchasable: `ROUND_INACTIVE`, `ROUND_ACTIVE` |
| `svOnPurchaseFunc` | ✅ | Server function called on purchase: `function(purchaser, itemId)` |
| `cooldown` | ❌ | Seconds between purchases (`math.huge` = once per round) |
| `weight` | ❌ | Sort order within category (lower = higher) |
| `shSkullCost` | ❌ | Skull cost. Accepts number or function. Zero is ignored. Negative gives skulls on purchase |
| `shCanShowInShop` | ❌ | Visibility function: `function(purchaser) -> bool` |
| `shPurchaseCheck` | ❌ | Validation function(s): `function(purchaser) -> bool, reason`, must return true for purchase to be allowed |
| `globalCooldowns` | ❌ | Cooldowns everyone shares, keyed by trigger (`onGhostPlace`, `onRoundStart`): `{ onGhostPlace = { time = 120, reason = "Wait.", ignoredWithCheats = true } }`. Scaled by the `glee_shop_itemglobalcooldownmul` hook, so reasons shouldn't state durations |
| `shCooldownCheck` | ❌ | Cooldowns that don't start at purchase: `function(purchaser) -> endTime, reason`. The latest end, of these and `cooldown`, wins. Shown with the time left |
| `canGoInDebt` | ❌ | Buyable with no score. Lets you force people into innate debuffs, etc |
| `markup` | ❌ | Price multiplier during active hunt |
| `markupPerPurchase` | ❌ | Additional markup per purchase |
| `fakeCost` | ❌ | Show a cost but don't take it. For items that charge the player themselves |
| `costDecorative` | ❌ | Fake, decorative cost. Accepts string, number, tables of strings, functions. Overrides `shSkullCost`, and `shCost` |
| `simpleCostDisplay` | ❌ | **Client.** Skip the coloring and formatting of the cost in the shop |
| `clBeforePurchase` | ❌ | **Client.** Runs instead of buying, from the shop or `termhunt_purchase`: `function(buy, check)`. Call `buy()` to go through with it. `check()` returns `GM:canPurchase`'s answer for right now, for anything that keeps the player waiting before buying. `termhunt_purchase_raw` skips it |
| `clDocument` | ❌ | **Client.** Name of a document from `GM:RegisterDocument`. Buying opens it, and the item is bought on signing. Clicking it in the shop while it can't be bought opens it too, unsignable until it can. Takes over from `clBeforePurchase` |
| `unpurchaseableReason` | ❌ | Custom denial string. Only used if the item has the `unpurchaseable` tag |
| `identifier` | ❌ | Auto-generated. The item's unique key |

#### Category Tags

An item goes in every category it carries the tag for, so one item can sit in several:

| Tag | Category | Visibility |
|-----|----------|------------|
| `ITEMS` | Items | Alive players |
| `MUTATIONS` | Mutations | Alive players |
| `HORRORS` | Horrors | Escaped players |
| `DEADSACRIFICES` | Sacrifices | Dead players |
| `DEADGIFTS` | Gifts | Dead players |
| `BANK` | Bank | All players |

Additional descriptive tags (e.g., `"Weapon"`, `"Utility"`) don't affect categorization.

An ALL CAPS tag that isn't in this table invalidates the item.
Don't set `.category` or `.categories` yourself either, the item is rejected outright.

Some other tags automatically apply special properties to items:

- `unpurchaseable`
    - Causes the item to be completely unpurchaseable, but doesn't hide it from the shop.
    - Good for using a shop slot to display information rather than provide an item.
    - Adding the `unpurchaseableReason` field to the item will let you override the fail reason string.

#### Shopping Helper Functions

`GAMEMODE.shopHelpers` provides common utilities:

```lua
shopHelpers.aliveCheck( purchaser )    -- Returns true if alive
shopHelpers.deadCheck( purchaser )     -- Returns true if dead
shopHelpers.escapedCheck( purchaser )  -- Returns true if they've escaped
shopHelpers.isCheats()                 -- Returns true if sv_cheats is on
shopHelpers.hasMultiplePeople()        -- Returns true if 2+ players, hide co-op items so solo players aren't confused

shopHelpers.getItemsByTag( "Weapon" )  -- Every item with that tag, unsorted

-- picks one at random, channel defaults to CHAN_STATIC
shopHelpers.playRandomSound( ent, sounds, level, pitch, channel )

shopHelpers.purchaseWeapon( purchaser, {
    class = "weapon_smg1",
    ammoType = "SMG1",                  -- Optional, defaults to the weapon's own primary ammo type
    purchaseClips = 2,                  -- Clips given on first purchase
    resupplyClips = 4,                  -- Clips given on repurchase
    secondaryAmmoType = "smg1_grenade", -- Optional, defaults to the weapon's own secondary ammo type
    purchaseSecondaryClips = 1,         -- Secondary clips given on first purchase
    resupplySecondaryClips = 1,         -- Secondary clips given on repurchase
    confirmSoundWeight = 1,             -- Gun cock sound intensity
} )

-- for screamer_crate derived "ghost/haunting" items
-- creates and spawns the ent owned by the purchaser, and hands it the item's
-- identifier and canGoInDebt, so the ent can charge for itself later
local placed = shopHelpers.setupPlacable( "glee_beartrap", purchaser, "my_beartrap_item" )
```

### Shopping Hooks

Additional ways to control access to shop items.

- `allow`, `failReason` = `glee_shop_canshow`( `ply`, `itemData` )
  - Return `false`, `failReason` to block the item from showing. ( also blocks purchasing )
  - Behaves similarly to `shCanShowInShop`, but called on a global scale and with reference to the item.
- `allow`, `failReason` = `glee_shop_canpurchase`( `ply`, `itemData` )
  - Return `false`, `failReason` to block the item from being purchased.
  - Use this hook if you want to programatically make, all items with X tag not purchasable, etc. 
  - DONT use this to define when a single item will be purchasable. Use `shopItem.shPurchaseCheck` to manage that.

#### The adjust hooks

These four don't use return values. Every listener gets the same `adjust` table and writes to it,
so several addons can tweak one field without fighting over a single return.

Number fields give you two keys. `adjust.value` is the field as it stands, and `adjust.mul` starts
at 1. The result is `adjust.value * adjust.mul`, so multiply `mul` to stack with other addons, and
write `value` when you need an absolute, like a floor. String fields only give you `adjust.value`.

- `glee_shop_itemcostmul`( `ply`, `itemData`, `adjust` )
  - `adjust.value` is the item's `shCost`, after markup is applied.
- `glee_shop_itemskullcostmul`( `ply`, `itemData`, `adjust` )
  - `adjust.value` is the item's `shSkullCost`, after markup is applied.
- `glee_shop_itemcooldownmul`( `ply`, `itemData`, `adjust` )
  - `adjust.value` is the item's `cooldown`.
- `glee_shop_itemdescription`( `ply`, `itemData`, `adjust` )
  - `adjust.value` is the item's `desc`. No `mul`, it's a string.

One listener erroring, or leaving the wrong type behind, throws away every listener's work for
that call and the field is used unadjusted.

Example:

```lua
hook.Add( "glee_shop_canshow", "i_really_hate_debuffs", function( ply, itemData )
    if itemData.tags.Debuff then return false, "Debuffs are LAME" end

end )

hook.Add( "glee_shop_itemcostmul", "half_price_guns", function( ply, itemData, adjust )
    if itemData.tags.Weapon then adjust.mul = adjust.mul * 0.5 end

end )

hook.Add( "glee_shop_itemcooldownmul", "never_instant", function( ply, itemData, adjust )
    adjust.value = math.max( adjust.value, 999 ) -- minimize the cooldown of everything to 999s

end )

```

---

### Status Effects

A status effect is a named bundle of hooks and timers living on one entity, usually a player.
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
            self:HookOnce( "PlayerFootstep", function( ply ) -- this function is best used on laggy hooks called often
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
    if effect then -- nil if they already had it, or if the name was never registered
        effect.cupsDrank = 1 -- it's just a table, can pass stuff to the effect

    end

    -- npcs and nextbots can have effects too
    hunter:GiveStatusEffect( "caffeinated" )
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
| `self:HookOnce( hookName, func )` | Same, but hooks only once no matter how many entities have the effect |
| `self:Timer( timerName, delay, reps, func )` | A `timer.Create` scoped to this effect. `reps` of 0 is infinite |
| `self:TimerRemove( timerName )` | Kill one of this effect's timers early |
| `self:SetPlyRemoveOnDeath( bool )` | **Server only.** Strip the effect when the owning player dies. Default is to persist. Npcs and nextbots always lose every effect on death |
| `self:GetOwner()` | The entity. Same as the `owner` argument |

Effects are also torn down automatically when the owner is removed, on disconnect, and on round change.
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

##### Clientside Example C: Wearing it

```lua
if CLIENT then
    GAMEMODE:RegisterStatusEffect( "caffeinated", nil, nil, {
        extraModels = {
            {
                model = "models/props_junk/garbage_coffeemug001a.mdl",
                bone = "ValveBiped.Bip01_Head1",
                pos = Vector( 8, 0, 0 ),
            },
        },
    } )
end
```

Everyone sees it, and it comes off when the effect does.  
Each entry is a [MyExtraModels](../terminator-hunter/README.md#entmyextramodels) entry. Autorefresh works, save the file and the mug moves.

A client registration is entirely optional, plenty of effects are server-only. You can
also register with no funcs at all ( like channel_666 ), if you just want a flag other code can check.

#### Stacking modifiers

```lua
owner:DoSpeedModifier( "caffeinated", 100 ) -- setup
owner:DoSpeedModifier( "caffeinated", nil ) -- teardown
```

Max health, run speed and bone manips have lots of things changing them at once.
So don't set them directly, give the player a keyed entry, and take it off when you're done.
The result is every key's entry combined.
Entries survive death.

**Max health**, [sv_maxhealth.lua](gamemodes/hunters_glee/gamemode/modules/maxhealth/sv_maxhealth.lua)
- `ply:DoMaxHealthAdd( key, amount )` adds onto the playermodel's health, 100 for most.
- `ply:DoMaxHealthFloor( key, floor )` raises it to at least this. Players already above keep theirs.
- `ply:DoMaxHealthMul( key, mul )` multiplies it, stacking with every other mul.
- `ply:DoMaxHealthCap( key, cap )` caps the result.

Health keeps its ratio, a player at half health stays at half.
Juggernaut, in sh_default_innate.lua, is a mul.
For anything a key can't say, the `glee_ply_maxhealth` hook runs last, see sv_maxhealth.lua.

**Run speed**, [sv_speedhandler.lua](gamemodes/hunters_glee/gamemode/modules/sv_speedhandler.lua)
- `ply:DoSpeedModifier( key, amount )` adds onto the player class's run speed.
- `ply:DoSpeedClamp( key, amount )` caps run speed at the class's plus this. The lowest clamp wins.

Sprinting on hands goes up to 200 past run speed, on top of all of this.

**Bones**, [sv_bonemanip.lua](gamemodes/hunters_glee/gamemode/modules/bonemaniphandler/sv_bonemanip.lua), server only
- `ent:ApplyBoneScaleManip( key, bone, scale )`, scales are multiplied together.
- `ent:ApplyBonePosManip( key, bone, pos )` and `ent:ApplyBoneAngleManip( key, bone, ang )` are added together.
- `ent:RemoveBoneManips( key )` takes off every bone this key touched.
- `ent:CopyBoneManipsTo( target )` copies every key's entries onto, say, a ragdoll.

Big head, in sh_default_bargains.lua, is a scale.
Plain `ManipulateBone*` calls still work, they all share one key, `"default"`.

---

### Adding Spawnsets

Spawnsets(Miseries) are the #1 way to change up the hunt.
They're defined in [lua/glee_spawnsets/](lua/glee_spawnsets/) and auto-loaded.
Third party addons can define their own spawnsets, they just have to be in the right spot.

Files are auto-loaded based on their prefix, same as shop items:
- `sh_` - Shared (runs on both client and server)
- `sv_` - Server only
- `cl_` - Client only
- No prefix - ( deprecated, server only )

Two letters and an underscore is read as a prefix, so `my_misery.lua` errors instead of loading.
Name it `sv_my_misery.lua`.

A spawnset only exists on the client to run `Activate` and `OnRemove` (see below), it never spawns anything.
So a `cl_` file needs nothing but a `name` matching the spawnset it's adding to.
A spawnset that only exists clientside is dropped, because it can never be picked.
It complains in console, and errors outright with `developer 1`.

The quickest start is copying [lua/glee_spawnsets/sv_default_example.lua](lua/glee_spawnsets/sv_default_example.lua).
Every field is in the Reference tables at the end.

#### Spawnset Example A: Your first spawnset

```lua
-- lua/glee_spawnsets/sv_mycustom_misery.lua

local mySpawnSet = {
    name = "mycustom_misery",                       -- Unique identifier
    prettyName = "My Custom Misery",                -- Display name
    description = "It's my misery, it's custom!",   -- Description, best used as a "hint" that teases the spawnset's content
    author = "Me",                                  -- Optional, credited in the vote tooltip
    
    -- Use "default" to borrow the default misery's values, or "default*2" for multipliers, see Example C
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
            hardRandomChance = { 5, 20 },              -- x% chance to be considered, rolled multiple times per wave, more if there's more budget
            name = "scary_hunter",
            prettyName = "A Scary Hunter",
            class = "terminator_nextbot",              -- Spawns the "overcharged" terminator
            spawnType = "hunter",
            difficultyCost = { 25, 50 },
            difficultyNeeded = { 50, 100 },             -- only consider spawning this after 5 - 10 minutes
            countClass = "terminator_nextbot_snail*",
            maxCount = { 1 },                          -- Never exceed this many
        },
    },
}

table.insert( GLEE_SPAWNSETS, mySpawnSet )
```

#### Spawnset Example B: Importing another misery's hunters

```lua
-- lua/glee_spawnsets/sv_wraiths_again.lua

local wraithsAgain = {
    name = "wraiths_again",
    prettyName = "Wraiths Again",
    description = "They never really left.",
    importedMiserySpawns = {
        { name = "hunters_glee_wraiths" },              -- every one of its .spawns entries, as is
    },
}

table.insert( GLEE_SPAWNSETS, wraithsAgain )
```

Only the `.spawns` come along.
Everything else still comes from `default`, Example C borrows the rest too.

#### Spawnset Example C: Borrowing from other miseries

Anything a misery leaves out comes from `default`.
Any other misery can be borrowed from the same way, by name.

```lua
-- lua/glee_spawnsets/sv_the_haunted_machine.lua

local hauntedMachine = {
    name = "the_haunted_machine",
    prettyName = "The Haunted Machine",
    description = "Something followed them out of the factory.",
    maxSpawnCount = "hunters_glee*1.5",                 -- 1.5x Hunter's Glee's cap
    waveInterval = "hunters_glee_wraiths",              -- the wraiths' pacing
    roundEndSound = "hunters_glee_wraiths",             -- and their round end sound
    importedMiserySpawns = {
        {
            name = "hunters_glee",                      -- every one of its .spawns entries...
            overrides = {
                terminator_doppleganger = NULL,         -- ...except this one
            },
        },
        {
            name = "hunters_glee_wraiths",
            overrides = {
                terminator_invisible = {                -- change only these fields
                    prettyName = "A Haunted Terminator",
                    difficultyNeeded = { 50, 100 },     -- only shows up after 5 - 10 minutes
                    minCount = NULL,                    -- NULL unsets a field, so it's no longer always kept around
                },
            },
        },
    },
}

table.insert( GLEE_SPAWNSETS, hauntedMachine )
```

Imported entries go after the misery's own `.spawns`, in the order they're listed.
A misery needs `.spawns`, `.importedMiserySpawns`, or both.
Two entries with the same name is an error, even when they come from different miseries. Rename an imported one with an override.
`NULL` only means something in overrides, it drops the entry or unsets the field, like it was never written.
`optional = true` on an import skips it when that misery isn't installed, eg one from another addon.
`needsEveryMisery = true` on the misery itself makes it quietly not load instead, when any misery it borrows or imports from isn't installed.

`template = true` makes a misery that's only there to borrow from.
It's never in the vote, and can't be picked.
`default` is one.

#### Spawnset Example D: Functions on spawn!

```lua
-- lua/glee_spawnsets/sv_the_true_machine.lua

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

#### Spawnset Example E: Lifecycle

- `Activate` - the misery changed TO this spawnset
- `OnRemove` - the misery changed AWAY from this spawnset

Both optional. Neither fires between rounds of the same misery.

```lua
function trueHorror:Activate()
    self:Hook( "OnNPCKilled", function( npc )
        if npc.glee_SpawnsetThatMadeMe ~= self.name then return end
        huntersGlee_Announce( player.GetAll(), 100, 5, "One less machine." )

    end )
end
```

| Method | Description |
|--------|-------------|
| `self:Hook( hookName, func )` | A `hook.Add` scoped to this spawnset. One per `hookName`, a second replaces the first |
| `self:Hook( hookName, id, func )` | Same, the `id` lets you keep more than one on a `hookName` |
| `self:Timer( timerName, delay, reps, func )` | A `timer.Create` scoped to this spawnset. `reps` of 0 is infinite |
| `self:TimerRemove( timerName )` | Kill one of this spawnset's timers early |
| `self:AddTeardown( func )` | Runs `func` when the misery changes, for undoing what hooks and timers can't |

These are removed for you when the misery changes.
Only write an `OnRemove` for things you didn't make through `self`.

`self`'s values are the misery's, before this round's roll.
A `waveInterval` of `{ 60, 90 }` is still `{ 60, 90 }` here, use `GAMEMODE:GetSpawnSet()` for the rolled number.
Borrowed values are already filled in, a `waveInterval` of `"default"` is default's range, and imported `.spawns` entries are already in.

A `cl_` file with the same `name` gets its own `Activate`, for HUD and sounds.

#### Set Helpers

`GAMEMODE.setHelpers` holds shared building blocks, like `makeHardcore( self )` for `Activate`, or `postSpawnedOvercharge` for `.postSpawnedFuncs`.

```lua
function set:Activate()
    -- everyone's kleiner
    GAMEMODE.setHelpers.overridePlayerModel( self, function( ply ) return "models/player/kleiner.mdl" end )
    -- and the richest player gets an RPG every spawn, with 3 rockets more than it comes with
    GAMEMODE:AddMiserySpawnWeapon( self, "default", { class = "weapon_rpg", ammoType = "RPG_Round", purchaseClips = 3 }, function( ply )
        return ply == GAMEMODE:GetRichestPlayer()

    end )

end
```

Weapons everyone gets belong in `.startWeapons` and `.defaultWeapons`, `GAMEMODE:AddMiserySpawnWeapon` is for the rest.
`"start"` gives one per round, `"default"` one per life, both on top of the misery's own.
Weapons are a class, or a `shopHelpers.purchaseWeapon` table when they should come with ammo.
Any of that table's fields but `class` can be a `function( ply )`, for ammo that depends on how many are playing.
The weapon itself can be a `function( ply )` too, for a random pick. It's called once per player per round.
Add your own with `sh_`/`sv_`/`cl_` files in [lua/glee_sethelpers/](lua/glee_sethelpers/). They're included before any spawnset, during gamemode load, so reach the table through `GM`.

```lua
-- lua/glee_sethelpers/sv_my_helpers.lua
local setHelpers = ( GM or GAMEMODE ).setHelpers

function setHelpers.postSpawnedRed( spawnData, npc )
    npc:SetColor( Color( 255, 0, 0 ) )

end
```

#### How a wave is built

Every wave, the spawner works out how many hunters it wants,
and how much it can spend.

It wants `startingSpawnCount`, plus `spawnCountPerDifficulty` per difficulty.
Never fewer than the player count, up to 8.
Never more than `maxSpawnCount`.

It can spend `difficulty + startingBudget`, on that wave alone.
Pricier entries are tried first.

So `difficultyCost` is how you pace a hunter.
At 20, the first wave affords 1, and more each wave as difficulty climbs.
At 1, the first wave fills the cap.

#### Reference

##### Spawnset Values

I had a problem when developing this.
Each round was feeling the same,
and I was updating spawnset values all over the place.
My solution? Dynamic values.

Number values can be:
- `nil` - Use the `default` misery's value, see [lua/glee_spawnsets/sv_default.lua](lua/glee_spawnsets/sv_default.lua)
- `"some_misery"` or `"some_misery*N"` - Borrow that misery's value, or N times it, see Example C
- `{ min, max }` - Random value in range is chosen at the start of each round.
- `{ n }` - A one member table, same as writing the number directly
- `function( spawnSet )` - Called each round, return a number, `{ min, max }` or `{ n }`
- `Direct number` - 8, 10, 11.25, etc ( not recommended, random value in range is much more fun )

`nil` and borrowing only work on the misery's own fields.
`.spawns` entries and `slotSizes` take the rest, a `nil` there is just unset.

Sound values can be:
- `nil` - Use the `default` misery's sound
- `"some/path"` - A sound path, or a music track like `"tracks/roundEnd"`
- `"some_misery"` - Borrow that misery's sound
- `""` - Silence

The rule is the `/`.
A sound value without one is ALWAYS a misery's name.
Sounds must be in a subfolder of `sound/`, so a sound's path always has a `/`.

##### Spawnset Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Unique identifier, should match filename |
| `prettyName` | ✅ | Display name for voting/UI |
| `description` | ✅ | Description shown to players, best used as a hint that teases what's coming |
| `spawns` | ✅ | THE indexed table of potential spawns ( see below ). Optional with `importedMiserySpawns` |
| `author` | ❌ | Who made it, shown under the description as "by ..." |
| `importedMiserySpawns` | ❌ | Copies other miseries' `.spawns` entries in, see Examples B and C |
| `chanceToBeVotable` | ❌ | Percent chance to appear in the !rtm vote, 0-100, accepts float. nil is always |
| `chanceToBeVotableWhenHard` | ❌ | Used instead while this misery still challenges the host, judged by its escape multiplier. Set it higher, so it sticks around while it's fun and fades out once they've mastered it |
| `easy` | ❌ | Marks this as a beginner misery. Tagged `(EASY)` in the !rtm vote, and while an easy one is active the vote prefers offering other easy ones. Also soft-caps its escape reward multiplier |
| `maxSpawnCount` | ❌ | Hard cap on hunter count. 10 is default, 6 is `hunters_glee`, 60 is `combine_onslaught` |
| `waveInterval` | ❌ | Seconds between spawn waves, skipped if all hunters are cleared. Default is 60 - 96 |
| `startingSpawnCount` | ❌ | How many hunters it wants at the start, grows with `spawnCountPerDifficulty`. Never below the player count, up to 8. About 2 by default, 8 is `combine_onslaught` |
| `roundStartSound` | ❌ | Sound on round start |
| `roundEarlyStartSound` | ❌ | Played 10s before the round starts, only if `roundStartSound` is "" |
| `roundEndSound` | ❌ | Sound on round end, when nobody escaped |
| `Activate` | ❌ | Called when this becomes the active misery ( see Example E ) |
| `OnRemove` | ❌ | Called when the misery changes away from this ( see Example E ) |

<details>
<summary>Advanced fields, best left alone until you know you need them</summary>

| Field | Description |
|-------|-------------|
| `template` | `true` makes this a misery to borrow from, never voted for or picked |
| `difficultyPerMin` | Difficulty gained per minute. Write it as `100 / 10` for 100 difficulty at 10 minutes |
| `diffBumpWhenWaveKilled` | Difficulty added to the round when a wave is completely killed |
| `startingBudget` | Added to every wave's budget, so more and pricier hunters each wave. Doesn't unlock `difficultyNeeded` entries |
| `spawnCountPerDifficulty` | Added to the wanted hunter count per difficulty. Default adds about 8 - 10 per 100 difficulty |
| `maxSpawnDist` | Soft cap on the dynamically marching spawn distance, only broken if there's nowhere hidden to spawn enemies |
| `minSpawnDist` | Never spawns closer than this. Don't shrink it, anything closer feels unfair |
| `genericSpawnerRate` | Multiplier on procedural spawn delays ( crates, flareguns, beartraps, skulls, gas, vehicles, etc ). Bigger for slower spawns, smaller for faster |
| `breathingRoom` | Scales an extra delay between waves for players who are overwhelmed. 0 is off, for really easy miseries |
| `hordeSpawn` | `true` Always reuses the last good spawn area, stacking hunter spawns into a horde. Defaults to true for waves of 8+ spawns, `false` disables it even then |
| `rotatingWaves` | `true` makes each wave come from one group, taking turns. The misery's own `.spawns` are one group, and each misery it imports from is another. A group with nothing to spawn still spends its turn. Each group stacks its hordes in its own spot |
| `slotSizes` | How many hunters fit in each `.slots` slot, eg `{ miniboss = 1 }`. Takes a number, `{ min, max }`, `{ n }` or a function, but not a misery's name. Or `"minutes*N"` / `"difficulty*N"` to grow with the round, `"minutes*0.1"` is one slot every 10 minutes, `"difficulty*0.01"` is one every 100 difficulty. Without it every slot holds 1. Slots are a hard cap on how many can be out at once. To ramp a count up, `difficultyCost` usually does it, see How a wave is built |
| `startWeapons` | Weapons everyone gets once a round, eg `{ { class = "weapon_smg1", purchaseClips = 3 } }`. See Set Helpers for what each one can be |
| `defaultWeapons` | Weapons everyone gets every life. Default is the crowbar, camera and radio, a list here replaces all three. They spawn holding the last weapon they were given: start weapons come after these, and a role's weapons after the misery's |
| `roundWinSound` | Sound on round end, when someone escaped |
| `roundPerfectWinSound` | Sound on round end, when everyone escaped |
| `highIntensitySound` | Played when things get really intense, like a wave wiped with no more than 1/4 of players alive |
| `grigoriArrivalSound` | Played when grigori arrives |
| `secondGrigoriArrivalSound` | Played when the second grigori arrives |
| `noMoreGrigoriSound` | Played when there are no more grigori |
| `tutorialExit` | `true` puts it in the server's first ever vote, the way out of the tutorial misery. Leave this alone, it's for the stock miseries |

</details>

##### .spawns Entries

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Unique identifier for this spawn entry |
| `prettyName` | ✅ | Display name |
| `class` | ✅ | Entity class to spawn |
| `spawnType` | ✅ | Spawning algorithm type, only supports `"hunter"` presently |
| `difficultyCost` | ✅ | Budget cost to spawn, spawns are checked from highest to lowest cost. Paces how many arrive each wave, see How a wave is built |
| `difficultyNeeded` | ❌ | Difficulty threshold needed to start spawning, good if you want difficult enemies to all start spawning suddenly. 100 is roughly 10 minutes, sooner if waves get wiped |
| `difficultyStopAfter` | ❌ | Difficulty threshold to stop spawning past, the mirror of `difficultyNeeded`, for enemies that should drop out of the pool later on |
| `hardRandomChance` | ❌ | Percent chance to even be considered, works since spawns are checked from highest to lowest cost. Rolled multiple times per wave, more if there's more budget |
| `countClass` | ❌ | Class pattern for .min/max count counting ( `*` = wildcard ). Falls back to `class` if nil |
| `minCount` | ❌ | Minimum maintained count, hard minimum, bypasses budget |
| `maxCount` | ❌ | Maximum allowed count |
| `postSpawnedFuncs` | ❌ | Functions called after hunter:Spawn() : `function(spawnData, npc)` |
| `isBoss` | ❌ | `true` marks as boss; `false` opts out of auto-detection. When the boss is killed, all alive players escape. Cleanup that removes boring hunters leaves any hunter alone for a while after it fights a player, a boss for a full 10 minutes. Lag never removes a boss. Auto-detected when `spawnSet.maxSpawnCount <= 1` (highest `difficultyCost` entry becomes boss). |

<details>
<summary>Advanced fields, for spawns that need special handling</summary>

| Field | Description |
|-------|-------------|
| `cooldown` | Seconds this has to stay gone before it spawns again. A wave can still spawn several, but no more until they've all died or despawned, then the cooldown starts |
| `slots` | Slots this takes up, eg `{ "miniboss" }`. Only spawns while every one of its slots has room, see the spawnset's `slotSizes` |
| `spawnSameZ` | Prefer spawning at roughly the same height as a player |
| `spawnAbove` | Prefer spawning above the highest player |
| `spawnBelow` | Prefer spawning below the lowest player |
| `preferredEFlags` | Prefer nav areas carrying all of these Extra Navmesh flags ( see sv_navmeshcategorizer ) |
| `firmPreferredEFlags` | `true` stops `preferredEFlags` from bending, the entry never spawns outside those areas, and is never picked on maps without them |
| `canSpawnOnMap` | `function(spawnData)`, asked once a map, after the navmesh is categorized. Return false and the entry never spawns on this map, eg the map's too cramped for it. A misery none of whose entries can spawn is left out of the vote, and can't be nominated. If it's already active, one !rtm is enough to start a vote |
| `areaFilter` | `function(spawnData, area)`, return false and the entry won't spawn in that nav area. Pair it with `canSpawnOnMap`, an entry no area passes holds up its wave until it's dropped |
| `preSpawnedFuncs` | Functions called before hunter:SetPos() and hunter:Spawn() : `function(spawnData, npc, spawnPos)`. Change spawnPos to move where it spawns. From the spawner, it's 20 units above the nav area, hunters fall into place |
| `hordeSpawn` | Toggle last good area re-use for just this spawn. `false` opts out of the spawnset's `hordeSpawn` |
| `scaryAsATerminator` | `true` makes players panic like it's a full hp terminator, for low hp npcs that are scarier than they look |
| `removeAfterStillSeconds` | Removes the hunter once it's stayed within 50 units of one spot for this many seconds. Only counts while the round is active |

Only one of `spawnSameZ`, `spawnAbove`, `spawnBelow` applies, they're checked in that order.
Those three and `preferredEFlags` all loosen the longer the spawner fails to find a spot, so they bend rather than block. A non-firm `preferredEFlags` is ignored outright on maps without those flags.
`areaFilter` and a firm `preferredEFlags` never bend, an entry they leave nowhere to go holds up its wave for about a minute, then gets dropped from it.
The gunship in [sv_combines_glee.lua](lua/glee_spawnsets/sv_combines_glee.lua) uses all of these.

</details>

Most miseries pair entries, a rare few early, then lots once the round heats up.
The rare one is pricey with a low `maxCount`, the common one is cheap with a high `difficultyNeeded`.
See [sv_combines_glee.lua](lua/glee_spawnsets/sv_combines_glee.lua)'s shotgunners.

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
| `GAMEMODE.ROUND_TESTSTATE` | 4 | Debug state, nothing spawns |

---

## License

See [LICENSE](LICENSE) for details.

Rounded shapes, soft shadows and blur are drawn with [RNDX](https://github.com/Srlion/RNDX) by Srlion, MIT licensed, at [lua/glee_hud/rndx.lua](lua/glee_hud/rndx.lua).

---

*Hunter's Glee is a passion project: a fantastic testbed for new ideas and always a great laugh. Contributions welcome!*
