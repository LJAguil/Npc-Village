extends RefCounted
## Who the villagers are beyond their quests: a short bio, birthday, gift
## tastes, extra lines that unlock as you become friends, heart events
## (little stories with rewards at 2, 5 and 8 hearts), daily routines and
## what they think of each other. Edit freely!
##
## gifts:   loves / likes / dislikes are item ids; like_kinds / dislike_kinds
##          are item kinds ("fish", "crop", "dish", "forage", "treasure"...).
## spots:   [from_hour, to_hour, position, what they're doing] -- during those
##          hours they often wander to that spot and do their thing.
## events:  hearts -> {"lines": [...], and one reward: "items" {id: n},
##          "recipe" (a secret recipe id) or "hat" (a hat id)}

const DATA := {
	"Bram": {
		"bio": "The village baker. Up before dawn, smells permanently of bread. Grumbles a lot, cares even more.",
		"birthday": 5,
		"loves": ["strawberry_cake", "pumpkin_pie", "wheat", "berry_tart"],
		"likes": ["strawberry", "berries", "herb"],
		"like_kinds": ["crop", "dish"],
		"dislikes": ["shell", "crab", "firefly"],
		"dislike_kinds": [],
		"reactions": {
			"love": ["Now THIS is something a baker can work with! Thank you!", "Oh-ho! You know the way to my heart."],
			"like": ["Very kind of you. I'll find a use for it.", "Thank you, friend."],
			"neutral": ["Oh. Er, thanks. I'll... put it somewhere."],
			"dislike": ["What would I do with this? It'll stink up the bakery!"],
		},
		"hearts_lines": {
			0: ["Mind the flour on the floor.", "Busy, busy. Always busy."],
			3: ["My father ran this bakery before me. His oven still works better than any new one.", "I save the burnt loaves for the birds. Don't tell anyone."],
			6: ["You know, you're the first person who's asked how I'm doing in years.", "One day I'll teach Pip to bake. If Pip ever stands still long enough."],
		},
		"events": {
			2: {"lines": ["Ah, it's you. Here -- I made too many rolls this morning.", "Well, 'too many.' I made extra because I hoped you'd stop by.", "Don't make it weird. Take the bread."],
				"items": {"bread": 3}},
			5: {"lines": ["Sit down a moment. I want to show you something.", "This is my father's recipe card. The Harvest Loaf.", "He only ever taught it to people he trusted. I... think he'd have liked you.", "Wheat and pumpkin, baked slow. Try it at your stove."],
				"recipe": "harvest_loaf"},
			8: {"lines": ["I've been thinking. A proper cook needs a proper hat.", "This was my first chef's hat. It's seen a thousand loaves.", "Wear it with pride. You're family now, whether you like it or not."],
				"hat": "chef_hat"},
		},
		"spots": [[7, 11, Vector3(1.8, 0, -14.5), "~ setting out loaves ~"], [14, 17, Vector3(-10.5, 0, -10.5), "~ kneading dough ~"], [17, 20, Vector3(2.8, 0, 1.2), "~ resting his feet ~"]],
		"opinions": {
			"Ivy": "Ivy brings me flowers for the shop window. Makes the bread look fancy.",
			"Pip": "Pip 'borrows' a roll every morning. I pretend not to notice.",
			"Otto": "Otto says my bread is too soft for his teeth. Then eats three.",
			"Sal": "Sal trades me fish for bread. Honest trade. Smelly, but honest.",
		},
		"birthday_lines": ["It's my birthday, you know. Nobody remembers a baker's birthday.", "...You did? Well. Hm. Thank you."],
	},
	"Ivy": {
		"bio": "Gardener and florist. Talks to her plants and swears they answer. Knows every flower in the valley.",
		"birthday": 12,
		"loves": ["bouquet", "strawberry", "herb", "garden_salad"],
		"likes": ["berries", "mushroom", "tomato", "firefly"],
		"like_kinds": ["forage", "crop"],
		"dislikes": ["bread", "old_coin"],
		"dislike_kinds": ["fish"],
		"reactions": {
			"love": ["Oh! It's perfect! I could just hug you!", "You remembered what I like! That's so sweet."],
			"like": ["How lovely, thank you!", "Ooh, this will look nice by my window."],
			"neutral": ["Oh, thank you! That's... interesting."],
			"dislike": ["Um. It's... wet. And it smells. But thank you for thinking of me?"],
		},
		"hearts_lines": {
			0: ["The roses are thirsty today.", "Did you know sunflowers follow the sun? I wish I had that much focus."],
			3: ["I came here from the city. Too much grey there. Here, everything grows.", "I name all my plants. The big fern is called Gerald."],
			6: ["When I'm sad I plant something. By the time it blooms, I'm usually okay again.", "You make this village feel more like home. Is that silly?"],
		},
		"events": {
			2: {"lines": ["You're just in time! I split my herb patch and have way too many.", "Take some -- they're lovely in cooking. And they make your hands smell nice."],
				"items": {"herb": 3, "bouquet": 1}},
			5: {"lines": ["Can I tell you a secret? I don't just grow flowers for looks.", "Tomatoes, strawberries and wild herbs... together they make the best salad.", "My grandmother's recipe. I've never shared it with anyone. Until now."],
				"recipe": "garden_salad"},
			8: {"lines": ["I picked this one the day you arrived in the village.", "I pressed it and kept it. I had a feeling you'd matter to all of us.", "Wear it in your hair. For luck. And for me."],
				"hat": "flower"},
		},
		"spots": [[7, 11, Vector3(9.5, 0, -9.5), "~ watering flowers ~"], [11, 15, Vector3(-15.6, 0, 1.5), "~ watching the frogs ~"], [15, 20, Vector3(-3.5, 0, 17.5), "~ admiring the farm ~"]],
		"opinions": {
			"Bram": "Bram pretends to be grumpy, but he gave me his umbrella last spring.",
			"Pip": "Pip once tried to eat one of my tulips. On a dare. From Pip.",
			"Otto": "Otto knows the old names of all the flowers. He's like a walking book.",
			"Sal": "Sal says the sea is his garden. I think that's beautiful.",
		},
		"birthday_lines": ["Today's my birthday! The whole garden bloomed for it -- well, I like to think so."],
	},
	"Pip": {
		"bio": "The village kid. Fastest legs in the valley (she'll tell you). Collects shells, bugs and trouble.",
		"birthday": 18,
		"loves": ["berries", "firefly", "shell", "berry_pancakes", "berry_tart"],
		"likes": ["strawberry", "crab", "pearl", "gem"],
		"like_kinds": ["critter", "treasure"],
		"dislikes": ["herb", "mushroom", "tomato"],
		"dislike_kinds": [],
		"reactions": {
			"love": ["WHOA! For ME?! You're the BEST!", "No way no way no way! Thank you!!"],
			"like": ["Cool! Thanks!", "Ooh, I'm putting this in my treasure box!"],
			"neutral": ["Huh. Okay. Thanks, I guess!"],
			"dislike": ["Ewww! That's a VEGETABLE. Or a fungus. Gross!"],
		},
		"hearts_lines": {
			0: ["Race you! ...Later. I'm busy.", "I can hold my breath for a whole minute. Almost."],
			3: ["My treasure box has 47 shells, 3 bottle caps and a tooth. Not mine.", "When I grow up I want to be a sea captain. Or a dragon."],
			6: ["Sometimes I pretend you're my big sibling. Is that okay?", "Don't tell Bram, but I'm scared of the dark. The fireflies help."],
		},
		"events": {
			2: {"lines": ["Psst! Come here! I found a secret.", "It's my best shell. And a firefly I caught last night.", "You can have them. Because you're my friend. Obviously."],
				"items": {"shell": 1, "firefly": 1}},
			5: {"lines": ["Okay okay okay. I'm gonna teach you something IMPORTANT.", "Berry pancakes! Berries, wheat and a strawberry on top. Bram doesn't know I make them.", "I burned the first eleven. You'll do better. Probably."],
				"recipe": "berry_pancakes"},
			8: {"lines": ["I made you something! Well, I fixed it. Well, I found it and then fixed it.", "It's a propeller cap! It doesn't make you fly. I checked. From the roof.", "Now we match! Kind of! Wear it ALWAYS."],
				"hat": "propeller_cap"},
		},
		"spots": [[7, 11, Vector3(27.5, 0, 9.0), "~ hunting for shells ~"], [11, 15, Vector3(-16.0, 0, -5.5), "~ skipping stones ~"], [15, 20, Vector3(6.0, 0, 6.0), "~ playing hopscotch ~"]],
		"opinions": {
			"Bram": "Bram's bread is the best. Don't tell him, his head will get big.",
			"Ivy": "Ivy lets me help in the garden. I mostly dig holes.",
			"Otto": "Otto tells the best stories! Some of them are even true.",
			"Sal": "Sal says he wrestled a shark once. I believe him. Mostly.",
		},
		"birthday_lines": ["IT'S MY BIRTHDAY!! Did you know? Did you? DID YOU?"],
	},
	"Otto": {
		"bio": "The village elder and self-appointed historian. Keeps a cabinet of curiosities and a hat of great dignity.",
		"birthday": 24,
		"loves": ["relic", "old_coin", "golden_carp", "truffle_stew", "truffle"],
		"likes": ["gem", "mushroom", "tomato_soup", "mushroom_soup"],
		"like_kinds": ["treasure", "dish"],
		"dislikes": ["firefly", "crab"],
		"dislike_kinds": ["critter"],
		"reactions": {
			"love": ["By my hat! A treasure! You have a keen eye, youngster.", "Remarkable. Simply remarkable. It shall have a place of honor."],
			"like": ["Hmm. Yes. Most thoughtful.", "A fine gift. Thank you kindly."],
			"neutral": ["Ah. How... modern. Thank you."],
			"dislike": ["It wriggles. Why does it wriggle? Take it away, please."],
		},
		"hearts_lines": {
			0: ["In my day, we walked to the well uphill. Both ways.", "Hmm. Yes. Indeed."],
			3: ["This village was founded by fishermen, you know. Sal's great-grandfather among them.", "My curio cabinet holds eighty years of memories. Each one has a story."],
			6: ["My dear wife loved the Harvest Festival. Seeing it again... it meant more than you know.", "You remind me of myself, long ago. Before the hat."],
		},
		"events": {
			2: {"lines": ["Ah, youngster. A word.", "I found this in my cabinet. An ancient coin, from before the village was built.", "I have three. You should have one. History ought to be shared."],
				"items": {"old_coin": 1}},
			5: {"lines": ["Every old man has one dish he's proud of. Mine is a stew.", "A truffle from the forest's edge and a good fish. Simmer it low.", "My wife made it every winter. Now you'll carry it on."],
				"recipe": "truffle_stew"},
			8: {"lines": ["I have been village elder for forty years. It is a heavy hat to wear.", "Literally. This is my spare. I would like you to have it.", "When I am gone, someone must keep the stories. I think it should be you."],
				"hat": "top_hat"},
		},
		"spots": [[7, 11, Vector3(2.6, 0, -1.8), "~ feeding the pigeons ~"], [11, 16, Vector3(-6.5, 0, -2.5), "~ napping under the oak ~"], [16, 20, Vector3(-3.2, 0, -5.0), "~ reading the notices ~"]],
		"opinions": {
			"Bram": "Bram's father was a great baker. Bram is... getting there. Don't repeat that.",
			"Ivy": "Ivy knows more about plants than any book I own. And I own many books.",
			"Pip": "Pip asked me if I was alive when dinosaurs were. I was offended. Mostly.",
			"Sal": "Sal and I have argued about the best fishing spot for thirty years.",
		},
		"birthday_lines": ["Today I turn... well, a gentleman never tells. But it is my birthday."],
	},
	"Sal": {
		"bio": "Old fisherman, forty years on these waters. Tells tall tales, keeps a tidy hut, and never misses a sunrise.",
		"birthday": 27,
		"loves": ["tuna", "moonfish", "fish_stew", "seafood_platter", "pearl"],
		"likes": ["squid", "swordfish", "shell", "bread"],
		"like_kinds": ["fish"],
		"dislikes": ["bouquet", "strawberry", "flower"],
		"dislike_kinds": [],
		"reactions": {
			"love": ["Well I'll be! That's a fine gift, matey. A FINE gift.", "Now you're speaking my language! Thank you kindly."],
			"like": ["Aye, that'll do nicely.", "Much obliged, friend."],
			"neutral": ["Hm. Thanks. I'll... use it as bait, maybe."],
			"dislike": ["Flowers? On a boat? That's bad luck, that is!"],
		},
		"hearts_lines": {
			0: ["The tide waits for no one.", "Smell that salt air."],
			3: ["My old boat was called the Marigold. Named after my mother. Sank in a storm, but I swam home.", "The lighthouse keeper was my best friend. He's gone now, but the light still turns."],
			6: ["I don't say it often, but it's good to have company on the dock.", "Forty years I've fished alone. These days I kind of like the chatter."],
		},
		"events": {
			2: {"lines": ["Ahoy! Caught a big one this morning and thought of you.", "Take it, and a treat for that pup of yours. Every sailor needs a ship's dog."],
				"items": {"tuna": 1, "pet_treat": 3}},
			5: {"lines": ["Sit down, matey. Let me tell you about the best meal I ever had.", "Three fish, fresh off the line, cooked right on the dock. A seafood platter fit for a king.", "Here's how it's done. Don't tell Otto -- he thinks he invented it."],
				"recipe": "seafood_platter"},
			8: {"lines": ["This cap went with me through every storm for forty years.", "Lost it overboard once. Dove in after it. Worth it.", "It's yours now. You've got the heart of a sailor, you have."],
				"hat": "sailor_hat"},
		},
		"spots": [[6, 11, Vector3(30.5, 0, 1.2), "~ watching the tide ~"], [11, 16, Vector3(25.0, 0, -3.5), "~ mending a net ~"], [16, 20, Vector3(30.0, 0, -6.0), "~ counting the waves ~"]],
		"opinions": {
			"Bram": "Bram makes a mean loaf. I trade him fish for it. Fair deal.",
			"Ivy": "Ivy tried to plant flowers on my dock. I pretended not to like them.",
			"Pip": "That Pip's got sea legs. Might make a sailor of her yet.",
			"Otto": "Otto thinks the best fishing spot is the pond. The POND. Can you imagine?",
		},
		"birthday_lines": ["Birthday today, matey. Another year older, another year saltier."],
	},
}


static func of(npc_name: String) -> Dictionary:
	return DATA.get(npc_name, {})


## "love" / "like" / "neutral" / "dislike" for giving this item.
static func taste(npc_name: String, item: String) -> String:
	var d := of(npc_name)
	if d.is_empty():
		return "neutral"
	var kind: String = Game.ITEMS[item]["kind"] if Game.ITEMS.has(item) else ""
	if item in d["loves"]:
		return "love"
	if item in d["dislikes"] or kind in d["dislike_kinds"]:
		return "dislike"
	if item in d["likes"] or kind in d["like_kinds"]:
		return "like"
	return "neutral"


const GIFT_POINTS := {"love": 80, "like": 45, "neutral": 20, "dislike": -30}
const TALK_POINTS := 10
const QUEST_POINTS := 60
const HEART_EVENTS := [2, 5, 8]
