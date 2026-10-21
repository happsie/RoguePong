class_name Balls
extends RefCounted
## Magic balls. You own a bag of them; each serve draws one (without replacement, reshuffled when the
## bag runs dry) and its ability lasts for that rally. Plain balls are the filler, so the more special
## balls you buy, the more often they show up. The effects themselves live in Game, keyed by id.
## `tier` sets the price (a share of the cleared stage's target) and how often the shop offers it.

const PLAIN := "plain"
const START_BAG := 10
const MAX_BAG := 20
## Price of a ball as a share of the cleared stage's target, per tier.
const PRICE_SHARE := [0.0, 0.5, 1.0, 1.8]
const SHOP_WEIGHT := [0, 60, 30, 10]
const REROLL_SHARE := 0.15
const REMOVE_SHARE := 0.3
const MIN_PRICE := 20

const DEFS := {
	"plain": {"name": "Plain Ball", "desc": "Nothing special.", "col": Color("fff4dc"), "tier": 0},
	"double_heat": {"name": "Double Heat", "desc": "Every Heat gain\nis doubled.", "col": Color("fe5f55"), "tier": 3},
	"midas": {"name": "Midas", "desc": "Every Power gain\nis doubled.", "col": Color("eac058"), "tier": 3},
	"gambler": {"name": "Gambler", "desc": "Coin flip: the rally\nbanks x3 or x0.5.", "col": Color("b86bff"), "tier": 1},
	"disco": {"name": "Disco", "desc": "Every return adds\na random bonus.", "col": Color("ff6bd6"), "tier": 1},
	"fireball": {"name": "Fireball", "desc": "Lights on return 5:\nHeat gains x3. Lose it\nlit and lose 2 lives.", "col": Color("ff8a1f"), "tier": 2},
	"pressure": {"name": "Pressure Cooker", "desc": "Heat +0.3 a second.\nReturns add no Heat.", "col": Color("e8503a"), "tier": 2},
	"vampire": {"name": "Vampire", "desc": "Win with 6+ Heat\nto regain a life.", "col": Color("8a2a4a"), "tier": 2},
	"phoenix": {"name": "Phoenix", "desc": "Lose this rally and\nit costs no life.", "col": Color("ffb03a"), "tier": 2},
	# Physics balls: Game.apply_ball_physics sets the matching Phys tweaks when one is drawn.
	"feather": {"name": "Feather", "desc": "Low gravity. Lobs and\ndrop shots pay double.", "col": Color("9fe6ff"), "tier": 1},
	"meteor": {"name": "Meteor", "desc": "Heavy, with steep arcs.\nSmashes give x3 Heat.", "col": Color("c4552a"), "tier": 2},
	"dervish": {"name": "Dervish", "desc": "Spin is stronger and curves\nmore. Spin tricks pay double.", "col": Color("4bc292"), "tier": 2},
	"yoyo": {"name": "Yo-Yo", "desc": "Backspin grips the table\nand throws the ball back.", "col": Color("ffe14d"), "tier": 2},
	"bouncy": {"name": "Bouncy Castle", "desc": "Livelier bounces. Each\nbounce of yours is +1 Heat.", "col": Color("6bffea"), "tier": 2},
	"ghost": {"name": "Ghost", "desc": "Passes through the net.\nEvery crossing is a net clip.", "col": Color("d8e0ff"), "tier": 3},
	"timewarp": {"name": "Time Warp", "desc": "Incoming balls slow down,\nyour returns speed up.", "col": Color("5aa7e8"), "tier": 2},
	"magnet": {"name": "Magnet", "desc": "Huge hit assist, but\nPower gains are halved.", "col": Color("c0c8d8"), "tier": 1},
	"pinball": {"name": "Pinball", "desc": "Invisible side walls:\nricochets pay +20 Power.", "col": Color("3a7bd5"), "tier": 1},
	"corkscrew": {"name": "Corkscrew", "desc": "Sidespin kicks the ball\nsideways off every bounce.", "col": Color("b8e05a"), "tier": 1},
}


static func ids() -> Array:
	return DEFS.keys()


static func color(id: String) -> Color:
	return DEFS[id].col


static func title(id: String) -> String:
	return DEFS[id].name


static func tier(id: String) -> int:
	return DEFS[id].tier


## `ref` is the target of the stage just cleared, so prices keep up with the scores.
static func price(id: String, ref: int) -> int:
	return _round5(maxf(MIN_PRICE, ref * PRICE_SHARE[tier(id)]))


static func reroll_cost(ref: int, times: int) -> int:
	return _round5(maxf(MIN_PRICE, ref * REROLL_SHARE * (1 + times)))


static func remove_cost(ref: int) -> int:
	return _round5(maxf(MIN_PRICE, ref * REMOVE_SHARE))


static func _round5(v: float) -> int:
	return int(round(v / 5.0)) * 5


## `n` distinct special balls, weighted by tier.
static func roll_offers(n: int) -> Array[String]:
	var pool: Array[String] = []
	for id in ids():
		if id != PLAIN:
			pool.append(id)
	var out: Array[String] = []
	while out.size() < n and not pool.is_empty():
		var total := 0
		for id in pool:
			total += SHOP_WEIGHT[tier(id)]
		var pick := randi() % total
		for id in pool:
			pick -= SHOP_WEIGHT[tier(id)]
			if pick < 0:
				out.append(id)
				pool.erase(id)
				break
	return out


# Shop layout, shared by the click handling in Game and the drawing in the HUD.
static func card_rect(i: int) -> Rect2:
	return Rect2(160 + i * 340, 170, 300, 280)


static func button_rect(i: int) -> Rect2:
	return Rect2(160 + i * 340, 480, 300, 60)
