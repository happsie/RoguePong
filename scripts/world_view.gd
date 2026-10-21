extends Node2D
## Draws the court in perspective, the characters, the ball and the effects. All state lives in Game.


var game: Game
var bubble := StyleBoxFlat.new()


func _init() -> void:
	bubble.set_corner_radius_all(22)
	bubble.set_border_width_all(4)
	bubble.border_color = Art.INK
	bubble.shadow_color = Color(0, 0, 0, 0.4)
	bubble.shadow_size = 2
	bubble.shadow_offset = Vector2(0, 6)


func _p(x: float, y: float, z: float) -> Vector2:
	return Cam.project(Vector3(x, y, z))


func _draw() -> void:
	if game == null:
		return
	game.bg_rect.visible = game.setting == Scenery.ARCADE
	if game.bonus != null and (game.state == Game.S.BONUS or game.state == Game.S.BONUS_END):
		_bonus_world()
		return
	Scenery.draw(self, game.setting, game.time, Cam.project(game.ball.p))
	_floor()
	_opponent()
	_table()
	_pinball_walls()
	_ball_shadow()
	if game.ball.p.z > Phys.NET_Z:
		_ball()
		_net()
	else:
		_net()
		_ball()
	_player()
	_fx()
	_taunt()


## The opponent's speech bubble: pops in beside their head, wobbles, then fades.
func _taunt() -> void:
	if game.taunt == "" or game.taunt_t > game.taunt_dur:
		return
	var t := game.taunt_t
	var o := game.opp
	var tok := Vector3(o.x * 0.55, 52.0, Phys.LENGTH + 64.0)
	var head := Cam.project(tok)
	var r := 26.0 * Cam.scale_at(tok)
	var font := ThemeDB.fallback_font
	var size := 24
	# greedy word wrap
	var lines: Array[String] = []
	var line := ""
	for word in game.taunt.split(" "):
		var trial := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > 250.0:
			lines.append(line)
			line = word
		else:
			line = trial
	lines.append(line)
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var box := Vector2(w + 40.0, lines.size() * 30.0 + 26.0)
	# sit beside the head, on whichever side has room, below the Power x Heat panel
	var side := -1.0 if head.x > 700.0 else 1.0
	var centre := head + Vector2(side * (r * 1.25 + box.x * 0.5), -r * 0.7)
	centre.x = clampf(centre.x, box.x * 0.5 + 12.0, 1268.0 - box.x * 0.5)
	centre.y = maxf(centre.y, 108.0 + box.y * 0.5)
	var pop := (1.0 - exp(-t * 22.0)) * (1.0 + 0.18 * sin(t * 20.0) * exp(-t * 6.0))
	var alpha := clampf((game.taunt_dur - t) / 0.3, 0.0, 1.0)
	var tilt := sin(t * 26.0) * 0.05 * exp(-t * 4.0)
	bubble.bg_color = Color.WHITE if game.taunt_mean else Color("dff3ff")
	bubble.border_color = Color(Art.INK, alpha)
	bubble.shadow_color = Color(0, 0, 0, 0.4 * alpha)
	draw_set_transform(head + Vector2(side * r * 0.9, -r * 0.1), tilt, Vector2(pop, pop))
	# everything below is drawn relative to the tail tip, which is the bubble's anchor
	var rect := Rect2(centre - head - Vector2(side * r * 0.9, -r * 0.1) - box * 0.5, box)
	var base_x := rect.position.x if side > 0.0 else rect.end.x
	var by := rect.end.y - 14.0
	var tail := PackedVector2Array([Vector2(base_x, by - 12.0), Vector2(base_x, by + 6.0), Vector2.ZERO])
	draw_colored_polygon(tail, Color(bubble.border_color, alpha))
	draw_style_box(bubble, rect)
	var inner := PackedVector2Array([Vector2(base_x + side * 3.0, by - 8.0), Vector2(base_x + side * 3.0, by + 2.0), Vector2(side * 9.0, -1.0)])
	draw_colored_polygon(inner, Color(bubble.bg_color, alpha))
	for i in lines.size():
		var tp := rect.position + Vector2(20.0, 36.0 + i * 30.0)
		draw_string(font, tp, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Art.INK, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The Pinball ball's invisible side walls, as faint glowing panes along the table.
func _pinball_walls() -> void:
	if not Phys.walls:
		return
	var pulse := 0.5 + 0.5 * sin(game.time * 6.0)
	for side in [-1.0, 1.0]:
		var x: float = side * Phys.WALL_X
		var quad := PackedVector2Array([_p(x, 0.0, 0.0), _p(x, 45.0, 0.0), _p(x, 45.0, Phys.LENGTH), _p(x, 0.0, Phys.LENGTH)])
		draw_colored_polygon(quad, Color(Balls.color(game.cur), 0.10 + 0.05 * pulse))
		draw_line(quad[1], quad[2], Color(Balls.color(game.cur), 0.6), 2.0)


func _floor() -> void:
	var fy := Phys.FLOOR_Y
	for i in range(-9, 10):
		draw_line(_p(i * 100.0, fy, -150.0), _p(i * 100.0, fy, 1000.0), Color(1, 1, 1, 0.05), 1.5)
	for j in 13:
		var z := -100.0 + j * 100.0
		draw_line(_p(-900.0, fy, z), _p(900.0, fy, z), Color(1, 1, 1, 0.05), 1.5)
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(_p(cos(a) * 100.0, fy, Phys.NET_Z + sin(a) * 170.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.4))


func _table() -> void:
	var hw := Phys.HALF_W
	var len := Phys.LENGTH
	var thick := 7.0
	# near legs, then the apron facing the camera
	for sx in [-1.0, 1.0]:
		var top_p := _p(sx * (hw - 12.0), -thick, 18.0)
		var bot_p := _p(sx * (hw - 12.0), Phys.FLOOR_Y, 18.0)
		var wpx := Cam.scale_at(Vector3(0, 0, 18.0)) * 6.0
		draw_line(top_p, bot_p, Art.INK, wpx + 6.0)
		draw_line(top_p, bot_p, Art.SLATE, wpx)
		draw_rect(Rect2(bot_p.x - wpx, bot_p.y - 4.0, wpx * 2.0, 8.0), Art.INK)
	draw_colored_polygon(PackedVector2Array([_p(-hw, 0, 0), _p(hw, 0, 0), _p(hw, -thick, 0), _p(-hw, -thick, 0)]), Art.TABLE_BODY)
	draw_polyline(PackedVector2Array([_p(-hw, 0, 0), _p(-hw, -thick, 0), _p(hw, -thick, 0), _p(hw, 0, 0)]), Art.INK, 3.0)
	# playing surface, lighter near the camera
	var near_c := Art.TABLE_TOP.lightened(0.12)
	var far_c := Art.TABLE_BODY.lightened(0.05)
	draw_polygon(
		PackedVector2Array([_p(-hw, 0, 0), _p(hw, 0, 0), _p(hw, 0, len), _p(-hw, 0, len)]),
		PackedColorArray([near_c, near_c, far_c, far_c]),
	)
	var lw := Cam.scale_at(Vector3(0, 0, len * 0.5)) * 2.0
	var corners := PackedVector2Array([_p(-hw, 0, 0), _p(hw, 0, 0), _p(hw, 0, len), _p(-hw, 0, len), _p(-hw, 0, 0)])
	draw_polyline(corners, Color(1, 1, 1, 0.9), lw)
	draw_line(_p(0, 0, 0), _p(0, 0, len), Color(1, 1, 1, 0.55), lw * 0.6)
	draw_polyline(PackedVector2Array([_p(-hw, 0, len), _p(hw, 0, len)]), Art.INK, 2.0)


func _net() -> void:
	var hw := Phys.HALF_W + Phys.NET_OVER
	var z := Phys.NET_Z
	var nh := Phys.NET_H
	var a := _p(-hw, 0, z)
	var b := _p(hw, 0, z)
	var c := _p(hw, nh, z)
	var d := _p(-hw, nh, z)
	var f := game.net_flash
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color(0.08, 0.1, 0.12, 0.55).lerp(Color(Art.GOLD, 0.55), f))
	# a hit sends a ripple along the mesh and lights the whole net up
	var ripple := sin(game.time * 45.0) * f * 5.0
	for i in 21:
		var x := -hw + i * (hw * 2.0 / 20.0)
		draw_line(_p(x, 0, z) + Vector2(ripple, 0), _p(x, nh, z) - Vector2(ripple, 0), Color(1, 1, 1, 0.2 + 0.6 * f), 1.0 + f)
	for j in range(1, 4):
		var y := nh * j / 4.0
		draw_line(_p(-hw, y, z), _p(hw, y, z), Color(1, 1, 1, 0.2 + 0.6 * f), 1.0 + f)
	var s := Cam.scale_at(Vector3(0, nh, z))
	draw_line(d, c, Art.INK, s * 2.4 + 3.0)
	draw_line(d, c, Color.WHITE.lerp(Art.GOLD, f), s * 1.7 * (1.0 + 0.5 * f))
	for sx in [-1.0, 1.0]:
		var bot := _p(sx * hw, -1.0, z)
		var top := _p(sx * hw, nh + 2.5, z)
		draw_line(bot, top, Art.INK, s * 3.2 + 3.0)
		draw_line(bot, top, Art.SLATE, s * 2.2)


func _opponent() -> void:
	var o := game.opp
	var tok := Vector3(o.x * 0.55, 52.0, Phys.LENGTH + 64.0)
	var r := 26.0 * Cam.scale_at(tok)
	var tp := Cam.project(tok)
	var pz := Vector3(o.x, o.y, Game.OPP_Z - game.opp_swing / 0.2 * 40.0)
	var pp := Cam.project(pz)
	var pr := Game.PADDLE_R * Cam.scale_at(pz)
	var tilt := clampf(o.x / 80.0, -1.0, 1.0) * 0.5
	_arm(tp + Vector2(0, r * 0.5), pp + Vector2(0, pr * 1.8).rotated(tilt), pr, Color("c9822f"))
	Art.goof(self, tp, r * 1.15, Roster.STAGES[game.stage], Cam.project(game.ball.p), game.opp_mood, game.time)
	Art.paddle_disc(self, pp, pr, tilt, 1.0)


func _arm(from: Vector2, to: Vector2, r: float, col: Color) -> void:
	draw_line(from, to, Art.INK, r * 0.66)
	draw_line(from, to, col, r * 0.46)
	draw_circle(to, r * 0.34, Art.INK)
	draw_circle(to, r * 0.26, col.lightened(0.15))


func _ball_shadow() -> void:
	var b := game.ball.p
	var on_table := absf(b.x) <= Phys.HALF_W and b.z >= 0.0 and b.z <= Phys.LENGTH and b.y >= 0.0
	var gy := 0.0 if on_table else Phys.FLOOR_Y
	var h := b.y - gy
	if h < 0.0:
		return
	var at := Vector3(b.x, gy, b.z)
	var rx := Phys.R * Cam.scale_at(at) * 1.5 * (1.0 + h * 0.002)
	var a := clampf(0.5 - h * 0.004, 0.1, 0.5) * (1.0 if on_table else 0.5)
	Art.ellipse(self, Cam.project(at), rx, rx * 0.4, Color(0, 0, 0, a))


func _ball() -> void:
	var b := game.ball
	var p := Cam.project(b.p)
	var r := Phys.R * Cam.scale_at(b.p) * 1.5
	for i in game.trail.size():
		var f := float(i) / float(game.trail.size())
		var tc := Color.WHITE if game.cur == Balls.PLAIN else Balls.color(game.cur)
		draw_circle(Cam.project(game.trail[i]), r * (0.35 + 0.5 * f), Color(tc, 0.16 * f if game.cur == Balls.PLAIN else 0.35 * f))
	if game.cur != Balls.PLAIN:
		# a glow so the magic ball stands out
		draw_circle(p, r * (2.0 + 0.3 * sin(game.time * 10.0)), Color(Balls.color(game.cur), 0.28))
	var vs := Cam.project(b.p + b.v * 0.01) - p
	var stretch := 1.0 + minf(vs.length() / 40.0, 0.3)
	draw_set_transform(p, vs.angle(), Vector2(stretch, 1.0 / stretch))
	draw_circle(Vector2.ZERO, r + 2.5, Art.INK)
	draw_circle(Vector2.ZERO, r, Balls.color(game.cur))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var m := Vector2(cos(game.ball_angle * 0.6), sin(game.ball_angle * 0.6) * 0.7) * r * 0.55
	draw_circle(p + m, maxf(2.0, r * 0.22), Art.RED)
	draw_circle(p - m, maxf(2.0, r * 0.22), Art.RED.darkened(0.2))
	draw_circle(p + Vector2(-r * 0.3, -r * 0.35), maxf(1.5, r * 0.25), Color(1, 1, 1, 0.85))


func _player() -> void:
	var pad := game.paddle
	var pp := Cam.project(pad)
	var pr := Game.PADDLE_R * Cam.scale_at(pad)
	if game.intercept.z > 0.0:
		var ic := Cam.project(Vector3(game.intercept.x, game.intercept.y, Game.PADDLE_Z))
		var pulse := 0.5 + 0.5 * sin(game.time * 12.0)
		draw_arc(ic, pr * 0.9, 0.0, TAU, 40, Color(1, 1, 1, 0.3 + 0.3 * pulse), 3.0)
	# fade the paddle a little as the ball closes in, so it never hides the ball
	var alpha := 1.0
	if game.last_hitter == Game.Who.OPP and game.ball.v.z < 0.0:
		alpha = 1.0 - 0.45 * clampf(inverse_lerp(160.0, 40.0, absf(game.ball.p.z - pad.z)), 0.0, 1.0)
	# the further out the paddle goes from the middle, the more it leans over (pivoting on the hand)
	var lean := clampf(pad.x / game.base_range(), -1.0, 1.0) * 0.6
	var tilt := lean + clampf(game.paddle_vel.x * -0.0004, -0.35, 0.35) + sin(game.paddle_wobble * 40.0) * game.paddle_wobble * 0.5
	var skin := game.paddle_def
	# while Stretch runs, streaks trail the paddle so it reads as reaching
	if game.ability_t > 0.0 and game.paddle_def.ability == "stretch":
		for k in 4:
			Art.paddle_disc(self, pp - Vector2(signf(pad.x) * (k + 1) * pr * 0.5, 0.0), pr, tilt, 0.12 * alpha, skin)
	Art.paddle_disc(self, pp, pr, tilt, alpha, skin)
	Art.glove(self, pp, pr, tilt, alpha, skin.handle)


func _fx() -> void:
	for pt in game.particles:
		var f: float = pt.life / pt.max
		draw_circle(pt.pos, pt.size * f, Color(pt.col, f))
	for pp in game.popups:
		var f: float = pp.t / 1.1
		var pop := 1.0 + 0.5 * exp(-pp.t * 14.0)
		var c: Color = pp.col
		draw_set_transform(pp.pos, 0.0, Vector2(pop, pop))
		Art.text(self, pp.text, Vector2.ZERO, pp.get("size", 26), Color(c, c.a * (1.0 - f * f)), HORIZONTAL_ALIGNMENT_CENTER)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- bonus rounds

func _bonus_world() -> void:
	var bo := game.bonus
	Scenery.draw(self, Scenery.ARCADE, game.time, Vector2(640, 300))
	_floor()
	_table()
	_bonus_wall(bo)
	for b in bo.balls:
		_bonus_shadow(b)
	for b in bo.balls:
		if b.ball.p.z > Phys.NET_Z:
			_bonus_ball(b)
	_net()
	for b in bo.balls:
		if b.ball.p.z <= Phys.NET_Z:
			_bonus_ball(b)
	_bonus_rings(bo)
	_player()
	_fx()


## The far-end wall: a wall of bricks for Break the Table, a neon ball machine for Multiball Mayhem.
func _bonus_wall(bo: Bonus) -> void:
	var hw := Phys.HALF_W + 14.0
	var top := Bonus.WALL_TOP if bo.kind == Bonus.Kind.MULTIBALL else Bonus.ROWS * Bonus.BRICK_H + 10.0
	var z := Bonus.WALL_Z
	var a := _p(-hw, -6.0, z)
	var b := _p(hw, -6.0, z)
	var c := _p(hw, top, z)
	var d := _p(-hw, top, z)
	var pulse := 0.5 + 0.5 * sin(game.time * 6.0)
	var board := Color("1a1030").lerp(Color("5a2a9a"), bo.wall_flash * 0.6)
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), board)
	var edge := Color(Art.GOLD, 0.6 + 0.4 * pulse) if bo.kind == Bonus.Kind.BREAKOUT else Color(Art.RED.lerp(Art.BLUE, pulse), 0.9)
	draw_polyline(PackedVector2Array([a, b, c, d, a]), Art.INK, 8.0)
	draw_polyline(PackedVector2Array([a, b, c, d, a]), edge, 4.0)
	if bo.kind == Bonus.Kind.BREAKOUT:
		_bricks(bo)
		return
	# machine: chasing bulbs along the top and a title on the panel
	for i in 15:
		var x := -hw + (hw * 2.0) * i / 14.0
		var on := int(game.time * 8.0) % 3 == i % 3
		draw_circle(_p(x, top - 3.0, z - 1.0), 5.0, Color(Art.GOLD, 1.0) if on else Color(Art.GOLD, 0.25))
	Art.text(self, "MULTIBALL", _p(0.0, top * 0.5 + 4.0, z - 1.0) + Vector2(0, 14), 44, Color(Art.CREAM, 0.85))
	for held in bo.balls:
		if held.phase == Bonus.Phase.HELD:
			# a charging ring shrinks onto the ball as it is about to be fired
			var p: Vector3 = held.ball.p
			var u := clampf(inverse_lerp(held.hold_from, held.fire_at, bo.t), 0.0, 1.0)
			var s := Cam.scale_at(p)
			draw_arc(_p(p.x, p.y, p.z), (6.0 + 22.0 * (1.0 - u)) * s, 0.0, TAU, 28, Color(held.col, 0.3 + 0.6 * u), 3.0)


func _bricks(bo: Bonus) -> void:
	var inset := 0.7
	for br in bo.bricks:
		if br.hp <= 0:
			continue
		var x0: float = -Bonus.WALL_HALF + br.c * Bonus.BRICK_W + inset
		var x1: float = x0 + Bonus.BRICK_W - inset * 2.0
		var y0: float = br.r * Bonus.BRICK_H + inset
		var y1: float = y0 + Bonus.BRICK_H - inset * 2.0
		var zf := Bonus.FRONT_Z
		var zb := Bonus.WALL_Z
		var col := Bonus.brick_color(br).lerp(Color.WHITE, br.flash * 0.7)
		draw_colored_polygon(PackedVector2Array([_p(x0, y1, zf), _p(x1, y1, zf), _p(x1, y1, zb), _p(x0, y1, zb)]), col.lightened(0.3))
		var front := PackedVector2Array([_p(x0, y0, zf), _p(x1, y0, zf), _p(x1, y1, zf), _p(x0, y1, zf)])
		draw_colored_polygon(front, col)
		draw_colored_polygon(PackedVector2Array([front[3], front[2], front[2] + Vector2(0, 5), front[3] + Vector2(0, 5)]), Color(1, 1, 1, 0.25))
		draw_polyline(PackedVector2Array([front[0], front[1], front[2], front[3], front[0]]), Art.INK, 2.5)
		var mid := (front[0] + front[2]) * 0.5
		var u := Cam.scale_at(Vector3(0.0, y0, zf))
		if br.kind == Bonus.Brick.TOUGH:
			draw_circle(front[0].lerp(front[3], 0.5) + Vector2(5, 0), 2.5, Art.INK)
			draw_circle(front[1].lerp(front[2], 0.5) - Vector2(5, 0), 2.5, Art.INK)
			if br.hp == 1:
				draw_polyline(PackedVector2Array([mid + Vector2(-8, -10), mid + Vector2(-2, -2), mid + Vector2(-6, 3), mid + Vector2(3, 11)]), Art.INK, 2.5)
		elif br.kind == Bonus.Brick.BOMB:
			var bob := sin(game.time * 10.0 + br.c) * 1.5
			draw_circle(mid + Vector2(0, bob), 5.0 * u, Art.INK)
			draw_circle(mid + Vector2(-1.5, -1.5 + bob), 1.6 * u, Color(1, 1, 1, 0.5))
			draw_line(mid + Vector2(2, -4.0 * u + bob), mid + Vector2(5, -6.5 * u + bob), Art.INK, 2.0)
			draw_circle(mid + Vector2(5, -6.5 * u + bob), 2.2 * u * (0.7 + 0.3 * sin(game.time * 30.0)), Art.GOLD)


func _bonus_shadow(b: Dictionary) -> void:
	if b.phase == Bonus.Phase.HELD:
		return
	var p: Vector3 = b.ball.p
	var on_table := absf(p.x) <= Phys.HALF_W and p.z >= 0.0 and p.z <= Phys.LENGTH and p.y >= 0.0
	var gy := 0.0 if on_table else Phys.FLOOR_Y
	var h := p.y - gy
	if h < 0.0:
		return
	var at := Vector3(p.x, gy, p.z)
	var rx := Phys.R * Cam.scale_at(at) * 1.5 * (1.0 + h * 0.002)
	var a := clampf(0.5 - h * 0.004, 0.1, 0.5) * (1.0 if on_table else 0.5)
	Art.ellipse(self, Cam.project(at), rx, rx * 0.4, Color(0, 0, 0, a))


func _bonus_ball(b: Dictionary) -> void:
	var ball: Phys.Ball = b.ball
	var col: Color = b.col
	var p := Cam.project(ball.p)
	var r := Phys.R * Cam.scale_at(ball.p) * 1.5
	var trail: Array = b.trail
	for i in trail.size():
		var f := float(i) / float(trail.size())
		draw_circle(Cam.project(trail[i]), r * (0.35 + 0.5 * f), Color(col, 0.35 * f))
	draw_circle(p, r * (2.0 + 0.3 * sin(game.time * 10.0 + b.angle)), Color(col, 0.28))
	var vs := Cam.project(ball.p + ball.v * 0.01) - p
	var stretch := 1.0 + minf(vs.length() / 40.0, 0.3)
	draw_set_transform(p, vs.angle(), Vector2(stretch, 1.0 / stretch))
	draw_circle(Vector2.ZERO, r + 2.5, Art.INK)
	draw_circle(Vector2.ZERO, r, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var m := Vector2(cos(b.angle * 0.6), sin(b.angle * 0.6) * 0.7) * r * 0.55
	draw_circle(p + m, maxf(2.0, r * 0.22), Art.RED)
	draw_circle(p - m, maxf(2.0, r * 0.22), Art.RED.darkened(0.2))
	draw_circle(p + Vector2(-r * 0.3, -r * 0.35), maxf(1.5, r * 0.25), Color(1, 1, 1, 0.85))


## Where each incoming ball will cross your paddle plane, in the ball's own colour.
func _bonus_rings(bo: Bonus) -> void:
	var pr := game.paddle_r * Cam.scale_at(game.paddle)
	var pulse := 0.5 + 0.5 * sin(game.time * 12.0)
	for b in bo.balls:
		if b.intercept.z > 0.0:
			var ic := Cam.project(Vector3(b.intercept.x, b.intercept.y, Game.PADDLE_Z))
			draw_arc(ic, pr * 0.9, 0.0, TAU, 40, Color(b.col, 0.35 + 0.4 * pulse), 3.0)
