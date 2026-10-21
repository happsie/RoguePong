class_name Runs
extends RefCounted
## The best runs, saved to disk and shown on the first intro card.

const PATH := "user://runs.json"
const KEEP := 5

## Each entry: {score: int, stage: int (1-based, the stage the run ended on), won: bool}.
static var top: Array[Dictionary] = []
static var _loaded := false


static func load_runs() -> void:
	if _loaded:
		return
	_loaded = true
	top.clear()
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Array:
		for e in data:
			if e is Dictionary and e.has("score") and e.has("stage"):
				top.append({"score": int(e.score), "stage": int(e.stage), "won": bool(e.get("won", false))})
	top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	top.resize(mini(top.size(), KEEP))


## Adds a finished run; returns its place (0-based) in the top list, or -1 if it didn't make it.
static func record(score: int, stage: int, won: bool) -> int:
	load_runs()
	if score <= 0:
		return -1
	var entry := {"score": score, "stage": stage, "won": won}
	var place := top.size()
	for i in top.size():
		if score > top[i].score:
			place = i
			break
	if place >= KEEP:
		return -1
	top.insert(place, entry)
	top.resize(mini(top.size(), KEEP))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(top))
	return place
