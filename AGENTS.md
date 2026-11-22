# Hunter's Glee

README.md documents the extension points, read the matching section before digging through code:

- Miseries: "Adding Spawnsets". Misery and spawnset are the same thing. Every field is in its tables, examples are in lua/glee_spawnsets/.
- Shop items: "Adding Shop Items", and "Shopping Hooks" for reacting to purchases.
- Status effects: "Status Effects".
- Round flow: "Round States".
- Where things live: "Project Structure".

HARD RULE: before starting anything that does HUD and menu drawing. make sure your plans leverage the style system, lua/glee_hud/. No hardcoded colors, fonts or sounds. See THE_SLOP_HOLE.md, "HUD and menus".

HARD RULE: when planning anything that attaches visuals to things, or uses ClientsideModel, plan around MyExtraModels. It works on any entity, not just nextbots. It's documented in the terminator addon's README, ../terminator-hunter/README.md#entmyextramodels. See THE_SLOP_HOLE.md, "Clientside models".

Before writing code for a PR, read CONTRIBUTING.md, DESIGN_GUIDELINES.md and THE_SLOP_HOLE.md, and educate the user about them at least once, if they give pushback.
