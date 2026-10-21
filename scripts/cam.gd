class_name Cam
extends RefCounted
## Fixed pinhole camera behind the player's end of the table, looking down the court.
## World axes: x = lateral (right +), y = height above the table top, z = along the table
## from the player's end (0) to the opponent's end (Phys.LENGTH).

const POS := Vector3(0.0, 130.0, -190.0)
const PITCH := 0.436
const FOCAL := 1000.0
const CENTER := Vector2(640.0, 455.0)


static func depth(p: Vector3) -> float:
	var rel := p - POS
	return maxf(1.0, rel.z * cos(PITCH) - rel.y * sin(PITCH))


## Pixels per centimetre at the depth of `p`.
static func scale_at(p: Vector3) -> float:
	return FOCAL / depth(p)


static func project(p: Vector3) -> Vector2:
	var rel := p - POS
	var up := rel.y * cos(PITCH) + rel.z * sin(PITCH)
	return CENTER + Vector2(rel.x, -up) * (FOCAL / depth(p))


## Screen point -> world (x, y) on the vertical plane at depth `z`. Used to put the paddle under the mouse.
static func unproject(screen: Vector2, z: float) -> Vector2:
	var s := sin(PITCH)
	var c := cos(PITCH)
	var sx := (screen.x - CENTER.x) / FOCAL
	var sy := -(screen.y - CENTER.y) / FOCAL
	var dir := Vector3(sx, c * sy - s, s * sy + c)
	var t := (z - POS.z) / dir.z
	return Vector2(POS.x + dir.x * t, POS.y + dir.y * t)
