# NPC Village: Dev Log

A running record of how this game was built: every request, what was done about it, problems hit along the way, and reference material. **Updated after every request.** The newest entry is at the bottom of the prompt log.

- **Project folder:** `AI/npc_village` (Godot 4.7, GDScript)
- **Last updated:** 2026-09-29, after prompt 17
- **Companion doc:** `npc-village-design.md` (game design summary)

---

## Prompt log

### 1. First version (2026-09-26, 9:24 PM)
> Build a very simple 3d game with some npcs that the player can interact with and the npcs can interact with each other. Use godot

**What was done**
- Created a Godot 4 project, built almost entirely in code, with one tiny scene.
- Capsule player with WASD movement, jumping and a follow camera.
- 4 NPCs (Bram, Ivy, Otto, Pip) running a state machine: idle, wander, approach, chat, talk.
- NPC-to-NPC chats with speech bubbles, friendship counts and gossip ("I was just talking to X...").
- Player dialogue box with the E key.
- Tested headless in Godot 4.3.

### 2. Bug: the world fell away (2026-09-26, 10:00 PM)
> when I opened it in godot and pressed F5 it started the game but the world fell and left the player in the void

**Cause:** the player spawned at exactly the same spot as Ivy. The two overlapping bodies pushed the player upward at about 100 m/s. The camera followed, so it looked like the world was falling.

**Fix:**
- Moved the player's spawn point and rotated the NPC spawn circle.
- Added a safety respawn if the player ends up far above or below the map.

### 3. Bug: still flying (2026-09-26, 10:06 PM)
> It still sends the player and ivy into the sky.

**Cause:** the fix never ran. Godot had the old scripts open and saved them back over the new files when F5 was pressed. The user was also on Godot 4.7, not the 4.3 used for testing.

**Fix:**
- Re-delivered the files with instructions to close Godot without saving first.
- Added "slide off" logic so characters can't stack on each other's heads.
- Tested in 4.7 and reproduced the original bug there.

### 4. Real models and a goal (2026-09-26, 10:17 PM)
> The game seems to be working how you said now. I would like to add some gameplay elements to it. Would it be possible to change the blobs that are the player and npcs into actual models? I also want there to be a way to "win" or something to actually do in the game.

**What was done**
- **Models:** Kenney's CC0 robot, with walk/idle/jump animations and a recolor shader. Each NPC gets its own color and a hat.
- **Quests:** Bram's flour sacks, Ivy's flowers, Otto's gold coins, and a game of tag with Pip. Helping all four wins.
- **Hints:** NPCs ask each other about lost items and answer with real locations. They also spread news when the player helps someone.
- **World:** houses, a well, named landmarks, a quest log, and a win screen.
- **Tag balance:** Pip is faster than the player but trips. He picks among 16 escape directions so he doesn't get stuck on obstacles.

### 5. Fishing, farming and polish (2026-09-28, 12:46 PM)
> I failed the tag game once but caught pip pretty consistently after that. I would like to add more and make it feel like a more polished game. I want to add a few minigames such as fishing and maybe add a farming mechanic.

**Choices made (asked before starting)**
- Structure: **economy loop.** Sell fish and crops, buy seeds and upgrades, and the win condition is funding the festival.
- Polish: **title and pause menus, sound and music, day/night cycle, saving and loading** (all four picked).
- Fishing style: **timing bar**, Stardew-style.

**What was done**
- **Fishing:** cast, bite, then the timing-bar minigame. Five fish, some time-restricted: catfish at night, the Golden Carp only before 9 AM.
- **Farming:** a 12-tile farm with till, plant, water and harvest. Crops grow overnight: wheat in 2 days, carrots in 3, pumpkins in 4.
- **Market:** buy seeds, the Better Rod and the Golden Lure; sell fish and crops.
- **Quests:** each villager got a second request (Pip a third) that uses fishing or farming. The finale is raising 300 coins for Otto's Harvest Festival.
- **Day/night:** a clock, lighting that changes through the day, lamps and lit windows, villagers going home at night, sleeping to end the day, and passing out at 2 AM.
- **Menus and saving:** title screen (New/Continue/Quit), Esc pause menu (save, volume), and JSON saves that autosave when you sleep.
- **Audio:** generated day and night music loops and sound effects, plus Kenney's footstep, jump and coin sounds.
- **Visual polish:** objects fade out near the camera, a forest outside the fence, grass, paths, a pond with lily pads, and festival decorations with confetti.
- **Testing:** a full automated playthrough passed. Difficulty was tuned with a simulated player that reacts 0.2 seconds late.

### 6. Dev log (2026-09-28, 1:13 PM)
> I like the documentation you made. Can you put together a log of all the prompts I've given you and other useful documentation. And have this update as we continue to work

**What was done:** created this dev log, both in the project and as `DEVLOG.md` in the game folder. It gets updated after every future request.

### 7. Polish: sound, map, farm, trees (2026-09-28, 1:30 PM)
> Perfect. Lets polish up the game a little before making any more changes. The sound for the game isnt working and we can improve the map. There are lights in the middle of path ways and I want the farm to look nicer. I don't like how we play in a square in the middle of the void. I like the trees but I want them to look nicer.

**Sound bug.** Godot on the user's computer had never imported the new `.ogg` files: there were no `.import` files, and the new scripts had no `.uid` files either. The editor had stayed open while files were copied in and never rescanned the folder. Scripts still ran straight from disk, but sounds can't load until they're imported.
- **Fix:** `audio.gd` now falls back to reading the `.ogg` files directly (`AudioStreamOggVorbis.load_from_file`) when they aren't imported.
- **Verified:** captured the audio output with and without the import step. Music and effects reached the speakers in both cases.

**Map**
- **No more square:** the square play area and fence are gone. The village is now a round clearing (radius 30 m) surrounded by rolling low-poly hills and a forest of about 520 trees.
- **Horizon:** snow-capped mountains in the distance, and fog that blends the horizon. The fog color follows the time of day.
- **Boundary:** an invisible round wall keeps you in the village, and the camera stays above the hills.
- **Trees:** new low-poly oaks, pines and birches with faceted shading, color variation, and leaves that sway in the wind. They fade out near the camera like buildings do.
- **Scenery:** low-poly rocks, bushes, flower patches, and colored grass.
- **Lamps:** placed beside the paths (checked to be at least 1.25 m from any path) instead of on them.
- **Farm:** dirt bed, post-and-rail fence with collision and a gate facing the village, tool shed, scarecrow, hay bales, water barrel, a wooden sign, and furrowed and damp-looking soil.

**Testing:** the full regression test passed, including actually walking from your house through the farm gate to a tile, to the pond and to the market, and confirming you can't walk out of the village.

### 8. Quest minigames, coastline, ocean fish (2026-09-28, 7:30 PM)
> Make some of the first quests more interesting while adding more minigames. Also add a coast line and unique fish that can be caught from the ocean.

**First quests reworked, with three new minigames**
- **Bram:** his flour sacks now tumble around in the wind (faster when you get close), so you have to chase them. Then comes the **baking minigame**: stop a swinging oven needle in the golden zone for 3 loaves. Each loaf is faster, with a smaller zone, and you can miss twice. Failing keeps the flour, so you can retry.
- **Ivy:** after picking flowers comes the **flower memory minigame**. Ivy shows a color pattern; repeat it with keys 1-4 (or by clicking). There are three rounds of 3, 4 and 5 flowers, with two mistakes allowed.
- **Otto:** the **metal detector hunt**. His 5 coins are buried and invisible. A detector bar (Cold / Warm / Hot / RIGHT HERE) fills and beeps faster as you get close; press E to dig.
- **Pip:** tag, unchanged; it was already a minigame.
- Villagers' gossip hints now also cover the buried coins.

**Coastline**
- The east side of the village now opens onto a sandy beach and an animated ocean, with waves, turquoise shallows fading to deep blue, and a foam line.
- The ground slopes gently down to the water, with real walking collision. An invisible wall runs along the waterline.
- **Sal's dock:** a wooden dock with railings, posts, crates and a lamp at the end.
- **Beach details:** Sal's Bait & Tackle hut, palm trees with swaying leaves, driftwood, shells, a rowboat, and a striped lighthouse on the northern headland whose beam turns at night.
- **Sound:** ocean wave sounds that get louder as you approach the beach.
- **Pond:** moved to the west side of the village to make room.

**Ocean fishing and Sal**
- Fish anywhere along the waterline ("E: Fish in the ocean") or off the end of the dock (deep water).
- **New ocean fish:**
  - Sardine (12 coins), Mackerel (26, daytime).
  - Pufferfish (45): makes sudden darts.
  - Swordfish (95, 10 AM - 6 PM): strong, drains the meter faster.
  - **Moonfish** (260, legendary): only at night, only off the end of the dock, and it glows.
- **Sal**, a new fisherman villager in a sailor hat, lives in the hut. His quests: catch a pufferfish, then the Moonfish. The festival now needs Sal's help too (12 requests in total).

**Bug found and fixed:** villagers walked in straight lines and could get stuck on trees (Pip got wedged on "the tall pine" on his way home). They now steer around trees, rocks and buildings, and sidestep if they still get stuck.

**Testing:**
- **New features:** 25 new automated checks passed:
  - the tumbling flour, baking (win and fail/retry) and memory game;
  - the detector getting stronger near coins, and digging;
  - walking down the beach to the end of the dock, where railings and the end rail stop you;
  - the waterline wall, the ocean/pond/dock fish tables, catching a pufferfish, and Sal's quests.
- **Regression:** the full regression test passed with 5 villagers, and all five get home at night in under 12 seconds.

### 9. Easier fishing option (2026-09-28, 8:41 PM)
> Add an option in the settings to switch between the fishing mini game and the easier version of fishing.

**What was done**
- **New setting:** "Fishing style" in the Esc pause menu.
  - **Minigame (timing bar):** the original timing-bar minigame.
  - **Simple (just react to the bite):** press Space or E when the "!" appears and the fish is caught, with no timing bar. Rarer fish give you less time to react: about 1.1 s for a minnow, 0.8 s for a bass, and about 0.5 s for the Golden Carp and Moonfish.
- The choice is saved in `settings.cfg`, not the save game, so it applies to every save.
- **Bug fixed along the way:** saving the volume used to rewrite `settings.cfg` from scratch. It now keeps the other settings in the file.
- **Testing:** simple mode catches in time and lets fish escape when you're too slow, in both the pond and the ocean; minigame mode still works; the menu option switches modes; both settings survive in the file. The full regression test passed.

### 10. More minigames, money to spend, fixes (2026-09-28, 10:00 PM)
> Add more minigames, maybe turn farming into a mini game? But add more elsewhere as well. Make the UI for the minigames nicer. Also add something more to do with money to add more playability for after the player has "won". The legendary fish are a little too common. Make them slightly rarer but not impossible to find. Raise the gold count for the festival since fishing is so profitable now. The hats the npcs wear are not quite on them and clip when the walk.

**Farming minigame ("Pull!")**
- Harvesting a ripe crop now opens a quick minigame: a marker rises and falls; stop it in the green band.
  - **Perfect:** 2 crops. **Good:** 1 crop, plus a 25% chance of a second. **Weak or too slow:** still 1 crop, so you never lose a harvest.
  - Harder crops are faster with a thinner band: wheat is easiest, pumpkins hardest.
- New **Farming style** setting in the Esc menu: **Minigame** (default) or **Simple** (harvest instantly, always 1 crop). Saved in `settings.cfg` like the fishing style.
- **Sprinklers** (800 coins at the market): your farm waters itself every morning, and you can see them spraying from 6 to 8:30 AM.

**New minigames around the village**
- **Crab Rocks** (on the beach, north of Sal's dock): once a day, a 25-second whack-a-crab on a 3x3 grid. Press 1-9 or click the crabs; grabbing a jellyfish loses a crab. Crabs sell for 15 coins.
- **Pip's race** (the "Race Pip!" sign next to the well): unlocks after you beat Pip at tag. A 3-2-1-GO countdown, then race Pip through 9 glowing rings around the village and back. Win to get 50 coins (once a day; you can rematch for fun) and a best-time record.
- **Fireflies**: after 8 PM, glowing fireflies drift over the meadows. They flit away when you get close, but you're faster; press E to catch one in a jar (20 coins each).

**Nicer minigame UI**
- A shared style (`ui_style.gd`) for every minigame screen, the market and the new projects board:
  - warm wooden panels with a gold border and drop shadow, and a round icon badge next to the title;
  - keyboard-key hint badges ("SPACE or E or click"), progress pips, and big pop-up result words ("Perfect!", "Burnt!", "Ouch!");
  - a pop-in animation when a screen opens.
- Hand-drawn vector icons (`ui_icon.gd`) for bread, flowers, fish, crabs, jellyfish, crops, coins, fireflies, hats and more; no image files needed.
- The baking, flower memory and fishing screens were all restyled to match.
- The market now has **Buy / Hats / Sell** tabs with icon cards.

**Things to spend money on (mostly after the festival)**
- **Hats** for you, sold at the market: Party Hat 250, Straw Hat 400, Flower Crown 700, Pirate Hat 1,500, Golden Crown 6,000. Buy them, then wear or take them off from the Hats tab.
- **Master Rod** (2,000; needs the Better Rod): the biggest catch bar, and legendary fish bite twice as often.
- **Village projects board** (next to the well). Before the festival it's a teaser; afterwards you can donate 100, 500 or the rest at a time. Each finished project appears in the village immediately:
  - **Flower Gardens** (800): four flower beds around the square.
  - **Fountain** (2,000): a stone fountain with spraying water.
  - **Bandstand** (3,500): lit at night; villagers gather and dance there in the evening.
  - **Golden Statue** (10,000): a shiny gold statue of you, in a crown, on an "OUR HERO" pedestal.
- Villagers gossip about the projects you've funded, and the projects become landmarks in their hints.

**Balance changes**
- **Legendary fish are about half as common:** the Golden Carp is now about 4% of dawn pond bites (was about 8%), and the Moonfish about 6% of night dock bites (was about 12%). The Golden Lure and Master Rod each double that.
- **The festival now costs 1,000 coins** (was 300).

**Hats fixed:** NPC hats are now attached to the robot's torso (which carries the head) instead of floating at a fixed height, so they stay on and move with the walk instead of clipping. They were also resized to sit snugly.

**Small fix:** villager hints could say "near ." when an item was closest to an unnamed object such as a lamp. Hints now only use named landmarks.

**Testing:**
- **New features:** a new test with 50 checks passed, covering:
  - legendary odds and the Master Rod, and the 1,000-coin festival;
  - a perfect pull, a missed pull, and simple farming mode;
  - sprinklers watering and spraying;
  - the crab game (a bot caught 34 in one round), once per day, and the jellyfish penalty;
  - the race: locked before tag, the countdown, a full run of the course in 23.6 s, the prize, and Pip winning if you stand still (28 s);
  - fireflies spawning, fleeing, being caught and leaving at dawn;
  - buying, wearing and removing hats, and the Sell tab;
  - project donations (partial, overpay, all four built), villagers gathering at the bandstand, and save/load/new game.
- **Regression:** the two earlier tests passed (22 and 28 checks).
- **Screenshots:** the new places, NPC hats while walking, and every new screen were checked.

### 11. Walk-in houses, house minigames, cooking, more crops and fish (2026-09-28, 11:15 PM)
> Add the ability to walk into each house. I want there to be a mini game in all the houses. Maybe it can be baking for Bram or something like that. Make the mini game in the player's house a cooking game. Add a few more crops and fish. I noticed some things to fix when playing it. Bram's flour went right through a house. Pip gives up on her race if you talk to her during it. The market menu says press esc to close but that just brings up the escape menu. Also make the village projects and hats slightly easier to get.

**Walk-in houses**
- Press E at any front door to go inside; press E on the green EXIT mat to go back out. Both fade through black.
- Each house has its own furnished room, seen through a cut-away front wall from a fixed camera:
  - **Bram's Bakery:** a glowing brick oven, a counter of loaves, flour sacks.
  - **Ivy's Flowers:** a workbench with a vase, flower pots and hanging baskets.
  - **Pip's Room:** a play mat with a block tower, a little bed, a toy chest and paper stars.
  - **Otto's Curiosities:** a glass curio cabinet, an armchair, a grandfather clock and books.
  - **Sal's Bait & Tackle:** a sorting table with three baskets, nets, a life ring and fish crates.
  - **Your house:** a kitchen with a stove, your bed, a table, a bookshelf and a plant.
- Villagers lock their doors from 9 PM to 7 AM. Your house is always open.
- **Your bed is now inside your house** (the old "Sleep" spot by the door is gone). Sleeping in bed wakes you up next to it. Passing out anywhere else wakes you outside your door.
- Rooms have windows that turn dark at night and warm lamps.

**A minigame in every house** (once a day each, except cooking)
- **Bram: baking.** Stop the oven needle in the golden zone. You keep every loaf you bake (3 for a full win); bread sells for 20.
- **Ivy: Flower Shop.** Customers show an order ticket of 4, 5 and then 6 flowers. Press them in order (1-4 or click) before the timer runs out; a wrong flower spoils the order. Each order filled gives a bouquet (35 coins).
- **Pip: Block Tower.** A block slides back and forth; press Space/E/click to drop it on the tower. Any overhang is cut off, so the blocks get narrower; a perfect drop keeps the width. Stack up to 15. Pip pays 5 coins per block.
- **Otto: Curio Cabinet.** Flip cards (click) to find 6 matching pairs in 11 tries. 8 coins per pair, plus 40 for finding them all.
- **Sal: Catch Sorting.** Items flop onto the table one at a time: pond fish go left (A), junk down (S), ocean fish right (D), or click a bin. Items come faster as you go; 15 items, 3 mistakes allowed. 4 coins each, plus 20 for a perfect sort.
- **Your stove: Home Cooking.** Pick a recipe (1-6), then three steps, each worth a star:
  1. **Chop:** tap Space fast to fill the bar in 4 seconds.
  2. **Stir:** press the 6 shown keys (WASD) in order within 5 seconds, with at most one mistake.
  3. **Cook:** hold Space to raise the heat and let go to cool; keep it in the moving green zone for 3 seconds.
  - 3 stars makes 2 dishes, 1-2 stars makes 1, 0 stars burns it. Ingredients are used when you start.

| Recipe | Ingredients | Sells for |
|---|---|---|
| Grilled Fish | 2 fish (any) | 70 |
| Fish Stew | 1 fish + 1 carrot | 90 |
| Tomato Soup | 2 tomatoes | 120 |
| Pumpkin Pie | 1 pumpkin + 2 wheat | 170 |
| Corn Chowder | 1 corn + 1 fish | 210 |
| Strawberry Cake | 2 strawberries + 1 wheat | 280 |

- Villagers now mention their houses in chats ("Pop into the bakery sometime").

**New crops and fish**

| New crop | Seed price | Days to grow | Sells for |
|---|---|---|---|
| Tomato | 15 | 3 | 40 |
| Strawberry | 35 | 4 | 95 |
| Corn | 40 | 5 | 120 |

- Each crop has its own plant model (a tomato vine on a stake, a low strawberry clump with berries, a tall corn stalk with cobs), a market icon and its own "Pull!" speed. Corn is the hardest pull.

| New fish | Where and when | Sells for |
|---|---|---|
| Trout | Pond, 6 AM - 6 PM | 32 |
| Eel | Pond, 8 PM - 2 AM; darts like a pufferfish | 58 |
| Squid | Ocean, 7 PM - 2 AM | 50 |
| Tuna | End of the dock only, 7 AM - 5 PM; pulls hard like a swordfish | 130 |

**Bugs fixed**
- **Bram's flour went through houses.** When a sack hit a house it was nudged toward the village centre, which for the outer houses pushed it straight through. Sacks now check their next step and turn to a clear direction before moving; one that somehow ends up inside something steps back out.
- **Pip quit the race if you talked to her.** Racing villagers can no longer be talked to (no "E: Talk" prompt), so the race carries on.
- **Esc in the market opened the pause menu.** The pause menu now stands aside while the market or the projects board is open, so Esc closes them as the button says.
- **Found while testing:** Sal's sorting game froze after the first fish, because a leftover timer went just below zero. Fixed.

**Cheaper hats and projects**
- **Hats:** Party 175 (was 250), Straw 300 (was 400), Flower Crown 500 (was 700), Pirate 1,000 (was 1,500), Golden Crown 4,000 (was 6,000).
- **Projects:** Gardens 600 (was 800), Fountain 1,500 (was 2,000), Bandstand 2,500 (was 3,500), Statue 7,000 (was 10,000).
- Everything together now costs about 20,000 coins (was about 27,000).

**Testing:**
- **New features:** a new test with 81 checks passed, covering:
  - the three bug fixes;
  - entering and leaving all six houses, walls holding you in, and locked doors at night;
  - each house game played through (perfect runs and mistakes), payouts and once-a-day limits;
  - cooking a 3-star soup and burning a stew;
  - sleeping in your bed and passing out indoors;
  - the new crops growing, the new fish biting in the right places, and save/load.
- **Regression:** the earlier tests passed (22 + 28 + 50 checks, updated for the new prices and fish).
- **Screenshots:** every room and every new screen were checked. Fixes from them: the ceiling lamp hid the room signs, Otto's glass showed as a white slab, windows stayed bright at night, and the rooms were enlarged so they feel less cramped.

### 12. Everyday activities, a puppy, music, more minigames, deeper villagers (2026-09-29, 12:45 AM)
> Add more everyday activities and more minigames. Everyday activities could include treasure hunting, foraging, and a pet to take care of. Add a mini game that uses an instrument and maybe add a freestyle mode for the instruments. Add other minigames as well. Add more depth to the npcs.

**Everyday activities** (everything refreshes each morning)
- **Treasure hunting.** A message in a bottle washes up somewhere on the beach every day.
  - Opening it gives you a treasure map: a live, hand-drawn map of the village with an X and an arrow showing where you are.
  - Press **M** to show or hide the map; you can walk around with it open.
  - A patch of turned earth marks the spot up close; press E to dig.
  - Finds: a chest of 60-150 coins, a Gemstone (120), an Ancient Coin (80) or an Old Relic (200).
- **Foraging.** 12 finds appear around the village every morning:
  - wild berries and herbs in the meadows;
  - mushrooms near the forest edge, with the odd truffle (95);
  - seashells on the beach, with a rare pearl (160).
  - They're used in three new recipes and make good gifts.
- **Your puppy.** A stray puppy waits by your front door on day 1. Say hi, name it, and it's yours (it gets a red collar).
  - It follows you everywhere, even into houses, sits when you stop, wags its tail (harder when happy) and barks now and then.
  - Press E on it for the pet menu: **Pet** (+10), **Feed** a Pet Treat from the market (8 coins) or a fish (+15), and **Play fetch** (+15). Each counts once a day.
  - Fetch: face where you want to throw, press E; the pup runs after the ball and brings it back, 3 throws.
  - Skipping meals or pats makes it sadder overnight. A happy, fed pup (60+) brings you a present some mornings.

**Music: three instruments, songs and freestyle**
- **Where:** the new **piano** in your house, and the bandstand once it's built. The **Guitar** (300) and **Flute** (250) are sold at the market; the piano is free.
- **Sounds:** each instrument has its own synthesized sound, pitched to real notes.
- **Song mode (rhythm game):** notes fall down 4 lanes; press D F J K (or 1-4) as they cross the line.
  - Every note plays its real pitch, so you're playing the melody, with a soft bass and chord accompaniment.
  - Timing grades: Perfect / Great / OK / Miss. There's a combo bonus, a final grade (S to D) and a saved best score.
  - Songs pay up to 60 coins once a day.

| Song | Level |
|---|---|
| Village Waltz | Easy |
| Harvest Jig | Medium |
| Moonlit Sea | Hard |

- **Freestyle:** play anything on a one-octave keyboard.
  - White keys A S D F G H J K; black keys W E T Y U.
  - Z / X change octave, Q switches instrument.
  - R records and P plays back what you recorded.
- **At the bandstand**, villagers nearby cheer and hop.

**Other new minigames**
- **Stone skipping** (the pile of flat stones at the pond's edge): stop the angle needle low (around 18 degrees is best), then the power bar near the top. 5 throws, a saved record, and 3 coins per skip of your best throw once a day. Too steep and it just plops.
- **Stargazing** (the telescope east of your house, at night): the card shows a constellation's shape; find it hidden among ~46 other stars and click its stars. A wrong star costs 2 seconds; 30 seconds each, 3 per session.
  - Chart all 8: The Fish, The Crown, The Watering Can, The Lantern, The Dog, The Boot, The Ship and The Bread Loaf.
  - Each new constellation pays 40 coins and goes in your journal.

**Deeper villagers**
- **Friendship hearts (0-10):**
  - chatting once a day +10;
  - finishing a request +60;
  - gifts: loved +80, liked +45, neutral +20, disliked -30.
  - Hearts show next to their name in the dialogue box.
- **Gifts:** press **G** next to a villager to pick something from your bag, once a day each. Every villager has their own tastes (Pip hates vegetables, Ivy dislikes fish, Otto loves relics, Sal thinks flowers on a boat are bad luck) and personal reactions. Tastes you discover are remembered in the gift picker and the journal.
- **Birthdays:** each villager has one (a season is 28 days), and gifts count double that day. They'll mention it when you talk.
- **Heart events:** at 2, 5 and 8 hearts each villager tells you a bit of their story and gives you something.
  - **2 hearts:** a small gift.
  - **5 hearts:** a **secret recipe** that appears at your stove: Bram's Harvest Loaf, Ivy's Garden Salad, Pip's Berry Pancakes, Otto's Truffle Stew, Sal's Seafood Platter.
  - **8 hearts:** their own **hat**: Bram's chef hat, Ivy's flower, Pip's propeller cap (it spins when you run), Otto's top hat, Sal's sailor cap.
- **New lines as you get closer:** backstory at 3 hearts (Bram's father's bakery, Ivy leaving the city, Sal's boat the Marigold...) and more personal things at 6.
- **Opinions:** villagers share what they think of each other.
- **Daily routines:** each villager has favorite spots at certain hours and does something there (Bram sets out loaves at the market in the morning, Ivy waters flowers, Pip hunts for shells then skips stones, Otto feeds the pigeons and naps under the big oak, Sal watches the tide).
- **Journal (J):**
  - **Villagers:** hearts, birthday, bio, discovered tastes, today's gift/chat status, what they're doing now and when the next story unlocks.
  - **Pet**, **Collections** (fish, crops, dishes, forage, treasures, constellations, stone-skip and race records, song bests, secret recipes) and a **Calendar** with birthdays.

**Also**
- Three new recipes: Mushroom Soup (2 mushrooms, 110), Berry Tart (2 berries + wheat, 120), Herb-Baked Fish (fish + herbs, 115).
- The cooking menu now shows only recipes you know, in two columns (keys 1-9 or click).
- The market sells Pet Treats, the Guitar and the Flute, and buys forage finds and treasures.
- The market's Hats tab shows villager gift hats once you own them.

**Found and fixed while testing:**
- The treasure map's coastline failed to draw (a single big polygon couldn't be triangulated); it's now drawn in strips.
- The piano was half out of view in your house, and shells were hard to spot on the bright sand (they're bigger and pinker, with a glint).
- The puppy's E prompt could steal focus from things you were standing at, so its range is smaller now.

**Testing:**
- **New features:** a new test with 62 checks passed, covering:
  - adopting and naming the puppy, following into houses, pet/feed/fetch, morning presents and overnight sadness;
  - foraging (a mix of finds, shells only on the beach, picked spots staying picked, new ones the next day);
  - the bottle, map and digging;
  - friendship from chats, gifts and tastes, birthdays, all three of Bram's heart events and the chef hat in the wardrobe;
  - routines, the journal tabs;
  - a full song on the guitar, freestyle recording and playback;
  - stone skipping (14 skips, and a "plop");
  - charting 3 constellations, and save/load/new game.
- **Regression:** all earlier tests passed (22 + 28 + 50 + 80 checks).
- **Screenshots:** every new screen and object was checked.

### 13. Wood and stone, a town hall, and a request board (2026-09-29, 2:45 AM)
> Add gathering wood and stone and add a town hall that you can build with resources gathered. Also add optional quests that the npcs offer on a board. Maybe something like delivering a type of fish or crop.

**Gathering wood and stone**
- **Where:** 14 choppable trees (marked with a **red ribbon** on the trunk) and 10 boulders stand around the edge of the village.
- **Chopping and breaking:** press E to swing.
  - A tree falls after 3 hits (it topples away from you with a creak and a thud) and gives 3-4 wood.
  - A boulder breaks after 4 hits and gives 3-4 stone, with an 8% chance of a gemstone.
  - Wood chips and stone chips fly with each hit, and the prompt shows your progress (1/3...).
- **Regrowth:** a stump or rubble is left behind, and it grows back after 2 days.
- **Placement:** always the same spots, kept clear of paths, the beach, the town hall site and Pip's race course.
- **Market:** sells wood and stone (15 each) if you're in a hurry, and buys them back cheaply.

**The Town Hall** (construction site east-northeast of the well, between the dock path and Ivy's house)
- Built in 4 stages. Each one appears in the world the moment it's finished:

| Stage | Needs | What appears |
|---|---|---|
| 1. Foundation | 30 stone + 200 coins | A stone floor |
| 2. Frame | 40 wood | Timber posts and beams |
| 3. Walls | 30 wood + 30 stone | Walls, windows and a double door |
| 4. Roof | 25 wood + 15 stone + 500 coins | A blue roof, a bell tower with a clock and a golden bell, a waving flag and a TOWN HALL sign |

- **Contributing:** press E at the site. Give what you have a bit at a time; partial progress is saved.
- **Helpers:** while it's going up, villagers wander over to help ("~ hammering ~").
- **Grand opening:** confetti, and cheering villagers.
- **Inside:** banners, a podium, a meeting table, a second request board, a trophy shelf and a Village Records plaque (fish caught, crops, dishes, requests done, treasures, best stone skip, best race).
- **Perks:** the request board gets a 4th slot, and request rewards go up by 25%.

**The request board** (next to the market stall)
- **New notes:** every morning villagers pin up optional jobs, up to 3 notes (4 with the town hall). Each villager asks for their own kind of thing:
  - **Sal:** fish, from sardines to tuna, or a fish stew.
  - **Bram:** crops, wood or a pumpkin pie.
  - **Ivy:** herbs, berries, mushrooms, strawberries.
  - **Pip:** shells, crabs, fireflies, small fish, berry tarts.
  - **Otto:** wood, stone, mushrooms and fish.
- **Taking notes:** take up to 3 notes at a time. Each gives you 3 days, and shows in the quest log with your progress and days left.
- **Handing in:** talk to that villager when you have the items. They take them and pay about 1.6x what the items would sell for (2x with the town hall), plus +40 friendship. If you haven't got everything yet, they remind you.
- **Expiry:** notes nobody takes come down after 2 days; accepted requests that run out of time drop off with a note.

**Found and fixed while testing:**
- A boulder landed right on Pip's race course and blocked the path between two rings. Trees and boulders now keep clear of the course.
- In the town hall, the request board and records plaque were on the side walls where the camera cut them off; they're on the back wall and standing in the room now.
- The "villagers gather at the bandstand" check sometimes failed because villagers stopped to chat. It now pauses chatting for that one check.

**Testing:**
- **New features:** a new test with 35 checks passed, covering:
  - gathering: placement, ribbons, swing counts, stumps, walking through a felled tree, regrowth;
  - the town hall: partial contributions and saving, helpers, all four stages, exact costs, the door, the interior and solid walls;
  - the board: posting, taking a note, the quest log, a reminder, handing in (coins and friendship), the 3-request limit, expiry, the town hall bonus, and save/load.
- **Regression:** all earlier tests passed (22 + 28 + 50 + 80 + 62 checks).
- **Screenshots:** every construction stage, the finished hall at dusk, the interior, the board and both screens were checked.

### 14. Tidier village, nicer houses, gathering minigames, pet modes, a village map (2026-09-29, 2:30 PM)
> I noticed the dog would get stuck behind a rock sometimes playing fetch. Fix that but I would also like to clean up the center area. There is a tree in the path and rocks in awkward spots. Make the center area nicer, it feels too cluttered. Make tree cutting and stone breaking into a minigame with toggles like fishing. Add a way to leave your pet at home or let the wonder the village. Add the option to change the "Home Sweet Home" In the player's house to whatever the player wants. Make the background music quieter or even turn off when player is playing instruments. Make the houses look better while you clean up the center area. Add a map the player can either in the journal or i the player's house that shows the player where all the minigames are.

**The dog no longer gets stuck**
- The pup now steers around trees, rocks and buildings, like the villagers do.
- If it still isn't getting anywhere, it hops and sidesteps. After a couple of seconds stuck, it simply appears on the other side, so it can never stay stuck behind a rock.
- This works for fetching, following and exploring.

**A tidier, nicer village centre**
- **A cobbled plaza** around the well (about 6 m across) with a stone curb, and the street lamps moved to its edge.
- **Nothing cluttering the middle:** no random bushes or flower patches within 12 m of the well (grass stays off the cobbles), and choppable boulders stay at least 17 m out.
- **Moved to the outskirts:**
  - the tall pine that stood on the path to Pip's house;
  - the grey rock that sat in front of the town hall;
  - the pointy rock where a flower bed goes;
  - the mossy rock.
  - Villagers still use their names in hints.

**Nicer houses.** Every house (the villagers' and yours) was rebuilt with:
- a stone base, timber corner posts and beams, and an overhanging roof with a ridge beam in a color matched to the walls;
- a gable with a round attic window, and a stone chimney with a little smoke;
- a framed front door with a small roof, a doorstep and a glowing lantern;
- four windows (front and sides) with frames, colored shutters and flower boxes.

**Chopping and mining minigames** (with a setting, like fishing)
- **Timber!** (trees): 3 swings; stop the swinging marker in the green for a clean cut (2 points) or the yellow for a chop (1).
  - The trunk shows a growing notch and topples at the end.
  - Wood = 2 + points / 2, plus 1 for a perfect 6 (so 2-6 wood).
- **Strike!** (boulders): 4 strikes; hit when the shrinking ring lines up with the glowing weak spot (perfect = 2, good = 1).
  - Cracks spread across the rock with each hit.
  - Stone = 2 + points / 2, plus 1 for a perfect 8 (2-7 stone), and each perfect strike raises the gemstone chance.
- **New setting, "Chopping & mining style":** Minigame (default) or Simple (the old 3-4 plain swings).

**Pet modes** (in the pet menu)
- **Follow me:** as before.
- **Stay home:** the pup potters around inside your house (it has its own cushion now) and comes to greet you when you get home.
- **Explore the village:** it wanders around on its own and curls up by your front door at night.
- Fetch works in any mode: the pup comes to you first, then goes back to its routine. The mode is saved.

**Name your home.** Stand under the sign inside your house and press E to write anything you like on it (up to 24 characters). It's saved.

**Quieter music while you play.** Background music fades out when you open the piano or bandstand, and fades back in when you're done. The new setting "Music while playing instruments" lets you pick **Off** (fade out, the default) or **Quiet**.

**A village map of everything to do**
- A new **Map** tab in the journal (J), also opened from a framed map on your house wall.
- It shows 17 numbered places with a legend of what you can do there: the market, request board, projects board, Race Pip, pond, flat stones, dock and beach, Crab Rocks, telescope, farm, your house, each villager's house game, and the town hall (plus the bandstand once built).
- Small dots show trees to chop, boulders and today's forage finds, plus today's treasure X and an arrow for you.

**Also:** the pause menu is wider, with the four style settings in two columns.

**Testing:**
- **New features:** a new test with 31 checks passed, covering:
  - the tidy centre and new houses;
  - the pup fetching a ball from behind a rock and over 6 trees and boulders;
  - all three pet modes and saving;
  - renaming and saving the sign; the wall map and journal map;
  - music fading out, coming back and the Quiet setting;
  - perfect and sloppy Timber!, a perfect Strike!, Simple mode, and the new settings.
- **Regression:** all earlier tests passed (22 + 28 + 50 + 80 + 62 + 35 checks). Two older tests were updated: one to use the simple chopping style, and one whose helper now skips the new sign and map spots.
- **Screenshots:** a before/after top-down view, the plaza, the new houses by day and night, and every new screen were checked.

---

### 15. Projects board at the market, a new race course, every tree and rock gatherable, rebuilt fountain, gardens, statue and bandstand (2026-09-29, 3:35 PM)
> Move the village project board next to the market. Update pips race to the updated village. Make all the trees and rocks breakable. There are a few that cannot be collected for resources. Except for the palm trees. Move the fountain as well and update its graphics. Also update the flower gardens. I havent seen the golden statue yet but it probably needs to be updated. Go ahead and update the bandstand too. Make it all look nicer.

**New layout.** The flower beds hug the square, Pip's race loops just outside them, and the bigger projects each got their own paved court further out, in the gaps between the paths:
- **Projects board:** beside the market, on the opposite side from the request board.
- **Fountain:** between Pip's path and yours (south-southeast).
- **Bandstand:** between Otto's path and the pond (west), facing the square across an open lawn.
- **Golden statue:** between the dock path and Pip's path (east-southeast), facing the well.
- Each court has a cobbled floor, a stone kerb and stepping stones from the nearest path.

**Every tree and rock can be gathered** (except the palms on the beach and the three Crab Rocks, which are part of the crab game)
- The named landmarks (the big oak, tall pine, lonely birch, old oak, grey, mossy, flat and pointy rocks, the big boulder) now work like the other trees and boulders. They keep their names for villagers' hints, leave a stump or rubble, and grow back in 2 days. Big ones (scale 1.25+) give 1 extra wood or stone.
- The 14 decorative trees around the edge became choppable too (28 random trees + 10 boulders + the 9 named ones). The red ribbons are gone, since every tree can be chopped now.
- Trees stay at least 2.5 m from the paths and out of the way of the farm gate.

**Fountain (rebuilt).** Three tiers:
- a wide stone basin with a rim you could sit on and wishing coins on the bottom;
- a middle bowl and a small top bowl, each spilling a sheet of water into the one below, with a jet on top;
- animated rippling water.
- Around it: three park benches and four potted shrubs.
- **New:** press E to toss a coin in and make a wish (1 coin, just for fun).

**Flower gardens (rebuilt).** Seven curved beds around the edge of the square, one in each gap between paths (the lawn by the race sign is left open). Each bed has:
- a stone kerb and dark soil, with leafy ground cover;
- lavender or hollyhocks at the back, tulips in the middle (a different colour scheme per bed) and daisies along the front;
- a clipped round shrub at each end.

**Golden statue (rebuilt).**
- A stepped marble plinth with gold bands and a brass plaque ("OUR HERO, who saved the Harvest Festival").
- You in gold, wearing the crown, holding a trophy up high with the other hand on your hip.
- Sparkling glints, four topiary pots, and a warm light on it after dark.

**Bandstand (rebuilt).** An octagon with:
- a brick base and a plank stage with steps at the front (you can walk up onto the stage and play from there);
- white posts and railings;
- a red roof with a white trim, a cupola and a gold finial;
- bunting and little lights under the eaves, and a hanging lantern at night;
- a drum, cymbal, music stand, stool and an upright piano on stage, plus flower boxes by the steps.
- Villagers now dance in a ring around it.

**Pip's race (new course)**
- The start / finish line is painted in black and white on the square, next to the "Race Pip!" sign (which has a chequered flag) at the edge of the lawn.
- 7 rings loop once around the village just outside the flower beds, then back to the line.
- The course is built after everything else is placed: each ring goes as far out as there's room, and every leg is checked so no building, tree, rock, lamp or flower bed is in the way. Trees, boulders and lamps also keep off the course.
- Pip runs it in about 19 s.

**Testing:**
- **New features:** a new test with 31 checks passed, covering:
  - every tree/rock within the village is gatherable (47), except palms and Crab Rocks;
  - chopping the big oak and breaking the big boulder, and regrowth;
  - the board at the market, and the map showing it;
  - each project's space (off paths, clear of buildings), the flower beds off the paths;
  - the wishing coin;
  - walking up the bandstand steps onto the stage and back down;
  - every race leg clear, no lamps or trees on the course, and both Pip and the player completing it.
- **Regression:** all earlier tests passed (22 + 28 + 50 + 80 + 62 + 35 + 31 checks). The older gathering tests were updated for the new tree counts (no ribbons, and big trees giving a bonus), and the projects test for the board's new spot.
- **Screenshots:** before/after top-down views and close-ups of each feature, by day and night, were checked.

---

### 16. Well, farm sign, Sal's shop, ghost berries, a museum in the town hall, a proper bag, map fix (2026-09-29, 4:54 PM)
> Clean up the gold plaque on the statue. Update the well in the middle of the village. Update or even take out the sign that says "your farm" in front of the farm. I noticed I keep getting a prompt to pick wild berries but I dont see any and nothing happens when I try to pick them. Fix the sign inside town hall as well. The words go off the sign. Add something else to the townhall as well. Something to do in it. Update the inventory system.  Update Sal's bait and tackle as well. Fix the map in the journal, it goes into the legend.

**Bug: "Pick wild berries" with nothing there**
- Each morning the old forage finds were removed but their "press E" spots were left behind, so yesterday's prompts hung around where nothing was.
- Now each find and its prompt are removed together. The message-in-a-bottle and the dig mound had the same leak and are fixed too.

**Bug: the journal map spilled into the legend.** The "Dock & beach" marker sat past the map's edge. Markers are now kept inside the map, the map clips anything drawn past its border, and the dock marker points at the dock itself.

**Bug: J or I didn't always close the journal or bag.** Switching tabs rebuilt the window and the old one's "closed" signal wiped the "open" flag. Fixed for both.

**Statue plaque.** A brass plate in a darker frame with corner screws. "OUR HERO" and "Saved the Harvest Festival" are sized to fit inside it (a test checks the text width).

**The well (rebuilt).**
- A ring of staggered stone blocks with capstones and a little moss, and dark water inside.
- A timber frame with a shingled roof, an axle with a crank, and a rope with a bucket.
- A spare bucket and two flower pots beside it.
- The frame only fades when the camera is right on top of it.

**The farm sign.** The old "Your Farm" board is gone. Instead, a wooden arch stands over the gate, with flowering vines on the posts and a small hanging "FARM" sign with painted wheat (readable from both sides).

**Sal's Bait & Tackle (rebuilt).**
- A beach shack on a plank deck, with blue plank walls, white corner boards and a red tin roof.
- A blue door, brass porthole windows, and a painted sign under a wooden fish.
- A striped porch awning hung with red and white buoys.
- A fishing net, a life ring, crates of fish, a barrel of rods, and a lantern that lights up at night.

**The town hall: records book and museum**
- The overflowing "Village Records" board is gone. A red **records book** on a lectern (press E) opens a tidy list of 11 village records, including fountain wishes and museum pieces.
- **New: the Village Museum.** Donate one of each fish, crop, forage find and treasure (29 pieces).
  - Fish swim in a long **aquarium** along the left wall.
  - Crops, finds and treasures sit on **stepped display shelves** on the right wall.
  - Press E at either one to open the museum screen: what's on display, what you're carrying that it still needs (click to donate) and "???" for things you haven't found yet.
  - Rewards at 5 / 10 / 15 / 20 / 25 / 29 pieces: 150, 300 (+ a gemstone), 500, 800 (+ a relic), 1,200 and 3,000 (+ a pearl) coins.
  - The trophies moved to a side table by the podium.

**A proper bag (inventory)**
- Press **I** (or Tab) for the new bag screen.
  - Totals: coins, number of things and what it's all worth.
  - Category tabs: Seeds, Crops, Fish, Finds, Food, Materials & more.
  - A grid of item slots with icons and counts.
- Click an item for its details:
  - what it sells for and where it comes from (e.g. which water and hours for each fish);
  - which of your known recipes use it;
  - villagers you've learned love it;
  - whether it's in the museum yet.
- Seeds have a "Plant these next" button. A small star marks things the museum still needs.
- **HUD:** the bottom-left box now shows your seeds (Q), a bag summary ("Bag (I): 33 things, 7 kinds") and icons for your last 6 finds, newest first, instead of long text lists.
- Seeds, quest items and each fish now have their own icons (fish are tinted by type).

**Testing:**
- **New features:** a new test with 28 checks passed, covering:
  - no ghost forage prompts after several days, one bottle, and picking works;
  - map markers inside the map;
  - the plaque, farm and Sal's sign text fitting, and the rebuilt well;
  - the records book, the museum prompt, donating, rewards, no double donations, fish swimming, and saving;
  - the bag opening and closing with I, tabs, sort order, "Plant these next", fish details, and the HUD's recent finds.
- **Regression:** all earlier tests passed (22 + 28 + 50 + 80 + 62 + 35 + 31 + 31 checks). The town hall test now checks the records book instead of the old board.
- **Screenshots:** every change was checked, including the hut and the well at night.

---

### 17. A playable .exe (2026-09-29, 11:16 PM)
> is there a way to turn the game into an exe or make it easier to play?

(Between 16 and 17 the project was also put on GitHub: https://github.com/LJAguil/Npc-Village.)

**Done:**
- **Windows and Linux builds**, exported with Godot 4.7's release templates.
  - Each is a single file with the game packed inside, so it runs with a double-click and no Godot install.
  - They're on a separate **`downloads`** branch of the GitHub repo, linked from the README: `NPC-Village-Windows.zip` (about 40 MB) and `NPC-Village-Linux.zip`, each with a short README.txt. (This session isn't allowed to create GitHub Releases, and the zip is too big to attach in chat.)
- **`export_presets.cfg`**: saved export settings for Windows Desktop and Linux, so you can make a new .exe from the editor with Project > Export.
- **A game icon** (`icon.png` / `icon.ico`: a cottage, a tree and a little robot villager). It's used for the window and for the .exe in Explorer.
- **README**: a "Play it" section (download, unzip, run; what to do about the Windows SmartScreen warning) and "Making a new .exe".

**Checks:** the Linux build was run on its own and reaches the title screen with no script errors (screenshot checked). The Windows build contains all the imported sounds and compiled scripts.

**Notes:**
- The .exe isn't code-signed, so Windows SmartScreen warns the first time ("More info" > "Run anyway").
- Saves go to the same folder as when playing from the editor.
- A browser version isn't possible as an artifact page: Godot's web engine file alone is about 40 MB, over the page-size limit.

---

## How to run
1. **Close Godot before copying new files in.** If it asks to save, say no. Otherwise it may save old scripts over the new ones.
2. Open the project in Godot 4.7 and press **F5**.
3. If Godot says files changed on disk, click **Reload**, not Resave.

## Controls
| Key | Action |
|---|---|
| WASD / arrows | Move |
| Space | Jump |
| E | Interact (talk, farm, fish, shop, go in/out of houses, sleep, dig, forage, chop trees, break boulders, build, read the board, pet menu, catch fireflies) |
| G | Give a gift to the villager you're facing |
| I or Tab | Your bag: every item, with details (sell price, where it's from, recipes, museum) |
| J | Journal (map, villagers, pet, collections, calendar) |
| M | Show / hide today's treasure map |
| 1-4 | Flower memory minigame |
| 1-9 (or click) | Crab catching minigame |
| 1-4 (or click) | Ivy's flower shop |
| Space / E / click | Drop a block in Pip's tower |
| Click | Otto's curio cards |
| A / S / D (or arrows, or click) | Sal's catch sorting |
| 1-9, then Space taps / WASD / hold Space | Cooking: pick a recipe, chop, stir, heat |
| D F J K (or 1-4) | Song mode (music) |
| A S D F G H J K, W E T Y U, Z/X, Q, R, P | Freestyle music: notes, octave, instrument, record, play back |
| Space / E / click | Stone skipping: stop the angle, then the power |
| Click | Stargazing: click the constellation's stars |
| Space / E / click | Timber! (stop the swing) and Strike! (hit when the ring lines up) |
| Space / E / click | "Pull!" when harvesting |
| Space / E / click | Stop the needle in the baking minigame |
| Q | Change seed |
| Hold Space / E / click | Reel in while fishing |
| Right-mouse drag | Rotate camera |
| Esc | Pause menu (save, volume, fishing / farming / chopping & mining styles, music while playing) |

## Code map
| File | Purpose | Tweak here |
|---|---|---|
| `scripts/game.gd` | Global state (autoload `Game`), save/load, key bindings | Item prices, crops, fish, shop stock, day length |
| `scripts/main.gd` | Builds the village (houses, farm, pond, market, lamps), day/night lighting and fog, quests, sleep, festival | `npc_defs`: villagers, dialogue, quest chains; map positions (`FARM_CENTER`, `POND_CENTER`...) |
| `scripts/npc.gd` | Villager AI: wander, chat, gossip, go home, tag | `FLEE_SPEED`, stumble timings, chat timing |
| `scripts/player.gd` | Movement, camera, interacting with the closest thing | `SPEED`, `JUMP_VELOCITY`, spawn point |
| `scripts/fishing.gd` | Casting, the fishing minigame and simple mode (pond and ocean) | `ZONE_*`, `FISH_SPEED_*`, `FISH_JUMP_*`, `simple_window()` |
| `scripts/minigames.gd` | Baking, flower memory, "Pull!" harvest and crab-catching minigames | Needle speed, zone width, pattern lengths, `pull_speed` per crop, `CRAB_TIME` |
| `scripts/house_games.gd` | Extends `minigames.gd` with the house games: bouquet, block tower, pairs, catch sorting, cooking | `ORDER_*`, `STACK_MAX`, `PAIR_TRIES`, `SORT_*`, cooking step timings |
| `scripts/gathering.gd` | Every tree and rock in the village: the named landmarks (`add_fixed`), the scattered trees and boulders, hits or the Timber!/Strike! minigames, stumps and regrowth | `TREES`, `BOULDERS`, hits, regrow days, `_bonus()` for big ones |
| `scripts/townhall.gd` | The town hall site, its four stages (models), contributions and grand opening | Costs are in `Game.TOWN_HALL` |
| `scripts/request_board.gd` | The request board: daily notes, accepting, handing in, expiry | `WANTS` (what each villager asks for), `ASKS`/`THANKS` lines, reward multiplier, days |
| `scripts/extra_games.gd` | Extends `house_games.gd` with music (songs + freestyle), stone skipping and stargazing | `SONGS` (write your own tunes as "NOTE:beats"), `FALL`, `CONSTELLATIONS`, skip formula |
| `scripts/everyday.gd` | Foraging, the daily treasure bottle and dig site, the telescope, the stone pile, the piano, the bandstand stage, the puppy's morning present | `FORAGE_COUNT`, treasure rewards, positions |
| `scripts/pet.gd` | The puppy: model, following, sitting, fetch | `WALK`, `RUN`, fetch distance |
| `scripts/panels.gd` | Treasure map overlay, adoption/naming, pet menu, gift picker, journal (with the village map), the bag (inventory), the village records and the museum screen | `item_icon()`, `item_about()`, `BAG_TABS` |
| `scripts/map_view.gd` | Draws the live treasure map | |
| `scripts/villager_data.gd` | Villager personalities: bios, birthdays, gift tastes, heart-tier lines, heart events and rewards, routines, opinions | **Edit freely**: `DATA`, `GIFT_POINTS`, `HEART_EVENTS` |
| `scripts/interiors.gd` | Walk-in houses: builds each room (far outside the village), door and exit spots, room cameras, stations, rewards, bed; the town hall's records book and museum (aquarium, shelves, `donate()`, swimming fish) | Opening hours, room size, furniture, payouts in `_reward()` |
| `scripts/activities.gd` | Crab Rocks, Pip's race (built by `build_race()` after everything else, with `race_leg_clear` / `on_race_course`), fireflies, the projects board, the four projects (flower beds, fountain with wishing coin, bandstand with a walkable stage, golden statue), sprinklers | Positions (`BOARD_POS`, `FOUNTAIN_POS`, `BANDSTAND_POS`, `STATUE_POS`, `RACE_SIGN_AT`, `RACE_GAPS`, `BED_INNER/OUTER`), `RACE_PIP_SPEED`, `RACE_PRIZE`, `MAX_FIREFLIES` |
| `scripts/projects_ui.gd` | The village projects screen | |
| `scripts/firefly.gd` | One firefly (drifts, blinks, flees, catchable) | Flee speed |
| `scripts/ui_style.gd` | Shared look for minigame and shop screens (panels, headers, key badges, pips, banners) | Colors |
| `scripts/ui_icon.gd` | Vector icons drawn in code | |
| `scripts/farm_tile.gd` | One farm tile and its plant visuals | |
| `scripts/shop_ui.gd` | Market screen (Buy / Hats / Sell tabs) | Hat colors and descriptions |
| `scripts/menus.gd` | Title and pause menus (volume, fishing style, farming style) | |
| `scripts/dialogue_ui.gd` | HUD: clock, coins, seeds / bag summary / recent finds, quest log, dialogue, win screen | |
| `scripts/audio.gd` | Music crossfade, sound effects, volume (autoload `Audio`) | |
| `scripts/character_visual.gd` | Robot model, recolor, hats (attached to the torso), animations | Hat shapes in `set_accessory()` |
| `scripts/interact_spot.gd` | Generic "press E here" spot | |
| `scripts/pickup.gd` | Collectible quest items (tumbling flour, buried coins) | Flour wind speed |
| `scripts/scenery.gd` | Terrain, beach, ocean, lighthouse, palms, hills, mountains, forest, trees, rocks, bushes, flowers, grass | Tree shapes, forest size, hill height and beach slope (`height_at`), `WATER_Y` |
| `shaders/recolor.gdshader` | Swaps the robot's purple to each villager's color | |
| `shaders/foliage.gdshader` | Leaf wind sway, per-tree tint, fade near the camera | `sway_strength` |
| `shaders/ocean.gdshader` | Waves, water colors, foam line | `wave_height`, colors |

**Build order (main.gd `_build_village`):** paths, houses, square, well, market, pond, farm, dock, town hall, request board, then the named trees and rocks, then the projects, then Pip's race, then the scattered trees and boulders (which avoid the race), then interiors and everyday activities, then lamps (which also avoid the race) and decor. Things placed later check `is_clear()` against everything placed earlier. Flower beds are *soft* landmarks: `is_clear(pos, margin, true)` ignores them.

**How interaction works:** anything in the `interactable` group has `get_prompt(player)`, `interact(player)`, `distance_to_player(player)` and `interact_range`. The player picks the closest one each frame. Villagers, farm tiles and interact spots all follow this pattern, so new interactables just need those four members.

**Settings:** `Game.gathering_mode` ("minigame" / "simple") and `Audio.instrument_music` ("off" / "quiet") were added in update 14. The fishing style is `Game.fishing_mode` and the farming style is `Game.farming_mode` (each "minigame" or "simple"), stored in `settings.cfg` next to the volumes.

**Crops, fish, goods, dishes and recipes** are all tables at the top of `game.gd` (`ITEMS`, `CROPS`, `FISH`, `RECIPES`, `SHOP`). A new crop also needs a plant model in `farm_tile.gd` and an icon in `ui_icon.gd`.

**Update-12 state** is one dictionary, `Game.extra` (friendship, gifts, heart events, recipes learned, the pet, forage/treasure days, music bests, skip record, constellations). New keys get defaults from `_default_extra()`, so old saves load fine. Helpers: `Game.xi()`, `xdict()`, `xarr()`, `pet()`, `hearts()`, `add_friendship()`.

**Sounds:** instruments are single samples recorded at middle C (`audio/inst_*.ogg`), and `Audio.play_note(instrument, midi)` pitch-shifts them.

**Interiors:** the rooms are real 3D rooms built at x = -500 (far outside the world), one every 30 m. Entering teleports the player there and switches to that room's camera; `player.fixed_camera` stops camera turning inside. `interiors.current` is the house you're in ("" outside).

**Money sinks** live in `game.gd`: `HATS`, `PROJECTS` (prices and descriptions) and the upgrade entries in `SHOP`. Project progress is `Game.projects` (id -> coins donated so far).

**Save file:** `user://save.json`. On Windows that's `%APPDATA%\Godot\app_userdata\NPC Village\`. Delete it to reset progress. Volume settings are in `settings.cfg` in the same folder.

## Map layout
| Place | Where |
|---|---|
| Well (village center) | (0, 0) on a cobbled plaza (radius 6.2); dirt paths run from here to everything else. Nothing random is placed within 12 m |
| Projects board | Beside the market (west side; the request board is on the east side) |
| "Race Pip!" sign and start line | West side of the square, on the open lawn facing the bandstand; the chequered line is on the cobbles |
| Flower beds | Seven curved beds around the edge of the square, in the gaps between paths |
| Fountain | Its own court south-southeast, between Pip's path and yours |
| Bandstand | Its own court west, between Otto's path and the pond, facing the square |
| Golden statue | Its own court east-southeast, between the dock path and Pip's path |
| Pip's race | A lap of 7 rings just outside the flower beds, starting and finishing on the square |
| Crab Rocks | On the beach, north of the dock |
| Town hall (construction site) | East-northeast of the well, between the dock path and Ivy's house |
| Request board | Next to the market stall |
| Trees and rocks | All of them can be chopped or broken (not the palms or Crab Rocks); the random ones are around the edge of the village |
| Telescope | Just east of your house |
| Stone pile (skipping) | The pond's east edge, facing the village |
| Treasure bottle, shells, pearls | Somewhere on the beach (new spots each day) |
| Piano | Inside your house, against the left wall |
| House doors | The front of each house (facing the well); press E to go in. Your bed is now inside your house |
| Market | North of the well |
| Villager houses | Bram NW, Ivy NE, Pip SE, Otto SW; Sal's hut on the beach |
| Your house and bed | South of the well |
| Your farm | Southwest, next to your house; the gate is on the north side |
| Pond | West of the well |
| Beach, ocean and dock | East of the well; the dock points straight out to sea |
| Lighthouse | On the headland north of the beach (you can see it but can't reach it) |
| Edge of the village | Round, 30 m from the well, with hills and forest beyond; on the beach side, the waterline |

## Tuning results
| What | Setting | Result (simulated human, 0.2 s reaction) |
|---|---|---|
| Tag | Pip speed 6.0 vs player 5.0; trips every 3–4.5 s for 0.7 s; 40 s limit | Usually caught in 5–18 s, occasionally escapes |
| Fishing, basic rod | Catch bar 95 px | Easy fish ~95%, bass ~86%, catfish ~88%, Golden Carp ~38% |
| Fishing, Better Rod | Catch bar 108 px | Golden Carp ~88% |
| Simple fishing | Reaction window = 1.3 s down to 0.5 s by fish difficulty | Minnow 1.1 s, bass 0.82 s, Golden Carp / Moonfish 0.54 s |
| Ocean fishing | Sardine 0.30, Mackerel 0.50, Pufferfish 0.60 (darts), Swordfish 0.85 (strong), Moonfish 0.95 difficulty | Moonfish is about as hard as the Golden Carp: ~38% basic rod, ~88% Better Rod |
| Baking | Needle 280 px/s, +90 per loaf; zone 95 px, -15 per loaf; 2 misses allowed | A careful player should usually pass |
| Economy | Start: 25 coins + 5 wheat seeds | Quest rewards total 735 coins; the festival costs 1,000 |
| Legendary fish | Golden Carp and Moonfish weight 4 (were 8 and 10) | Carp ~4.4% of dawn pond bites, Moonfish ~6.3% of night dock bites; x2 with the Lure, x2 again with the Master Rod |
| "Pull!" harvest | Speed 1.5 / 1.9 / 2.3 and band 40 / 34 / 28 px for wheat / carrot / pumpkin; 4 s limit | Perfect = 2 crops, good = 1 + 25% chance of 2 |
| Crab catch | 25 s; spawns every 0.75 s down to 0.38 s; 18% jellyfish | A perfect bot catches ~34; a person maybe 15–25 (~225–375 coins a day) |
| Pip's race | Pip 4.0 vs player 5.0; 7 rings + the finish; 90 s limit; 50 coin prize once a day | Pip finishes in ~19 s, so a straight run beats her by a few seconds |
| Money sinks | Hats 175–4,000; Sprinklers 800; Master Rod 2,000; projects 600 / 1,500 / 2,500 / 7,000 | ~20,000 coins to buy everything |
| House games (per day) | Bread 3 x 20; bouquets 3 x 35; tower 5/block (max 75); pairs 8 each + 40 (max 88); sorting 4 each + 20 (max 80) | Up to ~400 coins a day across the five houses |
| Gathering | Tree: 3 hits, 3-4 wood; boulder: 4 hits, 3-4 stone (8% gem); +1 for big ones; both regrow in 2 days | 32 trees + 15 rocks give ~110 wood and ~55 stone every 2 days |
| Town hall | 95 wood, 75 stone, 700 coins over 4 stages | Roughly 3-4 in-game days of gathering |
| Museum | 29 pieces (14 fish, 6 crops, 6 finds, 3 treasures); rewards at 5/10/15/20/25/29 | 5,950 coins plus a gem, a relic and a pearl in total |
| Request board | Reward = item value x count x 1.6 (+10), x2.0 with the town hall; +40 friendship; 3 days to deliver | 3 notes a day (4 with the town hall), up to 3 taken at once |
| Friendship | 100 points per heart, max 10 hearts; chat +10/day, request +60, gifts +80/+45/+20/-30, birthdays double | Heart events at 2, 5 and 8 hearts |
| Puppy | Pet +10, feed +15, fetch +15 (once a day each); overnight -15 if unfed, -5 if unpetted | Morning present at 60+ happiness if fed |
| Music | Perfect ±0.07 s (300), Great ±0.13 s (200), OK ±0.2 s (100); +20 per note at a 10+ combo | Up to 60 coins/day for a song |
| Stone skipping | Skips = power x (1 + 13 x angle quality^1.3) (+0-1 luck); over 38 degrees = plop | A bot with a good aim gets ~14; 3 coins per skip of your best (daily) |
| Stargazing | 30 s per constellation, wrong star -2 s; 8 constellations | 40 coins per new one, 5 for repeats |
| Cooking | Chop 4 s (~13 taps); stir 6 keys in 5 s, 1 mistake; heat: 3 s in a ±0.1 zone within 7 s | Dishes roughly double to triple the value of their ingredients |

## Problems hit and lessons learned
- **Overlapping spawns launch physics bodies.** Never spawn characters on top of each other. The slide-off logic in player/npc handles accidental overlaps.
- **Godot overwrites external edits** when the scripts are open in the editor. Close Godot before copying files in.
- **Test with the same Godot version the player uses.** The user is on 4.7, where a SceneTree `_physics_process` must return `bool`.
- **Headless testing can't show visuals.** Screenshots are rendered with `xvfb-run ... --rendering-driver opengl3`.
- **Preloading audio in an autoload fails on the first import** of a fresh project, so audio is `load()`ed at runtime.
- **GDScript can't infer types from `lerp()` or dictionary values**, so those variables need explicit types (`var x: float = ...`).
- **Tag bots that teleport pass through obstacles** and give misleading results. Simulate real key presses instead.
- **Villagers need obstacle avoidance.** Straight-line walking gets stuck on trees. `_steer_around_obstacles` in `npc.gd` uses the landmark list; anything with collision should be added to `landmarks` so villagers avoid it.
- **Water planes and a shallow sea floor fight each other.** If waves dip below the ground under the water, the ground shows through as dark patches. The sea floor must drop off quickly past the shoreline.
- **New asset files need Godot to import them.** If the editor is open when files are copied in, it may not rescan. Restarting Godot (or Project > Reload Current Project) imports them. The audio has a fallback, but models and textures don't, so any new ones need an import.
- **Hats must follow the animated bone, not the body.** A hat parented to the character root floats while the torso bobs; parenting it to the `torso` node keeps it on the head.
- **Camera-fade materials don't suit low objects.** Anything using `_mat()` with camera fade dithers out within 3.5–7.5 m of the camera, which made the statue pedestal and fountain vanish up close. Low decor uses solid materials; only tall things that can block the view fade.
- **Followers need obstacle avoidance and a stuck fallback.** Steering handles most cases; a "not making progress -> hop, sidestep, then just get there" fallback guarantees a follower can never stay stuck.
- **Keep the middle of a map deliberate.** Random scatter (bushes, rocks) near the hub makes it feel cluttered. Give the centre a designed feature (the plaza) and push randomness outward.
- **New obstacles must respect existing routes.** Anything placed in the world should keep clear of paths and of routes like Pip's race course, not just of other landmarks.
- **Mind the HUD when placing things in rooms.** The quest log covers the top-right of the screen, so important signs in a room shouldn't sit high on the right.
- **One big polygon can fail to triangulate** (Godot's `draw_colored_polygon` rejects self-intersecting or awkward shapes). Draw coastlines and other wiggly areas as strips of quads.
- **Keep the save format extendable.** Putting new features' state in one `extra` dictionary with defaults means old saves still load and adding features doesn't touch save/load code.
- **A follower with an interaction prompt competes for E.** Keep its interact range small so it doesn't steal focus.
- **Timers that count down can overshoot zero.** A countdown that ends when it reaches `<= 0` must be reset to exactly 0 afterwards if other code checks `== 0` (this froze Sal's sorting game).
- **Things that move on their own must look before they move.** Bram's flour checked for obstacles only after moving, then got pushed the wrong way. Check the next position first and turn away.
- **Two screens listening for Esc:** later nodes get input first, so the pause menu took Esc before the market could. Any screen that closes on Esc should turn off `menus.can_pause` while it's open.
- **Headless test loops that count frames aren't counting seconds.** Headless runs much faster than real time, so timed minigames need `create_timer` waits in tests.
- **Screenshots here use the Compatibility (OpenGL) renderer**, which looks brighter and hazier than the Vulkan (Forward+) renderer the game actually uses. A software Vulkan driver couldn't be installed here.

- **Build routes after the things they must avoid.** Pip's race used to be placed before the trees and rocks existed, so later objects could land on it. Now the course is built once the fixed objects are in, checks every leg, and anything placed afterwards keeps off it.
- **A round collider under an octagon leaves a lip.** The bandstand's round stage collider stuck out past the octagon's flat front, so you couldn't walk up the ramp. Keeping the collider inside the flat sides and tucking the ramp under the edge fixed it.
- **Parallel test runs need their own save folders.** Running suites side by side shares `user://`; giving each run its own `XDG_DATA_HOME` keeps their saves apart.

- **Remove a thing's interaction spot along with it.** Forage finds were freed each morning but their "press E" spots weren't, leaving invisible prompts behind. Anything with a spot stores it (`set_meta("spot", ...)`) and is removed with `_free_with_spot()`.
- **Rebuilding a window can reset its own flags.** When a panel reopens itself (switching tabs), the old copy's `tree_exiting` fires after the new one opened; check that it's still the current window before clearing "is open".
- **Check that 3D text fits.** `Label3D.get_aabb()` gives the text's real width, so tests can catch signs whose words run off the board.

- **Export templates can be fetched piece by piece.** The full 4.7 template bundle is 1.3 GB; reading the zip's directory with HTTP range requests and pulling only the Windows/Linux templates avoids downloading it all.

## Known limitations and ideas
- Audio hasn't been listened to (it was generated and tested headless). Adjust with the pause-menu sliders if needed.
- Colors and fog were tuned in the OpenGL renderer; the real game may look slightly different. Adjust `fog_density` in `main.gd` if the haze feels too strong or too weak.
- The lighthouse is scenery only (outside the walkable area).
- Collect-quest item positions aren't saved. On Continue, the remaining items respawn at new random spots.
- The golden statue always wears the crown, not the hat you're wearing.
- Villagers aren't shown inside their own houses (they're out in the village by day and hidden at home at night).
- Possible next steps: more villagers or quests, seasons, fish sizes and records, friendship rewards, more projects (a bridge), gamepad support.
