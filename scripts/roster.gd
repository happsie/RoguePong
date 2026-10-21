class_name Roster
extends RefCounted
## The run: one stage per opponent, two per map (a regular opponent, then that map's boss).
## `setting` indexes Scenery.NAMES, `target` is the stage score needed before you run out of lives,
## `diff` (0..1) drives the opponent AI, and the rest is how the character is drawn (see Art.goof).

const STAGES := [
	{
		"name": "Surfer Dude", "title": "Gnarly with a paddle", "setting": 0, "target": 250, "diff": 0.0,
		"skin": Color("f2b27a"), "shirt": Color("ffcf3a"), "hair": Color("ffe14d"), "acc": "shades",
	},
	{
		"name": "Lifeguard Larry", "title": "Rescues balls, not points", "setting": 0, "target": 500, "diff": 0.1, "boss": true,
		"skin": Color("f0a07a"), "shirt": Color("ff5a4d"), "hair": Color("ffffff"), "acc": "cap",
	},
	{
		"name": "Sherpa Sam", "title": "Knows every shortcut", "setting": 1, "target": 900, "diff": 0.2,
		"skin": Color("d9a066"), "shirt": Color("2e8b6f"), "hair": Color("ff5a4d"), "acc": "beanie",
	},
	{
		"name": "Yeti Jeff", "title": "Abominable at table tennis", "setting": 1, "target": 1400, "diff": 0.3, "boss": true,
		"skin": Color("f2f6ff"), "shirt": Color("5aa7e8"), "hair": Color("ffffff"), "acc": "fur",
	},
	{
		"name": "Little Green Guy", "title": "Take me to your paddle", "setting": 2, "target": 2200, "diff": 0.42,
		"skin": Color("7be07a"), "shirt": Color("b86bff"), "hair": Color("7be07a"), "acc": "antenna",
	},
	{
		"name": "Commander Zorp", "title": "Zero gravity, zero mercy", "setting": 2, "target": 3200, "diff": 0.54, "boss": true,
		"skin": Color("9fe6c8"), "shirt": Color("ff8a1f"), "hair": Color("ffffff"), "acc": "fishbowl",
	},
	{
		"name": "Count Drac", "title": "Never misses after dark", "setting": 3, "target": 4500, "diff": 0.66,
		"skin": Color("e6e0f0"), "shirt": Color("2a1a3a"), "hair": Color("14101c"), "acc": "vampire", "stripes": false,
	},
	{
		"name": "The Pumpkin King", "title": "Smashing, and not just pumpkins", "setting": 3, "target": 6000, "diff": 0.78, "boss": true,
		"skin": Color("ff8a1f"), "shirt": Color("5a2a7a"), "hair": Color("4bc292"), "acc": "pumpkin",
	},
	{
		"name": "Pixel Pete", "title": "Insert coin to lose", "setting": 4, "target": 8000, "diff": 0.89,
		"skin": Color("6bffea"), "shirt": Color("ff6bd6"), "hair": Color("ffe14d"), "acc": "visor",
	},
	{
		"name": "Boss Bot 9000", "title": "Final boss. Has never lost.", "setting": 4, "target": 12000, "diff": 1.0, "boss": true,
		"skin": Color("aab6c8"), "shirt": Color("5a6a80"), "hair": Color("fe5f55"), "acc": "robot", "stripes": false,
	},
]


## What the opponent says when you lose a rally: a few lines of their own plus the shared ones.
const TAUNTS := {
	"Surfer Dude": ["Whoa, bro. That was gnarly. For you.", "Wipeout!", "You paddle like a dolphin with a cold.", "Stay chill. You're drowning."],
	"Lifeguard Larry": ["I couldn't save that rally.", "Whistle! Foul on you.", "No running, no swinging, no trying.", "I've rescued ferns with more skill."],
	"Sherpa Sam": ["Wrong route, friend.", "The summit is not for you.", "You lost the trail AND the ball.", "Thin air getting to you?"],
	"Yeti Jeff": ["Cold. Like your technique.", "Rawr. That means 'bad'.", "Snowmen have better reflexes.", "Brrr-utal."],
	"Little Green Guy": ["On my planet, babies do that better.", "Bzzt. Return denied.", "Humans. So soft.", "Take me to your better player."],
	"Commander Zorp": ["Gravity is optional. Skill is not.", "Houston, you have a problem.", "That ball left orbit. So did your skill.", "Zero gravity, zero chance."],
	"Count Drac": ["Blah! I vant your points.", "You're dead on the table.", "Fresher garlic bread plays better.", "Bleh. Pathetic."],
	"The Pumpkin King": ["Smashed. Just like a pumpkin.", "Spooky bad.", "That was a real squash.", "You're gourd-awful."],
	"Pixel Pete": ["Insert coin to try again.", "404: skill not found.", "You have died of dysentery.", "Press START. Then lose again."],
	"Boss Bot 9000": ["ERROR: OPPONENT TOO WEAK.", "CALCULATING... YOU LOSE.", "RESISTANCE IS INEFFICIENT.", "BEEP. BOOP. BAD."],
}
const TAUNTS_ANY := [
	"Ha! Not even close!", "Is that your best?", "My grandma hits harder.", "Nice try. Not.",
	"Oof. Hard to watch.", "Try using the paddle.", "Easy.", "Have you played before?",
	"Was that a swing or a sneeze?", "Do you need a tutorial?",
]
## And what they mutter when you win one.
const WHINES := [
	"Lucky shot!", "Hey! No fair!", "I was distracted!", "Okay, okay, that was good.",
	"Beginner's luck!", "My paddle slipped!", "Rematch!", "Pfft. I let you.",
]


static func count() -> int:
	return STAGES.size()
