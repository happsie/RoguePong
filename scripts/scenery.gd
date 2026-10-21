class_name Scenery
extends RefCounted
## Themed backdrops drawn behind the court. Every helper draws into the CanvasItem passed in
## (call from its _draw). The ground starts at about y = 240, just behind the far end of the table.

const NAMES := ["Beach Club", "Mount Everest", "Moon Base", "Spooky Mansion", "Arcade Night"]
const ARCADE := 4


static func h(n: float) -> float:
	return fposmod(sin(n * 127.1) * 43758.5453, 1.0)


static func grad(ci: CanvasItem, y0: float, y1: float, c0: Color, c1: Color) -> void:
	ci.draw_polygon(
		PackedVector2Array([Vector2(-40, y0), Vector2(1320, y0), Vector2(1320, y1), Vector2(-40, y1)]),
		PackedColorArray([c0, c0, c1, c1]),
	)


static func draw(ci: CanvasItem, id: int, t: float, ball: Vector2) -> void:
	match id:
		0:
			_beach(ci, t)
		1:
			_everest(ci, t, ball)
		2:
			_moon(ci, t, ball)
		3:
			_haunted(ci, t, ball)
		_:
			_arcade(ci, t)


static func _cloud(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	for o in [Vector3(-26, 4, 20), Vector3(0, -8, 28), Vector3(28, 2, 22), Vector3(50, 8, 15)]:
		ci.draw_circle(p + Vector2(o.x, o.y) * s, o.z * s, col)
	ci.draw_rect(Rect2(p.x - 40.0 * s, p.y + 4.0 * s, 100.0 * s, 20.0 * s), col)


static func _drift_clouds(ci: CanvasItem, t: float, col: Color, y0: float, n: int) -> void:
	for k in n:
		var x := fposmod(t * (6.0 + k * 3.0) + k * 520.0, 1500.0) - 120.0
		_cloud(ci, Vector2(x, y0 + (k % 2) * 36.0 + h(k * 3.0) * 20.0), 0.9 + h(k + 1.0) * 0.6, col)


static func _eyes(ci: CanvasItem, c: Vector2, sep: float, r: float, look: Vector2, t: float) -> void:
	Art.googly(ci, c + Vector2(-sep, 0), r, look, t, 0.0)
	Art.googly(ci, c + Vector2(sep, 0), r * 0.85, look, t, 2.0)


# ---------------------------------------------------------------- beach club

static func _beach(ci: CanvasItem, t: float) -> void:
	grad(ci, -40, 250, Color("2fb4e9"), Color("c4f1f0"))
	# a sun in sunglasses
	var sun := Vector2(880, 120)
	for i in 14:
		var a := TAU * i / 14.0 + t * 0.3
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(sun + d * 56.0, sun + d * (74.0 + sin(t * 3.0 + i) * 8.0), Art.GOLD, 8.0)
	ci.draw_circle(sun, 52, Art.INK)
	ci.draw_circle(sun, 48, Color("ffd34d"))
	ci.draw_rect(Rect2(sun.x - 40, sun.y - 14, 34, 22), Art.INK)
	ci.draw_rect(Rect2(sun.x + 6, sun.y - 14, 34, 22), Art.INK)
	ci.draw_line(sun + Vector2(-8, -8), sun + Vector2(8, -8), Art.INK, 4.0)
	ci.draw_arc(sun + Vector2(0, 10), 22.0, deg_to_rad(20), deg_to_rad(160), 12, Art.INK, 4.0)
	_drift_clouds(ci, t, Color(1, 1, 1, 0.9), 70.0, 3)
	# sea with a little sailboat
	grad(ci, 196, 252, Color("1d86c9"), Color("45c3dd"))
	var bob := sin(t * 1.5) * 3.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(300, 218 + bob), Vector2(300, 170 + bob), Vector2(338, 214 + bob)]), Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(286, 218 + bob), Vector2(352, 218 + bob), Vector2(340, 230 + bob), Vector2(298, 230 + bob)]), Art.RED)
	for i in 16:
		var x := fposmod(i * 97.0 + t * 20.0, 1400.0) - 60.0
		var y := 208.0 + (i % 5) * 9.0
		ci.draw_line(Vector2(x, y), Vector2(x + 34, y), Color(1, 1, 1, 0.45), 3.0)
	# sand with a foamy edge
	grad(ci, 246, 760, Color("f6dca2"), Color("d6aa68"))
	var foam := PackedVector2Array()
	for i in 41:
		foam.append(Vector2(-40 + i * 34.0, 246.0 + sin(t * 2.0 + i * 0.7) * 3.0))
	ci.draw_polyline(foam, Color(1, 1, 1, 0.9), 6.0)
	# deckchair umbrella and a bouncing beach ball
	_umbrella(ci, Vector2(215, 280), t)
	_umbrella(ci, Vector2(1075, 290), t + 2.0)
	_beach_ball(ci, Vector2(420, 300 - absf(sin(t * 3.0)) * 70.0), t)
	_palm(ci, Vector2(70, 345), 1.0, t, 0.62)
	_palm(ci, Vector2(1215, 350), -1.0, t + 1.0, 0.62)
	# seagull
	var gx := fposmod(t * 60.0, 1500.0) - 110.0
	var gy := 52.0 + sin(t * 2.0) * 14.0
	var w := sin(t * 10.0) * 9.0
	var wing := PackedVector2Array([Vector2(gx - 26, gy - w), Vector2(gx - 11, gy - 6), Vector2(gx, gy), Vector2(gx + 11, gy - 6), Vector2(gx + 26, gy - w)])
	ci.draw_polyline(wing, Art.INK, 8.0)
	ci.draw_polyline(wing, Color.WHITE, 4.0)


static func _umbrella(ci: CanvasItem, base: Vector2, t: float) -> void:
	var sway := sin(t * 1.2) * 2.0
	var top := base + Vector2(sway, -118)
	ci.draw_line(base, top, Art.INK, 9.0)
	ci.draw_line(base, top, Art.WOOD, 5.0)
	for i in 6:
		var x0 := base.x - 78.0 + i * 26.0
		var tri := PackedVector2Array([top + Vector2(0, -8), Vector2(x0, top.y + 46), Vector2(x0 + 26, top.y + 46)])
		ci.draw_colored_polygon(tri, Art.RED if i % 2 == 0 else Art.CREAM)
		ci.draw_circle(Vector2(x0 + 13, top.y + 46), 13.0, Art.RED if i % 2 == 0 else Art.CREAM)
	ci.draw_polyline(PackedVector2Array([Vector2(base.x - 78, top.y + 46), top + Vector2(0, -8), Vector2(base.x + 78, top.y + 46)]), Art.INK, 3.0)


static func _beach_ball(ci: CanvasItem, p: Vector2, t: float) -> void:
	var cols := [Art.RED, Art.CREAM, Art.BLUE, Art.GOLD]
	ci.draw_circle(p, 26.0, Art.INK)
	for i in 4:
		var a0 := t * 3.0 + i * PI * 0.5
		var pts := PackedVector2Array([p])
		for k in 7:
			var a := a0 + k * PI * 0.5 / 6.0
			pts.append(p + Vector2(cos(a), sin(a)) * 23.0)
		ci.draw_colored_polygon(pts, cols[i])
	ci.draw_circle(p + Vector2(-8, -9), 5.0, Color(1, 1, 1, 0.7))
	Art.ellipse(ci, Vector2(p.x, 305), 24.0, 7.0, Color(0, 0, 0, 0.18))


static func _palm(ci: CanvasItem, base: Vector2, dir: float, t: float, s: float) -> void:
	var ctrl := base + Vector2(-dir * 34.0 * s, -150.0 * s)
	var top := base + Vector2(dir * 56.0 * s, -270.0 * s)
	var trunk := PackedVector2Array()
	for i in 11:
		var f := i / 10.0
		trunk.append(base * (1.0 - f) * (1.0 - f) + ctrl * 2.0 * (1.0 - f) * f + top * f * f)
	ci.draw_polyline(trunk, Art.INK, 30.0 * s)
	ci.draw_polyline(trunk, Art.WOOD, 22.0 * s)
	for k in 8:
		var a := deg_to_rad(-175.0 + k * 24.0) + sin(t * 1.6 + k) * 0.07
		var fr := PackedVector2Array()
		for j in 6:
			var f := j / 5.0
			fr.append(top + Vector2(cos(a), sin(a)) * 120.0 * s * f + Vector2(0, f * f * 62.0 * s))
		ci.draw_polyline(fr, Art.INK, 17.0 * s)
		ci.draw_polyline(fr, Art.GREEN.darkened(0.1 + (k % 2) * 0.15), 11.0 * s)
	for o in [Vector2(-9, 10), Vector2(9, 12)]:
		ci.draw_circle(top + o * s, 9.0 * s, Art.INK)
		ci.draw_circle(top + o * s, 6.5 * s, Art.WOOD_DARK)


# ---------------------------------------------------------------- mount everest

static func _peak(ci: CanvasItem, cx: float, base_y: float, w: float, ht: float, rock: Color, snow: Color) -> void:
	var tip := Vector2(cx, base_y - ht)
	var l := Vector2(cx - w, base_y)
	var r := Vector2(cx + w, base_y)
	ci.draw_colored_polygon(PackedVector2Array([l, tip, r]), rock)
	ci.draw_colored_polygon(PackedVector2Array([tip, r, Vector2(cx, base_y)]), Color(0, 0.05, 0.2, 0.18))
	var a := tip.lerp(l, 0.42)
	var b := tip.lerp(r, 0.42)
	var zig := PackedVector2Array([tip, b])
	for i in 5:
		var f := (i + 1) / 6.0
		var p := b.lerp(a, f)
		p.y += (28.0 if i % 2 == 0 else -4.0) * ht / 200.0
		zig.append(p)
	zig.append(a)
	ci.draw_colored_polygon(zig, snow)
	ci.draw_polyline(PackedVector2Array([l, tip, r]), Art.INK, 3.0)


static func _pine(ci: CanvasItem, base: Vector2, s: float) -> void:
	ci.draw_rect(Rect2(base.x - 7 * s, base.y - 18 * s, 14 * s, 24 * s), Art.WOOD_DARK)
	for i in 3:
		var y := base.y - 14.0 * s - i * 40.0 * s
		var wd := (58.0 - i * 14.0) * s
		var tri := PackedVector2Array([Vector2(base.x - wd, y), Vector2(base.x, y - 62.0 * s), Vector2(base.x + wd, y)])
		ci.draw_colored_polygon(tri, Color("1f6b52"))
		ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Art.INK, 3.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x - wd * 0.45, y - 28.0 * s), Vector2(base.x, y - 62.0 * s), Vector2(base.x + wd * 0.45, y - 28.0 * s)]), Color.WHITE)


static func _everest(ci: CanvasItem, t: float, ball: Vector2) -> void:
	grad(ci, -40, 252, Color("1c4fa8"), Color("b5e2f8"))
	var haze := Color("9ec2e6")
	_peak(ci, 640, 245, 270, 120, haze, Color("e8f3ff"))
	_peak(ci, 420, 245, 200, 100, haze.darkened(0.05), Color("e8f3ff"))
	_peak(ci, 880, 245, 210, 118, haze.darkened(0.05), Color("e8f3ff"))
	_drift_clouds(ci, t, Color(1, 1, 1, 0.85), 80.0, 3)
	_peak(ci, 230, 262, 310, 215, Color("5d6f94"), Color.WHITE)
	_peak(ci, 1040, 262, 340, 240, Color("55668c"), Color.WHITE)
	# a flag on the big summit
	var tip := Vector2(1040, 22)
	ci.draw_line(tip, tip + Vector2(0, -34), Art.INK, 4.0)
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -34), tip + Vector2(34 + sin(t * 6.0) * 4.0, -26), tip + Vector2(0, -18)]), Art.RED)
	grad(ci, 252, 760, Color("eaf3fb"), Color("a9c3de"))
	_pine(ci, Vector2(70, 330), 1.0)
	_pine(ci, Vector2(170, 296), 0.8)
	_pine(ci, Vector2(1240, 332), 1.0)
	_yeti(ci, Vector2(1128, 262), t, ball)
	for i in 55:
		var x := fposmod(h(i) * 1400.0 + sin(t + i) * 22.0, 1400.0) - 60.0
		var y := fposmod(h(i + 99.0) * 800.0 + t * (40.0 + h(i + 5.0) * 50.0), 800.0) - 40.0
		ci.draw_circle(Vector2(x, y), 2.0 + h(i + 7.0) * 2.5, Color(1, 1, 1, 0.8))


static func _yeti(ci: CanvasItem, p: Vector2, t: float, look: Vector2) -> void:
	var fur := Color("f2f6ff")
	var arm := PackedVector2Array([p + Vector2(-44, 4), p + Vector2(-76, -28 + sin(t * 8.0) * 18.0)])
	ci.draw_line(arm[0], arm[1], Art.INK, 28.0)
	ci.draw_line(arm[0], arm[1], fur, 21.0)
	Art.ellipse(ci, p + Vector2(0, 26), 58, 64, Art.INK)
	Art.ellipse(ci, p + Vector2(0, 26), 53, 59, fur)
	ci.draw_circle(p + Vector2(0, -22), 48.0, Art.INK)
	ci.draw_circle(p + Vector2(0, -22), 44.0, fur)
	ci.draw_circle(p + Vector2(0, -20), 31.0, Color("8fd0f2"))
	_eyes(ci, p + Vector2(0, -28), 13.0, 11.0, look, t)
	Art.ellipse(ci, p + Vector2(0, -2), 14.0, 9.0, Art.INK)
	ci.draw_rect(Rect2(p.x - 9, p.y - 7, 6, 8), Color.WHITE)
	ci.draw_rect(Rect2(p.x + 3, p.y - 7, 6, 8), Color.WHITE)


# ---------------------------------------------------------------- moon base

static func _moon(ci: CanvasItem, t: float, ball: Vector2) -> void:
	grad(ci, -40, 250, Color("05050f"), Color("231452"))
	for i in 90:
		var tw := 0.5 + 0.5 * sin(t * (1.0 + h(i) * 3.0) + i)
		ci.draw_circle(Vector2(h(i + 1.0) * 1300.0 - 10.0, h(i + 2.0) * 240.0), 1.0 + h(i + 3.0) * 1.6 * tw, Color(1, 1, 0.9, 0.4 + 0.5 * tw))
	# a smiling planet Earth
	var e := Vector2(310, 130)
	ci.draw_circle(e, 66.0, Art.INK)
	ci.draw_circle(e, 62.0, Color("2e7fd8"))
	for o in [Vector3(-26, -22, 20), Vector3(22, -34, 14), Vector3(30, 26, 18), Vector3(-34, 30, 12)]:
		ci.draw_circle(e + Vector2(o.x, o.y), o.z, Art.GREEN)
	ci.draw_arc(e, 50.0, deg_to_rad(210), deg_to_rad(300), 12, Color(1, 1, 1, 0.5), 6.0)
	_eyes(ci, e + Vector2(0, -2), 17.0, 12.0, ball, t)
	ci.draw_arc(e + Vector2(0, 14), 20.0, deg_to_rad(20), deg_to_rad(160), 12, Art.INK, 4.0)
	# UFO with a goofy pilot
	var u := Vector2(640.0 + sin(t * 0.6) * 430.0, 82.0 + sin(t * 1.7) * 14.0)
	ci.draw_colored_polygon(PackedVector2Array([u + Vector2(-14, 12), u + Vector2(14, 12), u + Vector2(60, 160), u + Vector2(-60, 160)]), Color(1, 1, 0.5, 0.1))
	ci.draw_circle(u + Vector2(0, -8), 24.0, Art.INK)
	ci.draw_circle(u + Vector2(0, -8), 20.0, Color(0.6, 1, 0.9, 0.85))
	Art.googly(ci, u + Vector2(0, -8), 10.0, ball, t, 4.0)
	Art.ellipse(ci, u + Vector2(0, 6), 46.0, 17.0, Art.INK)
	Art.ellipse(ci, u + Vector2(0, 6), 42.0, 13.0, Color("b9c3d6"))
	for i in 5:
		ci.draw_circle(u + Vector2(-28 + i * 14.0, 8), 3.0, Art.GOLD if int(t * 4.0 + i) % 2 == 0 else Art.RED)
	# ground, craters, flag and a glass dome
	grad(ci, 238, 760, Color("9a9aae"), Color("4c4c5c"))
	for c in [Vector3(120, 300, 70), Vector3(430, 270, 40), Vector3(900, 282, 55), Vector3(1200, 330, 80)]:
		Art.ellipse(ci, Vector2(c.x, c.y), c.z, c.z * 0.26, Color(0, 0, 0, 0.28))
		Art.ellipse(ci, Vector2(c.x, c.y + 2), c.z * 0.85, c.z * 0.18, Color(1, 1, 1, 0.12))
	ci.draw_rect(Rect2(960, 240, 130, 24), Art.INK)
	ci.draw_rect(Rect2(964, 244, 122, 16), Color("c8d0e0"))
	var dome := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		dome.append(Vector2(1025, 242) + Vector2(cos(a) * 62.0, sin(a) * 58.0))
	ci.draw_colored_polygon(dome, Color(0.5, 0.9, 1, 0.3))
	ci.draw_polyline(dome, Art.INK, 3.0)
	for i in 3:
		ci.draw_rect(Rect2(988 + i * 24.0, 218, 12, 14), Color(Art.GOLD, 0.6 + 0.4 * sin(t * 3.0 + i)))
	ci.draw_line(Vector2(260, 256), Vector2(260, 190), Art.INK, 5.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(260, 190), Vector2(300 + sin(t * 3.0) * 3.0, 200), Vector2(260, 214)]), Art.RED)


# ---------------------------------------------------------------- spooky mansion

static func _haunted(ci: CanvasItem, t: float, ball: Vector2) -> void:
	grad(ci, -40, 250, Color("150a2e"), Color("6a2f7a"))
	for i in 40:
		ci.draw_circle(Vector2(h(i + 1.0) * 1300.0, h(i + 2.0) * 200.0), 1.4, Color(1, 1, 1, 0.3 + 0.4 * sin(t * 2.0 + i)))
	var m := Vector2(960, 100)
	ci.draw_circle(m, 90.0, Color(1, 0.95, 0.7, 0.08))
	ci.draw_circle(m, 56.0, Art.INK)
	ci.draw_circle(m, 52.0, Color("fff1c2"))
	for c in [Vector3(-16, -12, 10), Vector3(14, 10, 14), Vector3(-6, 24, 7)]:
		ci.draw_circle(m + Vector2(c.x, c.y), c.z, Color("e8d598"))
	# mansion on the left
	var wall := Color("221338")
	ci.draw_rect(Rect2(36, 138, 270, 112), Art.INK)
	ci.draw_rect(Rect2(40, 142, 262, 106), wall)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(26, 142), Vector2(171, 62), Vector2(316, 142)]), Art.INK)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(40, 142), Vector2(171, 74), Vector2(302, 142)]), Color("2e1a4a"))
	ci.draw_rect(Rect2(10, 96, 56, 154), Art.INK)
	ci.draw_rect(Rect2(14, 100, 48, 150), wall)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(4, 100), Vector2(38, 46), Vector2(72, 100)]), Art.INK)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(12, 100), Vector2(38, 56), Vector2(64, 100)]), Color("2e1a4a"))
	for i in 5:
		var flick := 0.65 + 0.35 * sin(t * (3.0 + i) + i * 2.0)
		var wx := 62.0 + i * 46.0
		ci.draw_rect(Rect2(wx, 164, 24, 32), Art.INK)
		ci.draw_rect(Rect2(wx + 3, 167, 18, 26), Color(1, 0.8, 0.3, flick))
	ci.draw_rect(Rect2(26, 128, 24, 24), Color(1, 0.8, 0.3, 0.6 + 0.4 * sin(t * 5.0)))
	ci.draw_rect(Rect2(150, 206, 42, 44), Art.INK)
	ci.draw_rect(Rect2(153, 209, 36, 41), Color("6b3d2a"))
	# dead tree on the right
	var tr := Vector2(1190, 262)
	ci.draw_line(tr, tr + Vector2(0, -150), Art.INK, 24.0)
	ci.draw_line(tr, tr + Vector2(0, -150), Color("3a2540"), 16.0)
	for b in [Vector3(-60, -190, 8), Vector3(70, -200, 8), Vector3(-40, -120, 6), Vector3(55, -135, 6)]:
		var from := tr + Vector2(0, b.y * 0.55)
		ci.draw_line(from, tr + Vector2(b.x, b.y), Art.INK, b.z + 5.0)
		ci.draw_line(from, tr + Vector2(b.x, b.y), Color("3a2540"), b.z)
	# ground, gravestones and glowing pumpkins
	grad(ci, 240, 760, Color("2c1b3d"), Color("0e0715"))
	for g in [Vector2(335, 276), Vector2(1000, 270), Vector2(1100, 282)]:
		ci.draw_rect(Rect2(g.x - 20, g.y - 40, 40, 50), Art.INK)
		ci.draw_rect(Rect2(g.x - 17, g.y - 37, 34, 47), Color("8f93a8"))
		ci.draw_circle(g + Vector2(0, -40), 20.0, Art.INK)
		ci.draw_circle(g + Vector2(0, -40), 17.0, Color("8f93a8"))
		Art.text(ci, "RIP", g + Vector2(0, -10), 14, Art.INK)
	for pk in [Vector2(405, 300), Vector2(910, 304), Vector2(250, 330)]:
		var glow := 0.5 + 0.3 * sin(t * 4.0 + pk.x)
		ci.draw_circle(pk, 46.0, Color(1, 0.6, 0.1, 0.12 * glow))
		Art.ellipse(ci, pk, 28.0, 23.0, Art.INK)
		Art.ellipse(ci, pk, 25.0, 20.0, Color("ff8a1f"))
		ci.draw_colored_polygon(PackedVector2Array([pk + Vector2(-13, -6), pk + Vector2(-5, -6), pk + Vector2(-9, -14)]), Art.INK)
		ci.draw_colored_polygon(PackedVector2Array([pk + Vector2(5, -6), pk + Vector2(13, -6), pk + Vector2(9, -14)]), Art.INK)
		ci.draw_polyline(PackedVector2Array([pk + Vector2(-14, 6), pk + Vector2(-7, 12), pk + Vector2(0, 6), pk + Vector2(7, 12), pk + Vector2(14, 6)]), Art.INK, 3.0)
		ci.draw_line(pk + Vector2(0, -22), pk + Vector2(2, -30), Art.GREEN, 5.0)
	_ghost(ci, Vector2(445, 150 + sin(t * 1.6) * 12.0), t, ball)
	_ghost(ci, Vector2(840, 120 + sin(t * 1.3 + 2.0) * 12.0), t + 3.0, ball)
	for k in 4:
		var bx := fposmod(t * (70.0 + k * 18.0) + k * 380.0, 1500.0) - 100.0
		var by := 48.0 + k * 22.0 + sin(t * 3.0 + k) * 16.0
		var fl := sin(t * 16.0 + k) * 10.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx - 24, by - fl), Vector2(bx - 12, by + 8), Vector2(bx, by + 4), Vector2(bx + 12, by + 8), Vector2(bx + 24, by - fl)]), Art.INK)
		ci.draw_circle(Vector2(bx - 3, by), 2.0, Art.RED)
		ci.draw_circle(Vector2(bx + 3, by), 2.0, Art.RED)


static func _ghost(ci: CanvasItem, p: Vector2, t: float, look: Vector2) -> void:
	var col := Color(0.95, 0.97, 1.0, 0.88)
	ci.draw_circle(p, 38.0, Art.INK)
	ci.draw_rect(Rect2(p.x - 38, p.y, 76, 44), Art.INK)
	ci.draw_circle(p, 34.0, col)
	ci.draw_rect(Rect2(p.x - 34, p.y, 68, 42), col)
	for i in 4:
		var bx := p.x - 25.5 + i * 17.0
		var by := p.y + 44.0 + sin(t * 5.0 + i) * 3.0
		ci.draw_circle(Vector2(bx, by - 3), 10.0, Art.INK)
		ci.draw_circle(Vector2(bx, by - 3), 8.0, col)
	_eyes(ci, p + Vector2(0, -6), 13.0, 10.0, look, t)
	Art.ellipse(ci, p + Vector2(0, 20), 9.0, 12.0 + sin(t * 6.0) * 2.0, Art.INK)


# ---------------------------------------------------------------- arcade night

const INVADER := ["00100000100", "00010001000", "00111111100", "01101110110", "11111111111", "10111111101", "10100000101", "00011011000"]


static func _arcade(ci: CanvasItem, t: float) -> void:
	grad(ci, 185, 760, Color(Art.SLATE_DARK, 0.0), Color(Art.SLATE_DARK, 0.95))
	var cols := [Art.RED, Art.BLUE, Art.GREEN, Art.GOLD, Color("ff6bd6"), Color("6bffea")]
	var xs := [250.0, 390.0, 890.0, 1030.0]
	var ys := [150.0, 205.0, 160.0, 210.0]
	for k in 4:
		var p := Vector2(xs[k] + sin(t * 0.8 + k) * 22.0, ys[k] + sin(t * 1.5 + k * 2.0) * 12.0)
		var s := 5.0 + (k % 2) * 2.0
		var flip := 1 if int(t * 2.0 + k) % 2 == 0 else 0
		for y in INVADER.size():
			for x in 11:
				if INVADER[y][x] == "1":
					var dy := (y if flip == 0 or y < 6 else y - 1)
					ci.draw_rect(Rect2(p.x + (x - 5.5) * s, p.y + dy * s, s, s), cols[k])
