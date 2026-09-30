# NPC Village (Godot 4)

A small cozy village game: farm, fish, help your neighbors with their problems,
and raise money for the Harvest Festival to win. Villagers wander, chat with
each other, pass along hints, spread news about you, and go home at night.

## Running it
Open the project in Godot 4 (tested with 4.7), press **F5**.
The first time, Godot needs a few seconds to import the models and sounds.
**After copying in new files, restart Godot** (or use Project > Reload Current
Project) so it notices and imports them.

## Controls
| Key | Action |
|---|---|
| WASD / arrows | Move |
| Space | Jump |
| E | Interact (talk, farm, fish, shop, go in/out of houses, sleep, dig, catch fireflies) |
| 1-4 | Flower memory minigame (or click the flowers) |
| 1-9 | Crab catching minigame (or click the crabs) |
| 1-4 / Space / click / A S D | House minigames (shown on each screen) |
| G | Give a gift to a villager |
| I or Tab | Your bag (everything you carry, with details) |
| J | Journal |
| M | Treasure map |
| J, then Map | Village map: where every activity is |
| Q | Change which seed you plant |
| Space / E / left-click (hold) | Reel in while fishing |
| Right-mouse drag | Rotate camera |
| Esc | Pause menu (save, volume, fishing style, farming style, quit) |

## How to play
- **Villagers** each have a chain of requests (see the quest log, top right).
  Talk to them to get a request, talk again to hand it in. Stuck? Ask them
  again, or listen in when villagers chat -- they share real hints.
- **Farming**: your farm is next to your house. Press E on a tile to till it,
  plant the selected seed, and water it. Watered crops grow one stage each
  night. Wheat 2 days, carrots and tomatoes 3, pumpkins and strawberries 4,
  corn 5. Harvesting plays a quick
  "Pull!" minigame: stop the marker in the green band for a bonus crop
  (switch **Farming style** to **Simple** in the Esc menu to skip it).
  Sprinklers from the market water the farm for you every morning.
- **Minigames**: Bram's baking (stop the needle in the golden zone), Ivy's
  flower memory (repeat the pattern with 1-4), Otto's metal-detector treasure
  hunt (follow the beeps, press E to dig), and Pip's game of tag.
- **Houses**: walk into any house through its front door (villagers lock up
  from 9 PM to 7 AM). Each has a minigame you can play once a day: bake bread
  at Bram's, fill flower orders at Ivy's, build a block tower with Pip, match
  Otto's curios and sort Sal's catch. Your own house has your bed and a stove
  where you can **cook** crops and fish into dishes worth far more.
- **Can't find something?** Open the journal (J) and pick the Map tab, or
  look at the map on your house wall. It shows every activity.
- **Your pet** can follow you, stay home or explore the village (pet menu).
  You can also rename the sign over your room (press E under it).
- **Everyday life**: forage berries, herbs, mushrooms and shells (new ones
  every morning), follow the daily treasure map from the message in a bottle
  on the beach (M shows it), and adopt the puppy waiting by your door (pet,
  feed and play fetch with it every day).
- **Music**: play the piano in your house (or a guitar or flute from the
  market) in song mode (a rhythm game, D F J K) or freestyle. Also try
  **stone skipping** at the pond and **stargazing** at the telescope at night.
- **Villagers**: chat daily and give gifts (G) to raise their hearts. At 2, 5
  and 8 hearts they share their story and give you gifts, secret recipes and
  hats. Check the journal (J) for birthdays and what they like.
- **Wood and stone**: chop any tree (Timber!) and break any rock or boulder
  (Strike!) in the village (not the palms); they grow back in 2 days. Set
  "Chopping & mining style" to Simple in the Esc menu to just swing instead.
- **Town Hall**: bring wood, stone and coins to the construction site east of
  the well. It goes up in four stages; when it's done you can go inside, and the
  request board gets bigger and pays better. Inside: the village records book and
  the **museum**, where you donate one of each fish (to the aquarium), crop,
  forage find and treasure for rewards.
- **Request board** (next to the market): villagers pin optional jobs every
  morning, like "bring Sal 2 mackerel" or "bring Bram 4 tomatoes". Take a note,
  gather the items and talk to them for coins and friendship.
- **Every day**: catch crabs at the **Crab Rocks** on the beach, race Pip
  through glowing rings around the square (the **Race Pip!** sign on the lawn by the square, after you beat
  him at tag), and catch **fireflies** after 8 PM. Sell crabs and fireflies at
  the market.
- **Fishing**: stand at the pond's edge (west of the well), press E to cast,
  wait for the **!**, then press quickly to hook. Hold to raise the green bar
  and keep the fish inside it until the meter fills. Prefer something easier?
  Set **Fishing style** to **Simple** in the Esc menu: just press in time when
  the fish bites (rare fish give you less time). Catfish come out at night;
  so do eels; trout bite by day. The legendary Golden Carp only bites before
  9 AM, and it's rare.
- **Ocean**: the beach is east of the well. Fish anywhere along the waterline
  or off the end of Sal's dock for sardines, mackerel, pufferfish,
  swordfish and squid (at night). Tuna only bite off the end of the dock. The glowing Moonfish only bites at night, off the end of the dock.
- **Market** (north of the well): buy seeds, rods, the Golden Lure,
  sprinklers and hats; sell fish, crops, crabs, fireflies, bread, bouquets
  and dishes.
- **Days**: time passes while you play (a day is about 9 minutes). Sleep in your
  bed (inside your house) to end the day -- this also **saves the game**. Stay up past 2 AM and
  you'll pass out. You can also save from the Esc menu.
- **Winning**: help all five villagers (Bram, Ivy, Pip, Otto and Sal the
  fisherman), then raise 1000 coins for Otto's Harvest Festival.
- **After you win**: fund village projects at the board beside the market:
  flower beds around the square, a three-tier fountain (toss in a coin for a
  wish), a bandstand you can walk up onto to play music (villagers dance there
  in the evening), and a golden statue of you. Plus hats and the Master Rod to save up for.

## Files
| File | What it does |
|---|---|
| `scripts/game.gd` | Global state (autoload `Game`): coins, inventory, clock, quests, farm, save/load. **Item prices, crops, fish and shop stock are at the top.** |
| `scripts/audio.gd` | Music and sound effects (autoload `Audio`), volume settings |
| `scripts/main.gd` | Builds the village, day/night lighting, sleeping, quests, festival. **Villager names, dialogue and quest chains are in `npc_defs`.** |
| `scripts/npc.gd` | Villager behavior: wander, chat, gossip, go home at night, tag |
| `scripts/player.gd` | Movement, camera, interacting with the closest thing |
| `scripts/farm_tile.gd` | One farm tile: till, plant, water, grow, harvest |
| `scripts/fishing.gd` | Casting and the fishing minigame (tuning constants at the top) |
| `scripts/shop_ui.gd` | The market screen (Buy / Hats / Sell) |
| `scripts/gathering.gd`, `scripts/townhall.gd`, `scripts/request_board.gd` | Wood and stone, the town hall, the request board |
| `scripts/villager_data.gd` | Villager personalities, gift tastes, stories, routines |
| `scripts/everyday.gd` | Foraging, treasure, telescope, stone skipping, piano |
| `scripts/pet.gd`, `scripts/panels.gd`, `scripts/map_view.gd` | The puppy; pet/gift/journal screens; the treasure map |
| `scripts/extra_games.gd` | Music (songs + freestyle), stone skipping, stargazing |
| `scripts/interiors.gd` | Walk-in house rooms, their stations and rewards |
| `scripts/house_games.gd` | House minigames: bouquets, block tower, pairs, sorting, cooking |
| `scripts/activities.gd` | Crab Rocks, Pip's race, fireflies, projects board and decor, sprinklers |
| `scripts/projects_ui.gd` | The village projects screen |
| `scripts/firefly.gd` | A catchable firefly |
| `scripts/ui_style.gd`, `scripts/ui_icon.gd` | Shared minigame/shop look and drawn icons |
| `scripts/menus.gd` | Title screen and pause menu |
| `scripts/dialogue_ui.gd` | The HUD: clock, coins, inventory, quest log, dialogue box |
| `scripts/character_visual.gd` | Robot model, recoloring, hats, animations |
| `scripts/interact_spot.gd` | Generic "press E here" spot (bed, market, pond) |
| `scripts/pickup.gd` | Collectible quest items (tumbling flour, buried coins) |
| `scripts/minigames.gd` | Baking, flower memory, harvest "Pull!" and crab minigames |
| `scripts/scenery.gd` | Hills, beach, ocean, lighthouse, palms, mountains, forest, trees, rocks, flowers, grass |
| `shaders/foliage.gdshader` | Leaf sway and camera fade for trees |
| `shaders/ocean.gdshader` | Ocean waves, colors and foam |

## Credits
- Character and coin models, footstep/jump/land/coin sounds: Kenney (kenney.nl), CC0.
- Music and other sound effects were generated for this project (free to use).
