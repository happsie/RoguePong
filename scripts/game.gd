class_name Game
extends Node2D
## Match state machine, input, rules, opponent AI and scoring. Rendering lives in the view nodes.
##
## The paddle lives on a vertical plane at the player's end of the table: the mouse moves it
## left/right and up/down, a click lunges it forward over the table. The opponent has the same
## plane at the far end.

enum S { READY, RALLY, POINT_OVER, GAME_OVER, INTRO, CLEAR, VICTORY, SHOP, BONUS_OFFER, BONUS, BONUS_END }
enum Who { PLAYER, OPP }

const PADDLE_Z := -14.0
const OPP_Z := Phys.LENGTH + 14.0
const PADDLE_R := 12.0
const LUNGE_TIME := 0.14
const LUNGE_REACH := 55.0
const START_LIVES := 3
const MAX_LIVES := 5
# Bonus rounds (see Bonus): skipping one is worth a little permanent Heat; winning one is worth more,
# plus a life. Lives carry over from stage to stage (up to MAX_LIVES).
const BONUS_SKIP_HEAT := 0.25
const BONUS_WIN_HEAT := 0.5
const BONUS_WIN_LIVES := 1
const OPP_REST := Vector2(0.0, 30.0)
## Shows where the incoming ball will cross your paddle plane. Flip off to make reading depth part of the skill.
const INTERCEPT_HINT := true
## Hit correction: a mouse within ASSIST_CAPTURE of the ball's path over the last ASSIST_DIST cm gets
## a hit forgiven and the paddle nudged ASSIST_PULL of the way onto the ball (see `_assist`).
const ASSIST_CAPTURE := 27.0
const ASSIST_PULL := 0.35
const ASSIST_DIST := 90.0
# How far along the table the mouse can take the paddle (a paddle scales this with its `reach`).
# The screen only shows about 115 cm either side at the paddle's depth, so there is no point reaching further.
const BASE_RANGE := 100.0
## The farthest from the middle the opponent will send a ball across your paddle plane, so it is always reachable.
const OPP_REACH := 95.0
## Launch angle (degrees) a paddle that can't smash never goes below.
const NO_SMASH_ANGLE := 14.0
const SMASH_FALLOFF := 0.6
const SMASH_FLOOR := 0.5
const BANK_SWIPE := 450.0 # sideways paddle speed that banks a Pinball shot off the wall
# Settings overlay (Esc): volume sliders and resume / quit buttons.
const SET_PANEL := Rect2(400, 190, 480, 362)
const SET_BUSES := ["Music", "SFX"]

var state: int = S.READY
var settings_open := false
var settings_drag := -1
var settings_mouse_mode := Input.MOUSE_MODE_VISIBLE
var state_t := 0.0
var time := 0.0
var acc := 0.0

var ball := Phys.Ball.new()
var ball_angle := 0.0
var trail: Array[Vector3] = []
var last_hitter: int = Who.OPP
var bounces := 0
var hit_cd := 0.0
var opp_hit_cd := 0.0
var intercept := Vector3.ZERO

var paddle_id: String = Paddles.CLASSIC
var paddle_def: Dictionary = Paddles.DEFS[Paddles.CLASSIC]
var paddle_r := PADDLE_R
var paddle_xy := Vector2(0.0, 30.0)
var intent_xy := Vector2(0.0, 30.0)
var intent := Vector3(0.0, 30.0, PADDLE_Z)
## The paddle's ability (Space): `ability_t` counts down while it is active, `ability_cd` until it is ready again.
var ability_t := 0.0
var ability_cd := 0.0
var net_flash := 0.0
var net_hit_since_hit := false
var net_test := false
var shot_at := 7.0
var hit_assist := true
var assist_lock := false
var prev_rel_z := 0.0
var bot_err := 0.0
var paddle := Vector3(0.0, 30.0, PADDLE_Z)
var paddle_vel := Vector3.ZERO
var paddle_wobble := 0.0
var lunge_t := 0.0
var lunge_cd := 0.0

var opp := OPP_REST
var opp_target := OPP_REST
var opp_react := 0.0
var opp_swing := 0.0
var opp_mood := 0.0
var player_mood := 0.0

var power := 0.0
var heat := 1.0
var returns := 0
## Smashes landed in the current rally; each one pays less Heat than the last (see SMASH_FALLOFF).
var smashes := 0
var score := 0
var best := 0
var lives := START_LIVES
var disp_power := 0.0
var disp_heat := 1.0
var heat_pulse := 0.0
var power_pulse := 0.0
var panel_kick := 0.0  # shakes the Power x Heat panel; bigger when points are big
var _prev_power := 0.0
var _prev_heat := 1.0
var banner := ""
var banner_sub := ""
var banner_col := Color.WHITE
var banner_t := 0.0
# Win / lose feedback (drawn by the views): a counting banner, coins flying to the score, a flash,
# the shattering Power x Heat panel and the opponent's speech bubble.
var banner_count := -1
var win_word := ""
var win_col := Color.WHITE
var score_shown := 0.0
var score_pulse := 0.0
var flash := 0.0
var flash_col := Color.WHITE
var shatter_t := 99.0
# Stage intermission: the two halves of the screen slam together along a lightning tear and show the
# opponent card (phase 0); a click tears them apart again and a 3-2-1-GO countdown runs (phase 1).
const INTRO_CLOSE := 0.8
const COUNT_START := 0.35
const COUNT_BEAT := 0.8
const COUNT_TOTAL := 3.5
var intro_phase := 0
var intro_t := 0.0
var fliers: Array[Dictionary] = []
var shards: Array[Dictionary] = []
var taunt := ""
var taunt_t := 99.0
var taunt_dur := 2.6
var taunt_mean := true

var popups: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var popup_slot := 0
var freeze := 0.0
var shake := 0.0

var world_view: Node2D
var hud_view: Node2D
var bot := false
var shot_path := ""
var setting := 0
var bg_rect: ColorRect
var show_state := ""

# The run: Roster.STAGES in order. Clear a stage by reaching its target score before losing all lives.
var stage := 0
var target := 0
var run_score := 0
# Magic balls (see Balls): a bag you own, a shuffled draw pile, and the ball in play this rally.
# Plinks are the wallet: every point you bank also pays out as Plinks, which you spend in the shop.
# Plinks come from banked points but are throttled: PLINK_RATE of each rally, and at most PLINK_CAP
# times the stage target per stage. Shop prices are shares of that target too, so a huge score can't
# buy out the shop.
const PLINK_RATE := 0.3
const PLINK_CAP := 1.2
var plinks := 0
var stage_plinks := 0
var bag: Array[String] = []
var draw_pile: Array[String] = []
var cur := Balls.PLAIN
var fire_lit := false
var assist_mul := 1.0
## Dev: `--ball=<id>` fills the bag with one kind of ball, to test it.
var test_ball := ""
## Dev: `--paddle=<id>` starts the run holding that paddle.
var test_paddle := ""
var shop_offers: Array[String] = []
var shop_ref := 100
var shop_rerolls := 0
var shop_msg := ""
## How long the ball hovers before each serve; re-rolled every time so the serve can't be timed.
var serve_wait := 1.1
# Bonus rounds: which one is on offer, the live round, and what the run has earned from them.
var bonus: Bonus
var bonus_kind := 0
var bonus_level := 0
var bonus_won := false
## Extra Heat every rally starts with, earned from bonus rounds. Lasts the whole run.
var bonus_heat := 0.0
# Opponent difficulty for the current stage (see _apply_stage).
var opp_react_time := 0.15
var opp_speed := Vector2(430.0, 360.0)
var opp_miss_base := 0.05
var opp_miss_per_return := 0.014
var opp_wide_chance := 0.2


func _ready() -> void:
	randomize()
	Runs.load_runs()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage = clampi(int(a.substr(8)) - 1, 0, Roster.count() - 1)
		elif a.begins_with("--show="):
			show_state = a.substr(7)
		elif a == "--bot":
			bot = true
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a == "--nettest":
			net_test = true
		elif a.begins_with("--shot-at="):
			shot_at = float(a.substr(10))
		elif a.begins_with("--paddle="):
			test_paddle = a.substr(9)
		elif a.begins_with("--ball="):
			test_ball = a.substr(7)
		elif a == "--noassist":
			hit_assist = false
		elif a.begins_with("--sloppy="):
			bot_err = float(a.substr(9))

	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swirl := ShaderMaterial.new()
	swirl.shader = load("res://shaders/swirl.gdshader")
	bg.material = swirl
	add_child(bg)
	bg_rect = bg

	world_view = load("res://scripts/world_view.gd").new()
	world_view.game = self
	add_child(world_view)
	hud_view = load("res://scripts/hud_view.gd").new()
	hud_view.game = self
	add_child(hud_view)

	var layer := CanvasLayer.new()
	layer.layer = 100
	var crt := ColorRect.new()
	crt.size = Vector2(1280, 720)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crt_mat := ShaderMaterial.new()
	crt_mat.shader = load("res://shaders/crt.gdshader")
	crt.material = crt_mat
	layer.add_child(crt)
	add_child(layer)

	equip_paddle(test_paddle if Paddles.DEFS.has(test_paddle) else Paddles.CLASSIC)
	_reset_bag()
	_begin_stage()
	match show_state:
		"clear":
			score = target + 120
			_stage_clear()
		"win":
			power = 180.0
			heat = 4.5
			returns = 6
			_end_point(Who.PLAYER, "")
		"lose":
			power = 90.0
			heat = 2.0
			returns = 3
			_end_point(Who.OPP, "MISSED")
		"shop":
			score = target + 120
			plinks = 400
			bag.append_array(["fireball", "gambler", "disco"])
			_stage_clear()
			_open_shop()
		"victory":
			stage = Roster.count() - 1
			score = target + 120
			_stage_clear()
		"settings":
			_toggle_settings()
		"offer1", "offer2", "offer3", "offer4":
			stage = 2 * int(show_state.substr(5)) - 1
			_open_bonus_offer()
		"bonus1", "bonus2", "bonus3", "bonus4":
			stage = 2 * int(show_state.substr(5)) - 1
			_open_bonus_offer()
			_start_bonus()
		"over":
			lives = 0
			state = S.GAME_OVER
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func slider_rect(i: int) -> Rect2:
	return Rect2(440, 308 + i * 84, 400, 18)


static func set_button(i: int) -> Rect2:
	return Rect2(440 + i * 210, 456, 190, 52)


func _toggle_settings() -> void:
	settings_open = not settings_open
	settings_drag = -1
	if settings_open:
		settings_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = settings_mouse_mode
		Audio.save_settings()


func _settings_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		if event.pressed:
			for i in SET_BUSES.size():
				if slider_rect(i).grow(12.0).has_point(pos):
					settings_drag = i
					_drag_slider(pos)
			if set_button(0).has_point(pos):
				_toggle_settings()
			elif set_button(1).has_point(pos):
				get_tree().quit()
		else:
			if settings_drag == 1:
				Audio.play("hit")
			settings_drag = -1
	elif event is InputEventMouseMotion and settings_drag >= 0:
		_drag_slider(get_global_mouse_position())


func _drag_slider(pos: Vector2) -> void:
	var r := slider_rect(settings_drag)
	Audio.set_volume(SET_BUSES[settings_drag], snappedf((pos.x - r.position.x) / r.size.x, 0.01))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_settings()
		return
	if settings_open:
		_settings_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed)):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match state:
			S.INTRO:
				if state_t > INTRO_CLOSE + 0.3 and intro_phase == 0:
					intro_phase = 1
					intro_t = 0.0
					Audio.play("swoosh", 0.8)
			S.CLEAR:
				if state_t > 0.8:
					_open_shop()
			S.SHOP:
				if state_t > 0.3:
					_shop_click(get_global_mouse_position())
			S.BONUS_OFFER:
				if state_t > 0.3:
					_bonus_offer_click(get_global_mouse_position())
			S.BONUS_END:
				if state_t > 0.8:
					_next_stage()
			S.GAME_OVER, S.VICTORY:
				if state_t > 0.8:
					_restart()
			_:
				if lunge_cd <= 0.0:
					_lunge()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_ability()


func _lunge() -> void:
	lunge_t = LUNGE_TIME
	lunge_cd = 0.4
	Audio.play("swoosh")


## The paddle's ability, on Space (not every paddle has one): Focus slows time, Grab boosts the hit assist.
func _ability() -> void:
	if paddle_def.ability == "" or ability_cd > 0.0 or not (state == S.READY or state == S.RALLY or state == S.POINT_OVER):
		return
	ability_t = paddle_def.dur
	ability_cd = paddle_def.cd
	shake = maxf(shake, 3.0)
	Audio.play("dash")
	_burst(Cam.project(paddle), Art.CREAM, 10, 260.0)


func _ability_on(kind: String) -> bool:
	return ability_t > 0.0 and paddle_def.ability == kind


## How far along the table the mouse can take the paddle.
func base_range() -> float:
	return BASE_RANGE * float(paddle_def.reach)


func equip_paddle(id: String) -> void:
	paddle_id = id
	paddle_def = Paddles.DEFS[id]
	paddle_r = PADDLE_R * float(paddle_def.size)
	ability_t = 0.0
	ability_cd = 0.0


func _restart() -> void:
	stage = 0
	equip_paddle(test_paddle if Paddles.DEFS.has(test_paddle) else Paddles.CLASSIC)
	run_score = 0
	bonus_heat = 0.0
	lives = START_LIVES
	_reset_bag()
	_begin_stage()


## Sets up a stage: its map, target and opponent difficulty, then waits on the intro card.
func _begin_stage() -> void:
	var st: Dictionary = Roster.STAGES[stage]
	var d: float = st.diff
	setting = st.setting
	target = st.target
	score = 0
	score_shown = 0.0
	stage_plinks = 0
	Audio.play_music(Audio.STAGE_TRACKS[setting % Audio.STAGE_TRACKS.size()])
	fliers.clear()
	shards.clear()
	taunt_t = 99.0
	shatter_t = 99.0
	opp_react_time = lerpf(0.24, 0.10, d)
	opp_speed = Vector2(lerpf(330.0, 560.0, d), lerpf(280.0, 470.0, d))
	opp_miss_base = lerpf(0.13, 0.03, d)
	opp_miss_per_return = lerpf(0.02, 0.008, d)
	opp_wide_chance = lerpf(0.06, 0.34, d)
	opp = OPP_REST
	_shuffle_pile()
	if bot:
		print("stage %d: %s (target %d), run total %d" % [stage + 1, st.name, target, run_score])
	_start_serve()
	state = S.INTRO
	intro_phase = 0
	intro_t = 0.0
	Audio.play("swoosh", 0.7)
	banner = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _next_stage() -> void:
	stage += 1
	_begin_stage()


## Heat every rally starts from: 1, plus whatever the bonus rounds have added.
func base_heat() -> float:
	return 1.0 + bonus_heat


# ---------------------------------------------------------------------------------------------
# Bonus rounds
# ---------------------------------------------------------------------------------------------

static func bonus_button(i: int) -> Rect2:
	return Rect2(210 + i * 450, 520, 400, 78)


## After a boss the shop leads to a bonus offer instead of straight to the next stage.
func _leave_shop() -> void:
	if Roster.STAGES[stage].get("boss", false) and stage < Roster.count() - 1:
		_open_bonus_offer()
	else:
		_next_stage()


func _open_bonus_offer() -> void:
	var round_no := floori((stage - 1) / 2.0)
	bonus_kind = round_no % 2
	bonus_level = clampi(round_no, 0, 3)
	state = S.BONUS_OFFER
	state_t = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _bonus_offer_click(pos: Vector2) -> void:
	if bonus_button(0).has_point(pos):
		Audio.play("click")
		_start_bonus()
	elif bonus_button(1).has_point(pos):
		_skip_bonus()


func _skip_bonus() -> void:
	bonus_heat += BONUS_SKIP_HEAT
	Audio.play("buy")
	_burst(bonus_button(1).get_center(), Art.RED, 30, 420.0)
	_next_stage()


func _start_bonus() -> void:
	bonus = Bonus.new(self, bonus_kind, bonus_level)
	state = S.BONUS
	state_t = 0.0
	flash = 0.0
	Audio.play_music("rally")
	Audio.play("swoosh", 0.8)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## Called by Bonus when the round is decided; pays the reward on a win.
func _bonus_end(won: bool) -> void:
	bonus_won = won
	if bot:
		print("bonus %s lvl %d: %s  hits=%d tries=%d bricks_left=%d t=%.1fs" % [Bonus.TITLES[bonus_kind], bonus_level, "WON" if won else "lost", bonus.hits, bonus.tries, bonus.bricks_left(), bonus.t])
	state = S.BONUS_END
	state_t = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if won:
		bonus_heat += BONUS_WIN_HEAT
		lives = mini(lives + BONUS_WIN_LIVES, MAX_LIVES)
		Audio.play("clear")
		_burst(Vector2(640, 300), Art.GOLD, 60, 560.0)
		_burst(Vector2(640, 300), Art.RED, 40, 460.0)
		_burst(Vector2(640, 300), Art.BLUE, 40, 460.0)
	else:
		Audio.play("game_over", 1.0, 0.0)


# ---------------------------------------------------------------------------------------------
# Magic balls and the shop
# ---------------------------------------------------------------------------------------------

func _reset_bag() -> void:
	plinks = 0
	bag.clear()
	for i in Balls.START_BAG:
		bag.append(test_ball if Balls.DEFS.has(test_ball) else Balls.PLAIN)
	_shuffle_pile()


func _shuffle_pile() -> void:
	draw_pile = bag.duplicate()
	draw_pile.shuffle()


## Draws the ball for the coming rally. The pile is topped up as soon as it empties, so `next_ball`
## can always show what comes after this one.
func _draw_ball() -> void:
	if draw_pile.is_empty():
		_shuffle_pile()
	cur = draw_pile.pop_back()
	if draw_pile.is_empty():
		_shuffle_pile()
	fire_lit = false
	_apply_ball_physics()


## The physics balls bend the world for one rally. Phys is shared with the shot solver and the
## opponent AI, so they all play by the same rules.
func _apply_ball_physics() -> void:
	Phys.reset_tweaks()
	assist_mul = 1.0
	match cur:
		"feather":
			Phys.gravity = Phys.G * 0.4
		"meteor":
			Phys.gravity = Phys.G * 1.8
		"dervish":
			Phys.magnus = Phys.MAGNUS * 2.5
		"yoyo":
			Phys.table_grip = 0.8
		"bouncy":
			Phys.restitution = 1.0
		"ghost":
			Phys.ghost_net = true
		"magnet":
			assist_mul = 1.6
		"pinball":
			Phys.walls = true
		"corkscrew":
			Phys.kick = 1.6


## Time Warp: the simulation runs slower for balls coming at you and faster for your returns.
## The path is unchanged, only how fast it is travelled, so the solver stays exact.
func _ball_time() -> float:
	var focus := 0.45 if _ability_on("focus") else 1.0
	if cur == "timewarp":
		return focus * (0.75 if last_hitter == Who.OPP else 1.3)
	return focus


func next_ball() -> String:
	return draw_pile.back() if not draw_pile.is_empty() else Balls.PLAIN


func _open_shop() -> void:
	shop_ref = maxi(100, target)
	shop_rerolls = 0
	_roll_shop()
	shop_msg = ""
	state = S.SHOP
	state_t = 0.0
	Audio.play_music("shop")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _shop_click(pos: Vector2) -> void:
	for i in shop_offers.size():
		if shop_offers[i] != "" and Balls.card_rect(i).has_point(pos):
			_buy(i)
			return
	if Balls.button_rect(0).has_point(pos):
		var cost := Balls.remove_cost(shop_ref)
		if not bag.has(Balls.PLAIN) or bag.size() <= 1:
			shop_msg = "NO PLAIN BALLS LEFT TO REMOVE"
			Audio.play("deny")
		elif plinks < cost:
			shop_msg = "NOT ENOUGH PLINKS"
			Audio.play("deny")
		else:
			plinks -= cost
			bag.erase(Balls.PLAIN)
			shop_msg = "REMOVED A PLAIN BALL"
			Audio.play("remove")
			_burst(Balls.button_rect(0).get_center(), Art.CREAM, 14, 240.0)
	elif Balls.button_rect(1).has_point(pos):
		var cost := Balls.reroll_cost(shop_ref, shop_rerolls)
		if plinks < cost:
			shop_msg = "NOT ENOUGH PLINKS"
			Audio.play("deny")
		else:
			plinks -= cost
			shop_rerolls += 1
			_roll_shop()
			shop_msg = ""
			Audio.play("reroll")
	elif Balls.button_rect(2).has_point(pos):
		Audio.play("click")
		_leave_shop()


## Price of a shop offer, ball or paddle.
func offer_price(id: String) -> int:
	if Paddles.is_offer(id):
		return Paddles.price(Paddles.strip(id), shop_ref)
	return Balls.price(id, shop_ref)


## Three offers: balls, with the last slot often a paddle (always after the first stage, so you meet them early).
func _roll_shop() -> void:
	shop_offers = Balls.roll_offers(3)
	var p := Paddles.roll_offer(paddle_id)
	if p != "" and randf() < (1.0 if stage == 0 else 0.5):
		shop_offers[2] = Paddles.offer_id(p)


func _buy(i: int) -> void:
	var id := shop_offers[i]
	if Paddles.is_offer(id):
		_buy_paddle(i)
		return
	var cost := Balls.price(id, shop_ref)
	if bag.size() >= Balls.MAX_BAG:
		shop_msg = "YOUR BAG IS FULL"
		Audio.play("deny")
	elif plinks < cost:
		shop_msg = "NOT ENOUGH PLINKS"
		Audio.play("deny")
	else:
		Audio.play("buy")
		plinks -= cost
		bag.append(id)
		shop_offers[i] = ""
		shop_msg = "ADDED %s TO YOUR BAG" % Balls.title(id).to_upper()
		_burst(Balls.card_rect(i).get_center(), Balls.color(id), 30, 420.0)


## A new paddle replaces the one you hold.
func _buy_paddle(i: int) -> void:
	var id := Paddles.strip(shop_offers[i])
	var cost := Paddles.price(id, shop_ref)
	if plinks < cost:
		shop_msg = "NOT ENOUGH PLINKS"
		Audio.play("deny")
		return
	Audio.play("buy")
	plinks -= cost
	equip_paddle(id)
	shop_offers[i] = ""
	shop_msg = "NOW HOLDING THE %s" % Paddles.title(id).to_upper()
	_burst(Balls.card_rect(i).get_center(), Paddles.DEFS[id].face, 30, 420.0)


func _stage_clear() -> void:
	run_score += score
	best = maxi(best, run_score)
	if stage >= Roster.count() - 1:
		Runs.record(run_score, stage + 1, true)
	state = S.VICTORY if stage >= Roster.count() - 1 else S.CLEAR
	state_t = 0.0
	banner = ""
	Audio.play("clear")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_burst(Vector2(640, 300), Art.GOLD, 60, 560.0)
	_burst(Vector2(640, 300), Art.RED, 40, 460.0)
	_burst(Vector2(640, 300), Art.BLUE, 40, 460.0)


# ---------------------------------------------------------------------------------------------
# Frame loop
# ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if settings_open:
		hud_view.queue_redraw()
		if shot_path != "":
			time += delta
			if time > shot_at:
				get_viewport().get_texture().get_image().save_png(shot_path)
				get_tree().quit()
		return
	delta = minf(delta, 0.05)
	time += delta
	_update_paddle(delta)
	_update_fx(delta)
	if freeze > 0.0:
		freeze -= delta
	else:
		match state:
			S.READY:
				state_t += delta
				ball.p.y = 32.0 + sin(time * 6.0) * 1.5
				if state_t > serve_wait:
					_launch_serve()
			S.RALLY:
				acc += delta * _ball_time()
				while acc >= Phys.DT and state == S.RALLY:
					acc -= Phys.DT
					_sim()
			S.POINT_OVER:
				state_t += delta
				acc += delta
				while acc >= Phys.DT:
					acc -= Phys.DT
					Phys.step(ball, Phys.DT)
					ball_angle += ball.w.x * Phys.DT
				if state_t > 1.7:
					_after_point()
			S.GAME_OVER:
				state_t += delta
				if bot and state_t > 1.0:
					_restart()
			S.INTRO:
				state_t += delta
				if intro_phase == 0 and state_t - delta < INTRO_CLOSE and state_t >= INTRO_CLOSE:
					Audio.play("point_big", 0.9, 0.0)
					shake = 10.0
					flash = 0.6
					flash_col = Color.WHITE
				if intro_phase == 1:
					var before := intro_t
					intro_t += delta
					var beat := floori((intro_t - COUNT_START) / COUNT_BEAT)
					if intro_t >= COUNT_START and beat != floori((before - COUNT_START) / COUNT_BEAT):
						Audio.play("serve" if beat >= 3 else "click", 1.0 + 0.15 * beat, 0.0)
					if intro_t >= COUNT_TOTAL:
						_start_serve()
				if bot and state_t > 1.0:
					_start_serve()
			S.CLEAR:
				state_t += delta
				if bot and state_t > 1.5:
					_open_shop()
			S.SHOP:
				state_t += delta
				if bot and state_t > 1.0:
					for i in shop_offers.size():
						if shop_offers[i] != "" and plinks >= offer_price(shop_offers[i]):
							_buy(i)
					_leave_shop()
			S.BONUS_OFFER:
				state_t += delta
				if bot and state_t > 1.0:
					_start_bonus()
			S.BONUS:
				state_t += delta
				bonus.update(delta)
			S.BONUS_END:
				state_t += delta
				if bot and state_t > 1.0:
					_next_stage()
			S.VICTORY:
				state_t += delta
				if int(state_t * 3.0) != int((state_t - delta) * 3.0):
					_burst(Vector2(randf_range(160.0, 1120.0), randf_range(120.0, 400.0)), [Art.GOLD, Art.RED, Art.BLUE, Art.GREEN].pick_random(), 22, 380.0)
				if bot and state_t > 3.0:
					_restart()
	_update_opp(delta)
	if INTERCEPT_HINT and state == S.RALLY and last_hitter == Who.OPP and ball.v.z < 0.0:
		intercept = Phys.predict(ball, PADDLE_Z, -1.0)
	else:
		intercept = Vector3.ZERO
	if shot_path != "" and time > shot_at:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()
	world_view.queue_redraw()
	hud_view.queue_redraw()


func _update_paddle(delta: float) -> void:
	lunge_cd = maxf(0.0, lunge_cd - delta)
	lunge_t = maxf(0.0, lunge_t - delta)
	ability_cd = maxf(0.0, ability_cd - delta)
	ability_t = maxf(0.0, ability_t - delta)
	paddle_wobble = maxf(0.0, paddle_wobble - delta * 3.0)
	hit_cd = maxf(0.0, hit_cd - delta)
	opp_hit_cd = maxf(0.0, opp_hit_cd - delta)
	var target := _bot_target() if bot else Cam.unproject(get_global_mouse_position(), PADDLE_Z)
	var rng := base_range()
	target = Vector2(clampf(target.x, -rng, rng), clampf(target.y, -35.0, 85.0))
	var reach := 0.0
	if lunge_t > 0.0:
		reach = LUNGE_REACH * sin(PI * (1.0 - lunge_t / LUNGE_TIME))
	# a touch of lag gives the paddle some weight without costing control; a nimble paddle has less
	var follow := 1.0 - exp(-delta * 30.0 * float(paddle_def.speed))
	# Swing speed (and so spin and aim) is read from where the player is steering the paddle,
	# while the paddle itself is gently pulled onto the ball's path by the hit correction.
	var intent_old := intent
	intent_xy = intent_xy.lerp(target, follow)
	intent = Vector3(intent_xy.x, intent_xy.y, PADDLE_Z + reach)
	var assisted := _assist(target)
	assisted.x = clampf(assisted.x, -rng, rng)
	paddle_xy = paddle_xy.lerp(assisted, follow)
	paddle = Vector3(paddle_xy.x, paddle_xy.y, PADDLE_Z + reach)
	if delta > 0.0:
		paddle_vel = paddle_vel.lerp((intent - intent_old) / delta, follow)


## Hit correction. The paddle always follows the mouse, so the swing that makes the spin is never
## fought. If the mouse is within the catch zone of the ball's path as it closes in, the paddle is
## only nudged a little towards it, and the hit itself is forgiven (see `assist_lock`: a ball that
## crosses counts as a hit and lands near the sweet spot). Nothing latches: it is recomputed every
## frame, so there is nothing to get stuck on. The paddle stays within its reach, so the widest
## balls are eased so they never cross the plane out of reach (see `_opp_hit`).
func _assist(target: Vector2) -> Vector2:
	var dz := ball.p.z - paddle.z
	assist_lock = false
	if not hit_assist or state != S.RALLY or last_hitter != Who.OPP or ball.v.z >= 0.0 or hit_cd > 0.0 or dz > ASSIST_DIST:
		return target
	var pr := Phys.predict(ball, paddle.z, -1.0)
	if pr.z == 0.0:
		return target
	var ic := Vector2(pr.x, pr.y)
	if target.distance_to(ic) > ASSIST_CAPTURE * assist_mul * (2.5 if _ability_on("grab") else 1.0):
		return target
	assist_lock = true
	var urgency := _smooth(inverse_lerp(ASSIST_DIST, ASSIST_DIST * 0.25, dz))
	return target.lerp(ic, urgency * ASSIST_PULL)


func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _bot_target() -> Vector2:
	if state == S.BONUS:
		return bonus.bot_target()
	if state == S.RALLY and last_hitter == Who.OPP and ball.v.z < 0.0:
		var pr := Phys.predict(ball, PADDLE_Z, -1.0)
		if pr.z > 0.0:
			if ball.p.z < 80.0 and lunge_cd <= 0.0 and randf() < 0.05:
				_lunge()
			# the bot uses the paddle's ability when the ball is close
			if ball.p.z < 140.0 and ability_cd <= 0.0 and paddle_def.ability != "":
				_ability()
			return Vector2(pr.x, pr.y) + Vector2.from_angle(float(bounces) * 2.4 + returns) * bot_err
	return Vector2(0.0, 30.0)


const SCORE_AT := Vector2(1150.0, 62.0)
const PANEL_RECT := Rect2(500.0, 8.0, 280.0, 58.0)


## Coins fly from the banner to the score, which only counts up as each one lands. Shards fall.
func _update_win_fx(delta: float) -> void:
	for i in range(fliers.size() - 1, -1, -1):
		var f := fliers[i]
		f.t += delta
		if f.t >= f.delay + f.dur:
			score_shown = minf(score_shown + f.share, float(score))
			score_pulse = 1.0
			_burst(SCORE_AT, Art.GOLD, 3, 140.0)
			fliers.remove_at(i)
	if fliers.is_empty():
		score_shown = float(score)
	for i in range(shards.size() - 1, -1, -1):
		var s := shards[i]
		s.life -= delta
		s.vel.y += 1500.0 * delta
		s.pos += s.vel * delta
		s.rot += s.spin * delta
		if s.life <= 0.0:
			shards.remove_at(i)


func _spawn_fliers(bank: int) -> void:
	var n := clampi(6 + bank / 50, 6, 28)
	for i in n:
		var from := Vector2(640.0 + randf_range(-90.0, 90.0), 330.0 + randf_range(-30.0, 30.0))
		fliers.append({
			"from": from,
			"ctrl": Vector2(from.x + randf_range(-260.0, 260.0), from.y - randf_range(120.0, 320.0)),
			"delay": 0.45 + randf() * 0.45,
			"dur": randf_range(0.45, 0.7),
			"t": 0.0,
			"share": float(bank) / n,
		})


## The Power x Heat panel breaks into tumbling pieces.
func _spawn_shards() -> void:
	var cols := 7
	var rows := 2
	var cw := PANEL_RECT.size.x / cols
	var ch := PANEL_RECT.size.y / rows
	# same colours as the live panel (see HudView._power_heat), so the pieces read as the panel breaking
	var k := clampf(disp_power * disp_heat / float(maxi(1, target)) * 4.0, 0.0, 1.0)
	var top := Color("4a2bb8").lerp(Color("d9480f"), k)
	var bot := Color("a02bc4").lerp(Art.GOLD.darkened(0.15), k)
	for cx in cols:
		for cy in rows:
			var c := PANEL_RECT.position + Vector2((cx + 0.5) * cw, (cy + 0.5) * ch)
			shards.append({
				"pos": c,
				"vel": Vector2((c.x - 640.0) * 1.6 + randf_range(-90.0, 90.0), randf_range(-420.0, -80.0)),
				"rot": randf_range(-0.4, 0.4),
				"spin": randf_range(-9.0, 9.0),
				"size": Vector2(cw, ch) * randf_range(0.85, 1.0),
				"life": randf_range(0.9, 1.4),
				"col": (top if cy == 0 else bot).darkened(0.12 * ((cx + cy) % 2)),
			})


func _win_word() -> String:
	if heat >= 10.0:
		win_col = Art.RED
		return "UNREAL!"
	if heat >= 6.0:
		win_col = Art.GOLD
		return "AWESOME!"
	if heat >= 3.5:
		win_col = Art.GREEN
		return "GREAT!"
	win_col = Art.BLUE.lightened(0.3)
	return "NICE!"


## The opponent talks. `mean` lines are taunts for when you lose, the rest are sore-loser mutterings.
func _say(mean: bool) -> void:
	var pool: Array = []
	if mean:
		pool.append_array(Roster.TAUNTS.get(Roster.STAGES[stage].name, []))
		pool.append_array(Roster.TAUNTS_ANY)
	else:
		pool.append_array(Roster.WHINES)
	var line: String = pool.pick_random()
	if line == taunt and pool.size() > 1:
		line = pool.pick_random()
	taunt = line
	taunt_t = 0.0
	taunt_mean = mean
	taunt_dur = 2.6


func _update_fx(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 30.0)
	world_view.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	opp_mood = move_toward(opp_mood, 0.0, delta * 0.5)
	player_mood = move_toward(player_mood, 0.0, delta * 0.5)
	opp_swing = maxf(0.0, opp_swing - delta)
	heat_pulse = maxf(0.0, heat_pulse - delta * 4.0)
	power_pulse = maxf(0.0, power_pulse - delta * 4.0)
	panel_kick = maxf(0.0, panel_kick - delta * 3.0)
	if power > _prev_power:
		power_pulse = 1.0
		panel_kick = maxf(panel_kick, 0.35)
	if heat > _prev_heat:
		panel_kick = maxf(panel_kick, 0.5)
	_prev_power = power
	_prev_heat = heat
	net_flash = maxf(0.0, net_flash - delta * 1.2)
	banner_t += delta
	taunt_t += delta
	shatter_t += delta
	flash = maxf(0.0, flash - delta * 2.2)
	score_pulse = maxf(0.0, score_pulse - delta * 5.0)
	_update_win_fx(delta)
	disp_power = lerpf(disp_power, power, 1.0 - exp(-delta * 18.0))
	disp_heat = lerpf(disp_heat, heat, 1.0 - exp(-delta * 18.0))
	if state == S.RALLY or state == S.POINT_OVER:
		trail.append(ball.p)
		if trail.size() > 14:
			trail.pop_front()
	for i in range(popups.size() - 1, -1, -1):
		popups[i].t += delta
		popups[i].pos.y -= 38.0 * delta
		if popups[i].t > 1.1:
			popups.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.life -= delta
		p.vel.y += 900.0 * delta
		p.pos += p.vel * delta
		if p.life <= 0.0:
			particles.remove_at(i)


# ---------------------------------------------------------------------------------------------
# Rally flow
# ---------------------------------------------------------------------------------------------

func _start_serve() -> void:
	state = S.READY
	state_t = 0.0
	serve_wait = randf_range(0.7, 1.7)
	acc = 0.0
	power = 0.0
	heat = base_heat()
	returns = 0
	smashes = 0
	last_hitter = Who.OPP
	bounces = 0
	_draw_ball()
	ball.p = Vector3(0.0, 32.0, Phys.LENGTH - 14.0)
	ball.v = Vector3.ZERO
	ball.w = Vector3.ZERO
	trail.clear()
	opp_target = OPP_REST
	banner = ""
	banner_count = -1
	win_word = ""
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	banner_sub = ""
	banner_col = Color.WHITE
	if cur != Balls.PLAIN:
		# say which ball is coming and what it does
		banner = Balls.title(cur).to_upper()
		banner_sub = str(Balls.DEFS[cur].desc).replace("\n", " ")
		banner_col = Balls.color(cur).lightened(0.2)
	banner_t = 0.0


func _launch_serve() -> void:
	banner = ""
	var w := Vector3(-randf_range(0.0, 30.0), randf_range(-20.0, 20.0), 0.0)
	var sol := Phys.solve_robust(ball.p, -1.0, randf_range(-55.0, 55.0), randf_range(30.0, Phys.NET_Z - 40.0), w, randf_range(10.0, 30.0))
	ball.v = sol.v
	ball.w = sol.w
	if net_test:
		# dev check: a slow, low serve that runs straight into the net
		ball.v = Vector3(0.0, 60.0, -420.0)
		ball.w = Vector3.ZERO
	net_hit_since_hit = false
	opp_swing = 0.2
	Audio.play("serve")
	state = S.RALLY


func _after_point() -> void:
	if score >= target:
		_stage_clear()
	elif lives <= 0:
		Runs.record(run_score + score, stage + 1, false)
		state = S.GAME_OVER
		state_t = 0.0
		banner = ""
		Audio.play("game_over", 1.0, 0.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_start_serve()


func _sim() -> void:
	if cur == "pressure" and returns > 0:
		heat += 0.3 * Phys.DT
	var ev := Phys.step(ball, Phys.DT)
	ball_angle += ball.w.x * Phys.DT
	match ev:
		Phys.Ev.BOUNCE:
			_on_bounce()
		Phys.Ev.NET_CLIP:
			if last_hitter == Who.PLAYER:
				_trick("NET CLIP", 0.0, 2.0)
			else:
				_net_popup("NET CLIP")
			_net_flash(0.8)
			Audio.play("net_clip")
			_burst(Cam.project(ball.p), Color.WHITE, 6, 160.0)
		Phys.Ev.WALL:
			Audio.play("wall")
			if last_hitter == Who.PLAYER:
				_trick("RICOCHET", 20.0, 0.0)
			_burst(Cam.project(ball.p), Balls.color(cur), 8, 200.0)
		Phys.Ev.NET:
			net_hit_since_hit = true
			Audio.play("net")
			_net_popup("NET!")
			_net_flash(1.0)
			freeze = 0.06
			shake = maxf(shake, 4.0)
			_burst(Cam.project(ball.p), Color.WHITE, 8, 160.0)
	if state != S.RALLY:
		return
	# The lunge moves the paddle ~13 cm per frame, so also count the ball and the paddle plane passing
	# through each other between two checks, not just overlapping at one of them.
	var rel_z := ball.p.z - paddle.z
	var crossed := prev_rel_z > 0.0 and rel_z <= 0.0
	prev_rel_z = rel_z
	# A locked hit correction means the player was within the catch zone, so crossing is a hit even if
	# the paddle's sideways position hasn't quite caught up (a lunge sweeps past the ball very fast).
	if hit_cd <= 0.0 and last_hitter == Who.OPP and ball.v.z < 0.0 and (_touches(paddle, paddle_r) or (crossed and (assist_lock or _within_face(paddle, paddle_r)))):
		_player_hit()
	elif opp_hit_cd <= 0.0 and last_hitter == Who.PLAYER and bounces >= 1 and ball.v.z > 0.0 and _touches(Vector3(opp.x, opp.y, OPP_Z), PADDLE_R):
		_opp_hit()
	if ball.p.y < Phys.FLOOR_Y or absf(ball.p.x) > 500.0 or ball.p.z < -260.0 or ball.p.z > Phys.LENGTH + 260.0:
		_ball_dead()


func _touches(c: Vector3, r: float) -> bool:
	return absf(ball.p.z - c.z) <= Phys.R + 6.0 and _within_face(c, r)


func _within_face(c: Vector3, r: float) -> bool:
	return Vector2(ball.p.x - c.x, ball.p.y - c.y).length() <= r + Phys.R


func _on_bounce() -> void:
	bounces += 1
	var near_side := ball.p.z < Phys.NET_Z
	Audio.play("bounce", 1.0, 0.08, linear_to_db(clampf(ball.v.length() / 700.0, 0.3, 1.0)))
	_burst(Cam.project(Vector3(ball.p.x, 0.0, ball.p.z)), Color.WHITE, 5, 140.0)
	if cur == "bouncy" and last_hitter == Who.PLAYER and near_side == false:
		_trick("BOING", 0.0, 1.0)
	if last_hitter == Who.PLAYER:
		if not near_side and bounces == 1 and (absf(ball.p.x) > Phys.HALF_W - 6.0 or ball.p.z > Phys.LENGTH - 6.0):
			_trick("EDGE BALL", 20.0, 1.0)
		if near_side and bounces == 1:
			_end_point(Who.OPP, "own_side")
		elif not near_side and bounces == 2:
			_end_point(Who.PLAYER, "")
	else:
		if not near_side and bounces == 1:
			_end_point(Who.PLAYER, "their_side")
		elif near_side and bounces == 2:
			_end_point(Who.OPP, "")


func _ball_dead() -> void:
	if bounces == 0:
		_end_point(Who.OPP if last_hitter == Who.PLAYER else Who.PLAYER, "OUT")
	else:
		_end_point(last_hitter, "")


func _end_point(winner: int, why: String) -> void:
	# A shot that dies on the hitter's own side is either a net hit or simply a short ball: say which.
	if why == "own_side" or why == "their_side":
		var who := "YOUR" if why == "own_side" else "THEIR"
		why = "HIT THE NET" if net_hit_since_hit else "BOUNCED ON %s SIDE" % who
	state = S.POINT_OVER
	state_t = 0.0
	acc = 0.0
	banner_t = 0.0
	banner_sub = why
	freeze = 0.1
	if bot:
		print("point -> %s  %s  returns=%d  power=%d heat=%.1f" % ["PLAYER" if winner == Who.PLAYER else "OPP", why, returns, power, heat])
	if winner == Who.PLAYER:
		var mult := 1.0
		if cur == "gambler":
			mult = 3.0 if randf() < 0.5 else 0.5
			banner_sub = "GAMBLER  x" + _num(mult)
		var bank := int(power * heat * mult)
		if cur == "vampire" and heat >= 6.0 and lives < START_LIVES:
			lives += 1
			banner_sub = "VAMPIRE  +1 LIFE"
		score += bank
		var gain := clampi(int(bank * PLINK_RATE), 0, maxi(0, int(target * PLINK_CAP) - stage_plinks))
		plinks += gain
		stage_plinks += gain
		banner_sub = (banner_sub + "   -   " if banner_sub != "" else "") + "+%d PLINKS" % gain
		best = maxi(best, run_score + score)
		banner = "+" + Art.fmt(bank)
		banner_count = bank
		banner_col = Art.GOLD
		opp_mood = -1.0
		player_mood = 1.0
		var big := heat >= 3.5
		Audio.play("point_big" if big else "point_win", 1.0, 0.0)
		shake = 9.0 + (4.0 if big else 0.0)
		win_word = _win_word()
		heat_pulse = 1.0
		panel_kick = 2.5 if big else 1.5
		flash = 0.5 if big else 0.3
		flash_col = Art.GOLD
		_spawn_fliers(bank)
		_say(false)
		_burst(Vector2(640, 360), Art.GOLD, 36, 420.0)
		if big:
			_burst(Vector2(420, 330), Art.RED, 24, 480.0)
			_burst(Vector2(860, 330), Art.BLUE, 24, 480.0)
		disp_power = power
		disp_heat = heat
	else:
		if cur == "phoenix":
			banner_sub = "PHOENIX  LIFE SAVED"
		elif cur == "fireball" and fire_lit:
			lives = maxi(0, lives - 2)
			banner_sub = "BURNED  -2 LIVES"
		else:
			lives -= 1
		banner = "NET!" if why == "HIT THE NET" else ("FAULT" if why.begins_with("BOUNCED") else "MISSED")
		banner_col = Art.RED
		banner_count = -1
		Audio.play("point_lose", 1.0, 0.0)
		win_word = ""
		opp_mood = 1.0
		player_mood = -1.0
		shake = 12.0
		flash = 0.45
		flash_col = Art.RED
		shatter_t = 0.0
		_spawn_shards()
		_say(true)
		if lives <= 0:
			taunt_dur = 4.0
		power = 0.0
		heat = base_heat()
		_burst(Vector2(640, 90), Art.RED, 30, 380.0)


# ---------------------------------------------------------------------------------------------
# Hits
# ---------------------------------------------------------------------------------------------

func _player_hit() -> void:
	hit_cd = 0.15
	var pv := paddle_vel
	var t := clampf(inverse_lerp(80.0, 800.0, pv.length()), 0.0, 1.0)
	var perfect := lunge_t > 0.0
	var off := Vector2(ball.p.x - paddle.x, ball.p.y - paddle.y)
	if assist_lock:
		# a forgiven hit lands near the sweet spot, so assisted hits are accurate and never wild rim shots
		off = off.limit_length(paddle_r * 0.6)
	var rim := off.length() > paddle_r * 0.78
	var h := ball.p.y
	var volley := bounces == 0

	# Swing -> shot: swipe up = topspin, down = backspin, sideways = sidespin and aim.
	var w := Vector3(clampf(pv.y * 0.17, -110.0, 110.0), clampf(pv.x * 0.22, -140.0, 140.0), 0.0)
	if cur == "dervish":
		w *= 1.5
	# reaching out wide angles the paddle inwards, so the ball tends to come back across the table
	var lean := clampf(paddle.x / base_range(), -1.0, 1.0)
	var tx := clampf(pv.x * 0.14 + off.x * 2.4 - lean * 20.0, -62.0, 62.0)
	var tz := lerpf(Phys.NET_Z + 35.0, Phys.LENGTH - 14.0, pow(t, 0.8))
	var pref := 20.0 - (h - 28.0) * 0.35
	if h < 30.0 and pv.y > 350.0 and t < 0.6:
		pref = 52.0
		tz = Phys.LENGTH - 25.0
	if perfect:
		pref = 3.0
		tz = Phys.LENGTH - 16.0
	# a paddle that can't smash always sends the ball up in a normal arc, however high it is hit
	if paddle_def.get("no_smash", false):
		pref = maxf(pref, NO_SMASH_ANGLE)
	if rim:
		tx += randf_range(-30.0, 30.0)
		w += Vector3(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0), 0.0)
		tx = clampf(tx, -62.0, 62.0)

	# With side walls up, a hard sideways swipe banks the ball off the wall on that side.
	var bank := 0.0
	if Phys.walls and absf(pv.x) > BANK_SWIPE and not rim:
		bank = signf(pv.x)
		tx = clampf(off.x * 0.5 - bank * 20.0, -50.0, 50.0)
	var sol := Phys.solve_robust(ball.p, 1.0, tx, tz, w, pref, bank)
	w = sol.w
	net_hit_since_hit = false
	ball.v = sol.v
	ball.w = w
	last_hitter = Who.PLAYER
	bounces = 0
	returns += 1
	popup_slot = 0
	if cur == "fireball" and returns >= 5 and not fire_lit:
		fire_lit = true
		Audio.play("fire")
		_burst(Cam.project(ball.p), Balls.color(cur), 30, 420.0)
		popups.append({"text": "FIREBALL LIT!", "pos": Cam.project(ball.p) + Vector2(0.0, -80.0), "t": 0.0, "col": Balls.color(cur), "size": 44})
	if cur != Balls.PLAIN and (returns == 1 or cur == "midas" or cur == "double_heat"):
		var label := Balls.title(cur).to_upper() + ("  x2" if cur == "midas" or cur == "double_heat" else "")
		popups.append({"text": label, "pos": Cam.project(ball.p) + Vector2(0.0, -150.0), "t": 0.0, "col": Balls.color(cur).lightened(0.2), "size": 30})
	power += _pw(10.0)
	if returns > 1 and cur != "pressure":
		heat += _ht(0.5)
		heat_pulse = 1.0
	if cur == "disco":
		var bonus: Array = [[15.0, 0.0], [25.0, 0.0], [0.0, 1.0]].pick_random()
		_trick("DISCO", bonus[0], bonus[1])

	if w.x > 38.0:
		_trick("TOPSPIN", 20.0, 0.0)
	elif w.x < -38.0:
		_trick("CHOP", 30.0, 0.0)
	if absf(w.y) > 38.0:
		_trick("CURVE", 0.0, 1.0)
	if absf(tx) > 52.0:
		_trick("ANGLE", 0.0, 1.0)
	if sol.v.y < 0.0 and h > 42.0 and not paddle_def.get("no_smash", false):
		# a smash streak fades: each smash in the same rally pays 60% of the one before, down to a floor
		_trick("SMASH", 0.0, maxf(SMASH_FLOOR, 2.0 * pow(SMASH_FALLOFF, smashes)))
		smashes += 1
	if sol.deg >= 44.0:
		_trick("LOB", 25.0, 0.0)
	if t < 0.15 and w.x < -10.0:
		_trick("DROP SHOT", 0.0, 2.0)
	if volley:
		_trick("VOLLEY", 0.0, 1.0)
	if perfect:
		_trick("PERFECT", 10.0, 1.0)
	if rim:
		_trick("RIM SHOT", 50.0, 1.0)

	Audio.play("hit", 0.85 + t * 0.4, 0.06, 2.0 if perfect else 0.0)
	freeze = 0.04 + t * 0.03
	shake = 3.0 + t * 6.0 + (4.0 if perfect else 0.0)
	paddle_wobble = 0.6
	_burst(Cam.project(ball.p), Art.RED, 10, 300.0)
	_plan_opp()


func _plan_opp() -> void:
	# The opponent reads the ball's path once per player hit, then moves with a reaction delay.
	var pr := Phys.predict(ball, OPP_Z, 1.0)
	opp_react = opp_react_time
	if pr.z == 0.0:
		opp_target = OPP_REST
		return
	var tgt := Vector2(pr.x, pr.y)
	var miss := opp_miss_base + opp_miss_per_return * returns + minf(ball.v.z / 9000.0, 0.1)
	if randf() < miss:
		tgt += Vector2((1.0 if randf() < 0.5 else -1.0) * randf_range(34.0, 48.0), randf_range(-10.0, 10.0))
	opp_target = Vector2(clampf(tgt.x, -115.0, 115.0), clampf(tgt.y, -35.0, 95.0))


func _opp_hit() -> void:
	opp_hit_cd = 0.15
	Audio.play("opp_hit")
	# Aim away from where the player is standing, with some scatter.
	var tx := clampf(-paddle.x * 0.5 + randf_range(-30.0, 30.0), -62.0, 62.0)
	var tz := randf_range(45.0, Phys.NET_Z - 40.0)
	var topspin: float = [randf_range(-35.0, -12.0), randf_range(10.0, 40.0), randf_range(-5.0, 10.0)].pick_random()
	var w := Vector3(-topspin, randf_range(-25.0, 25.0), 0.0)
	if returns >= 2 and randf() < opp_wide_chance:
		# Occasional very wide ball, curling outwards.
		var side := signf(randf() - 0.5)
		tx = side * randf_range(60.0, 68.0)
		w.y = -side * randf_range(60.0, 90.0)
	var pref := randf_range(8.0, 26.0)
	var sol := Phys.solve_robust(ball.p, -1.0, tx, tz, w, pref)
	ball.v = sol.v
	ball.w = sol.w
	# However wide, the ball must cross your paddle plane where the mouse can reach it (and the screen
	# can show it): ease the curl and the aim until it does.
	for i in 5:
		var cross := Phys.predict(ball, PADDLE_Z, -1.0)
		if cross.z == 0.0 or absf(cross.x) <= OPP_REACH:
			break
		w.y *= 0.5
		tx *= 0.9
		if i == 4:
			# last resort: a plain shot with no curl, aimed well inside the table
			w.y = 0.0
			tx = signf(tx) * 25.0
		sol = Phys.solve_robust(ball.p, -1.0, tx, tz, w, pref)
		ball.v = sol.v
		ball.w = sol.w
	net_hit_since_hit = false
	last_hitter = Who.OPP
	bounces = 0
	opp_swing = 0.2
	freeze = 0.03
	shake = 2.5
	_burst(Cam.project(ball.p), Art.BLUE, 8, 240.0)


func _update_opp(delta: float) -> void:
	if state == S.RALLY and last_hitter == Who.PLAYER:
		if opp_react > 0.0:
			opp_react -= delta
		else:
			opp.x = move_toward(opp.x, opp_target.x, opp_speed.x * delta)
			opp.y = move_toward(opp.y, opp_target.y, opp_speed.y * delta)
	else:
		opp.x = move_toward(opp.x, OPP_REST.x, 200.0 * delta)
		opp.y = move_toward(opp.y, OPP_REST.y, 200.0 * delta)


# ---------------------------------------------------------------------------------------------
# Feedback
# ---------------------------------------------------------------------------------------------

## 2.0 -> "2", 1.5 -> "1.5"
func _num(v: float) -> String:
	return String.num(v, 1).trim_suffix(".0")


## What a Power / Heat gain is really worth with the ball in play (Midas, Double Heat, a lit Fireball).
func _pw(d: float) -> float:
	if cur == "midas":
		return d * 2.0
	if cur == "magnet":
		return d * 0.5
	return d


func _ht(d: float) -> float:
	if cur == "double_heat":
		return d * 2.0
	if cur == "fireball" and fire_lit:
		return d * 3.0
	return d


func _trick(label: String, d_power: float, d_heat: float) -> void:
	# Physics balls that make particular tricks pay more.
	if cur == "feather" and (label == "LOB" or label == "DROP SHOT"):
		d_power *= 2.0
		d_heat *= 2.0
	elif cur == "meteor" and label == "SMASH":
		d_heat *= 3.0
	elif cur == "dervish" and (label == "TOPSPIN" or label == "CHOP" or label == "CURVE"):
		d_power *= 2.0
		d_heat *= 2.0
	d_power = _pw(d_power)
	d_heat = _ht(d_heat)
	power += d_power
	heat += d_heat
	var s := label
	var col := Art.BLUE.lightened(0.2)
	if d_power > 0.0:
		s += "  +" + _num(d_power)
	if d_heat > 0.0:
		s += "  +" + _num(d_heat) + " HEAT"
		col = Art.RED.lightened(0.15)
	heat_pulse = 1.0
	var at := Cam.project(ball.p) + Vector2(0.0, -46.0 - popup_slot * 30.0)
	popups.append({"text": s, "pos": Vector2(clampf(at.x, 160.0, 1120.0), at.y), "t": 0.0, "col": col})
	popup_slot += 1


## Net contact has to be unmistakable: the net flashes and ripples, and a big label pops up.
func _net_flash(strength: float) -> void:
	net_flash = strength


func _net_popup(label: String) -> void:
	var at := Cam.project(Vector3(clampf(ball.p.x, -Phys.HALF_W, Phys.HALF_W), Phys.NET_H + 8.0, Phys.NET_Z))
	popups.append({"text": label, "pos": at + Vector2(0.0, -30.0), "t": 0.0, "col": Art.GOLD.lightened(0.3), "size": 44})


func _burst(pos: Vector2, col: Color, n: int, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		var life := randf_range(0.25, 0.6)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(a), sin(a) - 0.4) * randf_range(0.3, 1.0) * speed,
			"life": life,
			"max": life,
			"size": randf_range(2.5, 6.0),
			"col": col,
		})
