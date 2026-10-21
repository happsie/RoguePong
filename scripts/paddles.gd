class_name Paddles
extends RefCounted
## Paddles. You hold one at a time; buying another in the shop swaps it in. Each has a face size, a
## reach (how far along the table the mouse can take it), a feel, and an ability on Space.
## Abilities: `stretch` (the reach extends), `focus` (time slows) and `grab` (a much stronger hit assist).
## The effects themselves live in Game, keyed by `ability`.
## `tier` sets the price (a share of the cleared stage's target, like Balls) and how often it is offered.

const CLASSIC := "classic"
const PREFIX := "paddle:"

## Fields: size and reach scale the base values, speed scales how fast the paddle follows the mouse,
## `cd` and `dur` are the ability's cooldown and active time in seconds. The rest is how it is drawn
## (see Art.paddle_disc): `face` and `rim` colours, `grip` for the handle wrap, `handle` for its
## length, `look` for the decoration.
const DEFS := {
	"classic": {
		"name": "Classic", "desc": "Balanced.\nStretch: reach wide\nballs for a moment.", "tier": 0,
		"ability": "stretch", "size": 1.0, "reach": 1.0, "speed": 1.0, "cd": 3.0, "dur": 0.5,
		"face": Color("fe5f55"), "rim": Color("c98b52"), "grip": Color("8a5a2f"), "handle": 1.0, "look": "classic",
	},
	"pan": {
		"name": "Frying Pan", "desc": "Huge face, short reach.\nGrab: a strong hit\nassist for a moment.", "tier": 1,
		"ability": "grab", "size": 1.4, "reach": 0.8, "speed": 0.85, "cd": 4.0, "dur": 1.2,
		"face": Color("3a4048"), "rim": Color("a8b0ba"), "grip": Color("2a2f35"), "handle": 1.35, "look": "pan",
	},
	"needle": {
		"name": "Needle", "desc": "Tiny but quick, with\nlong reach. Focus:\ntime slows down.", "tier": 1,
		"ability": "focus", "size": 0.75, "reach": 1.2, "speed": 1.3, "cd": 5.0, "dur": 0.9,
		"face": Color("ff6bd6"), "rim": Color("fff4dc"), "grip": Color("1fb8a0"), "handle": 1.1, "look": "classic",
	},
	"gold": {
		"name": "Golden Paddle", "desc": "Bigger face, long reach.\nStretch, ready sooner\nand lasts longer.", "tier": 3,
		"ability": "stretch", "size": 1.15, "reach": 1.25, "speed": 1.0, "cd": 2.0, "dur": 0.65,
		"face": Color("eac058"), "rim": Color("fff1b0"), "grip": Color("c9962a"), "handle": 1.0, "look": "gold",
	},
}

const ABILITY_NAMES := {"stretch": "STRETCH", "focus": "FOCUS", "grab": "GRAB"}


static func is_offer(id: String) -> bool:
	return id.begins_with(PREFIX)


static func offer_id(paddle_id: String) -> String:
	return PREFIX + paddle_id


static func strip(id: String) -> String:
	return id.trim_prefix(PREFIX)


static func tier(id: String) -> int:
	return DEFS[id].tier


static func title(id: String) -> String:
	return DEFS[id].name


## `ref` is the target of the stage just cleared, same scale as the ball prices.
static func price(id: String, ref: int) -> int:
	return Balls._round5(maxf(Balls.MIN_PRICE, ref * Balls.PRICE_SHARE[tier(id)]))


## One paddle for the shop, weighted by tier, or "" when you already own everything on offer.
static func roll_offer(owned: String) -> String:
	var pool: Array[String] = []
	var total := 0
	for id in DEFS:
		if id != CLASSIC and id != owned:
			pool.append(id)
			total += Balls.SHOP_WEIGHT[tier(id)]
	if pool.is_empty():
		return ""
	var pick := randi() % total
	for id in pool:
		pick -= Balls.SHOP_WEIGHT[tier(id)]
		if pick < 0:
			return id
	return pool[0]
