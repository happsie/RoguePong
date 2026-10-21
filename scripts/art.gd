class_name Art
extends RefCounted
## Shared palette and code-drawn art helpers. Every helper draws into the CanvasItem passed in,
## so it must be called from that node's _draw().

const SLATE := Color("374244")
const SLATE_DARK := Color("232b2d")
const RED := Color("fe5f55")
const BLUE := Color("009dff")
const GOLD := Color("eac058")
const GREEN := Color("4bc292")
const INK := Color("14181a")
const CREAM := Color("fff4dc")
const WOOD := Color("c98b52")
const WOOD_DARK := Color("8a5a2f")
const TABLE_TOP := Color("2fa3bd")
const TABLE_BODY := Color("1b6a80")
const TABLE_DARK := Color("114556")


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Outlined text with a hard drop shadow. `pos` is the baseline anchor for the chosen alignment.
static func text(ci: CanvasItem, s: String, pos: Vector2, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var font := ThemeDB.fallback_font
	var w := 700.0
	var p := pos
	match align:
		HORIZONTAL_ALIGNMENT_CENTER:
			p.x -= w * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			p.x -= w
	ci.draw_string(font, p + Vector2(3, 4), s, align, w, size, Color(0, 0, 0, 0.5))
	ci.draw_string_outline(font, p, s, align, w, size, maxi(2, int(size * 0.22)), INK)
	ci.draw_string(font, p, s, align, w, size, col)


static func rounded_pts(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [r.position + Vector2(rad, rad), r.position + Vector2(r.size.x - rad, rad), r.end - Vector2(rad, rad), r.position + Vector2(rad, r.size.y - rad)]
	for q in 4:
		for i in 7:
			var a := deg_to_rad(180.0 + q * 90.0 + i * 15.0)
			pts.append(cs[q] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Vivid HUD panel: gradient fill, scrolling shine stripes and (with `energy` > 0) twinkling sparkles.
## `t` is the clock; `energy` 0..1 speeds the shine and brightens it.
static func vivid(ci: CanvasItem, r: Rect2, top: Color, bot: Color, t: float, energy: float = 0.0, rad: float = 18.0) -> void:
	var outer := rounded_pts(r.grow(4.0), rad + 4.0)
	var shadow := PackedVector2Array()
	for p in outer:
		shadow.append(p + Vector2(0, 8))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	ci.draw_colored_polygon(outer, INK)
	var pts := rounded_pts(r, rad)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bot, clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	var speed := 36.0 + 160.0 * energy
	var span := 70.0
	var slant := r.size.y
	var x0 := r.position.x - slant - fposmod(t * speed, span * 2.0)
	var n := int((r.size.x + slant) / (span * 2.0)) + 3
	for i in n:
		var x := x0 + i * span * 2.0
		var band := PackedVector2Array([Vector2(x + slant, r.position.y), Vector2(x + slant + span * 0.5, r.position.y), Vector2(x + span * 0.5, r.end.y), Vector2(x, r.end.y)])
		for piece in Geometry2D.intersect_polygons(band, pts):
			if piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty():
				ci.draw_colored_polygon(piece, Color(1, 1, 1, 0.07 + 0.12 * energy))
	# glossy top edge
	ci.draw_line(r.position + Vector2(rad, 5), Vector2(r.end.x - rad, r.position.y + 5), Color(1, 1, 1, 0.35), 3.0)
	if energy > 0.25:
		for i in 6:
			var ph := fposmod(t * (0.8 + 0.3 * i) + i * 0.37, 1.0)
			var sp := r.position + Vector2(fposmod(i * 0.381 + 0.11, 1.0) * r.size.x, fposmod(i * 0.617 + 0.23, 1.0) * r.size.y)
			var s := sin(ph * PI) * (3.0 + 5.0 * energy)
			ci.draw_line(sp - Vector2(s, 0), sp + Vector2(s, 0), Color(1, 1, 1, 0.9), 2.0)
			ci.draw_line(sp - Vector2(0, s), sp + Vector2(0, s), Color(1, 1, 1, 0.9), 2.0)


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func capsule(ci: CanvasItem, top_y: float, bottom_y: float, x: float, r: float, col: Color) -> void:
	ci.draw_circle(Vector2(x, top_y + r), r, col)
	ci.draw_circle(Vector2(x, bottom_y - r), r, col)
	ci.draw_rect(Rect2(x - r, top_y + r, r * 2.0, bottom_y - top_y - r * 2.0), col)


static func heart(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var hx := 16.0 * pow(sin(t), 3.0)
		var hy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(hx, hy) * (size / 34.0))
	ci.draw_colored_polygon(pts, col)


## Paddle seen end-on from behind the table: round red face, wooden rim, handle hanging below.
static func paddle_disc(ci: CanvasItem, pos: Vector2, r: float, tilt: float, alpha: float) -> void:
	ci.draw_set_transform(pos, tilt, Vector2.ONE)
	ci.draw_circle(Vector2(r * 0.14, r * 0.2), r + 3.0, Color(0, 0, 0, 0.3 * alpha))
	ci.draw_rect(Rect2(-r * 0.2 - 3.0, r * 0.6, r * 0.4 + 6.0, r * 1.25 + 3.0), Color(INK, alpha))
	ci.draw_rect(Rect2(-r * 0.2, r * 0.6, r * 0.4, r * 1.25), Color(WOOD, alpha))
	for i in 4:
		ci.draw_line(Vector2(-r * 0.2, r * 0.95 + i * r * 0.2), Vector2(r * 0.2, r * 1.05 + i * r * 0.2), Color(WOOD_DARK, alpha), maxf(1.5, r * 0.05))
	ci.draw_circle(Vector2.ZERO, r + 3.0, Color(INK, alpha))
	ci.draw_circle(Vector2.ZERO, r, Color(WOOD, alpha))
	ci.draw_circle(Vector2.ZERO, r * 0.84, Color(RED.darkened(0.25), alpha))
	ci.draw_circle(Vector2.ZERO, r * 0.8, Color(RED, alpha))
	ci.draw_arc(Vector2.ZERO, r * 0.62, deg_to_rad(200), deg_to_rad(260), 10, Color(RED.lightened(0.5), alpha), maxf(2.0, r * 0.07))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Googly eye: the pupil lags and jiggles inside a big white eyeball. `look` is a screen point.
static func googly(ci: CanvasItem, e: Vector2, r: float, look: Vector2, t: float, seed_: float) -> void:
	ci.draw_circle(e, r + 3.0, INK)
	ci.draw_circle(e, r, Color.WHITE)
	var d := (look - e).limit_length(80.0) / 80.0
	var jig := Vector2(sin(t * 9.0 + seed_), cos(t * 7.3 + seed_ * 2.0)) * r * 0.1
	var pr := r * 0.5
	ci.draw_circle(e + d * r * 0.42 + jig, pr, INK)
	ci.draw_circle(e + d * r * 0.42 + jig + Vector2(-pr * 0.3, -pr * 0.3), pr * 0.28, Color.WHITE)


## Goofy front-facing opponent: huge head, googly eyes, big nose, stubby torso. `ch` is a Roster entry
## (skin, shirt, hair, acc); `acc` picks the costume. `pos` is the head centre, `r` the head
## radius, `mood` > 0 grins and < 0 yells.
static func goof(ci: CanvasItem, pos: Vector2, r: float, ch: Dictionary, look: Vector2, mood: float, t: float) -> void:
	var skin: Color = ch.skin
	var shirt: Color = ch.shirt
	var hair: Color = ch.get("hair", RED)
	var acc: String = ch.acc
	var c := pos + Vector2(0, sin(t * 3.0 + pos.x) * 3.0)
	var squash := 1.0 + sin(t * 6.0) * 0.03
	var bc := c + Vector2(0, r * 1.25)
	if acc == "vampire":
		var cape := PackedVector2Array([c + Vector2(-r * 1.55, r * 2.3), c + Vector2(-r * 0.95, r * 0.2), c + Vector2(r * 0.95, r * 0.2), c + Vector2(r * 1.55, r * 2.3)])
		ci.draw_colored_polygon(cape, INK)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.4, r * 2.25), c + Vector2(-r * 0.85, r * 0.3), c + Vector2(r * 0.85, r * 0.3), c + Vector2(r * 1.4, r * 2.25)]), Color("a01c3a"))
	if acc == "fur":
		for pass_ in 2:
			for i in 14:
				var a := TAU * i / 14.0
				var fp := c + Vector2(cos(a), sin(a)) * r * 0.95
				ci.draw_circle(fp, r * 0.24 + 3.0 if pass_ == 0 else r * 0.24, INK if pass_ == 0 else skin)
	# floppy torso
	ci.draw_circle(c + Vector2(6, 10), r + 5.0, Color(0, 0, 0, 0.35))
	ellipse(ci, bc, r * squash + 4.0, r * 0.85 + 4.0, INK)
	ellipse(ci, bc, r * squash, r * 0.85, shirt)
	if acc == "cap":
		# lifeguard cross
		ci.draw_rect(Rect2(bc.x - r * 0.1, bc.y - r * 0.4, r * 0.2, r * 0.8), Color.WHITE)
		ci.draw_rect(Rect2(bc.x - r * 0.4, bc.y - r * 0.1, r * 0.8, r * 0.2), Color.WHITE)
	elif acc == "beanie":
		# zip-up jacket with two pockets
		for s in [-1.0, 1.0]:
			ci.draw_rect(Rect2(bc.x + s * r * 0.5 - r * 0.2, bc.y + r * 0.05, r * 0.4, r * 0.3), shirt.darkened(0.25))
		ci.draw_line(bc + Vector2(0, -r * 0.75), bc + Vector2(0, r * 0.8), CREAM, 4.0)
		ci.draw_circle(bc + Vector2(0, -r * 0.68), r * 0.07, GOLD)
	elif acc == "fur":
		# fluffy pale belly, scalloped along the top like fur
		ellipse(ci, bc + Vector2(0, r * 0.15), r * 0.58, r * 0.55, Color("a8dcf5"))
		for k in 5:
			ci.draw_circle(bc + Vector2((k - 2) * r * 0.22, -r * 0.34 + absf(k - 2) * r * 0.06), r * 0.13, Color("a8dcf5"))
	elif acc == "antenna":
		# space suit: a gold badge over a belt
		ci.draw_line(bc + Vector2(-r * 0.8, r * 0.38), bc + Vector2(r * 0.8, r * 0.38), INK, r * 0.12)
		ci.draw_circle(bc + Vector2(0, -r * 0.15), r * 0.22, INK)
		ci.draw_circle(bc + Vector2(0, -r * 0.15), r * 0.16, GOLD)
	elif acc == "fishbowl":
		# chest pack with two dials
		ci.draw_rect(Rect2(bc.x - r * 0.55, bc.y - r * 0.05, r * 1.1, r * 0.55), INK)
		for s in [-1.0, 1.0]:
			var dial := bc + Vector2(s * r * 0.26, r * 0.22)
			ci.draw_circle(dial, r * 0.2, CREAM)
			ci.draw_line(dial, dial + Vector2(cos(t * 2.0 + s), sin(t * 2.0 + s)) * r * 0.15, RED, 3.0)
	elif acc == "pumpkin":
		# vest: white collar and gold buttons
		ci.draw_colored_polygon(PackedVector2Array([bc + Vector2(-r * 0.45, -r * 0.8), bc + Vector2(0, -r * 0.55), bc + Vector2(-r * 0.05, -r * 0.2)]), CREAM)
		ci.draw_colored_polygon(PackedVector2Array([bc + Vector2(r * 0.45, -r * 0.8), bc + Vector2(0, -r * 0.55), bc + Vector2(r * 0.05, -r * 0.2)]), CREAM)
		for i in 3:
			ci.draw_circle(bc + Vector2(0, -r * 0.05 + i * r * 0.28), r * 0.09, INK)
			ci.draw_circle(bc + Vector2(0, -r * 0.05 + i * r * 0.28), r * 0.06, GOLD)
	elif acc == "visor":
		# a pixel heart
		var heart_rows := ["01010", "11111", "11111", "01110", "00100"]
		var px := r * 0.14
		for y in heart_rows.size():
			for x in 5:
				if heart_rows[y][x] == "1":
					ci.draw_rect(Rect2(bc.x + (x - 2.5) * px, bc.y - r * 0.3 + y * px, px, px), CREAM)
	elif acc == "shades":
		# open-collared floral shirt: a skin V at the neck, and a few flowers
		ci.draw_colored_polygon(PackedVector2Array([bc + Vector2(-r * 0.32, -r * 0.8), bc + Vector2(r * 0.32, -r * 0.8), bc + Vector2(0, r * 0.1)]), skin)
		for f: Vector2 in [Vector2(-0.55, -0.1), Vector2(0.5, 0.05), Vector2(-0.3, 0.42), Vector2(0.35, 0.5)]:
			for k in 5:
				var a: float = TAU * k / 5.0 + f.x
				ci.draw_circle(bc + f * r + Vector2(cos(a), sin(a)) * r * 0.09, r * 0.07, CREAM)
			ci.draw_circle(bc + f * r, r * 0.05, GOLD)
	elif acc == "vampire":
		ci.draw_colored_polygon(PackedVector2Array([bc + Vector2(-r * 0.3, -r * 0.7), bc + Vector2(r * 0.3, -r * 0.7), bc + Vector2(0, r * 0.5)]), CREAM)
		for i in 3:
			ci.draw_circle(bc + Vector2(0, -r * 0.2 + i * r * 0.22), r * 0.05, INK)
	elif acc == "robot":
		var blink := 0.5 + 0.5 * sin(t * 6.0)
		ci.draw_rect(Rect2(bc.x - r * 0.45, bc.y - r * 0.4, r * 0.9, r * 0.6), INK)
		ci.draw_circle(bc + Vector2(-r * 0.22, -r * 0.1), r * 0.1, RED.lerp(Color.WHITE, blink))
		ci.draw_circle(bc + Vector2(r * 0.02, -r * 0.1), r * 0.1, GREEN)
		ci.draw_circle(bc + Vector2(r * 0.26, -r * 0.1), r * 0.1, GOLD.lerp(Color.WHITE, 1.0 - blink))
	# hair and things that sit behind the head
	var tufts := acc in ["shades", "visor", "headband"]
	if tufts or acc == "fishbowl":
		for i in (3 if tufts else 1):
			var a := deg_to_rad(-90.0 + ((i - 1) if tufts else 0) * 32.0)
			var base := c + Vector2(cos(a), sin(a)) * r * 0.92
			var sway := sin(t * 5.0 + i * 1.7) * r * 0.18
			var tip := base + Vector2(sway + (i - 1) * r * 0.16, -r * 0.55)
			ci.draw_line(base, tip, INK, r * 0.2)
			ci.draw_circle(tip, r * 0.17, INK)
			ci.draw_circle(tip, r * 0.1, hair if acc != "headband" else (RED if i != 1 else GOLD))
	if acc == "antenna":
		for s in [-1.0, 1.0]:
			var base := c + Vector2(s * r * 0.4, -r * 0.88)
			var tip := base + Vector2(s * r * 0.35 + sin(t * 4.0 + s) * r * 0.12, -r * 0.7)
			ci.draw_line(base, tip, INK, r * 0.14)
			ci.draw_line(base, tip, skin.darkened(0.2), r * 0.07)
			ci.draw_circle(tip, r * 0.2, INK)
			ci.draw_circle(tip, r * 0.14, GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 6.0 + s)))
	if acc == "pumpkin":
		ci.draw_line(c + Vector2(0, -r), c + Vector2(r * 0.12, -r * 1.35), INK, r * 0.3)
		ci.draw_line(c + Vector2(0, -r), c + Vector2(r * 0.12, -r * 1.35), hair.darkened(0.2), r * 0.2)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.1, -r * 1.2), c + Vector2(r * 0.55, -r * 1.3 + sin(t * 3.0) * 3.0), c + Vector2(r * 0.3, -r * 1.0)]), hair)
	# ears (or bolts for the robot, nothing for the furry ones)
	if acc != "fur" and acc != "pumpkin":
		for s in [-1.0, 1.0]:
			var ep := c + Vector2(s * r * 1.0, r * 0.05)
			ci.draw_circle(ep, r * 0.27, INK)
			ci.draw_circle(ep, r * 0.2, (Color("c9d3e0") if acc == "robot" else skin.darkened(0.1)))
			if acc == "robot":
				ci.draw_line(ep + Vector2(-r * 0.1, 0), ep + Vector2(r * 0.1, 0), INK, 3.0)
				ci.draw_line(ep + Vector2(0, -r * 0.1), ep + Vector2(0, r * 0.1), INK, 3.0)
	# head
	ci.draw_circle(c, r + 5.0, INK)
	ci.draw_circle(c, r, skin)
	ci.draw_arc(c, r * 0.82, deg_to_rad(200), deg_to_rad(265), 12, skin.lightened(0.35), 5.0)
	if acc == "fur":
		ellipse(ci, c + Vector2(0, r * 0.12), r * 0.78, r * 0.7, Color("a8dcf5"))
	if acc == "pumpkin":
		for k in [-0.55, 0.0, 0.55]:
			ci.draw_arc(c + Vector2(k * r * 1.3, 0), r * 0.45, deg_to_rad(95), deg_to_rad(265), 10, skin.darkened(0.25), 4.0)
	if acc == "robot":
		for k in 3:
			ci.draw_circle(c + Vector2(-r * 0.65 + k * r * 0.1, -r * 0.55 + k * r * 0.1), r * 0.04, INK)
	# costume that sits on the head
	match acc:
		"headband", "visor":
			var hy := c.y - r * 0.62
			var band := RED if acc == "headband" else Color("6bffea")
			ci.draw_line(Vector2(c.x - r * 0.9, hy), Vector2(c.x + r * 0.9, hy), INK, r * 0.38)
			ci.draw_line(Vector2(c.x - r * 0.88, hy), Vector2(c.x + r * 0.88, hy), band, r * 0.26)
			if acc == "visor":
				for k in 5:
					ci.draw_rect(Rect2(c.x - r * 0.7 + k * r * 0.28, hy - r * 0.08, r * 0.14, r * 0.16), Color.WHITE if k % 2 == 0 else INK)
		"shades":
			var sy := c.y - r * 0.68
			ci.draw_rect(Rect2(c.x - r * 0.62, sy - r * 0.14, r * 0.52, r * 0.3), INK)
			ci.draw_rect(Rect2(c.x + r * 0.1, sy - r * 0.14, r * 0.52, r * 0.3), INK)
			ci.draw_line(Vector2(c.x - r * 0.1, sy - r * 0.05), Vector2(c.x + r * 0.1, sy - r * 0.05), INK, 4.0)
			ci.draw_rect(Rect2(c.x - r * 0.56, sy - r * 0.08, r * 0.2, r * 0.07), Color(1, 1, 1, 0.5))
			ci.draw_rect(Rect2(c.x + r * 0.16, sy - r * 0.08, r * 0.2, r * 0.07), Color(1, 1, 1, 0.5))
		"beanie":
			var dome := PackedVector2Array()
			for i in 17:
				var a := deg_to_rad(180.0 + i * 180.0 / 16.0)
				dome.append(c + Vector2(cos(a), sin(a)) * (r + 3.0) + Vector2(0, -r * 0.2))
			ci.draw_colored_polygon(dome, INK)
			var dome_in := PackedVector2Array()
			for i in 17:
				var a := deg_to_rad(180.0 + i * 180.0 / 16.0)
				dome_in.append(c + Vector2(cos(a), sin(a)) * (r - 1.0) + Vector2(0, -r * 0.2))
			ci.draw_colored_polygon(dome_in, hair)
			ci.draw_rect(Rect2(c.x - r - 3.0, c.y - r * 0.4, r * 2.0 + 6.0, r * 0.3), INK)
			ci.draw_rect(Rect2(c.x - r + 1.0, c.y - r * 0.36, r * 2.0 - 2.0, r * 0.22), CREAM)
			ci.draw_circle(c + Vector2(0, -r * 1.25 + sin(t * 5.0) * 3.0), r * 0.26, INK)
			ci.draw_circle(c + Vector2(0, -r * 1.25 + sin(t * 5.0) * 3.0), r * 0.2, CREAM)
		"cap":
			var cap := PackedVector2Array()
			for i in 17:
				var a := deg_to_rad(190.0 + i * 160.0 / 16.0)
				cap.append(c + Vector2(cos(a), sin(a)) * (r + 3.0))
			ci.draw_colored_polygon(cap, INK)
			var cap_in := PackedVector2Array()
			for i in 17:
				var a := deg_to_rad(193.0 + i * 154.0 / 16.0)
				cap_in.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
			ci.draw_colored_polygon(cap_in, RED)
			ci.draw_rect(Rect2(c.x - r * 0.12, c.y - r * 0.95, r * 0.24, r * 0.5), Color.WHITE)
			ci.draw_rect(Rect2(c.x - r * 0.25, c.y - r * 0.82, r * 0.5, r * 0.24), Color.WHITE)
			ci.draw_rect(Rect2(c.x - r * 0.95, c.y - r * 0.42, r * 1.9, r * 0.14), INK)
			# zinc nose
			ci.draw_circle(c + Vector2(0, r * 0.14), r * 0.23, Color("fff06b"))
		"vampire":
			var peak := PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.35), c + Vector2(-r * 0.7, -r * 0.95), c + Vector2(0, -r * 1.02), c + Vector2(r * 0.7, -r * 0.95), c + Vector2(r * 0.95, -r * 0.35), c + Vector2(r * 0.4, -r * 0.62), c + Vector2(0, -r * 0.3), c + Vector2(-r * 0.4, -r * 0.62)])
			ci.draw_colored_polygon(peak, hair)
			ci.draw_polyline(peak, INK, 3.0, true)
			ci.draw_arc(c + Vector2(0, r * 0.42), r * 0.2, 0.0, TAU, 8, Color(1, 0.3, 0.4, 0.5), 3.0)
	# eyes: mismatched, slightly crossed
	googly(ci, c + Vector2(-r * 0.36, -r * 0.2), r * 0.32, look, t, 0.0)
	googly(ci, c + Vector2(r * 0.34, -r * 0.14), r * 0.25, look, t, 2.0)
	if acc == "antenna":
		googly(ci, c + Vector2(0, -r * 0.62), r * 0.17, look, t, 5.0)
	# big round nose
	if acc != "cap":
		ci.draw_circle(c + Vector2(0, r * 0.14), r * 0.2, INK)
		ci.draw_circle(c + Vector2(0, r * 0.14), r * 0.16, Color("ff8a7a") if acc != "robot" else Color("fe5f55"))
		ci.draw_circle(c + Vector2(-r * 0.05, r * 0.08), r * 0.05, Color(1, 1, 1, 0.8))
	else:
		ci.draw_circle(c + Vector2(-r * 0.05, r * 0.08), r * 0.05, Color(1, 1, 1, 0.8))
	# mouth
	var m := c + Vector2(0, r * 0.5)
	if acc == "robot":
		var open := r * (0.2 + (0.14 if absf(mood) > 0.2 else 0.0))
		ci.draw_rect(Rect2(m.x - r * 0.38, m.y - open * 0.4, r * 0.76, open), INK)
		for k in 5:
			ci.draw_line(Vector2(m.x - r * 0.3 + k * r * 0.15, m.y - open * 0.4), Vector2(m.x - r * 0.3 + k * r * 0.15, m.y + open * 0.6), Color("c9d3e0"), 2.0)
	elif mood > 0.2:
		ellipse(ci, m, r * 0.36, r * 0.24, INK)
		ellipse(ci, m + Vector2(0, r * 0.1), r * 0.2, r * 0.1, Color("ff6b8a"))
	elif mood < -0.2:
		ellipse(ci, m + Vector2(0, r * 0.1), r * 0.2, r * 0.26 + sin(t * 30.0) * 2.0, INK)
		ci.draw_circle(c + Vector2(r * 0.8, -r * 0.5), r * 0.1, BLUE.lightened(0.5))
	else:
		ci.draw_arc(m + Vector2(0, -r * 0.12), r * 0.34, deg_to_rad(20), deg_to_rad(160), 12, INK, 4.0)
		ci.draw_rect(Rect2(m.x - r * 0.14, m.y + r * 0.04, r * 0.12, r * 0.16), Color.WHITE)
		ci.draw_rect(Rect2(m.x + 0.0, m.y + r * 0.04, r * 0.12, r * 0.16), Color.WHITE)
		ci.draw_rect(Rect2(m.x - r * 0.14, m.y + r * 0.04, r * 0.26, r * 0.16), INK, false, 2.0)
	if acc == "vampire":
		for s in [-1.0, 1.0]:
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(s * r * 0.2 - r * 0.07, r * 0.0), m + Vector2(s * r * 0.2 + r * 0.07, r * 0.0), m + Vector2(s * r * 0.2, r * 0.26)]), Color.WHITE)
	if acc == "pumpkin":
		ci.draw_polyline(PackedVector2Array([m + Vector2(-r * 0.4, 0), m + Vector2(-r * 0.2, r * 0.2), m + Vector2(0, 0), m + Vector2(r * 0.2, r * 0.2), m + Vector2(r * 0.4, 0)]), GOLD, 4.0)
	if acc == "fishbowl":
		ci.draw_circle(c, r * 1.2, Color(0.7, 0.95, 1.0, 0.22))
		ci.draw_arc(c, r * 1.2, 0.0, TAU, 40, INK, 5.0)
		ci.draw_arc(c, r * 1.06, deg_to_rad(205), deg_to_rad(250), 10, Color(1, 1, 1, 0.8), 6.0)
		ci.draw_rect(Rect2(c.x - r * 0.7, c.y + r * 1.08, r * 1.4, r * 0.16), INK)
		ci.draw_rect(Rect2(c.x - r * 0.66, c.y + r * 1.1, r * 1.32, r * 0.1), Color("c9d3e0"))


## Round character token. `flip` is the way it faces (+1 right, -1 left); `kind` 0 = headband, 1 = cap.
static func token(ci: CanvasItem, pos: Vector2, r: float, col: Color, look: Vector2, mood: float, kind: int, flip: float, t: float) -> void:
	var c := pos + Vector2(0, sin(t * 3.0 + pos.x) * 3.0)
	ci.draw_circle(c + Vector2(6, 9), r + 5.0, Color(0, 0, 0, 0.35))
	ci.draw_circle(c, r + 5.0, INK)
	ci.draw_circle(c, r, col)
	ci.draw_arc(c, r * 0.82, deg_to_rad(200), deg_to_rad(265), 12, col.lightened(0.35), 5.0)
	for s in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(s * r * 0.36 + flip * r * 0.14, -r * 0.1)
		ci.draw_circle(e, r * 0.25, INK)
		ci.draw_circle(e, r * 0.2, Color.WHITE)
		var d := (look - e).limit_length(60.0) / 60.0
		ci.draw_circle(e + d * r * 0.09, r * 0.1, INK)
	var m := c + Vector2(flip * r * 0.14, r * 0.38)
	if mood > 0.2:
		ci.draw_arc(m + Vector2(0, -r * 0.1), r * 0.26, deg_to_rad(15), deg_to_rad(165), 12, INK, 4.0)
	elif mood < -0.2:
		ci.draw_arc(m + Vector2(0, r * 0.22), r * 0.24, deg_to_rad(195), deg_to_rad(345), 12, INK, 4.0)
	else:
		ci.draw_line(m + Vector2(-r * 0.16, 0), m + Vector2(r * 0.16, 0), INK, 4.0)
	if kind == 0:
		var y := c.y - r * 0.5
		ci.draw_line(Vector2(c.x - r * 0.88, y), Vector2(c.x + r * 0.88, y), INK, 14.0)
		ci.draw_line(Vector2(c.x - r * 0.86, y), Vector2(c.x + r * 0.86, y), RED, 9.0)
		var knot := Vector2(c.x - flip * r * 0.9, y)
		ci.draw_line(knot, knot + Vector2(-flip * 16, 8), RED, 6.0)
		ci.draw_line(knot, knot + Vector2(-flip * 14, -6), RED, 6.0)
	else:
		var pts := PackedVector2Array()
		for i in 17:
			var a := deg_to_rad(194.0 + i * 152.0 / 16.0)
			pts.append(c + Vector2(cos(a), sin(a)) * (r + 2.0))
		ci.draw_colored_polygon(pts, INK)
		var inner := PackedVector2Array()
		for i in 17:
			var a := deg_to_rad(197.0 + i * 146.0 / 16.0)
			inner.append(c + Vector2(cos(a), sin(a)) * (r - 1.0))
		ci.draw_colored_polygon(inner, BLUE)
		ci.draw_rect(Rect2(c.x + flip * r * 0.25 - (0.0 if flip > 0.0 else r * 0.9), c.y - r * 0.42, r * 0.9, 9), INK)
		ci.draw_rect(Rect2(c.x + flip * r * 0.25 + 2 - (0.0 if flip > 0.0 else r * 0.9), c.y - r * 0.42 + 2, r * 0.9 - 4, 5), BLUE.darkened(0.2))
