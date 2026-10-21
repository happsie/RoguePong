extends Node2D
## Heads-up display: lives, score, the Power x Heat panel and the centre banners.

var game: Game
var panel := StyleBoxFlat.new()


func _init() -> void:
	panel.bg_color = Art.SLATE
	panel.set_corner_radius_all(20)
	panel.set_border_width_all(4)
	panel.border_color = Art.INK
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 3
	panel.shadow_offset = Vector2(0, 8)


func _draw() -> void:
	if game == null:
		return
	_draw_screen()
	if game.settings_open:
		_settings()


func _draw_screen() -> void:
	if game.state == Game.S.SHOP:
		_shop()
		return
	if game.state == Game.S.BONUS_OFFER:
		_bonus_offer()
		return
	if game.flash > 0.01:
		draw_rect(Rect2(0, 0, 1280, 720), Color(game.flash_col, game.flash * 0.55))
	if game.state == Game.S.BONUS or game.state == Game.S.BONUS_END:
		_bonus_screen()
		return
	_lives()
	if game.bonus_heat > 0.0:
		Art.text(self, "BASE HEAT  %.2f" % game.base_heat(), Vector2(36, 112), 14, Art.RED.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT)
	_score()
	_power_heat()
	_shards()
	_banner()
	_fliers()
	_balls()
	_ability_meter()
	var st: Dictionary = Roster.STAGES[game.stage]
	match game.state:
		Game.S.INTRO:
			_intro(st)
		Game.S.CLEAR:
			_clear()
		Game.S.VICTORY:
			_victory()
		Game.S.GAME_OVER:
			_game_over()


func _settings() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
	draw_style_box(panel, Game.SET_PANEL)
	Art.text(self, "SETTINGS", Vector2(640, 250), 44, Art.GOLD)
	var mouse := get_global_mouse_position()
	for i in Game.SET_BUSES.size():
		var bus: String = Game.SET_BUSES[i]
		var v: float = Audio.vol[bus]
		var r := Game.slider_rect(i)
		Art.text(self, bus.to_upper(), Vector2(r.position.x, r.position.y - 12), 20, Art.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
		Art.text(self, "%d%%" % roundi(v * 100.0), Vector2(r.end.x, r.position.y - 12), 20, Art.GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
		draw_rect(r.grow(3.0), Art.INK)
		draw_rect(Rect2(r.position, Vector2(r.size.x * v, r.size.y)), Art.GREEN)
		var hot := r.grow(12.0).has_point(mouse) or game.settings_drag == i
		var knob := Vector2(r.position.x + r.size.x * v, r.get_center().y)
		draw_circle(knob, 15.0 if hot else 12.0, Art.INK)
		draw_circle(knob, 11.0 if hot else 8.0, Art.CREAM)
	var labels := ["RESUME", "QUIT GAME"]
	for i in 2:
		var b := Game.set_button(i)
		var hover := b.has_point(mouse)
		draw_style_box(panel, b.grow(4.0 if hover else 0.0))
		Art.text(self, labels[i], b.get_center() + Vector2(0, 8), 22, Art.GREEN if i == 0 else Art.RED)
	Art.text(self, "ESC to close", Vector2(640, 538), 14, Color(1, 1, 1, 0.45))


## The paddle's ability: its name and the key, a bar that refills during the cooldown, and a bright
## bar that drains while the ability is running.
func _ability_meter() -> void:
	var def: Dictionary = game.paddle_def
	if def.ability == "":
		return
	var ready := game.ability_cd <= 0.0
	var active := game.ability_t > 0.0
	var x := 1040.0
	var y := 690.0
	var fill := 1.0 - game.ability_cd / float(def.cd)
	var label := "%s   [SPACE]" % Paddles.ABILITY_NAMES[def.ability]
	Art.text(self, label, Vector2(x, y - 8), 15, Art.GOLD if active else (Art.GREEN if ready else Color(1, 1, 1, 0.45)), HORIZONTAL_ALIGNMENT_LEFT)
	draw_rect(Rect2(x - 3, y - 3, 206, 18), Art.INK)
	if active:
		draw_rect(Rect2(x, y, 200.0 * game.ability_t / float(def.dur), 12), Art.GOLD)
	else:
		draw_rect(Rect2(x, y, 200.0 * fill, 12), Art.GREEN if ready else Art.GOLD.darkened(0.3))


## Hearts for the run's lives, or for the balls you can still drop in a bonus round.
func _lives(label := "LIVES", count := -1) -> void:
	if count < 0:
		count = game.lives
	Art.text(self, label, Vector2(36, 30), 16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
	for i in maxi(Game.START_LIVES, count):
		var c := Vector2(54 + i * 50, 72)
		var alive := i < count
		Art.heart(self, c + Vector2(3, 4), 40.0, Color(0, 0, 0, 0.4))
		Art.heart(self, c, 44.0, Art.INK)
		Art.heart(self, c, 36.0, Art.RED if alive else Art.SLATE_DARK)
		if alive:
			draw_circle(c + Vector2(-8, -9), 3.5, Color(1, 1, 1, 0.6))


func _score() -> void:
	var frac := clampf(game.score_shown / float(maxi(1, game.target)), 0.0, 1.0)
	var done := frac >= 1.0
	var sh := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * game.score_pulse * 2.5
	var r := Rect2(986, 10, 274, 142)
	draw_set_transform(sh, 0.0, Vector2.ONE)
	Art.vivid(self, r, Color("0b5fb8").lerp(Color("159a68"), 1.0 if done else 0.0), Color("1a2f8f").lerp(Color("0f6b4a"), 1.0 if done else 0.0), game.time, maxf(game.score_pulse, 0.5 if done else 0.0))
	Art.text(self, "SCORE", Vector2(1004, 38), 18, Art.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	Art.text(self, "STAGE  %d / %d" % [game.stage + 1, Roster.count()], Vector2(1242, 38), 16, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	var pop := 1.0 + game.score_pulse * 0.18
	draw_set_transform(Vector2(1242, 86) + sh, 0.0, Vector2(pop, pop))
	Art.text(self, Art.fmt(int(game.score_shown)), Vector2.ZERO, 50, Art.GOLD.lightened(0.25 + game.score_pulse * 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	draw_set_transform(sh, 0.0, Vector2.ONE)
	Art.text(self, "TARGET  " + Art.fmt(game.target), Vector2(1242, 112), 16, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(1002, 120, 242, 20), Art.INK)
	draw_rect(Rect2(1005, 123, 236, 14), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(1005, 123, 236.0 * frac, 14), Art.GREEN.lightened(0.2) if done else Art.GOLD)
	draw_rect(Rect2(1005, 123, 236.0 * frac, 5), Color(1, 1, 1, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _power_heat() -> void:
	if game.returns > 0 and game.state == Game.S.RALLY:
		Art.text(self, "RALLY  %d" % game.returns, Vector2(36, 134), 24, Art.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	# a lost rally smashes the panel; it is rebuilt a moment later, empty
	if game.shatter_t < 0.9:
		return
	var r := Rect2(500, 8, 280, 58)
	var rebuild := _smooth01(inverse_lerp(0.9, 1.15, game.shatter_t))
	# how big the rally is worth so far, 0..1 against the stage target: drives glow and shake
	var k := clampf(game.disp_power * game.disp_heat / float(maxi(1, game.target)) * 4.0, 0.0, 1.0)
	var kick := minf(game.panel_kick, 2.5)
	var amp := kick * (1.5 + 4.5 * k)
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp
	var tilt := randf_range(-1.0, 1.0) * kick * (0.004 + 0.012 * k)
	var grow := (0.8 + 0.2 * rebuild) * (1.0 + 0.04 * kick + 0.05 * k)
	var c := r.get_center() + jitter
	if k > 0.15:
		# a heat glow behind the panel that swells with the score and breathes while it climbs
		var breathe := 0.5 + 0.5 * sin(game.time * (6.0 + 8.0 * k))
		var glow := Color(Art.RED.lerp(Art.GOLD, k), (0.10 + 0.22 * k) * (0.6 + 0.4 * breathe))
		for i in 3:
			draw_circle(c, 110.0 + i * 22.0 + 14.0 * k, Color(glow, glow.a * (0.5 - i * 0.15)))
	draw_set_transform(c, tilt, Vector2.ONE * grow)
	var top := Color("4a2bb8").lerp(Color("d9480f"), k)
	var bot := Color("a02bc4").lerp(Art.GOLD.darkened(0.15), k)
	Art.vivid(self, Rect2(-r.size * 0.5, r.size), top, bot, game.time, maxf(k, minf(kick * 0.4, 1.0)), 16.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var pp := 1.0 + game.power_pulse * 0.2
	var hp := 1.0 + game.heat_pulse * 0.3 + 0.08 * k * sin(game.time * 12.0)
	var base := c + Vector2(0, 2)
	Art.text(self, "POWER", base + Vector2(-80, -16), 12, Art.BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	Art.text(self, "HEAT", base + Vector2(80, -16), 12, Art.RED, HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(base + Vector2(-80, 14), tilt, Vector2(pp, pp))
	Art.text(self, str(int(round(game.disp_power))), Vector2.ZERO, 32, Art.BLUE.lightened(0.25 + 0.3 * game.power_pulse), HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(base + Vector2(80, 14), tilt, Vector2(hp, hp))
	Art.text(self, "%.1f" % game.disp_heat, Vector2.ZERO, 32, Art.RED.lightened(0.15 + 0.3 * game.heat_pulse).lerp(Art.GOLD, k * 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(base + Vector2(0, 12), tilt, Vector2.ONE)
	Art.text(self, "×", Vector2.ZERO, 26, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _smooth01(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _banner() -> void:
	if game.banner == "":
		return
	var t := game.banner_t
	var s := 1.0 + 0.5 * exp(-t * 9.0)
	var text := game.banner
	if game.banner_count >= 0:
		# the winnings count up while the number is punched in
		var k := _smooth01(t / 0.55)
		text = "+" + Art.fmt(int(game.banner_count * k))
		s += 0.12 * sin(minf(t / 0.55, 1.0) * PI)
	elif game.state == Game.S.POINT_OVER:
		# a lost rally drops in heavy and wobbles
		var wob := sin(t * 40.0) * exp(-t * 6.0) * 0.08
		draw_set_transform(Vector2(640, 330 - 60.0 * exp(-t * 14.0)), wob, Vector2(s, s))
		Art.text(self, text, Vector2.ZERO, 72, game.banner_col, HORIZONTAL_ALIGNMENT_CENTER)
		if game.banner_sub != "":
			Art.text(self, game.banner_sub, Vector2(0, 44), 24, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_set_transform(Vector2(640, 330), 0.0, Vector2(s, s))
	Art.text(self, text, Vector2.ZERO, 72, game.banner_col, HORIZONTAL_ALIGNMENT_CENTER)
	if game.banner_sub != "":
		Art.text(self, game.banner_sub, Vector2(0, 44), 24, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if game.win_word != "" and game.state == Game.S.POINT_OVER:
		# the rating word slams in above the number
		var wt := maxf(0.0, t - 0.15)
		var ws := 1.0 + 1.1 * exp(-wt * 10.0)
		draw_set_transform(Vector2(640, 228), sin(t * 14.0) * 0.05 * exp(-t * 2.0), Vector2(ws, ws))
		Art.text(self, game.win_word, Vector2.ZERO, 54, game.win_col, HORIZONTAL_ALIGNMENT_CENTER)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Coins arcing from the banner to the score; the score ticks up as each one lands.
func _fliers() -> void:
	for f in game.fliers:
		var u: float = (f.t - f.delay) / f.dur
		if u < 0.0:
			continue
		for k in 4:
			var uu := clampf(u - k * 0.05, 0.0, 1.0)
			var p := _bezier(f.from, f.ctrl, Game.SCORE_AT, uu * uu)
			draw_circle(p, 8.0 - k * 1.6, Color(Art.GOLD, 0.9 - k * 0.22))
		var head := _bezier(f.from, f.ctrl, Game.SCORE_AT, u * u)
		draw_circle(head, 10.0, Art.INK)
		draw_circle(head, 7.5, Art.GOLD)
		draw_circle(head + Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.8))


func _bezier(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


## The pieces of the shattered Power x Heat panel.
func _shards() -> void:
	for s in game.shards:
		var fade := clampf(s.life / 0.4, 0.0, 1.0)
		var h: Vector2 = s.size * 0.5
		var pts := PackedVector2Array()
		for corner in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x * 0.6, h.y), Vector2(-h.x, h.y * 0.8)]:
			pts.append(s.pos + corner.rotated(s.rot))
		draw_colored_polygon(pts, Color(s.col, fade))
		pts.append(pts[0])
		draw_polyline(pts, Color(Art.INK, fade), 3.0)


func _blink_prompt(s: String, y: float) -> void:
	var blink := 0.55 + 0.45 * sin(game.time * 5.0)
	Art.text(self, s, Vector2(640, y), 26, Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER)


## Pops a full-screen card in: everything drawn until the transform is reset scales up from the centre.
func _pop(t: float) -> void:
	var x := clampf(t / 0.4, 0.0, 1.0) - 1.0
	var s := 0.6 + 0.4 * (1.0 + 2.70158 * x * x * x + 1.70158 * x * x)
	draw_set_transform(Vector2(640, 360) * (1.0 - s), 0.0, Vector2(s, s))


func _reset_tf() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A big vivid card behind an end-of-run / end-of-stage message.
func _card(r: Rect2, top: Color, bot: Color, energy: float) -> void:
	Art.vivid(self, r, top, bot, game.time, energy, 26.0)


## The jagged lightning seam between the two screen halves; the same zig-zag on both sides so they
## lock together when `c` reaches 1.
func _tear_edge(i: int) -> float:
	return (fposmod(sin(i * 12.9898) * 43758.5453, 1.0) - 0.5) * 90.0


func _tear_cover(c: float, boss: bool) -> void:
	var steps := 16
	var h := 720.0 / steps
	var e := 640.0 * c
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var le := PackedVector2Array()
	var re := PackedVector2Array()
	var flick := 1.0 if c >= 1.0 else 1.0 + 0.2 * sin(game.time * 45.0)
	for i in steps + 1:
		var z := _tear_edge(i) * flick
		le.append(Vector2(e + z, i * h))
		re.append(Vector2(1280.0 - e + z, i * h))
	left.append(Vector2(-60, 0))
	left.append_array(le)
	left.append(Vector2(-60, 720))
	right.append(Vector2(1340, 0))
	right.append_array(re)
	right.append(Vector2(1340, 720))
	var top := Color("8a1030") if boss else Color("3b1fa8")
	var bot := Color("d9480f") if boss else Color("c2268f")
	for poly in [left, right]:
		var cols := PackedColorArray()
		for p in poly:
			cols.append(top.lerp(bot, clampf(p.y / 720.0, 0.0, 1.0)))
		draw_polygon(poly, cols)
		for i in 15:
			var x := -900.0 + i * 220.0 + fposmod(game.time * 90.0, 220.0)
			var band := PackedVector2Array([Vector2(x + 720, 0), Vector2(x + 820, 0), Vector2(x + 100, 720), Vector2(x, 720)])
			for piece in Geometry2D.intersect_polygons(band, poly):
				if piece.size() >= 3:
					draw_colored_polygon(piece, Color(1, 1, 1, 0.07))
	# the lightning itself: glow, ink outline, white-hot core, and a few forks
	var burn := 1.0
	if game.intro_phase == 0:
		burn = clampf(1.0 - (game.state_t - Game.INTRO_CLOSE) * 2.5, 0.0, 1.0)
	for edge in ([le, re] if burn > 0.02 else []):
		draw_polyline(edge, Color(Art.GOLD, 0.35 * burn), 22.0)
		draw_polyline(edge, Art.INK, 11.0)
		draw_polyline(edge, Color(1, 1, 1, burn), 4.0)
		for i in range(1, steps, 3):
			var dir := -1.0 if edge == le else 1.0
			var fork: Vector2 = edge[i] + Vector2(dir * (30.0 + 10.0 * sin(game.time * 30.0 + i)), 26.0)
			draw_line(edge[i], fork, Color(1, 1, 1, 0.8 * burn), 3.0)


## The card that introduces a stage. The two halves of the screen slam together along a lightning
## tear and show the opponent; a click tears them open again and 3-2-1-GO counts down.
func _intro(st: Dictionary) -> void:
	var closing := game.intro_phase == 0
	var c: float
	if closing:
		c = clampf(game.state_t / Game.INTRO_CLOSE, 0.0, 1.0)
		c *= c
	else:
		c = 1.0 - _smooth01(game.intro_t / 0.5)
	var boss: bool = st.get("boss", false)
	if c > 0.0:
		_tear_cover(c, boss)
	var s := 1.0
	if closing:
		var x := clampf((game.state_t - Game.INTRO_CLOSE) / 0.35, 0.0, 1.0) - 1.0
		s = 0.5 + 0.5 * (1.0 + 2.70158 * x * x * x + 1.70158 * x * x) if game.state_t > Game.INTRO_CLOSE else 0.0
	else:
		s = c
	if s > 0.2:
		draw_set_transform(Vector2(640, 360), 0.0, Vector2(s, s))
		var head := "STAGE %d / %d   -   %s" % [game.stage + 1, Roster.count(), Scenery.NAMES[st.setting].to_upper()]
		Art.text(self, head, Vector2(0, -252), 22, Color(1, 1, 1, 0.85))
		var mood := 1.0 if fposmod(game.time, 3.0) < 1.5 else 0.0
		Art.goof(self, Vector2(0, -130), 62.0, st, Vector2(sin(game.time * 1.5) * 100.0, 40.0), mood, game.time)
		Art.text(self, str(st.name).to_upper(), Vector2(0, 50), 58, Art.GOLD if boss else Art.CREAM)
		Art.text(self, str(st.title), Vector2(0, 88), 24, Color(1, 1, 1, 0.8))
		Art.text(self, "SCORE  " + Art.fmt(st.target) + "  TO ADVANCE", Vector2(0, 156), 36, Art.GOLD)
		_controls_panel()
		if game.stage == 0:
			_top_runs_panel()
		if closing and game.state_t > Game.INTRO_CLOSE + 0.3:
			var blink := 0.55 + 0.45 * sin(game.time * 5.0)
			Art.text(self, "CLICK TO START", Vector2(0, 336), 30, Color(1, 1, 1, blink))
		_reset_tf()
	if not closing:
		_countdown()


## The best saved runs, on the left of the first intro card (mirrors the controls panel).
## Drawn inside the card's centred transform, so coordinates are relative to the screen centre.
func _top_runs_panel() -> void:
	var n := maxi(Runs.top.size(), 1)
	Art.vivid(self, Rect2(-620, -240, 290, 96 + n * 36), Color("0f4c9a"), Color("0b1f55"), game.time, 0.15, 20.0)
	Art.text(self, "TOP RUNS", Vector2(-475, -204), 24, Art.GOLD)
	if Runs.top.is_empty():
		Art.text(self, "no runs yet", Vector2(-475, -150), 18, Color(1, 1, 1, 0.7))
		return
	for i in Runs.top.size():
		var e: Dictionary = Runs.top[i]
		var y := -156.0 + i * 36.0
		var col: Color = Art.GOLD if i == 0 else Color(1, 1, 1, 0.95)
		Art.text(self, "%d." % (i + 1), Vector2(-600, y + 8), 20, col, HORIZONTAL_ALIGNMENT_LEFT)
		Art.text(self, Art.fmt(e.score), Vector2(-566, y + 8), 20, col, HORIZONTAL_ALIGNMENT_LEFT)
		Art.text(self, "WON" if e.won else "STAGE %d" % e.stage, Vector2(-350, y + 8), 16, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)


## Keybinds on the right of the intermission card, drawn with real-looking keycaps and a mouse.
## Drawn inside the card's centred transform, so coordinates are relative to the screen centre.
func _controls_panel() -> void:
	var t := game.time
	var has_ability: bool = game.paddle_def.ability != ""
	Art.vivid(self, Rect2(285, -240, 340, 352 if has_ability else 282), Color("0f4c9a"), Color("0b1f55"), t, 0.15, 20.0)
	Art.text(self, "CONTROLS", Vector2(455, -204), 24, Art.GOLD)
	var label_x := 448.0
	var rows := [-150.0, -80.0, -10.0, 60.0]
	var lab := Color(1, 1, 1, 0.95)
	# paddle follows the mouse, across the whole table
	_mouse(Vector2(360, rows[0]), 0, t)
	Art.text(self, "PADDLE", Vector2(label_x + 36, rows[0] + 8), 22, lab, HORIZONTAL_ALIGNMENT_LEFT)
	Art.text(self, "move mouse", Vector2(label_x + 36, rows[0] + 28), 14, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	# spin: swipe across the ball
	_mouse(Vector2(360, rows[1]), 1, t)
	Art.text(self, "SPIN", Vector2(label_x + 36, rows[1] + 8), 22, lab, HORIZONTAL_ALIGNMENT_LEFT)
	Art.text(self, "flick as you hit", Vector2(label_x + 36, rows[1] + 28), 14, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	# lunge: left click
	_mouse(Vector2(360, rows[2]), 2, t)
	Art.text(self, "LUNGE", Vector2(label_x + 36, rows[2] + 8), 22, lab, HORIZONTAL_ALIGNMENT_LEFT)
	Art.text(self, "left click", Vector2(label_x + 36, rows[2] + 28), 14, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	# the paddle's ability, if it has one
	if not has_ability:
		return
	_keycap(Vector2(360, rows[3]), Vector2(96, 42), "SPACE", maxf(0.0, sin(t * 3.0 + 1.5) * 2.0), 17)
	Art.text(self, Paddles.ABILITY_NAMES[game.paddle_def.ability], Vector2(label_x + 36, rows[3] + 8), 22, lab, HORIZONTAL_ALIGNMENT_LEFT)
	Art.text(self, "paddle ability", Vector2(label_x + 36, rows[3] + 28), 14, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)


## A chunky keycap: ink outline, cream top, darker side. `lit` (0..1) presses it down and makes it glow.
func _keycap(c: Vector2, size: Vector2, label: String, lit: float, font_size: int = 26) -> void:
	var depth := 8.0
	var press := clampf(lit, 0.0, 1.0)
	var top := Rect2(c - size * 0.5 + Vector2(0, press * (depth - 2.0)), size)
	var base := Rect2(c - size * 0.5 + Vector2(0, depth), size)
	if press > 0.0:
		draw_circle(c + Vector2(0, depth * 0.5), size.x * 0.7, Color(Art.GOLD, 0.25 * press))
	draw_colored_polygon(Art.rounded_pts(base.grow(3.0), 11.0), Art.INK)
	draw_colored_polygon(Art.rounded_pts(base, 8.0), Art.CREAM.darkened(0.45))
	draw_colored_polygon(Art.rounded_pts(top.grow(3.0), 11.0), Art.INK)
	var face := Art.CREAM.lerp(Art.GOLD, press * 0.8)
	draw_colored_polygon(Art.rounded_pts(top, 8.0), face)
	draw_colored_polygon(Art.rounded_pts(Rect2(top.position + Vector2(4, 4), top.size - Vector2(8, 12)), 6.0), face.lightened(0.35))
	var font := ThemeDB.fallback_font
	draw_string(font, top.position + Vector2(0, size.y * 0.5 + font_size * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Art.INK)


## A mouse seen from above. `kind` 0 = moves side to side, 1 = swipes, 2 = left button clicks.
func _mouse(c: Vector2, kind: int, t: float) -> void:
	var sway := sin(t * 3.0) * 10.0 if kind == 0 else 0.0
	var m := c + Vector2(sway, 0)
	if kind == 1:
		# a quick straight flick, cycling up / right / down / left, with afterimages and speed lines
		var dir: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][int(t) % 4]
		var u := clampf(fposmod(t, 1.0) / 0.3, 0.0, 1.0)
		var ease_out := 1.0 - (1.0 - u) * (1.0 - u)
		m = c + dir * (-14.0 + 28.0 * ease_out)
		if u < 1.0:
			for g in 3:
				var gp := m - dir * (g + 1) * 9.0 * u
				draw_colored_polygon(Art.rounded_pts(Rect2(gp - Vector2(19, 27), Vector2(38, 54)), 17.0), Color(1, 1, 1, 0.22 - g * 0.06))
			var side := Vector2(-dir.y, dir.x)
			for g: float in [-1.0, 0.0, 1.0]:
				var a: Vector2 = m - dir * 34.0 + side * g * 14.0
				draw_line(a, a - dir * 14.0, Color(Art.GOLD, 0.9), 3.0)
		else:
			var tip := c + dir * 40.0
			var fade := Color(Art.GOLD, clampf(1.0 - (fposmod(t, 1.0) - 0.3) * 2.0, 0.0, 1.0))
			draw_line(c + dir * 26.0, tip, fade, 4.0)
			var side2 := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([tip + dir * 8.0, tip + side2 * 6.0, tip - side2 * 6.0]), fade)
	var body := Rect2(m - Vector2(19, 27), Vector2(38, 54))
	var click := clampf(sin(t * 4.0) * 3.0, 0.0, 1.0) if kind == 2 else 0.0
	if kind == 2:
		draw_circle(m + Vector2(-9, -12), 30.0 * click, Color(Art.GOLD, 0.3 * click))
	var pts := Art.rounded_pts(body, 17.0)
	draw_colored_polygon(Art.rounded_pts(body.grow(3.0), 20.0), Art.INK)
	draw_colored_polygon(pts, Art.CREAM)
	var left_btn := Geometry2D.intersect_polygons(pts, PackedVector2Array([m + Vector2(-20, -28), m + Vector2(0, -28), m + Vector2(0, -3), m + Vector2(-20, -3)]))
	for piece in left_btn:
		if piece.size() >= 3:
			draw_colored_polygon(piece, Art.CREAM.lerp(Art.GOLD, click) if kind == 2 else Art.CREAM.darkened(0.08))
	draw_line(m + Vector2(-19, -3), m + Vector2(19, -3), Art.INK, 3.0)
	draw_line(m + Vector2(0, -27), m + Vector2(0, -3), Art.INK, 3.0)
	draw_rect(Rect2(m + Vector2(-2.5, -20), Vector2(5, 11)), Art.INK)
	if kind == 0:
		for s in [-1.0, 1.0]:
			var tip := c + Vector2(s * 40.0, 0)
			draw_line(c + Vector2(s * 28.0, 0), tip, Art.GOLD, 4.0)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(s * 8.0, 0), tip + Vector2(0, -6), tip + Vector2(0, 6)]), Art.GOLD)


func _countdown() -> void:
	var lt := game.intro_t - Game.COUNT_START
	if lt < 0.0:
		return
	var idx := mini(int(lt / Game.COUNT_BEAT), 3)
	var u := lt - idx * Game.COUNT_BEAT
	var labels := ["3", "2", "1", "GO!"]
	var cols := [Art.RED, Art.GOLD, Art.BLUE.lightened(0.2), Art.GREEN]
	var col: Color = cols[idx]
	var fade := clampf(1.0 - u / Game.COUNT_BEAT, 0.0, 1.0)
	draw_arc(Vector2(640, 330), 70.0 + u * 420.0, 0.0, TAU, 56, Color(col, 0.6 * fade), 10.0)
	draw_arc(Vector2(640, 330), 40.0 + u * 300.0, 0.0, TAU, 56, Color(1, 1, 1, 0.4 * fade), 5.0)
	var s := 1.0 + 1.3 * exp(-u * 10.0)
	var wob := sin(u * 30.0) * exp(-u * 5.0) * 0.1
	draw_set_transform(Vector2(640, 330), wob, Vector2(s, s))
	Art.text(self, labels[idx], Vector2(0, 62 if idx < 3 else 48), 190 if idx < 3 else 150, col)
	_reset_tf()


func _clear() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
	_pop(game.state_t)
	_card(Rect2(220, 150, 840, 420), Color("1c63c8"), Color("2a2a9a"), 0.5)
	Art.text(self, "STAGE CLEAR!", Vector2(640, 250), 84, Art.GOLD)
	Art.text(self, "SCORE  %s  /  %s" % [Art.fmt(game.score), Art.fmt(game.target)], Vector2(640, 320), 34, Art.CREAM)
	Art.text(self, "RUN TOTAL  " + Art.fmt(game.run_score), Vector2(640, 362), 22, Color(1, 1, 1, 0.9))
	var more := "" if game.state == Game.S.VICTORY else "   -   %s PLINKS" % Art.fmt(game.plinks)
	Art.text(self, "TO THE BALL SHOP" + more, Vector2(640, 470), 18, Art.GREEN.lightened(0.2))
	_blink_prompt("CLICK TO CONTINUE", 530)
	_reset_tf()


## The wallet, the ball in play and the one coming next.
func _balls() -> void:
	var pr := Rect2(986, 164, 274, 46)
	Art.vivid(self, pr, Color("12a36b"), Color("0b6a4c"), game.time, 0.0, 14.0)
	var cc := Vector2(1014, 187 + sin(game.time * 4.0) * 2.0)
	draw_circle(cc, 14.0, Art.INK)
	draw_circle(cc, 11.0, Art.GOLD)
	draw_arc(cc, 6.5, 0.0, TAU, 14, Art.GOLD.darkened(0.3), 2.0)
	draw_circle(cc + Vector2(-4, -4), 2.5, Color(1, 1, 1, 0.8))
	Art.text(self, "PLINKS", Vector2(1036, 195), 18, Art.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	Art.text(self, Art.fmt(game.plinks), Vector2(1244, 197), 28, Art.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	if game.state == Game.S.SHOP or game.state == Game.S.CLEAR or game.state == Game.S.VICTORY:
		return
	# The ball in play announces itself on the serve banner, so the corner only shows what comes next.
	var nxt := game.next_ball()
	var bc := Balls.color(nxt)
	Art.vivid(self, Rect2(24, 148, 190, 170), bc.darkened(0.5).lerp(Art.BLUE.darkened(0.5), 0.3), bc.darkened(0.15), game.time, 0.35 if nxt != Balls.PLAIN else 0.0)
	Art.text(self, "NEXT BALL", Vector2(119, 176), 16, Color(1, 1, 1, 0.9))
	var bob := sin(game.time * 3.0) * 4.0
	draw_circle(Vector2(119, 222), 44.0 + 3.0 * sin(game.time * 4.0), Color(1, 1, 1, 0.16))
	_ball_icon(Vector2(119, 222 + bob), 28.0, nxt)
	Art.text(self, Balls.title(nxt).to_upper(), Vector2(119, 280), 17, Balls.color(nxt).lightened(0.2))
	Art.text(self, "BAG  %d" % game.bag.size(), Vector2(119, 304), 14, Color(1, 1, 1, 0.5))


func _ball_icon(c: Vector2, r: float, id: String) -> void:
	draw_circle(c + Vector2(0, 3), r + 3.0, Color(0, 0, 0, 0.4))
	draw_circle(c, r + 3.0, Art.INK)
	draw_circle(c, r, Balls.color(id))
	if id != Balls.PLAIN:
		draw_circle(c + Vector2(r * 0.3, r * 0.2), r * 0.35, Balls.color(id).darkened(0.25))
	draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.8))


func _shop() -> void:
	Art.vivid(self, Rect2(-10, -10, 1300, 740), Color("0f2f7a"), Color("5a1f9a"), game.time, 0.1, 6.0)
	var bob := sin(game.time * 3.0) * 4.0
	draw_set_transform(Vector2(640, 86 + bob), sin(game.time * 2.0) * 0.015, Vector2.ONE)
	Art.text(self, "SHOP", Vector2.ZERO, 64, Art.GOLD)
	_reset_tf()
	Art.text(self, "PLINKS  " + Art.fmt(game.plinks), Vector2(640, 128), 28, Art.GREEN)
	var mouse := get_global_mouse_position()
	var tier_cols := [Art.CREAM, Art.GREEN, Art.BLUE, Art.GOLD]
	var tier_tops := [[Color("4a6ab0"), Color("26386e")], [Color("1a9a6a"), Color("0d5a45")], [Color("1a7ad0"), Color("15398a")], [Color("e08a20"), Color("a03a1a")]]
	for i in game.shop_offers.size():
		var r := Balls.card_rect(i)
		var id := game.shop_offers[i]
		if id == "":
			Art.vivid(self, r, Color("2a2f4a"), Color("161a2e"), game.time, 0.0)
			Art.text(self, "SOLD", r.get_center() + Vector2(0, 10), 36, Color(1, 1, 1, 0.35))
			continue
		var price := game.offer_price(id)
		var is_pad := Paddles.is_offer(id)
		var pid := Paddles.strip(id)
		var tier: int = Paddles.tier(pid) if is_pad else Balls.tier(id)
		var title: String = Paddles.title(pid) if is_pad else Balls.title(id)
		var desc: String = Paddles.DEFS[pid].desc if is_pad else Balls.DEFS[id].desc
		var tint: Color = Paddles.DEFS[pid].face if is_pad else Balls.color(id)
		var afford := game.plinks >= price
		var hover := r.has_point(mouse)
		if hover:
			r = r.grow(6)
		var tc: Array = tier_tops[tier]
		var top_c: Color = tc[0]
		var bot_c: Color = tc[1]
		if not afford:
			top_c = top_c.lerp(Color("3a3f55"), 0.55)
			bot_c = bot_c.lerp(Color("20243a"), 0.55)
		Art.vivid(self, r, top_c, bot_c, game.time + i * 0.7, 0.7 if hover and afford else (0.25 if afford else 0.0))
		draw_rect(Rect2(r.position + Vector2(18, 10), Vector2(r.size.x - 36, 6)), tier_cols[tier])
		draw_circle(Vector2(r.get_center().x, r.position.y + 62), 46.0 + 3.0 * sin(game.time * 3.0 + i), Color(1, 1, 1, 0.14))
		if is_pad:
			Art.paddle_disc(self, Vector2(r.get_center().x, r.position.y + 44 + sin(game.time * 3.0 + i) * 3.0), 25.0, sin(game.time * 2.0 + i) * 0.15, 1.0, Paddles.DEFS[pid])
			Art.text(self, "PADDLE", r.position + Vector2(22, 40), 15, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
		else:
			_ball_icon(Vector2(r.get_center().x, r.position.y + 62), 32.0, id)
		Art.text(self, title.to_upper(), Vector2(r.get_center().x, r.position.y + 134), 26 if title.length() < 14 else 22, tint.lightened(0.5))
		var lines: PackedStringArray = desc.split("\n")
		for k in lines.size():
			Art.text(self, lines[k], Vector2(r.get_center().x, r.position.y + 166 + k * 22), 17, Color(1, 1, 1, 0.8))
		Art.text(self, "%s PLINKS" % Art.fmt(price), Vector2(r.get_center().x, r.end.y - 22), 24, Art.GOLD.lightened(0.25) if afford else Art.RED.lightened(0.2))
	_shop_button(0, "REMOVE A PLAIN BALL", Balls.remove_cost(game.shop_ref), mouse)
	_shop_button(1, "REROLL", Balls.reroll_cost(game.shop_ref, game.shop_rerolls), mouse)
	_shop_button(2, "NEXT STAGE", -1, mouse)
	Art.text(self, game.shop_msg, Vector2(640, 580), 22, Art.CREAM)
	Art.text(self, "YOUR BAG   %d / %d" % [game.bag.size(), Balls.MAX_BAG], Vector2(640, 626), 18, Color(1, 1, 1, 0.9))
	var counts := {}
	for id in game.bag:
		counts[id] = int(counts.get(id, 0)) + 1
	var parts: PackedStringArray = []
	for id in counts:
		parts.append("%d x %s" % [counts[id], Balls.title(id)])
	Art.text(self, "   ".join(parts), Vector2(640, 654), 16, Color(1, 1, 1, 0.8))


func _shop_button(i: int, label: String, cost: int, mouse: Vector2) -> void:
	var r := Balls.button_rect(i)
	var hover := r.has_point(mouse)
	var go := cost < 0
	var col := Art.CREAM if go else (Art.CREAM if game.plinks >= cost else Art.RED)
	var top := Color("1ab87a") if go else Color("7a3be0")
	var bot := Color("0d7a52") if go else Color("3a1a8a")
	if not go and game.plinks < cost:
		top = top.lerp(Color("3a3f55"), 0.55)
		bot = bot.lerp(Color("20243a"), 0.55)
	Art.vivid(self, r.grow(4.0 if hover else 0.0), top, bot, game.time + i, 0.6 if hover else (0.3 if go else 0.0), 16.0)
	Art.text(self, label, r.get_center() + Vector2(0, -2 if go else -8), 22, col)
	if not go:
		Art.text(self, "%s PLINKS" % Art.fmt(cost), r.get_center() + Vector2(0, 20), 16, col)


func _victory() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
	_pop(game.state_t)
	_card(Rect2(220, 140, 840, 400), Color("6a2bd0"), Color("d0267a"), 0.8)
	var bob := sin(game.time * 4.0) * 6.0
	Art.text(self, "YOU WIN!", Vector2(640, 260 + bob), 110, Art.GOLD)
	Art.text(self, "You beat all %d opponents" % Roster.count(), Vector2(640, 330), 30, Art.CREAM)
	Art.text(self, "TOTAL SCORE  " + Art.fmt(game.run_score), Vector2(640, 380), 34, Art.GREEN)
	_blink_prompt("CLICK TO PLAY AGAIN", 470)
	_reset_tf()


func _game_over() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.62))
	var st: Dictionary = Roster.STAGES[game.stage]
	_pop(game.state_t)
	_card(Rect2(240, 170, 800, 370), Color("3a1050"), Color("8a1030"), 0.2)
	Art.text(self, "GAME OVER", Vector2(640, 270), 84, Art.RED)
	Art.text(self, "Stopped by %s at stage %d / %d" % [st.name, game.stage + 1, Roster.count()], Vector2(640, 326), 24, Color(1, 1, 1, 0.85))
	Art.text(self, "SCORE  %s  /  %s" % [Art.fmt(game.score), Art.fmt(game.target)], Vector2(640, 378), 34, Art.GOLD)
	Art.text(self, "BEST RUN  " + Art.fmt(game.best), Vector2(640, 416), 22, Color(1, 1, 1, 0.8))
	_blink_prompt("CLICK TO START A NEW RUN", 486)
	_reset_tf()


# ---------------------------------------------------------------- bonus rounds

## The offer after a boss: play a bonus round for a life and Heat, or skip it for a smaller Heat bonus.
func _bonus_offer() -> void:
	Art.vivid(self, Rect2(-10, -10, 1300, 740), Color("3a0f7a"), Color("0f5a8a"), game.time, 0.2, 6.0)
	var t := game.time
	draw_set_transform(Vector2(640, 104 + sin(t * 3.0) * 4.0), sin(t * 2.0) * 0.02, Vector2.ONE)
	Art.text(self, "BONUS ROUND!", Vector2.ZERO, 76, Art.GOLD)
	_reset_tf()
	Art.text(self, Bonus.TITLES[game.bonus_kind].to_upper(), Vector2(640, 178), 48, Art.CREAM)
	var blurb: Array = Bonus.BLURBS[game.bonus_kind]
	for i in blurb.size():
		Art.text(self, blurb[i], Vector2(640, 224 + i * 30), 22, Color(1, 1, 1, 0.85))
	if game.bonus_kind == Bonus.Kind.MULTIBALL:
		for i in 5:
			var c := Vector2(440 + i * 100, 360 + sin(t * 4.0 + i * 1.3) * 22.0)
			draw_circle(c, 40.0, Color(Bonus.BALL_COLS[i], 0.2))
			_ball_dot(c, 22.0, Bonus.BALL_COLS[i])
	else:
		for r in 3:
			for c in 8:
				var br := {"kind": Bonus.Brick.NORMAL, "r": r}
				if r == 1 and c % 3 == 1:
					br.kind = Bonus.Brick.TOUGH
				if r == 1 and c == 5:
					br.kind = Bonus.Brick.BOMB
				var rect := Rect2(364 + c * 68, 316 + (2 - r) * 36, 62, 30)
				draw_rect(rect.grow(3.0), Art.INK)
				draw_rect(rect, Bonus.brick_color(br))
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), Color(1, 1, 1, 0.3))
	var mouse := get_global_mouse_position()
	_bonus_button(0, "PLAY IT", "WIN: +1 LIFE   +%s BASE HEAT" % String.num(Game.BONUS_WIN_HEAT, 2), Color("1ab87a"), Color("0d7a52"), mouse)
	_bonus_button(1, "SKIP", "+%s BASE HEAT, GUARANTEED" % String.num(Game.BONUS_SKIP_HEAT, 2), Color("7a3be0"), Color("3a1a8a"), mouse)
	Art.text(self, "Drop three balls and you get nothing.", Vector2(640, 634), 18, Color(1, 1, 1, 0.7))
	Art.text(self, "LIVES  %d / %d      BASE HEAT  %.2f" % [game.lives, Game.MAX_LIVES, game.base_heat()], Vector2(640, 676), 22, Art.CREAM)


func _bonus_button(i: int, label: String, sub: String, top: Color, bot: Color, mouse: Vector2) -> void:
	var r := Game.bonus_button(i)
	var hover := r.has_point(mouse)
	Art.vivid(self, r.grow(4.0 if hover else 0.0), top, bot, game.time + i, 0.6 if hover else 0.25, 16.0)
	Art.text(self, label, r.get_center() + Vector2(0, -6), 32, Art.CREAM)
	Art.text(self, sub, r.get_center() + Vector2(0, 24), 16, Color(1, 1, 1, 0.9))


func _ball_dot(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(0, 3), r + 3.0, Color(0, 0, 0, 0.4))
	draw_circle(c, r + 3.0, Art.INK)
	draw_circle(c, r, col)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.8))


## Tries, progress and the intro banner while a bonus round runs, and its result card afterwards.
func _bonus_screen() -> void:
	var bo := game.bonus
	_lives("BALLS", bo.tries)
	var multi := bo.kind == Bonus.Kind.MULTIBALL
	var frac := float(bo.hits) / float(bo.goal) if multi else 1.0 - float(bo.bricks_left()) / float(bo.bricks.size())
	var r := Rect2(440, 10, 400, 92)
	Art.vivid(self, r, Color("0b5fb8"), Color("1a2f8f"), game.time, 0.2, 16.0)
	Art.text(self, "BONUS  -  " + Bonus.TITLES[bo.kind].to_upper(), Vector2(640, 34), 16, Art.CREAM)
	var big := "RETURNS  %d / %d" % [bo.hits, bo.goal] if multi else "BRICKS LEFT  %d" % bo.bricks_left()
	Art.text(self, big, Vector2(640, 68), 30, Art.GOLD.lightened(0.2))
	draw_rect(Rect2(462, 78, 356, 16), Art.INK)
	draw_rect(Rect2(465, 81, 350.0 * clampf(frac, 0.0, 1.0), 10), Art.GREEN.lightened(0.2))
	_ability_meter()
	if game.state == Game.S.BONUS and bo.t < Bonus.INTRO:
		var a := clampf((Bonus.INTRO - bo.t) / 0.4, 0.0, 1.0)
		var s := 1.0 + 0.5 * exp(-bo.t * 9.0)
		draw_set_transform(Vector2(640, 300), 0.0, Vector2(s, s))
		Art.text(self, Bonus.TITLES[bo.kind].to_upper(), Vector2.ZERO, 70, Color(Art.GOLD, a))
		var blurb: Array = Bonus.BLURBS[bo.kind]
		for i in blurb.size():
			Art.text(self, blurb[i], Vector2(0, 46 + i * 30), 24, Color(1, 1, 1, 0.9 * a))
		_reset_tf()
	if game.state == Game.S.BONUS_END:
		_bonus_end_card()


func _bonus_end_card() -> void:
	var won := game.bonus_won
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
	_pop(game.state_t)
	if won:
		_card(Rect2(220, 150, 840, 420), Color("1c63c8"), Color("2a2a9a"), 0.6)
		Art.text(self, "BONUS CLEARED!", Vector2(640, 250), 80, Art.GOLD)
		Art.text(self, "+%d LIFE      LIVES  %d / %d" % [Game.BONUS_WIN_LIVES, game.lives, Game.MAX_LIVES], Vector2(640, 330), 30, Art.GREEN.lightened(0.2))
		Art.text(self, "+%s BASE HEAT      NOW  %.2f" % [String.num(Game.BONUS_WIN_HEAT, 2), game.base_heat()], Vector2(640, 380), 30, Art.RED.lightened(0.3))
	else:
		_card(Rect2(220, 150, 840, 420), Color("3a1050"), Color("8a1030"), 0.2)
		Art.text(self, "BONUS FAILED", Vector2(640, 250), 80, Art.RED)
		Art.text(self, "No reward this time.", Vector2(640, 330), 30, Color(1, 1, 1, 0.85))
	_blink_prompt("CLICK TO CONTINUE", 520)
	_reset_tf()
