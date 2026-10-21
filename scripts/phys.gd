class_name Phys
extends RefCounted
## 3D ball simulation shared by the live game, the shot solver and the opponent AI (centimetres, seconds).
## x = lateral (right +), y = height above the table top, z = along the table from the player's end (0)
## to the opponent's end (LENGTH). Spin `w` is an angular-velocity vector on those axes: a ball
## travelling +z with w.x > 0 has topspin, and w.y > 0 curves it towards +x.

const G := 900.0
const DRAG := 0.10
const MAGNUS := 0.007
const SPIN_ARM := 8.0
const R := 3.6
const HALF_W := 76.0
const LENGTH := 274.0
const NET_Z := 137.0
const NET_H := 15.25
const NET_OVER := 12.0
const FLOOR_Y := -76.0
const DT := 1.0 / 240.0

const WALL_X := HALF_W + 34.0

enum Ev { NONE, BOUNCE, NET, NET_CLIP, WALL }

# World tweaks for the magic ball in play (see Balls). They are static so the live game, the shot
# solver and the opponent AI all simulate the same world; Game sets them whenever a ball is drawn.
static var gravity := G
static var magnus := MAGNUS
static var restitution := 0.86
static var table_grip := 0.25
static var kick := 0.0
static var ghost_net := false
static var walls := false
# Set by `fly`: whether the ball it just simulated ricocheted off a side wall.
static var fly_hit_wall := false


static func reset_tweaks() -> void:
	gravity = G
	magnus = MAGNUS
	restitution = 0.86
	table_grip = 0.25
	kick = 0.0
	ghost_net = false
	walls = false


class Ball extends RefCounted:
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var w := Vector3.ZERO

	func duplicate_ball() -> Ball:
		var b := Ball.new()
		b.p = p
		b.v = v
		b.w = w
		return b


static func step(b: Ball, dt: float) -> int:
	var ev: int = Ev.NONE
	b.v += (Vector3(0.0, -gravity, 0.0) + magnus * b.w.cross(b.v) - DRAG * b.v) * dt
	b.w *= 1.0 - 0.1 * dt
	var old := b.p
	b.p += b.v * dt
	if walls and absf(b.p.x) > WALL_X and b.p.x * b.v.x > 0.0:
		b.p.x = signf(b.p.x) * WALL_X
		b.v.x *= -0.9
		ev = Ev.WALL

	# The net is a thin wall: skim the tape and the ball is lifted over, hit the mesh and it drops back.
	if old.z != b.p.z and (old.z - NET_Z) * (b.p.z - NET_Z) <= 0.0:
		var f := (NET_Z - old.z) / (b.p.z - old.z)
		var cx := old.x + (b.p.x - old.x) * f
		var cy := old.y + (b.p.y - old.y) * f
		if absf(cx) < HALF_W + NET_OVER and cy - R < NET_H and cy + R > 0.0:
			if ghost_net:
				ev = Ev.NET_CLIP
			elif cy - R > NET_H - 2.5:
				b.v.y = absf(b.v.y) * 0.3 + 70.0
				b.v.z *= 0.8
				ev = Ev.NET_CLIP
			else:
				var side := signf(old.z - NET_Z)
				if side == 0.0:
					side = 1.0
				b.p.z = NET_Z + side * (R + 0.6)
				b.v.z = -b.v.z * 0.3
				b.v.x *= 0.8
				ev = Ev.NET

	# Spin-aware table bounce: friction at the contact point trades spin for speed along the table.
	if b.v.y < 0.0 and old.y > R and b.p.y <= R and absf(b.p.x) <= HALF_W and b.p.z >= 0.0 and b.p.z <= LENGTH:
		var dvx := -(b.v.x + b.w.z * SPIN_ARM) * table_grip
		var dvz := -(b.v.z - b.w.x * SPIN_ARM) * table_grip
		b.p.y = R
		b.v.x += dvx + b.w.y * kick
		b.v.z += dvz
		b.w.x -= dvz / SPIN_ARM
		b.w.z += dvx / SPIN_ARM
		b.v.y = -b.v.y * restitution
		ev = Ev.BOUNCE
	return ev


## Flies a ball until its first table bounce.
## Returns Vector3(kind, x, z): kind 0 = too slow (net, or landed on the wrong half),
## 1 = landed legally, 2 = too fast (flew past the table), 4 = missed the table sideways.
static func fly(p: Vector3, v: Vector3, w: Vector3, dir: float) -> Vector3:
	var b := Ball.new()
	b.p = p
	b.v = v
	b.w = w
	fly_hit_wall = false
	for i in 600:
		var old_z := b.p.z
		var ev := step(b, DT)
		if ev == Ev.WALL:
			fly_hit_wall = true
		if not ghost_net:
			if ev == Ev.NET or ev == Ev.NET_CLIP:
				return Vector3(0.0, b.p.x, b.p.z)
			if (old_z - NET_Z) * (b.p.z - NET_Z) <= 0.0 and b.p.y - R < NET_H + 3.0:
				return Vector3(0.0, b.p.x, b.p.z)
		if ev == Ev.BOUNCE:
			var far := (b.p.z - NET_Z) * dir > 0.0
			return Vector3(1.0 if far else 0.0, b.p.x, b.p.z)
		if b.v.y < 0.0 and b.p.y <= R:
			# Dropped to table height without a bounce: it missed the table. Say which way.
			if absf(b.p.x) > HALF_W:
				return Vector3(4.0, b.p.x, b.p.z)
			return Vector3(2.0 if (b.p.z - NET_Z) * dir > 0.0 else 0.0, b.p.x, b.p.z)
		if b.p.y < FLOOR_Y or absf(b.p.x) > 400.0 or b.p.z < -300.0 or b.p.z > LENGTH + 300.0:
			return Vector3(2.0, b.p.x, b.p.z)
	return Vector3(2.0, b.p.x, b.p.z)


static func _launch(speed: float, el: float, az: float, dir: float) -> Vector3:
	var flat := cos(el) * speed
	return Vector3(sin(az) * flat, sin(el) * speed, dir * cos(az) * flat)


## Finds a launch velocity that lands the ball near (tx, tz) on the table with spin `w`.
## `dir` is +1 when hitting towards the opponent's end and -1 towards the player's.
## Tries a few elevations around `pref_deg`, keeping the one closest to it that lands accurately.
## `bank` is -1 or +1 to bank the shot off that side's wall (needs `walls`), 0 for a direct shot.
static func solve(p: Vector3, dir: float, tx: float, tz: float, w: Vector3, pref_deg: float, bank := 0.0) -> Dictionary:
	var best := {}
	var best_cost := INF
	var dist := maxf(absf(tz - p.z), 40.0)
	# Elevations near the preferred one first; only widen the search if none of them lands.
	var offsets := [-14.0, -5.0, 5.0, 14.0, -28.0, 24.0, 38.0]
	for k in offsets.size():
		if k == 4 and not best.is_empty():
			break
		var deg := clampf(pref_deg + offsets[k], -35.0, 62.0)
		var el := deg_to_rad(deg)
		# A bank shot aims at the target's mirror image across the wall. Past the wall, a wider aim
		# lands the ball closer to the wall, so the sideways correction flips sign.
		var aim_x := tx
		var side_gain := -0.8
		if bank != 0.0:
			var wx := bank * WALL_X
			aim_x = wx + (wx - tx) / 0.9
			side_gain = 0.8
		var az := atan2(aim_x - p.x, dist)
		var lo := 200.0
		var hi := 2000.0
		# Bisect the launch speed for depth while nudging the aim for sideways error:
		# sidespin curves the ball, so the straight-line aim is only a starting guess.
		for i in 18:
			var mid := (lo + hi) * 0.5
			var r := fly(p, _launch(mid, el, az, dir), w, dir)
			if bank != 0.0 and not fly_hit_wall and r.x != 0.0 and r.x != 2.0:
				# Never reached the wall: swing the aim further out.
				az += bank * 0.06
				if r.x == 1.0:
					if (r.z - tz) * dir < 0.0:
						lo = mid
					else:
						hi = mid
			elif r.x == 1.0:
				if (r.z - tz) * dir < 0.0:
					lo = mid
				else:
					hi = mid
				az += atan2(r.y - tx, dist) * side_gain
			elif r.x == 4.0:
				az += atan2(r.y - tx, dist) * side_gain
			elif r.x == 0.0:
				lo = mid
			else:
				hi = mid
		var speed := (lo + hi) * 0.5
		var res := fly(p, _launch(speed, el, az, dir), w, dir)
		if res.x != 1.0 or (bank != 0.0 and not fly_hit_wall):
			continue
		var err := Vector2(res.y - tx, (res.z - tz) * dir)
		if err.length() > 26.0:
			continue
		var cost := err.length() + absf(deg - pref_deg) * 1.5
		if cost < best_cost:
			best_cost = cost
			best = {"ok": true, "v": _launch(speed, el, az, dir), "deg": deg}
	if best.is_empty():
		# No legal solution: fall back to a plain medium lob so the rally never stalls.
		best = {"ok": false, "v": _launch(650.0, 0.8, 0.0, dir), "deg": 46.0}
	return best


## `solve`, but if the aimed shot is impossible it eases off the spin and the target, so a hit never
## degenerates into a random lob. The result also carries the spin actually used, as "w".
static func solve_robust(p: Vector3, dir: float, tx: float, tz: float, w: Vector3, pref_deg: float, bank := 0.0) -> Dictionary:
	var sol := solve(p, dir, tx, tz, w, pref_deg, bank)
	if not sol.ok and bank != 0.0:
		# The bank is impossible from here: ease off the spin first, then give up on the wall.
		w *= 0.4
		sol = solve(p, dir, tx, tz, w, pref_deg, bank)
		bank = 0.0
	if not sol.ok:
		w *= 0.4
		tx *= 0.6
		sol = solve(p, dir, tx, tz, w, pref_deg)
	if not sol.ok:
		w = Vector3.ZERO
		tx = 0.0
		sol = solve(p, dir, tx, tz, w, pref_deg)
	sol["w"] = w
	sol["banked"] = bank != 0.0 and sol.ok
	return sol


## Where (x, y) the ball will cross the vertical plane at `z_plane`, travelling in direction `dir`.
## Returns Vector3(x, y, 1), or Vector3.ZERO if it never gets there.
static func predict(b: Ball, z_plane: float, dir: float) -> Vector3:
	var c := b.duplicate_ball()
	for i in 1200:
		step(c, DT)
		if (c.p.z - z_plane) * dir >= 0.0:
			return Vector3(c.p.x, c.p.y, 1.0)
		if c.p.y < FLOOR_Y or absf(c.p.x) > 400.0:
			break
	return Vector3.ZERO
