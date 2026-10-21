class_name Bonus
extends RefCounted
## The two optional bonus rounds offered after each boss. There is no opponent: a wall at the far end
## sends the balls back. Multiball Mayhem keeps several balls alive at once; Break the Table smashes
## a wall of bricks. It runs its own small simulation (same Phys as the rally) and borrows the paddle,
## the effects and the sounds from Game. Win and Game pays out the reward; lose and it pays nothing.

enum Kind { MULTIBALL, BREAKOUT }
## OUT: heading for the far wall after your hit. HELD: waiting at the wall to be fired. IN: coming at you.
enum Phase { OUT, HELD, IN }
enum Brick { NORMAL, TOUGH, BOMB }

const TITLES := ["Multiball Mayhem", "Break the Table"]
const BLURBS := [
	["Keep the balls alive and rack up", "returns before you drop three."],
	["Smash the whole wall before you", "drop three. Hard hits crack tough bricks."],
]
const TRIES := 3
const INTRO := 1.8
const FRONT_Z := Phys.LENGTH + 6.0
const WALL_Z := Phys.LENGTH + 12.0
## There is no mouse assist in here, so the paddle is simply generous.
const HIT_R := 19.0
const MAX_BALLS := [3, 4, 4, 5]
const COLS := 8
const ROWS := 4
## The bricks only span the width a shot can actually be aimed at, so the edge columns are reachable.
const WALL_HALF := 62.0
const BRICK_W := WALL_HALF * 2.0 / COLS
const BRICK_H := 9.0
## Height of the back panel behind the bricks / the ball machine.
const WALL_TOP := 56.0
## A ball faster than this at the wall does double damage to bricks.
const HARD_SPEED := 420.0
const BALL_COLS := [Color("eac058"), Color("fe5f55"), Color("009dff"), Color("4bc292"), Color("ff6bd6")]

var game: Game
var kind := Kind.MULTIBALL
var lvl := 0
var balls: Array[Dictionary] = []
var bricks: Array[Dictionary] = []
var t := 0.0
var acc := 0.0
var hits := 0
## Balls you can still drop. Separate from the run's lives, which a bonus round never touches.
var tries := TRIES
var goal := 24
var max_balls := 3
var gap := 0.65
var last_arrival := 0.0
var finished := false
var won := false
var wall_flash := 0.0


func _init(g: Game, k: int, level: int) -> void:
	game = g
	kind = k
	lvl = clampi(level, 0, 3)
	Phys.reset_tweaks()
	game.cur = Balls.PLAIN
	game.setting = Scenery.ARCADE
	game.popups.clear()
	game.particles.clear()
	game.banner = ""
	max_balls = MAX_BALLS[lvl]
	goal = 24 + 4 * lvl
	gap = 0.65 - 0.05 * lvl
	if kind == Kind.BREAKOUT:
		_build_wall()
		_new_ball(INTRO)
	else:
		_new_ball(INTRO)
		_new_ball(INTRO + 0.6)


## 8 x 4 bricks. Tough ones sit in the middle rows, bombs are scattered anywhere.
func _build_wall() -> void:
	bricks.clear()
	for r in ROWS:
		for c in COLS:
			bricks.append({"c": c, "r": r, "hp": 1, "kind": Brick.NORMAL, "flash": 0.0})
	var slots: Array = range(bricks.size())
	slots.shuffle()
	for i in 3:
		var b := bricks[slots.pop_back()]
		b.kind = Brick.BOMB
	var tough := 2 + lvl * 2
	for idx in slots:
		if tough <= 0:
			break
		var b := bricks[idx]
		if b.r == 1 or b.r == 2:
			b.kind = Brick.TOUGH
			b.hp = 2
			tough -= 1


func bricks_left() -> int:
	var n := 0
	for b in bricks:
		if b.hp > 0:
			n += 1
	return n


func brick_center(b: Dictionary) -> Vector3:
	return Vector3(-WALL_HALF + (b.c + 0.5) * BRICK_W, (b.r + 0.5) * BRICK_H, FRONT_Z)


# ---------------------------------------------------------------------------------------------
# Balls
# ---------------------------------------------------------------------------------------------

func _new_ball(delay: float) -> void:
	var b := {
		"ball": Phys.Ball.new(), "phase": Phase.HELD, "bounces": 0, "hit_cd": 0.0, "angle": 0.0,
		"trail": [], "col": BALL_COLS[balls.size() % BALL_COLS.size()], "intercept": Vector3.ZERO,
		"prev_rel": 0.0, "fire_at": 0.0, "hold_from": t, "plan": {},
	}
	balls.append(b)
	_hold(b, delay, Vector3.ZERO)


## Parks the ball at the wall and works out the shot that will send it back, plus when to fire it so
## that balls arrive at the player one after another instead of all at once.
func _hold(b: Dictionary, delay: float, at: Vector3) -> void:
	var ball: Phys.Ball = b.ball
	b.phase = Phase.HELD
	b.bounces = 0
	var p: Vector3
	if kind == Kind.MULTIBALL:
		p = Vector3(randf_range(-55.0, 55.0), randf_range(22.0, 46.0), FRONT_Z - 4.0)
	else:
		p = Vector3(clampf(at.x, -66.0, 66.0), clampf(at.y, 10.0, 52.0), FRONT_Z - 4.0)
	var tx := clampf(-game.paddle.x * 0.5 + randf_range(-30.0, 30.0), -62.0, 62.0)
	var tz := randf_range(45.0, Phys.NET_Z - 40.0)
	var topspin: float = [randf_range(-35.0, -12.0), randf_range(10.0, 40.0), randf_range(-5.0, 10.0)].pick_random()
	var w := Vector3(-topspin, randf_range(-25.0, 25.0), 0.0)
	var sol := Phys.solve_robust(p, -1.0, tx, tz, w, randf_range(8.0, 26.0))
	var flight := _flight_time(p, sol.v, sol.w)
	var at_t := t + delay
	if kind == Kind.MULTIBALL:
		at_t = maxf(at_t, last_arrival + gap - flight)
	last_arrival = at_t + flight
	b.plan = {"p": p, "v": sol.v, "w": sol.w}
	b.fire_at = at_t
	b.hold_from = t
	b.trail.clear()
	ball.p = p
	ball.v = Vector3.ZERO
	ball.w = Vector3.ZERO


func _flight_time(p: Vector3, v: Vector3, w: Vector3) -> float:
	var s := Phys.Ball.new()
	s.p = p
	s.v = v
	s.w = w
	for i in 720:
		Phys.step(s, Phys.DT)
		if s.p.z <= Game.PADDLE_Z:
			return i * Phys.DT
	return 3.0


func _fire(b: Dictionary) -> void:
	var ball: Phys.Ball = b.ball
	ball.p = b.plan.p
	ball.v = b.plan.v
	ball.w = b.plan.w
	b.phase = Phase.IN
	b.bounces = 0
	b.hit_cd = 0.0
	b.prev_rel = ball.p.z - game.paddle.z
	Audio.play("opp_hit", 1.0 + randf_range(-0.1, 0.1))
	game._burst(Cam.project(ball.p), b.col, 8, 240.0)


func _wanted() -> int:
	if kind == Kind.BREAKOUT:
		return 1
	return clampi(2 + floori(hits * 4.0 / goal), 2, max_balls)


# ---------------------------------------------------------------------------------------------
# Frame loop
# ---------------------------------------------------------------------------------------------

func update(delta: float) -> void:
	if finished:
		return
	t += delta
	wall_flash = maxf(0.0, wall_flash - delta * 3.0)
	for br in bricks:
		br.flash = maxf(0.0, br.flash - delta * 4.0)
	acc += delta
	while acc >= Phys.DT and not finished:
		acc -= Phys.DT
		_step()
	if finished:
		return
	while balls.size() < _wanted():
		_new_ball(0.3)
		_popup("MORE BALLS!", Vector2(640.0, 250.0), Art.GOLD.lightened(0.2), 46)
		Audio.play("point_big", 1.2, 0.0)
	for b in balls:
		if b.phase == Phase.HELD and t >= b.fire_at:
			_fire(b)
		var ball: Phys.Ball = b.ball
		if b.phase == Phase.IN and ball.v.z < 0.0:
			b.intercept = Phys.predict(ball, Game.PADDLE_Z, -1.0)
		else:
			b.intercept = Vector3.ZERO
		if b.phase != Phase.HELD:
			b.trail.append(ball.p)
			if b.trail.size() > 12:
				b.trail.pop_front()


func _step() -> void:
	for b in balls:
		if b.phase == Phase.HELD:
			continue
		var ball: Phys.Ball = b.ball
		var ev := Phys.step(ball, Phys.DT)
		b.angle += ball.w.x * Phys.DT
		b.hit_cd = maxf(0.0, b.hit_cd - Phys.DT)
		match ev:
			Phys.Ev.BOUNCE:
				_on_bounce(b)
			Phys.Ev.NET:
				Audio.play("net")
				game.freeze = maxf(game.freeze, 0.04)
				game._net_flash(1.0)
				game._net_popup("NET!")
			Phys.Ev.NET_CLIP:
				Audio.play("net_clip")
				game._net_flash(0.8)
		if finished:
			return
		if b.phase == Phase.HELD:
			continue
		if b.phase == Phase.OUT:
			if ball.p.z >= FRONT_Z - Phys.R:
				_wall(b)
			elif ball.p.y < Phys.FLOOR_Y or absf(ball.p.x) > 400.0 or ball.p.z < -260.0:
				_lose(b, "OUT")
		else:
			var rel := ball.p.z - game.paddle.z
			var crossed: bool = b.prev_rel > 0.0 and rel <= 0.0
			b.prev_rel = rel
			var close := Vector2(ball.p.x - game.paddle.x, ball.p.y - game.paddle.y).length() <= HIT_R + Phys.R
			if b.hit_cd <= 0.0 and ball.v.z < 0.0 and close and (absf(rel) <= Phys.R + 6.0 or crossed):
				_player_hit(b)
			elif ball.p.z < Game.PADDLE_Z - 40.0 or ball.p.y < Phys.FLOOR_Y or absf(ball.p.x) > 400.0:
				_lose(b, "MISSED")
		if finished:
			return


func _on_bounce(b: Dictionary) -> void:
	var ball: Phys.Ball = b.ball
	b.bounces += 1
	var near := ball.p.z < Phys.NET_Z
	Audio.play("bounce", 1.0, 0.08, linear_to_db(clampf(ball.v.length() / 700.0, 0.3, 1.0)))
	game._burst(Cam.project(Vector3(ball.p.x, 0.0, ball.p.z)), Color.WHITE, 4, 120.0)
	if b.phase == Phase.OUT and near:
		_lose(b, "FAULT")
	elif b.phase == Phase.IN and near and b.bounces >= 2:
		_lose(b, "MISSED")


## Your swing becomes the shot, just like in a rally (spin from the swipe, depth from swing speed).
func _player_hit(b: Dictionary) -> void:
	var ball: Phys.Ball = b.ball
	b.hit_cd = 0.15
	var pv: Vector3 = game.paddle_vel
	var sw := clampf(inverse_lerp(80.0, 800.0, pv.length()), 0.0, 1.0)
	var perfect: bool = game.lunge_t > 0.0
	var off := Vector2(ball.p.x - game.paddle.x, ball.p.y - game.paddle.y).limit_length(game.paddle_r * 0.6)
	var h := ball.p.y
	var w := Vector3(clampf(pv.y * 0.17, -110.0, 110.0), clampf(pv.x * 0.22, -140.0, 140.0), 0.0)
	var lean := clampf(game.paddle.x / game.base_range(), -1.0, 1.0)
	var tx := clampf(pv.x * 0.14 + off.x * 2.4 - lean * 20.0, -62.0, 62.0)
	var tz := lerpf(Phys.NET_Z + 35.0, Phys.LENGTH - 14.0, pow(sw, 0.8))
	var pref := 20.0 - (h - 28.0) * 0.35
	if h < 30.0 and pv.y > 350.0 and sw < 0.6:
		pref = 52.0
		tz = Phys.LENGTH - 25.0
	if perfect:
		pref = 3.0
		tz = Phys.LENGTH - 16.0
	if game.paddle_def.get("no_smash", false):
		pref = maxf(pref, Game.NO_SMASH_ANGLE)
	if game.is_diving():
		tx = clampf(tx + randf_range(-30.0, 30.0), -62.0, 62.0)
		w += Vector3(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0), 0.0)
	var sol := Phys.solve_robust(ball.p, 1.0, tx, tz, w, pref)
	ball.v = sol.v
	ball.w = sol.w
	b.phase = Phase.OUT
	b.bounces = 0
	hits += 1
	Audio.play("hit", 0.85 + sw * 0.4, 0.06, 2.0 if perfect else 0.0)
	game.freeze = 0.03 + sw * 0.02
	game.shake = 3.0 + sw * 5.0
	game.paddle_wobble = 0.6
	game._burst(Cam.project(ball.p), b.col, 10, 300.0)
	if kind == Kind.MULTIBALL:
		_popup("%d" % hits, Cam.project(ball.p) + Vector2(0.0, -50.0), b.col.lightened(0.3), 30)
		if hits >= goal:
			_finish(true)
	elif perfect:
		_popup("POWER HIT", Cam.project(ball.p) + Vector2(0.0, -50.0), Art.RED.lightened(0.15), 30)


# ---------------------------------------------------------------------------------------------
# The wall
# ---------------------------------------------------------------------------------------------

func _wall(b: Dictionary) -> void:
	var ball: Phys.Ball = b.ball
	wall_flash = 1.0
	var at := ball.p
	if kind == Kind.BREAKOUT:
		_hit_bricks(ball)
		if finished:
			return
		_hold(b, 0.12, at)
	else:
		Audio.play("wall")
		game._burst(Cam.project(ball.p), b.col, 8, 220.0)
		_hold(b, 0.1, at)


func _hit_bricks(ball: Phys.Ball) -> void:
	var c := floori((ball.p.x + WALL_HALF) / BRICK_W)
	var r := floori(ball.p.y / BRICK_H)
	var hard := ball.v.length() > HARD_SPEED
	var idx := c + r * COLS
	if c < 0 or c >= COLS or r < 0 or r >= ROWS or bricks[idx].hp <= 0:
		Audio.play("wall")
		_popup("THUNK", Cam.project(ball.p) + Vector2(0.0, -40.0), Color(1, 1, 1, 0.8), 24)
		return
	var br := bricks[idx]
	br.flash = 1.0
	br.hp -= 2 if hard else 1
	if br.hp > 0:
		Audio.play("net_clip", 0.8)
		game.shake = maxf(game.shake, 4.0)
		game._burst(Cam.project(brick_center(br)), Art.CREAM, 8, 200.0)
		_popup("CRACK", Cam.project(brick_center(br)) + Vector2(0.0, -40.0), Art.CREAM, 28)
		return
	_break(idx)
	if bricks_left() == 0:
		_finish(true)


func _break(idx: int) -> void:
	var br := bricks[idx]
	br.hp = 0
	br.flash = 1.0
	var col := brick_color(br)
	game._burst(Cam.project(brick_center(br)), col, 16, 380.0)
	game.shake = maxf(game.shake, 6.0)
	Audio.play("remove", 1.0 + randf_range(0.0, 0.3))
	if br.kind == Brick.BOMB:
		Audio.play("point_big", 0.9, 0.0)
		game.flash = 0.35
		game.flash_col = Art.GOLD
		game.shake = 14.0
		_popup("BOOM!", Cam.project(brick_center(br)) + Vector2(0.0, -50.0), Art.RED.lightened(0.2), 48)
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				var nc: int = br.c + dc
				var nr: int = br.r + dr
				if nc < 0 or nc >= COLS or nr < 0 or nr >= ROWS:
					continue
				if bricks[nc + nr * COLS].hp > 0:
					_break(nc + nr * COLS)


static func brick_color(br: Dictionary) -> Color:
	if br.kind == Brick.BOMB:
		return Color("ff5a2a")
	if br.kind == Brick.TOUGH:
		return Color("9aa7b8")
	return [Color("4bc292"), Color("009dff"), Color("eac058"), Color("c06bff")][br.r % 4]


# ---------------------------------------------------------------------------------------------
# Outcomes
# ---------------------------------------------------------------------------------------------

func _lose(b: Dictionary, why: String) -> void:
	var ball: Phys.Ball = b.ball
	tries -= 1
	var at := Cam.project(ball.p)
	_popup("FAULT" if why == "FAULT" else "MISSED", Vector2(clampf(at.x, 160.0, 1120.0), clampf(at.y, 160.0, 560.0)), Art.RED, 44)
	game._burst(Vector2(clampf(at.x, 80.0, 1200.0), clampf(at.y, 80.0, 640.0)), Art.RED, 22, 380.0)
	Audio.play("point_lose", 1.0, 0.0)
	game.shake = 12.0
	game.flash = 0.4
	game.flash_col = Art.RED
	if tries <= 0:
		_finish(false)
		return
	_hold(b, 1.0, ball.p)


func _finish(w: bool) -> void:
	if finished:
		return
	finished = true
	won = w
	game._bonus_end(w)


func _popup(text: String, pos: Vector2, col: Color, size: int) -> void:
	game.popups.append({"text": text, "pos": pos, "t": 0.0, "col": col, "size": size})


## For --bot runs: stand where the nearest incoming ball will cross the paddle plane.
func bot_target() -> Vector2:
	var best := Vector3.ZERO
	var best_z := INF
	for b in balls:
		var ball: Phys.Ball = b.ball
		if b.phase == Phase.IN and b.intercept.z > 0.0 and ball.p.z < best_z:
			best_z = ball.p.z
			best = b.intercept
	if best.z > 0.0:
		if best_z < 80.0 and game.lunge_cd <= 0.0 and randf() < 0.05:
			game._lunge()
		return Vector2(best.x, best.y)
	return Vector2(0.0, 30.0)
