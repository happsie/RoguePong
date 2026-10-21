extends SceneTree
## Headless check that the shot solver can land a ball on the target from a spread of
## contact points, targets and spins. Run:  godot --headless --path . --script tests/solver_test.gd


func _init() -> void:
	var total := 0
	var ok := 0
	var worst := 0.0
	var worst_ms := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		var p := Vector3(rng.randf_range(-90.0, 90.0), rng.randf_range(0.0, 70.0), -14.0)
		var tx := rng.randf_range(-62.0, 62.0)
		var tz := rng.randf_range(Phys.NET_Z + 35.0, Phys.LENGTH - 14.0)
		var w := Vector3(rng.randf_range(-100.0, 100.0), rng.randf_range(-140.0, 140.0), 0.0)
		var pref := rng.randf_range(0.0, 30.0)
		var t0 := Time.get_ticks_usec()
		var sol := Phys.solve(p, 1.0, tx, tz, w, pref)
		worst_ms = maxf(worst_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		total += 1
		if not sol.ok:
			print("NO SOLUTION  p=%s target=(%.0f, %.0f) w=%s pref=%.0f" % [p, tx, tz, w, pref])
			continue
		var res := Phys.fly(p, sol.v, w, 1.0)
		var err := Vector2(res.y - tx, res.z - tz).length()
		worst = maxf(worst, err)
		if res.x == 1.0 and err < 30.0:
			ok += 1
		else:
			print("MISS  err=%.1f kind=%d" % [err, int(res.x)])
	# Pinball bank shots: off the wall, landing on the table
	Phys.walls = true
	var bank_ok := 0
	var bank_total := 40
	for i in bank_total:
		var side := signf(rng.randf() - 0.5)
		var p := Vector3(rng.randf_range(-60.0, 60.0), rng.randf_range(5.0, 60.0), -14.0)
		var tx := clampf(-side * 20.0 + rng.randf_range(-15.0, 15.0), -50.0, 50.0)
		var tz := rng.randf_range(Phys.NET_Z + 35.0, Phys.LENGTH - 14.0)
		var w := Vector3(rng.randf_range(-100.0, 100.0), side * rng.randf_range(0.0, 140.0), 0.0)
		var sol := Phys.solve_robust(p, 1.0, tx, tz, w, rng.randf_range(5.0, 30.0), side)
		if sol.banked:
			var res := Phys.fly(p, sol.v, sol.w, 1.0)
			if res.x == 1.0 and Phys.fly_hit_wall and Vector2(res.y - tx, res.z - tz).length() < 30.0:
				bank_ok += 1
				continue
		print("BANK MISS  p=%s target=(%.0f, %.0f) side=%d banked=%s" % [p, tx, tz, int(side), sol.banked])
	print("bank shots: %d/%d ricocheted and landed" % [bank_ok, bank_total])
	Phys.walls = false
	# The opponent's very wide, heavily curved shots (towards the player's end)
	var wide_ok := 0
	var wide_total := 40
	for i in wide_total:
		var side := signf(rng.randf() - 0.5)
		var p := Vector3(rng.randf_range(-50.0, 80.0), rng.randf_range(0.0, 45.0), Phys.LENGTH + 5.0)
		var tx := side * rng.randf_range(58.0, 68.0)
		var tz := rng.randf_range(45.0, Phys.NET_Z - 40.0)
		var w := Vector3(rng.randf_range(-35.0, 35.0), -side * rng.randf_range(50.0, 90.0), 0.0)
		var sol := Phys.solve(p, -1.0, tx, tz, w, rng.randf_range(8.0, 26.0))
		if sol.ok:
			var res := Phys.fly(p, sol.v, w, -1.0)
			if res.x == 1.0 and Vector2(res.y - tx, res.z - tz).length() < 30.0:
				wide_ok += 1
				continue
		print("WIDE MISS  p=%s target=(%.0f, %.0f) w=%s" % [p, tx, tz, w])
	print("wide opponent shots: %d/%d landed" % [wide_ok, wide_total])
	total += wide_total
	ok += wide_ok
	print("solver: %d/%d landed, worst error %.1f cm, slowest solve %.1f ms" % [ok, total, worst, worst_ms])
	quit(0 if ok == total else 1)
