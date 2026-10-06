class_name MountainGen
extends RefCounted

## Pure, seedable mountain layout. No nodes, no scene tree — so the
## "is every mountain climbable?" guarantee is unit-tested headlessly
## (tests/run_tests.gd) instead of being hoped for.
##
## World units are pixels, y grows downward, the trailhead sits at y = 0 and
## the summit at y = -SUMMIT_HEIGHT. 10 px = 1 m on the HUD.

enum Kind { NORMAL, SMALL, CRUMBLE, LEDGE, SUMMIT, START }
enum Item { NONE, STAR, GEM, HEART }

const REACH: float = 235.0          ## Max leap distance between two holds.
const MAIN_STEP: float = 0.82       ## Main-path hops stay under REACH * this.
const ZONE_HEIGHT: float = 1100.0
const ZONE_COUNT: int = 5
const SUMMIT_HEIGHT: float = ZONE_HEIGHT * ZONE_COUNT
const LEDGE_SPACING: float = 733.0  ## ~7 lantern ledges per mountain.
const X_MIN: float = 330.0
const X_MAX: float = 950.0
const CENTER_X: float = 640.0
const MIN_SPACING: float = 88.0

## Per-zone tuning: [crumble chance, small-hold chance, branch chance]
const ZONE_TUNING: Array = [
	[0.00, 0.05, 0.45],
	[0.08, 0.12, 0.40],
	[0.12, 0.20, 0.38],
	[0.16, 0.26, 0.36],
	[0.20, 0.30, 0.34],
]

static func zone_of(y: float) -> int:
	return clampi(int(floor(-y / ZONE_HEIGHT)), 0, ZONE_COUNT - 1)

## Build a layout. Returns Array of Dictionaries:
##   { "pos": Vector2, "kind": Kind, "item": Item, "main": bool }
## Index 0 is always the START trailhead; the last element is the SUMMIT.
static func generate(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var holds: Array = []
	holds.append(_hold(Vector2(CENTER_X, 0.0), Kind.START, Item.NONE, true))

	var cur := Vector2(CENTER_X, 0.0)
	var next_ledge_y: float = -LEDGE_SPACING
	var last_kind: int = Kind.START
	var main_indices: Array[int] = [0]

	while cur.y > -SUMMIT_HEIGHT + 160.0:
		var zone: int = zone_of(cur.y)
		var tuning: Array = ZONE_TUNING[zone]
		var dy: float = rng.randf_range(-150.0, -105.0)
		var dx: float = rng.randf_range(-165.0, 165.0)
		var nxt := Vector2(clampf(cur.x + dx, X_MIN, X_MAX), cur.y + dy)
		# If clamping pushed the hop out of reach, pull it back toward cur.
		var limit: float = REACH * MAIN_STEP
		if nxt.distance_to(cur) > limit:
			nxt = cur + (nxt - cur).normalized() * limit

		var kind: int = Kind.NORMAL
		var item: int = Item.NONE
		if nxt.y <= next_ledge_y:
			# A lantern ledge: generous, near the middle, never right after a crumble.
			nxt.y = maxf(next_ledge_y, cur.y - limit * 0.9)
			nxt.x = clampf(nxt.x, CENTER_X - 200.0, CENTER_X + 200.0)
			if nxt.distance_to(cur) > limit:
				nxt.x = cur.x + clampf(nxt.x - cur.x, -limit * 0.4, limit * 0.4)
			kind = Kind.LEDGE
			next_ledge_y -= LEDGE_SPACING
		else:
			var r: float = rng.randf()
			if r < float(tuning[0]) and last_kind != Kind.CRUMBLE and last_kind != Kind.LEDGE:
				kind = Kind.CRUMBLE
			elif r < float(tuning[0]) + float(tuning[1]):
				kind = Kind.SMALL
			if rng.randf() < 0.18:
				item = Item.STAR
		holds.append(_hold(nxt, kind, item, true))
		main_indices.append(holds.size() - 1)
		last_kind = kind
		cur = nxt

	# Summit platform, always reachable from the last main hold.
	var summit := Vector2(CENTER_X, -SUMMIT_HEIGHT)
	if summit.distance_to(cur) > REACH * MAIN_STEP:
		summit = cur + (summit - cur).normalized() * REACH * MAIN_STEP
		summit.y = minf(summit.y, cur.y - 60.0)
	# Make sure the summit is high enough to read as the top.
	holds.append(_hold(summit, Kind.SUMMIT, Item.NONE, true))
	main_indices.append(holds.size() - 1)

	# Side routes: a detour hold reachable from BOTH main[i] and main[i+1], so
	# taking it can never strand you. Detours carry the sunlight and gems.
	var hearts_placed: Dictionary = {}
	for k in range(1, main_indices.size() - 2):
		var a: Dictionary = holds[main_indices[k]]
		var b: Dictionary = holds[main_indices[k + 1]]
		var zone2: int = zone_of(a["pos"].y)
		if rng.randf() > float(ZONE_TUNING[zone2][2]):
			continue
		var mid: Vector2 = (a["pos"] + b["pos"]) * 0.5
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var tried: int = 0
		while tried < 4:
			tried += 1
			var off := Vector2(side * rng.randf_range(120.0, 190.0), rng.randf_range(-30.0, 30.0))
			var p: Vector2 = mid + off
			if p.x < X_MIN or p.x > X_MAX:
				side = -side
				continue
			if p.distance_to(a["pos"]) > REACH * 0.95 or p.distance_to(b["pos"]) > REACH * 0.95:
				continue
			if _too_close(holds, p):
				continue
			var it: int = Item.STAR
			var roll: float = rng.randf()
			if not hearts_placed.has(zone2) and roll < 0.25:
				it = Item.HEART
				hearts_placed[zone2] = true
			elif roll < 0.42:
				it = Item.GEM
			var dk: int = Kind.SMALL if rng.randf() < 0.3 else Kind.NORMAL
			holds.append(_hold(p, dk, it, false))
			break
	return holds

static func _hold(pos: Vector2, kind: int, item: int, main: bool) -> Dictionary:
	return {"pos": pos, "kind": kind, "item": item, "main": main}

static func _too_close(holds: Array, p: Vector2) -> bool:
	for h in holds:
		if (h["pos"] as Vector2).distance_to(p) < MIN_SPACING:
			return true
	return false

## Indices of holds within REACH of holds[from_index] (excluding itself).
static func neighbours(holds: Array, from_index: int) -> Array[int]:
	var out: Array[int] = []
	var p: Vector2 = holds[from_index]["pos"]
	for i in holds.size():
		if i != from_index and (holds[i]["pos"] as Vector2).distance_to(p) <= REACH:
			out.append(i)
	return out

## Breadth-first: can the summit be reached from the start without ever
## standing on a crumbling hold for long? (Crumbles are passable, they just
## break after you leave or linger, so they count as traversable.)
static func summit_reachable(holds: Array) -> bool:
	var target: int = holds.size() - 1
	for i in holds.size():
		if holds[i]["kind"] == Kind.SUMMIT:
			target = i
	var seen: Dictionary = {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == target:
			return true
		for n in neighbours(holds, cur):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return false
